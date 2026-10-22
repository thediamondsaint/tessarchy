#include <hyprutils/memory/WeakPtr.hpp>
#include <hyprutils/signal/Signal.hpp>
#include <wayland-server-core.h>
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <vector>
#include <stdexcept>
#include <sys/wait.h>
#include <unistd.h>
#include "ShutdownSequence.hpp"
using namespace Hyprutils::Memory;
using namespace Hyprutils::Signal;
template <typename T> using UP = CUniquePointer<T>;
template <typename T> using WP = CWeakPointer<T>;
template <typename T> using SP = CSharedPointer<T>;
static int destroyed = 0, events = 0, releases = 0, cancelled = 0, probes = 0;
static bool dependencies = true;
static int auditFd = -1;
static void audit(char marker) { if (auditFd >= 0) assert(write(auditFd, &marker, 1) == 1); }
struct Probe { std::function<void()> check; ~Probe() { ++probes; check(); } };
struct Timer {
    wl_event_source* source;
    SP<Probe> probe;
    explicit Timer(wl_event_loop* loop) : source(wl_event_loop_add_timer(loop, [](void*) { ++events; return 0; }, nullptr)) {
        assert(source && wl_event_source_timer_update(source, 1) == 0);
    }
    void cancel() { if (source) { wl_event_source_remove(source); source = nullptr; ++cancelled; } }
    ~Timer() { cancel(); }
};
struct Framebuffer { void release() { assert(dependencies); audit('R'); ++releases; } };
struct Session {
    bool m_stopped = false, m_sharing = true;
    struct { CHyprSignalListener monitor, window; } m_listeners;
    SP<Timer> m_shareStopTimer;
    SP<Framebuffer> m_tempFB = makeShared<Framebuffer>();
    ~Session() { assert(m_stopped && !m_sharing && "all native owners must be inert before callback destruction"); ++destroyed; audit('D'); }
};
struct Cursor {
    bool m_stopped = false;
    struct { CHyprSignalListener pointer, cursor; } m_listeners;
    struct { bool pending = false; std::function<void()> callback; } m_pendingFrame;
    ~Cursor() { assert(m_stopped && "all cursor owners must be inert before callback destruction"); }
};
struct Frame { bool m_failed = false; std::function<void()> m_callback; };
struct Managed { UP<Session> m_session = makeUnique<Session>(); CHyprSignalListener stoppedListener; };
class CScreenshareManager {
  public:
    bool m_shutdown = false;
    std::vector<UP<Managed>> m_managedSessions;
    std::vector<WP<Session>> m_sessions;
    std::vector<WP<Cursor>> m_cursorSessions;
    std::vector<WP<Frame>> m_pendingFrames;
    void quiesceForShutdown();
    void releaseShutdownResources();
};
#include "teardown-methods.inc"
int main() {
    for (int phase = 0; phase < 6; ++phase) {
        for (bool destroyPeers : {false, true}) {
            const auto before = probes;
            auto* loop = wl_event_loop_create();
            assert(loop);
            CScreenshareManager manager;
            auto managed = makeUnique<Managed>();
            auto ordinary = makeUnique<Session>();
            auto cursor = makeUnique<Cursor>();
            auto frame = makeUnique<Frame>();
            auto peer = makeUnique<Session>();
            auto peerCursor = makeUnique<Cursor>();
            auto peerFrame = makeUnique<Frame>();
            cursor->m_pendingFrame.pending = true;
            CSignalT<> signal;
            managed->m_session->m_shareStopTimer = makeShared<Timer>(loop);
            ordinary->m_shareStopTimer = makeShared<Timer>(loop);
            managed->stoppedListener = signal.listen([] { ++events; });
            ordinary->m_listeners.monitor = signal.listen([] { ++events; });
            cursor->m_listeners.cursor = signal.listen([] { ++events; });
            peer->m_listeners.window = signal.listen([] { ++events; });
            peerCursor->m_listeners.pointer = signal.listen([] { ++events; });
            manager.m_sessions = {managed->m_session, ordinary, peer, {}};
            manager.m_cursorSessions = {cursor, peerCursor, {}};
            manager.m_pendingFrames = {frame, peerFrame, {}};
            manager.m_managedSessions.emplace_back(std::move(managed));
            auto probe = makeShared<Probe>();
            probe->check = [&] {
                assert(manager.m_shutdown);
                for (auto& s : manager.m_sessions)
                    assert(!s || (s->m_stopped && !s->m_sharing && "all native owners must be inert before callback destruction"));
                for (auto& s : manager.m_cursorSessions)
                    assert(!s || (s->m_stopped && "all cursor owners must be inert before callback destruction"));
                for (auto& f : manager.m_pendingFrames)
                    assert(!f || (f->m_failed && "all frames must be failed before callback destruction"));
                manager.quiesceForShutdown();
                assert(manager.m_managedSessions.size() == 1 && releases == 0);
                if (destroyPeers) { peer.reset(); peerCursor.reset(); peerFrame.reset(); }
            };
            if (phase == 0) manager.m_managedSessions[0]->stoppedListener = signal.listen([probe] {});
            if (phase == 1) ordinary->m_listeners.monitor = signal.listen([probe] {});
            if (phase == 2) ordinary->m_shareStopTimer->probe = probe;
            if (phase == 3) cursor->m_listeners.cursor = signal.listen([probe] {});
            if (phase == 4) frame->m_callback = [probe] {};
            if (phase == 5) cursor->m_pendingFrame.callback = [probe] {};
            probe.reset();
            NativeShutdown::CShutdownSequence sequence;
            const auto expectedReleases = destroyPeers ? 2 : 3;
            sequence.run(NativeShutdown::CShutdownSequence::Clock::now(), [&] {
                manager.quiesceForShutdown();
                assert(probes == before + 1);
                signal.emit();
                assert(wl_event_loop_dispatch(loop, 2) == 0 && events == 0);
                assert(!ordinary->m_shareStopTimer && !cursor->m_pendingFrame.pending && !frame->m_callback);
                manager.quiesceForShutdown();
            }, [&](auto) {
                assert(releases == 0 && dependencies && manager.m_managedSessions.size() == 1);
                assert(ordinary->m_tempFB && manager.m_managedSessions[0]->m_session->m_tempFB);
                return true;
            }, [&] {
                manager.releaseShutdownResources();
                assert(releases == expectedReleases);
                manager.releaseShutdownResources();
                assert(releases == expectedReleases && manager.m_shutdown);
            }, [&] {
                dependencies = false;
                peer.reset(); peerCursor.reset(); peerFrame.reset();
                ordinary.reset(); cursor.reset(); frame.reset();
            });
            assert(sequence.state() == NativeShutdown::CShutdownSequence::EState::COMPLETE);
            assert(manager.m_sessions.empty() && manager.m_cursorSessions.empty() && manager.m_pendingFrames.empty());
            wl_event_loop_destroy(loop);
            dependencies = true;
            releases = 0;
            std::printf("PASS teardown closure phase=%d destroy-peers=%d: inert peers, recursive quiesce, detached signals/timers, late destruction\n", phase, destroyPeers);
        }
    }
    assert(cancelled == 24 && destroyed == 36 && probes == 12);
    std::fflush(stdout);
    for (bool throwDrain : {false, true}) {
        int channel[2];
        assert(pipe(channel) == 0);
        const auto child = fork();
        assert(child >= 0);
        if (child == 0) {
            close(channel[0]);
            auditFd = channel[1];
            CScreenshareManager manager;
            auto managed = makeUnique<Managed>();
            manager.m_sessions.emplace_back(managed->m_session);
            manager.m_managedSessions.emplace_back(std::move(managed));
            NativeShutdown::CShutdownSequence sequence;
            sequence.run(NativeShutdown::CShutdownSequence::Clock::now(), [&] {
                manager.quiesceForShutdown();
            }, [&](auto) -> bool {
                assert(manager.m_shutdown && manager.m_managedSessions.size() == 1 && manager.m_managedSessions[0]->m_session->m_tempFB);
                if (throwDrain) throw std::runtime_error("injected drain failure");
                return false;
            }, [&] { manager.releaseShutdownResources(); }, [] { audit('T'); });
            std::_Exit(42);
        }
        close(channel[1]);
        int status = 0;
        assert(waitpid(child, &status, 0) == child && WIFEXITED(status) && WEXITSTATUS(status) == EXIT_FAILURE);
        char marker = 0;
        assert(read(channel[0], &marker, 1) == 0 && "failed drain must not release resources, destroy owners or tear down dependencies");
        close(channel[0]);
        std::printf("PASS actual quiesced owners survive fail-stop without unwind: drain-throws=%d\n", throwDrain);
    }
    std::puts("14 actual-source teardown cases passed; real Hyprutils ownership/signals and Wayland timers; no compositor/GPU");
}
