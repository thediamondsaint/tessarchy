#include <hyprutils/memory/SharedPtr.hpp>
#include <hyprutils/utils/ScopeGuard.hpp>
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <memory>
#include <sys/eventfd.h>
#include <sys/wait.h>
#include <unistd.h>
#include "SubmittedWork.hpp"

using Hyprutils::OS::CFileDescriptor;
using Hyprutils::Utils::CScopeGuard;
template<typename T> using SP = Hyprutils::Memory::CSharedPointer<T>;
using Hyprutils::Memory::makeShared;
#define LIKELY(x) (x)
static int releases = 0, unbinds = 0, flushes = 0, imports = 0, completions = 0;
static bool contextOK = true;
struct Releaser { void addSyncFileFd(const CFileDescriptor& fd) { assert(fd.isValid()); ++imports; } };
struct IHLBuffer { virtual ~IHLBuffer() = default; std::vector<SP<Releaser>> m_syncReleasers; };
namespace Aquamarine { using IBuffer = IHLBuffer; }
struct CHLBufferReference {
    SP<IHLBuffer> buffer;
    CHLBufferReference() = default;
    explicit CHLBufferReference(SP<IHLBuffer> value) : buffer(std::move(value)) {}
    IHLBuffer* operator->() const { return buffer.get(); }
};
struct IFramebuffer { void release() { assert(contextOK); ++releases; } };
struct IRenderbuffer { void unbind() { ++unbinds; } };
struct OutputState {
    int buffers = 0, fences = 0, resets = 0;
    void setBuffer(SP<IHLBuffer>) { ++buffers; }
    void setExplicitInFence(int fd) { assert(fd >= 0); ++fences; }
    void resetExplicitFences() { ++resets; }
};
struct Output { SP<OutputState> state = makeShared<OutputState>(); };
struct Monitor { SP<Output> m_output = makeShared<Output>(); CFileDescriptor m_inFence; };
struct RenderData {
    SP<Monitor> pMonitor;
    int damage = 5;
    float mouseZoomFactor = 2.f;
    bool mouseZoomUseMouse = false;
    SP<IFramebuffer> currentFB, mainFB, outFB;
};
struct Renderer { RenderData m_renderData; };
static Renderer* g_pHyprRenderer;
struct GL { int ends = 0; void end() { ++ends; } };
static GL* g_pHyprOpenGL;
static void glFlush() { ++flushes; }
namespace Log { enum { ERR }; struct Logger { void log(int, const char*) {} }; static Logger instance; static Logger* logger = &instance; }
struct Loop {
    wl_event_loop* loop = wl_event_loop_create();
    CScopedReadableRegistry registry{loop};
    CFileDescriptor signal;
    ~Loop() { registry.close(); wl_event_loop_destroy(loop); }
    auto doOnReadableScoped(CFileDescriptor fd, CScopedReadableRegistry::FCallback callback) {
        signal = fd.duplicate();
        return registry.arm(std::move(fd), std::move(callback));
    }
    void pulse() {
        const uint64_t value = 1;
        assert(write(signal.get(), &value, sizeof(value)) == sizeof(value));
        assert(wl_event_loop_dispatch(loop, 0) == 0);
    }
};
static Loop* g_pEventLoopManager;
struct Sync {
    bool valid;
    CFileDescriptor descriptor{eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK)};
    bool isValid() { return valid; }
    CFileDescriptor& fd() { return descriptor; }
    CFileDescriptor takeFd() { return std::move(descriptor); }
};
enum { RENDER_MODE_NORMAL, RENDER_MODE_FULL_FAKE, RENDER_MODE_TO_BUFFER, RENDER_MODE_TO_BUFFER_READ_ONLY };
class CHyprGLRenderer {
  public:
    struct SSubmittedResources {
        std::vector<CHLBufferReference> sources;
        CHLBufferReference destinationLock;
        SP<Aquamarine::IBuffer> destination;
        SP<IRenderbuffer> renderbuffer;
        SP<IFramebuffer> currentFB, mainFB, outFB;
        std::vector<SP<IFramebuffer>> explicitReleases;
    };
    static bool checkedContext() { return contextOK; }
    static bool retireResources(SSubmittedResources& resources);
    NativeRetirement::EFence fenceStatus = NativeRetirement::EFence::ACTIVE;
    NativeRetirement::CSubmittedWork<SSubmittedResources> m_submittedWork{
        [this](int fd) { return fd < 0 ? NativeRetirement::EFence::ERROR : fenceStatus; }, retireResources};
    bool m_shutdownDrain = false, outputExplicit = false;
    int syncKind = 1, m_renderMode = RENDER_MODE_NORMAL;
    RenderData m_renderData;
    struct { int render(int damage) { return damage + 1; } } m_renderPass;
    SP<IHLBuffer> m_currentBuffer;
    SP<IRenderbuffer> m_currentRenderbuffer;
    std::vector<CHLBufferReference> m_usedAsyncBuffers;
    std::vector<SP<IFramebuffer>> m_pendingFBReleases;
    bool explicitSyncSupported() { return outputExplicit; }
    std::unique_ptr<Sync> createSyncFDManager() {
        if (syncKind == 0) return {};
        auto result = std::make_unique<Sync>(); result->valid = syncKind == 1; return result;
    }
    void endRender(const std::function<void()>& renderingDoneCallback);
};
#include "render-submission.inc"

