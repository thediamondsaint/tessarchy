#include "../../patches/hyprland/shutdown/ScopedReadable.hpp"

#include <cerrno>
#include <iostream>
#include <stdexcept>
#include <string>
#include <sys/eventfd.h>
#include <unistd.h>
#include <vector>

using CRegistry = CScopedReadableRegistry;
using EArm = CRegistry::EArmResult;
using EOutcome = CRegistry::EOutcome;
using CFileDescriptor = Hyprutils::OS::CFileDescriptor;

static void require(bool condition, const char* message) {
    if (!condition)
        throw std::runtime_error(message);
}

struct SLoop {
    wl_event_loop* loop = wl_event_loop_create();
    SLoop() { require(loop, "event loop creation failed"); }
    ~SLoop() { wl_event_loop_destroy(loop); }
    void dispatch() { require(wl_event_loop_dispatch(loop, 0) == 0, "dispatch failed"); }
};

static CFileDescriptor event(unsigned initial = 0) {
    CFileDescriptor fd{eventfd(initial, EFD_NONBLOCK | EFD_CLOEXEC)};
    require(fd.isValid(), "eventfd failed");
    return fd;
}

static void signal(int fd) {
    const uint64_t value = 1;
    require(write(fd, &value, sizeof(value)) == sizeof(value), "eventfd write failed");
}

static void invalidFD() {
    SLoop loop;
    CRegistry registry(loop.loop);
    int calls = 0;
    auto result = registry.arm({}, [&](EOutcome) { ++calls; });
    require(result.result == EArm::INVALID_FD && !result.handle.active() && calls == 0, "invalid fd accepted");
}

static void inlineCompletion() {
    SLoop loop;
    CRegistry registry(loop.loop);
    int calls = 0;
    auto result = registry.arm(event(1), [&](EOutcome outcome) {
        require(outcome == EOutcome::READABLE && registry.size() == 0, "bad inline outcome");
        ++calls;
    });
    require(result.result == EArm::COMPLETED && !result.handle.active() && calls == 1, "inline result lost");
    loop.dispatch();
    require(calls == 1, "inline callback repeated");
}

static void deferredCompletion() {
    SLoop loop;
    CRegistry registry(loop.loop);
    auto fd = event();
    auto writer = fd.duplicate();
    int calls = 0;
    auto result = registry.arm(std::move(fd), [&](EOutcome outcome) {
        require(outcome == EOutcome::READABLE && registry.size() == 0, "not taken before callback");
        ++calls;
    });
    require(result.result == EArm::ARMED && result.handle.active(), "not armed");
    signal(writer.get());
    loop.dispatch();
    loop.dispatch();
    require(calls == 1 && !result.handle.active(), "deferred callback repeated");
}

static void cancellation() {
    SLoop loop;
    CRegistry registry(loop.loop);
    auto fd = event();
    const int owned = fd.get();
    auto writer = fd.duplicate();
    int calls = 0;
    auto result = registry.arm(std::move(fd), [&](EOutcome) { ++calls; });
    result.handle.reset();
    require(registry.size() == 0 && fcntl(owned, F_GETFD) == -1 && errno == EBADF, "cancel retained fd");
    signal(writer.get());
    loop.dispatch();
    require(calls == 0, "cancelled callback delivered");
}

static void handleMoves() {
    SLoop loop;
    CRegistry registry(loop.loop);
    auto first = registry.arm(event(), [](EOutcome) {});
    auto second = registry.arm(event(), [](EOutcome) {});
    CRegistry::CHandle moved(std::move(first.handle));
    require(!first.handle.active() && moved.active() && registry.size() == 2, "move construction failed");
    second.handle = std::move(moved);
    require(!moved.active() && second.handle.active() && registry.size() == 1, "move assignment failed");
    const auto moveAssign = [](auto& target, auto& source) { target = std::move(source); };
    moveAssign(second.handle, second.handle);
    require(second.handle.active(), "self move lost handle");
}

static void ownerLifetime() {
    SLoop loop;
    CRegistry::CHandle stale;
    {
        CRegistry registry(loop.loop);
        auto result = registry.arm(event(), [](EOutcome) { throw std::runtime_error("stale callback"); });
        stale = std::move(result.handle);
    }
    CRegistry replacement(loop.loop);
    auto result = replacement.arm(event(), [](EOutcome) {});
    stale.reset();
    require(result.handle.active() && replacement.size() == 1, "stale handle affected replacement registry");
}

static void closedRegistry() {
    SLoop loop;
    CRegistry registry(loop.loop);
    int calls = 0;
    auto pending = registry.arm(event(), [&](EOutcome) { ++calls; });
    registry.close();
    registry.close();
    auto result = registry.arm(event(1), [&](EOutcome) { ++calls; });
    require(result.result == EArm::CLOSED && !pending.handle.active() && calls == 0, "closed registry accepted work");
    loop.dispatch();
}

static void inlineOwnerDestruction() {
    SLoop loop;
    auto registry = std::make_unique<CRegistry>(loop.loop);
    int calls = 0;
    auto result = registry->arm(event(1), [&](EOutcome) { ++calls; registry.reset(); });
    require(!registry && calls == 1 && result.result == EArm::COMPLETED, "inline destruction failed");
}

