#include "../../patches/hyprland/shutdown/ShutdownSequence.hpp"
#include "../../patches/hyprland/shutdown/SubmittedWork.hpp"
#include <cassert>
#include <cstdio>
#include <sys/eventfd.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

using namespace NativeShutdown;
using namespace NativeRetirement;
using FD = Hyprutils::OS::CFileDescriptor;
static auto deadline() { return Clock::now() + std::chrono::seconds(1); }
static void run(const char* name, void (*test)(), int expected = 0) {
    std::fflush(nullptr);
    const auto pid = fork();
    assert(pid >= 0);
    if (!pid) {
        test();
        _exit(0);
    }
    int status = 0;
    assert(waitpid(pid, &status, 0) == pid);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == expected);
    std::printf("PASS %s\n", name);
}
struct NoUnwind {
    ~NoUnwind() { _exit(99); }
};
struct Target {
    bool* retired;
    bool* context;
    int* releases;
    void release() { assert(*retired && *context); ++*releases; }
};
struct Payload {
    std::shared_ptr<Target> transient;
    bool explicitRelease = false;
};
using Queue = CSubmittedWork<Payload>;

static void failedCleanup() {
    NoUnwind owner;
    CShutdownSequence sequence;
    sequence.run(deadline(), [] {}, [](auto) { return false; }, [] { _exit(98); }, [] { _exit(97); });
    _exit(96);
}