static void scenario(int mode, bool explicitOutput, int syncKind, bool releaseContext, bool cancelDelivery) {
    Loop loop; g_pEventLoopManager = &loop;
    Renderer frontend; g_pHyprRenderer = &frontend;
    GL gl; g_pHyprOpenGL = &gl;
    CHyprGLRenderer renderer;
    renderer.m_renderMode = mode; renderer.outputExplicit = explicitOutput; renderer.syncKind = syncKind;
    auto monitor = makeShared<Monitor>(); frontend.m_renderData.pMonitor = monitor;
    auto state = monitor->m_output->state;
    auto destination = makeShared<IHLBuffer>();
    auto source = makeShared<IHLBuffer>();
    auto explicitSource = makeShared<IHLBuffer>(); explicitSource->m_syncReleasers.emplace_back(makeShared<Releaser>());
    auto target = makeShared<IRenderbuffer>();
    auto current = makeShared<IFramebuffer>(), main = makeShared<IFramebuffer>(), out = makeShared<IFramebuffer>(), transient = makeShared<IFramebuffer>();
    renderer.m_currentBuffer = destination; renderer.m_currentRenderbuffer = target;
    renderer.m_usedAsyncBuffers = {CHLBufferReference(source), CHLBufferReference(explicitSource)};
    renderer.m_renderData.currentFB = current; renderer.m_renderData.mainFB = main; renderer.m_renderData.outFB = out;
    renderer.m_pendingFBReleases.emplace_back(transient);
    renderer.endRender([] { ++completions; });
    assert(renderer.m_submittedWork.size() == 1 && "every render path submits ownership");
    assert(completions == 0 && releases == 0 && "no early completion or explicit release");
    assert(!renderer.m_currentBuffer && !renderer.m_currentRenderbuffer && unbinds == 1);
    assert(renderer.m_pendingFBReleases.empty() && renderer.m_usedAsyncBuffers.empty());
    assert(gl.ends == (mode != RENDER_MODE_TO_BUFFER_READ_ONLY));
    assert(state->buffers == (mode == RENDER_MODE_NORMAL));
    assert(state->fences == (mode == RENDER_MODE_NORMAL && explicitOutput && syncKind == 1));
    assert(imports == (syncKind == 1) && "explicit release points imported before source unlock");
    assert(flushes == (syncKind != 1));
    assert(state->resets == (mode == RENDER_MODE_NORMAL && syncKind != 1));
    assert(!frontend.m_renderData.pMonitor == (mode == RENDER_MODE_TO_BUFFER_READ_ONLY));
    assert(destination.strongRef() == 3 && "destination storage and lock retained");
    assert(source.strongRef() == 2 && explicitSource.strongRef() == (syncKind == 1 ? 1 : 2));
    assert(target.strongRef() == 2 && current.strongRef() == 3 && main.strongRef() == 3 && out.strongRef() == 3);
    assert(transient.strongRef() == 2 && "explicit temporary framebuffer retained");
    renderer.m_renderData = {};
    if (cancelDelivery) {
        renderer.m_submittedWork.cancelAllDelivery(); loop.registry.close();
    }
    assert(source.strongRef() == 2 && transient.strongRef() == 2 && completions == 0);
    contextOK = releaseContext; renderer.fenceStatus = NativeRetirement::EFence::COMPLETE;
    if (!cancelDelivery && syncKind == 1) {
        assert(NativeRetirement::nativeFenceStatus(loop.signal.get()) == NativeRetirement::EFence::ERROR);
        loop.pulse();
    }
    const bool drained = renderer.m_submittedWork.drain(NativeRetirement::Clock::now() + std::chrono::milliseconds(50));
    assert(drained == (syncKind == 1 && releaseContext));
    if (!drained) {
        assert(renderer.m_submittedWork.size() == 1 && releases == 0 && source.strongRef() == 2 && transient.strongRef() == 2);
        std::_Exit(0);
    }
    assert(releases == 1 && completions == !cancelDelivery && renderer.m_submittedWork.size() == 0);
    assert(source.strongRef() == 1 && destination.strongRef() == 1 && target.strongRef() == 1);
    assert(current.strongRef() == 1 && main.strongRef() == 1 && out.strongRef() == 1 && transient.strongRef() == 1);
}

int main() {
    int cases = 0;
    for (int mode = 0; mode < 4; ++mode)
        for (bool explicitOutput : {false, true})
            for (int syncKind : {0, 1, 2})
                for (bool releaseContext : {false, true})
                  for (bool cancelDelivery : {false, true}) {
                    const auto child = fork(); assert(child >= 0);
                    if (!child) { scenario(mode, explicitOutput, syncKind, releaseContext, cancelDelivery); std::_Exit(0); }
                    int status = 0; assert(waitpid(child, &status, 0) == child);
                    if (!WIFEXITED(status) || WEXITSTATUS(status)) return 1;
                    ++cases;
                }
    std::printf("PASS %d actual endRender submission-path cases (injected fence/EGL/GL, CPU only)\n", cases);
}