static void deferredOwnerDestruction() {
    SLoop loop;
    auto registry = std::make_unique<CRegistry>(loop.loop);
    auto fd = event();
    auto writer = fd.duplicate();
    int calls = 0;
    auto result = registry->arm(std::move(fd), [&](EOutcome) { ++calls; registry.reset(); });
    auto other = registry->arm(event(), [](EOutcome) { throw std::runtime_error("cancelled sibling delivered"); });
    signal(writer.get());
    loop.dispatch();
    require(!registry && calls == 1 && !result.handle.active() && !other.handle.active(), "deferred destruction failed");
}

static void reentrantSiblingCancellation() {
    SLoop loop;
    CRegistry registry(loop.loop);
    auto fd = event();
    auto writer = fd.duplicate();
    auto siblingFD = event();
    auto siblingWriter = siblingFD.duplicate();
    CRegistry::CHandle sibling;
    int firstCalls = 0, siblingCalls = 0;
    auto first = registry.arm(std::move(fd), [&](EOutcome) { ++firstCalls; sibling.reset(); });
    auto second = registry.arm(std::move(siblingFD), [&](EOutcome) { ++siblingCalls; });
    sibling = std::move(second.handle);
    signal(writer.get());
    signal(siblingWriter.get());
    loop.dispatch();
    require(firstCalls == 1 && siblingCalls == 0 && registry.size() == 0, "sibling cancellation failed");
}

static void hangupIsFailure() {
    SLoop loop;
    CRegistry registry(loop.loop);
    int fds[2];
    require(pipe2(fds, O_NONBLOCK | O_CLOEXEC) == 0, "pipe failed");
    CFileDescriptor writer{fds[1]};
    int calls = 0;
    auto result = registry.arm(CFileDescriptor{fds[0]}, [&](EOutcome outcome) {
        require(outcome == EOutcome::ERROR, "hangup accepted as success");
        ++calls;
    });
    require(result.result == EArm::ARMED, "pipe not armed");
    require(write(writer.get(), "x", 1) == 1, "pipe write failed");
    writer.reset();
    loop.dispatch();
    require(calls == 1 && !result.handle.active(), "hangup not terminal");
}

static void initialHangup() {
    SLoop loop;
    CRegistry registry(loop.loop);
    int fds[2];
    require(pipe2(fds, O_NONBLOCK | O_CLOEXEC) == 0, "pipe failed");
    close(fds[1]);
    auto result = registry.arm(CFileDescriptor{fds[0]}, [](EOutcome) { throw std::runtime_error("initial hangup delivered"); });
    require(result.result == EArm::POLL_FAILED && registry.size() == 0, "initial hangup accepted");
}

static void registrationFailure() {
    SLoop loop;
    CRegistry registry(loop.loop);
    const int fd = fcntl(wl_event_loop_get_fd(loop.loop), F_DUPFD_CLOEXEC, 0);
    require(fd >= 0, "loop fd duplication failed");
    auto result = registry.arm(CFileDescriptor{fd}, [](EOutcome) { throw std::runtime_error("failed registration delivered"); });
    require(result.result == EArm::REGISTRATION_FAILED && registry.size() == 0, "epoll self-registration accepted");
    require(fcntl(fd, F_GETFD) == -1 && errno == EBADF, "failed registration leaked fd");
}

static void closureDestructionCancelsSibling() {
    SLoop loop;
    CRegistry registry(loop.loop);
    CRegistry::CHandle sibling;
    struct SCancelSibling {
        explicit SCancelSibling(CRegistry::CHandle* value) : handle(value) {}
        CRegistry::CHandle* handle;
        ~SCancelSibling() { handle->reset(); }
    };
    auto payload = std::make_shared<SCancelSibling>(&sibling);
    auto first = registry.arm(event(), [payload](EOutcome) { throw std::runtime_error("cancelled closure delivered"); });
    auto second = registry.arm(event(), [](EOutcome) { throw std::runtime_error("cancelled sibling delivered"); });
    sibling = std::move(second.handle);
    payload.reset();
    registry.close();
    require(!first.handle.active() && !sibling.active(), "closure destruction left an active handle");
    loop.dispatch();
}

int main() {
    const std::vector<std::pair<const char*, void (*)()>> cases = {
        {"invalid descriptor", invalidFD}, {"inline completion", inlineCompletion},
        {"deferred completion", deferredCompletion}, {"cancel closes fd", cancellation},
        {"handle moves", handleMoves}, {"owner lifetime", ownerLifetime},
        {"closed registry", closedRegistry}, {"inline owner destruction", inlineOwnerDestruction},
        {"deferred owner destruction", deferredOwnerDestruction}, {"reentrant sibling cancellation", reentrantSiblingCancellation},
        {"hangup beats readable", hangupIsFailure}, {"initial hangup", initialHangup},
        {"registration failure", registrationFailure},
        {"closure destruction cancels sibling", closureDestructionCancelsSibling},
    };
    for (const auto& [name, test] : cases) {
        try {
            test();
            std::cout << "PASS " << name << '\n';
        } catch (const std::exception& error) {
            std::cerr << "FAIL " << name << ": " << error.what() << '\n';
            return 1;
        }
    }
    std::cout << cases.size() << " native Wayland-loop tests passed\n";
}
