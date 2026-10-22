#include <hyprutils/memory/WeakPtr.hpp>
#include <cassert>
#include <cstdlib>
#include <cstdio>
#include <functional>
#include <vector>

using namespace Hyprutils::Memory;
template <typename T> using UP = CUniquePointer<T>;
template <typename T> using WP = CWeakPointer<T>;
template <typename T> using SP = CSharedPointer<T>;

static bool dependencies = true, context = false;
static int releases = 0, destroyed = 0, stopSignals = 0;
struct Listener { bool attached = false; void reset() { attached = false; } };
struct Timer { bool cancelled = false; void cancel() { cancelled = true; } };
struct Framebuffer { void release() { assert(dependencies && context); ++releases; } };
struct Frame { bool m_failed = false; std::function<void()> m_callback; };
struct Session {
    bool m_stopped = false, m_sharing = true;
    struct { Listener monitor, window; } m_listeners;
    SP<Timer> m_shareStopTimer = makeShared<Timer>();
    SP<Framebuffer> m_tempFB = makeShared<Framebuffer>();
    ~Session() { ++destroyed; if (!m_stopped) { assert(dependencies); ++stopSignals; } }
};
struct Cursor {
    bool m_stopped = false;
    struct { Listener pointer, cursor; } m_listeners;
    struct { bool pending = false; std::function<void()> callback; } m_pendingFrame;
};
struct Managed { UP<Session> m_session = makeUnique<Session>(); Listener stoppedListener; };
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

constexpr int EGL_NO_DISPLAY = 0, EGL_NO_CONTEXT = 0, EGL_NO_SURFACE = 0, EGL_TRUE = 1, GL_NO_ERROR = 0;
struct GL { int m_eglDisplay = 4, m_eglContext = 8; };
static UP<GL> g_pHyprOpenGL;
static bool bindOK = true;
static int currentDisplay = 4, currentContext = 8, resetStatus = GL_NO_ERROR, bindCalls = 0;
static int eglMakeCurrent(int display, int, int, int ctx) { assert(display == 4 && ctx == 8); ++bindCalls; return bindOK; }
static int eglGetCurrentContext() { return currentContext; }
static int eglGetCurrentDisplay() { return currentDisplay; }
static int glGetGraphicsResetStatus() { return resetStatus; }
class CHyprGLRenderer {
  public:
    struct SSubmittedResources { std::vector<SP<Framebuffer>> explicitReleases; };
    static bool checkedContext();
    static bool retireResources(SSubmittedResources& resources);
};

#include "shutdown-methods.inc"

int main() {
    {
        CScreenshareManager manager;
        auto managed = makeUnique<Managed>();
        auto protocol = makeUnique<Session>();
        auto cursor = makeUnique<Cursor>();
        auto frame = makeUnique<Frame>();
        auto timer = managed->m_session->m_shareStopTimer;
        managed->stoppedListener.attached = true;
        managed->m_session->m_listeners.monitor.attached = true;
        protocol->m_listeners.window.attached = true;
        cursor->m_listeners.cursor.attached = true;
        cursor->m_pendingFrame.pending = true;
        cursor->m_pendingFrame.callback = [] { assert(false); };
        frame->m_callback = [] { assert(false); };
        manager.m_sessions.emplace_back(managed->m_session);
        manager.m_sessions.emplace_back(protocol);
        manager.m_sessions.emplace_back();
        manager.m_cursorSessions.emplace_back(cursor);
        manager.m_cursorSessions.emplace_back();
        manager.m_pendingFrames.emplace_back(frame);
        manager.m_pendingFrames.emplace_back();
        manager.m_managedSessions.emplace_back(std::move(managed));
        manager.quiesceForShutdown();
        assert(manager.m_shutdown && manager.m_managedSessions.size() == 1 && destroyed == 0);
        assert(!manager.m_managedSessions[0]->stoppedListener.attached);
        assert(manager.m_managedSessions[0]->m_session->m_stopped && !manager.m_managedSessions[0]->m_session->m_sharing);
        assert(!manager.m_managedSessions[0]->m_session->m_listeners.monitor.attached);
        assert(protocol->m_stopped && !protocol->m_listeners.window.attached);
        assert(timer->cancelled && !manager.m_managedSessions[0]->m_session->m_shareStopTimer);
        assert(frame->m_failed && !frame->m_callback && cursor->m_stopped && !cursor->m_listeners.cursor.attached);
        assert(!cursor->m_pendingFrame.pending && !cursor->m_pendingFrame.callback && releases == 0 && stopSignals == 0);
        manager.quiesceForShutdown();
        assert(manager.m_managedSessions.size() == 1 && destroyed == 0);
        std::puts("PASS actual quiesce method detaches producers and retains unique owners silently");
        context = true;
        manager.releaseShutdownResources();
        assert(releases == 2 && destroyed == 1 && stopSignals == 0);
        assert(!protocol->m_tempFB && manager.m_sessions.empty() && manager.m_managedSessions.empty());
        assert(manager.m_pendingFrames.empty() && manager.m_cursorSessions.empty() && manager.m_shutdown);
        dependencies = false;
        protocol.reset();
        assert(destroyed == 2 && stopSignals == 0);
        std::puts("PASS actual release method explicitly releases FBs before dependency loss and late protocol destruction");
    }
    dependencies = true;
    assert(!CHyprGLRenderer::checkedContext());
    g_pHyprOpenGL = makeUnique<GL>();
    g_pHyprOpenGL->m_eglDisplay = EGL_NO_DISPLAY;
    assert(!CHyprGLRenderer::checkedContext());
    g_pHyprOpenGL->m_eglDisplay = 4;
    g_pHyprOpenGL->m_eglContext = EGL_NO_CONTEXT;
    assert(!CHyprGLRenderer::checkedContext());
    g_pHyprOpenGL->m_eglContext = 8;
    assert(bindCalls == 0);
    bindOK = false;
    assert(!CHyprGLRenderer::checkedContext());
    bindOK = true; currentContext = 9;
    assert(!CHyprGLRenderer::checkedContext());
    currentContext = 8; currentDisplay = 5;
    assert(!CHyprGLRenderer::checkedContext());
    currentDisplay = 4; resetStatus = 1;
    assert(!CHyprGLRenderer::checkedContext());
    std::puts("PASS actual context method rejects absent GL/display/context, failed binding, wrong current binding and reset");
    CHyprGLRenderer::SSubmittedResources resources;
    resources.explicitReleases.emplace_back(makeShared<Framebuffer>());
    const auto before = releases;
    assert(!CHyprGLRenderer::retireResources(resources));
    assert(resources.explicitReleases.size() == 1 && releases == before);
    resetStatus = GL_NO_ERROR;
    assert(CHyprGLRenderer::retireResources(resources));
    assert(resources.explicitReleases.empty() && releases == before + 1);
    assert(CHyprGLRenderer::retireResources(resources) && releases == before + 1);
    std::puts("PASS actual retirement method retains explicit-release owners on context failure and releases once after success");
    std::puts("4 source-method shutdown mock groups passed; no actual EGL/GL execution");
}