int main() {
    run("quiesce then drain then explicit release then dependency teardown", [] {
        CShutdownSequence sequence;
        std::vector<int> order;
        const auto limit = deadline();
        sequence.run(limit, [&] { order.push_back(1); }, [&](auto actual) { assert(actual == limit); order.push_back(2); return true; },
                     [&] { order.push_back(3); }, [&] { order.push_back(4); });
        assert((order == std::vector<int>{1, 2, 3, 4}));
        assert(sequence.state() == CShutdownSequence::EState::COMPLETE);
        sequence.run(limit, [] { assert(false); }, [](auto) { assert(false); return false; }, [] { assert(false); }, [] { assert(false); });
    });
    run("main cleanup failure exits nonzero without owner unwind", failedCleanup, EXIT_FAILURE);
    run("destructor fallback failure exits nonzero without owner unwind", [] {
        struct Fallback { ~Fallback() { failedCleanup(); } } fallback;
    }, EXIT_FAILURE);
    run("quiescence exception cannot unwind or tear down", [] {
        NoUnwind owner;
        CShutdownSequence s;
        s.run(deadline(), [] { throw 1; }, [](auto) { _exit(98); return true; }, [] { _exit(97); }, [] { _exit(96); });
    }, EXIT_FAILURE);
    run("drain exception cannot unwind or release dependencies", [] {
        NoUnwind owner;
        CShutdownSequence s;
        s.run(deadline(), [] {}, [](auto) -> bool { throw 1; }, [] { _exit(98); }, [] { _exit(97); });
    }, EXIT_FAILURE);
    run("release exception cannot unwind or reach dependent teardown", [] {
        NoUnwind owner;
        CShutdownSequence s;
        s.run(deadline(), [] {}, [](auto) { return true; }, [] { throw 1; }, [] { _exit(98); });
    }, EXIT_FAILURE);
    run("teardown exception is a nonzero outcome", [] {
        NoUnwind owner;
        CShutdownSequence s;
        s.run(deadline(), [] {}, [](auto) { return true; }, [] {}, [] { throw 1; });
    }, EXIT_FAILURE);
    run("recursive cleanup fails before duplicate quiescence", [] {
        NoUnwind owner;
        CShutdownSequence s;
        s.run(deadline(), [&] {
            s.run(deadline(), [] { _exit(98); }, [](auto) { return true; }, [] {}, [] {});
        }, [](auto) { return true; }, [] {}, [] {});
    }, EXIT_FAILURE);
    run("cancel all delivery retains transient target until checked drain and explicit release", [] {
        auto* loop = wl_event_loop_create();
        CScopedReadableRegistry registry(loop);
        bool complete = false, context = false, retired = false;
        int releases = 0, callbacks = 0;
        Queue q([&](int) { return complete ? EFence::COMPLETE : EFence::ACTIVE; }, [&](Payload& payload) {
            assert(complete && context);
            retired = true;
            if (payload.explicitRelease)
                payload.transient->release();
            return true;
        });
        auto target = std::make_shared<Target>(Target{&retired, &context, &releases});
        std::weak_ptr<Target> weak = target;
        for (int i = 0; i < 2; ++i) {
            const auto id = q.submit({target, i == 1}, FD{eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC)}, [&] { ++callbacks; });
            q.arm(id, [&](FD fd, auto callback) { return registry.arm(std::move(fd), std::move(callback)); });
        }
        CShutdownSequence sequence;
        sequence.run(deadline(), [&] {
            q.cancelAllDelivery();
            assert(registry.size() == 0 && q.size() == 2 && target.use_count() == 3);
        }, [&](auto limit) {
            // Injected fence completion and context: no GPU proof is asserted.
            complete = true; context = true;
            retired = q.drain(limit);
            return retired;
        }, [&] {
            assert(callbacks == 0 && q.size() == 0 && target.use_count() == 1 && releases == 1);
            target.reset();
        }, [&] { assert(releases == 1 && weak.expired()); context = false; });
        registry.close(); wl_event_loop_destroy(loop);
    });
    run("failed fence preserves target and skips explicit release", [] {
        NoUnwind owner;
        bool retired = false, context = true;
        int releases = 0;
        Queue q;
        auto target = std::make_shared<Target>(Target{&retired, &context, &releases});
        q.submit({target}, FD{eventfd(1, EFD_NONBLOCK | EFD_CLOEXEC)}, [] { _exit(98); });
        CShutdownSequence s;
        s.run(deadline(), [&] { q.cancelAllDelivery(); }, [&](auto limit) {
            // Real kernel rejects eventfd as sync_file; no synthetic success probe.
            assert(!q.drain(limit) && q.size() == 1 && target.use_count() == 2 && releases == 0);
            return false;
        }, [&] { target->release(); _exit(97); }, [] { _exit(96); });
    }, EXIT_FAILURE);
    run("retirement context failure quarantines transient owners despite completed fence", [] {
        bool retired = true, context = false;
        int releases = 0;
        auto target = std::make_shared<Target>(Target{&retired, &context, &releases});
        Queue q([](int) { return EFence::COMPLETE; }, [&](Payload&) { return context; });
        const auto id = q.submit({target, true}, FD{eventfd(1, EFD_NONBLOCK | EFD_CLOEXEC)}, [] { _exit(98); });
        assert(!q.drain(deadline()) && q.failed(id) && target.use_count() == 2 && releases == 0);
        _exit(0);
    });
    run("active fence never invokes explicit release hook", [] {
        int releases = 0;
        Queue q([](int) { return EFence::ACTIVE; }, [&](Payload&) { ++releases; return true; });
        q.submit({}, FD{eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC)}, [] { _exit(98); });
        assert(!q.drain(deadline(), [](int, auto) { return false; }) && releases == 0 && q.size() == 1);
        _exit(0);
    });
    run("native invalid fence never invokes release hook", [] {
        int releases = 0;
        Queue q(nativeFenceStatus, [&](Payload&) { ++releases; return true; });
        q.submit({}, {}, [] { _exit(98); });
        assert(!q.drain(deadline()) && releases == 0 && q.size() == 1);
        _exit(0);
    });
    run("Wayland completion releases explicitly before success notification", [] {
        auto* loop = wl_event_loop_create();
        CScopedReadableRegistry registry(loop);
        int released = 0, delivered = 0;
        Queue q([](int) { return EFence::COMPLETE; }, [&](Payload&) { ++released; return true; });
        const auto id = q.submit({}, FD{eventfd(1, EFD_NONBLOCK | EFD_CLOEXEC)}, [&] { assert(released == 1 && q.size() == 0); ++delivered; });
        q.arm(id, [&](FD fd, auto callback) { return registry.arm(std::move(fd), std::move(callback)); });
        assert(released == 1 && delivered == 1 && q.size() == 0);
        registry.close(); wl_event_loop_destroy(loop);
    });
    std::puts("14 shutdown-sequence cases passed");
}
