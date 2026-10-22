#include "../../patches/hyprland/shutdown/SubmittedWork.hpp"
#include <cassert>
#include <cstdio>
#include <sys/eventfd.h>
#include <sys/wait.h>
#include <unistd.h>

using namespace NativeRetirement;
using FD = Hyprutils::OS::CFileDescriptor;
struct Resources {
    std::shared_ptr<int> source, destination, target;
};
using Queue = CSubmittedWork<Resources>;

static FD fence(bool ready = false) { return FD{eventfd(ready ? 1 : 0, EFD_CLOEXEC | EFD_NONBLOCK)}; }
static auto future() { return Clock::now() + std::chrono::seconds(1); }
static void run(const char* name, void (*test)()) {
    const auto pid = fork();
    assert(pid >= 0);
    if (pid == 0) {
        test();
        _exit(0);
    }
    int status = 0;
    assert(waitpid(pid, &status, 0) == pid);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
    std::printf("PASS %s\n", name);
}

int main() {
    run("cancelled waiter retains all three resource roles until checked retirement", [] {
        auto* loop = wl_event_loop_create();
        CScopedReadableRegistry registry(loop);
        bool complete = false;
        Queue q([&](int) { return complete ? EFence::COMPLETE : EFence::ACTIVE; });
        auto source = std::make_shared<int>(1), destination = std::make_shared<int>(2), target = std::make_shared<int>(3);
        std::weak_ptr<int> s = source, d = destination, t = target;
        int delivered = 0;
        const auto id = q.submit({source, destination, target}, fence(), [&] { ++delivered; });
        source.reset(); destination.reset(); target.reset();
        q.arm(id, [&](FD fd, auto fn) { return registry.arm(std::move(fd), std::move(fn)); });
        assert(registry.size() == 1);
        q.cancelDelivery(id);
        assert(registry.size() == 0 && q.size() == 1);
        assert(!s.expired() && !d.expired() && !t.expired());
        complete = true;
        assert(q.drain(future()));
        assert(s.expired() && d.expired() && t.expired() && delivered == 0);
        registry.close(); wl_event_loop_destroy(loop);
    });
    run("registry destruction does not own submitted payload", [] {
        auto* loop = wl_event_loop_create();
        Queue q([](int) { return EFence::COMPLETE; });
        auto target = std::make_shared<int>(7);
        std::weak_ptr<int> weak = target;
        const auto id = q.submit({{}, {}, target}, fence(), {});
        target.reset();
        {
            CScopedReadableRegistry registry(loop);
            q.arm(id, [&](FD fd, auto fn) { return registry.arm(std::move(fd), std::move(fn)); });
        }
        assert(!weak.expired() && q.size() == 1);
        assert(q.drain(future()));
        assert(weak.expired());
        wl_event_loop_destroy(loop);
    });
    run("inline completion consumes ownership before reentrant notification", [] {
        auto* loop = wl_event_loop_create();
        CScopedReadableRegistry registry(loop);
        auto q = std::make_unique<Queue>([](int) { return EFence::COMPLETE; });
        const auto id = q->submit({}, fence(true), [&] { assert(q->size() == 0); q.reset(); });
        q->arm(id, [&](FD fd, auto fn) { return registry.arm(std::move(fd), std::move(fn)); });
        assert(!q);
        registry.close(); wl_event_loop_destroy(loop);
    });
    run("readability alone never retires active fence", [] {
        auto* loop = wl_event_loop_create();
        CScopedReadableRegistry registry(loop);
        bool complete = false;
        Queue q([&](int) { return complete ? EFence::COMPLETE : EFence::ACTIVE; });
        int delivered = 0;
        const auto id = q.submit({}, fence(true), [&] { ++delivered; });
        q.arm(id, [&](FD fd, auto fn) { return registry.arm(std::move(fd), std::move(fn)); });
        assert(q.size() == 1 && delivered == 0);
        complete = true;
        assert(q.drain(future()) && delivered == 1);
        registry.close(); wl_event_loop_destroy(loop);
    });
    run("deferred real Wayland readability performs checked exactly-once retirement", [] {
        auto* loop = wl_event_loop_create();
        CScopedReadableRegistry registry(loop);
        bool complete = false;
        int delivered = 0;
        Queue q([&](int) { return complete ? EFence::COMPLETE : EFence::ACTIVE; });
        auto fd = fence();
        auto trigger = fd.duplicate();
        const auto id = q.submit({}, std::move(fd), [&] { assert(q.size() == 0); ++delivered; });
        q.arm(id, [&](FD waitFD, auto fn) { return registry.arm(std::move(waitFD), std::move(fn)); });
        complete = true;
        uint64_t value = 1;
        assert(write(trigger.get(), &value, sizeof(value)) == sizeof(value));
        assert(wl_event_loop_dispatch(loop, 0) == 0);
        assert(q.size() == 0 && delivered == 1 && registry.size() == 0);
        assert(wl_event_loop_dispatch(loop, 0) == 0 && delivered == 1);
        registry.close(); wl_event_loop_destroy(loop);
    });
    run("negative native completion status retains owners", [] {
        auto* loop = wl_event_loop_create();
        CScopedReadableRegistry registry(loop);
        Queue q([](int) { return EFence::ERROR; });
        const auto id = q.submit({}, fence(true), [] { assert(false); });
        q.arm(id, [&](FD fd, auto fn) { return registry.arm(std::move(fd), std::move(fn)); });
        assert(q.failed(id) && q.size() == 1 && !q.drain(future()));
        _exit(0);
    });
    run("native ioctl rejects eventfd and invalid descriptor", [] {
        auto fd = fence(true);
        assert(nativeFenceStatus(fd.get()) == EFence::ERROR);
        assert(nativeFenceStatus(-1) == EFence::ERROR);
    });
    run("native error quarantines payload and suppresses success", [] {
        Queue q;
        auto held = std::make_shared<int>(8);
        const auto id = q.submit({held, held, held}, fence(true), [] { assert(false); });
        assert(!q.drain(future()) && q.failed(id) && q.size() == 1);
        assert(held.use_count() == 4);
        // The child deliberately exits without unwinding unresolved GPU ownership.
        _exit(0);
    });
    run("registration failure quarantines instead of releasing", [] {
        Queue q([](int) { return EFence::COMPLETE; });
        const auto id = q.submit({}, fence(), [] { assert(false); });
        q.arm(id, [](FD, auto) { return CScopedReadableRegistry::SRegistration{CScopedReadableRegistry::EArmResult::CLOSED, {}}; });
        assert(q.failed(id) && !q.drain(future()) && q.size() == 1);
        _exit(0);
    });
    run("one absolute deadline is shared by every record", [] {
        int probes = 0, waits = 0;
        Queue q([&](int) { return ++probes % 2 == 1 ? EFence::ACTIVE : EFence::COMPLETE; });
        q.submit({}, fence(), {}); q.submit({}, fence(), {});
        const auto deadline = future();
        assert(q.drain(deadline, [&](int, Deadline actual) { ++waits; assert(actual == deadline); return true; }));
        assert(waits == 2 && q.size() == 0);
    });
    run("timeout retains submitted work and can be retried", [] {
        bool complete = false;
        Queue q([&](int) { return complete ? EFence::COMPLETE : EFence::ACTIVE; });
        q.submit({}, fence(), {});
        assert(!q.drain(future(), [](int, Deadline) { return false; }) && q.size() == 1);
        complete = true;
        assert(q.drain(future()));
    });
    run("expired deadline does not wait", [] {
        auto fd = fence();
        assert(!waitNativeFence(fd.get(), Clock::now()));
        assert(!waitNativeFence(-1, future()));
    });
    run("unresolved destructor fails before payload unwinding", [] {
        const auto pid = fork();
        assert(pid >= 0);
        if (!pid) {
            std::set_terminate([] { _exit(42); });
            Queue q;
            q.submit({}, fence(), {});
            // Exercise the fail-stop destructor, not a compositor or GPU.
            return;
        }
        int status = 0;
        assert(waitpid(pid, &status, 0) == pid);
        assert(WIFEXITED(status) && WEXITSTATUS(status) == 42);
    });
    std::puts("13 submitted-work cases passed");
}
