#include <hyprutils/memory/WeakPtr.hpp>
#include <hyprutils/signal/Signal.hpp>
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <functional>
#include <utility>
#include <vector>
#include "TerminalDelivery.hpp"
#include "ext-image-copy-capture-v1.hpp"
#include <sys/socket.h>
#include <unistd.h>
#include <cerrno>
#include <cstdint>
#include <cstring>
using namespace Hyprutils::Memory;
using namespace Hyprutils::Signal;
template <typename T> using UP = CUniquePointer<T>;
template <typename T> using SP = CSharedPointer<T>;
template <typename T> using WP = CWeakPointer<T>;
#define UNLIKELY(x) (x)
#define LOGM(...) ((void)0)
struct Vector2D { int x = 64, y = 64; bool operator==(const Vector2D&) const = default; };
struct CRegion { void add(int, int, int, int) {} void clear() {} };
struct CBox {};
struct Monitor { struct { CSignalT<> commit; } m_events; };
struct Window { WP<Monitor> m_monitor; };
struct CImageCaptureSource {
    WP<Monitor> m_monitor;
    WP<Window> m_window;
    CBox logicalBox() { return {}; }
};
struct CWLPointerResource {};
enum EImageCaptureDelivery { READY, FAILED_UNKNOWN, FAILED_STOPPED, FAILED_CONSTRAINTS };
using CImageCaptureDelivery = CTerminalDelivery<EImageCaptureDelivery>;
struct IHLBuffer {};
struct CWLBufferResource {
    WP<IHLBuffer> m_buffer;
    static SP<CWLBufferResource> fromResource(wl_resource*) { return {}; }
};
static int nativeSessions = 0, nativeFrames = 0, stops = 0, cursorSessions = 0, constraints = 0;
static std::function<void(int)> completion;
namespace Screenshare {
struct CScreenshareSession;
struct CScreenshareFrame {
    WP<CScreenshareSession> owner;
    explicit CScreenshareFrame(WP<CScreenshareSession> session) : owner(session) { ++nativeFrames; }
    ~CScreenshareFrame() { assert(owner); --nativeFrames; }
    int transform() { return 0; }
    int share(SP<IHLBuffer>, const CRegion&, std::function<void(int)> callback);
};
struct CScreenshareSession {
    WP<CScreenshareSession> self;
    bool stopped = false;
    CScreenshareSession() { ++nativeSessions; }
    ~CScreenshareSession() { --nativeSessions; }
    Vector2D bufferSize() { return {}; }
    UP<CScreenshareFrame> nextFrame(bool) { return makeUnique<CScreenshareFrame>(self); }
    void stop() { stopped = true; ++stops; }
};
int CScreenshareFrame::share(SP<IHLBuffer>, const CRegion&, std::function<void(int)> callback) {
    assert(owner && !owner->stopped);
    completion = std::move(callback);
    return 0;
}
}
namespace Screenshare {
struct CCursorshareSession {
    struct { CSignalT<> stopped, constraintsChanged; } m_events;
    CCursorshareSession() { ++cursorSessions; }
    ~CCursorshareSession() { --cursorSessions; }
    int share(SP<Monitor>, SP<IHLBuffer>, std::function<CBox()> box, std::function<void(int)> callback) {
        (void)box();
        completion = std::move(callback);
        return 0;
    }
};
static WP<CCursorshareSession> lastCursor;
struct Manager {
    UP<CCursorshareSession> newCursorSession(wl_client*, SP<CWLPointerResource>) {
        auto session = makeUnique<CCursorshareSession>();
        lastCursor = session;
        return session;
    }
};
static Manager manager;
static Manager* mgr() { return &manager; }
}
class CImageCopyCaptureSession;
class CImageCopyCaptureProtocol;
#include "child-declarations.inc"
class CImageCopyCaptureProtocol {
  public:
    std::vector<SP<CImageCopyCaptureSession>> m_sessions;
    std::vector<SP<CImageCopyCaptureFrame>> m_frames;
    std::vector<SP<CImageCopyCaptureCursorSession>> m_cursorSessions;
    std::vector<SP<CImageCopyCaptureCursorFrame>> m_cursorFrames;
    void destroyResource(CImageCopyCaptureSession* resource);
    void destroyResource(CImageCopyCaptureFrame* resource);
    void destroyResource(CImageCopyCaptureCursorFrame* resource);
    void destroyResource(CImageCopyCaptureCursorSession* resource);
};
namespace PROTO { static UP<CImageCopyCaptureProtocol> imageCopyCapture; }
static CImageCaptureDelivery makeImageCaptureDelivery(WP<CExtImageCopyCaptureFrameV1> frame) {
    return CImageCaptureDelivery([frame](auto result) {
        if (!frame || !frame->resource()) return;
        if (result == READY) frame->sendReady();
        else frame->sendFailed(EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_UNKNOWN);
    });
}
static std::function<void(int)> captureCallback(CImageCaptureDelivery delivery) {
    return [delivery](int result) { delivery.finish(result == 0 ? READY : FAILED_UNKNOWN); };
}
static void captureError(int error, const CImageCaptureDelivery& delivery, SP<CExtImageCopyCaptureFrameV1>) {
    if (error) delivery.finish(FAILED_UNKNOWN);
}
CImageCopyCaptureSession::CImageCopyCaptureSession(SP<CExtImageCopyCaptureSessionV1> resource, SP<CImageCaptureSource>, extImageCopyCaptureManagerV1Options) : m_resource(resource) {
    m_session = makeUnique<Screenshare::CScreenshareSession>();
    m_session->self = m_session;
    m_bufferSize = m_session->bufferSize();
}
void CImageCopyCaptureSession::sendConstraints() {}
void CImageCopyCaptureCursorSession::sendConstraints() { ++constraints; m_bufferSize = Vector2D(64, 64); }
void CImageCopyCaptureCursorSession::sendCursorEvents() {}
#include "child-methods.inc"

extern const wl_interface ext_image_capture_source_v1_interface = {"ext_image_capture_source_v1", 1, 0, nullptr, 0, nullptr};

struct Wire {
    wl_display* display = wl_display_create();
    int sockets[2] = {-1, -1};
    wl_client* client = nullptr;
    Wire() {
        assert(socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, sockets) == 0);
        client = wl_client_create(display, sockets[0]);
        assert(client);
    }
    ~Wire() { wl_client_destroy(client); close(sockets[1]); wl_display_destroy(display); }
    void request(uint32_t id, uint32_t opcode, uint32_t argument = 0) {
        uint32_t packet[] = {id, ((argument ? 12U : 8U) << 16) | opcode, argument};
        const auto size = argument ? 12U : 8U;
        assert(send(sockets[1], packet, size, MSG_NOSIGNAL) == size);
        assert(wl_event_loop_dispatch(wl_display_get_event_loop(display), 0) == 0);
    }
    std::pair<int, int> frameEvents(uint32_t id) {
        wl_client_flush(client);
        char bytes[4096];
        const auto length = recv(sockets[1], bytes, sizeof(bytes), MSG_DONTWAIT);
        if (length < 0) { assert(errno == EAGAIN); return {}; }
        int ready = 0, failed = 0;
        for (size_t at = 0; at < static_cast<size_t>(length);) {
            uint32_t header[2];
            assert(at + sizeof(header) <= static_cast<size_t>(length));
            std::memcpy(header, bytes + at, sizeof(header));
            const auto size = header[1] >> 16;
            assert(size >= 8 && at + size <= static_cast<size_t>(length));
            if (header[0] == id) {
                ready += (header[1] & 0xffff) == 3;
                failed += (header[1] & 0xffff) == 4;
            }
            at += size;
        }
        return {ready, failed};
    }
};

int main() {
    for (int order = 0; order < 8; ++order) {
        Wire wire;
        PROTO::imageCopyCapture = makeUnique<CImageCopyCaptureProtocol>();
        auto parentResource = makeShared<CExtImageCopyCaptureSessionV1>(wire.client, 1, 2);
        auto parent = makeShared<CImageCopyCaptureSession>(parentResource, SP<CImageCaptureSource>{}, EXT_IMAGE_COPY_CAPTURE_MANAGER_V1_OPTIONS_PAINT_CURSORS);
        WP<CImageCopyCaptureSession> weakParent = parent;
        WP<CExtImageCopyCaptureSessionV1> weakResource = parentResource;
        parentResource->setDestroy([ptr = parent.get()](auto*) { PROTO::imageCopyCapture->destroyResource(ptr); });
        parentResource->setOnDestroy([ptr = parent.get()](auto*) { PROTO::imageCopyCapture->destroyResource(ptr); });
        auto frameResource = makeShared<CExtImageCopyCaptureFrameV1>(wire.client, 1, 3);
        auto child = makeShared<CImageCopyCaptureFrame>(frameResource, parent);
        PROTO::imageCopyCapture->m_sessions.push_back(parent);
        PROTO::imageCopyCapture->m_frames.push_back(child);
        parent.reset(); child.reset(); parentResource.reset(); frameResource.reset();
        if (order & 1) wire.request(3, 3);
        if (order & 4) wl_resource_destroy(wl_client_get_object(wire.client, 2));
        else wire.request(2, 1);
        assert((nativeSessions == 1 && nativeFrames == 1 && stops == order && weakParent) && "parent destruction must preserve native child state");
        assert(!weakResource && !wl_client_get_object(wire.client, 2) && "parent destroy must destroy its protocol resource immediately");
        if (!(order & 1)) wire.request(3, 3);
        auto finish = std::exchange(completion, {});
        assert(finish);
        if (order & 2) {
            wire.request(3, 0);
            assert(nativeFrames == 0 && nativeSessions == 0 && !weakParent);
            finish(0);
            auto [ready, failed] = wire.frameEvents(3);
            assert(ready == 0 && failed == 0);
        } else {
            finish(0); finish(1);
            auto [ready, failed] = wire.frameEvents(3);
            assert(ready == 1 && failed == 0);
            wire.request(3, 0);
            assert(nativeFrames == 0 && nativeSessions == 0 && !weakParent);
        }
        assert(stops == order + 1);
        assert(PROTO::imageCopyCapture->m_frames.empty());
        PROTO::imageCopyCapture.reset();
    }
    for (int order = 0; order < 16; ++order) {
        Wire wire;
        PROTO::imageCopyCapture = makeUnique<CImageCopyCaptureProtocol>();
        auto monitor = makeShared<Monitor>();
        auto source = makeShared<CImageCaptureSource>();
        source->m_monitor = monitor;
        auto resource = makeShared<CExtImageCopyCaptureCursorSessionV1>(wire.client, 1, 2);
        auto parent = makeShared<CImageCopyCaptureCursorSession>(resource, source, SP<CWLPointerResource>{});
        PROTO::imageCopyCapture->m_cursorSessions.push_back(parent);
        parent.reset(); resource.reset();
        wire.request(2, 1, 3);
        wire.request(3, 0, 4);
        if (order & 1) wire.request(4, 3);
        if (order & 4) wire.request(2, 0);
        else wire.request(3, 1);
        assert(cursorSessions == 1 && "cursor parent destruction must preserve native child state");
        if (order & 4) assert(!wl_client_get_object(wire.client, 2) && !wl_client_get_object(wire.client, 3));
        else assert(!wl_client_get_object(wire.client, 3));
        auto beforeConstraints = constraints;
        Screenshare::lastCursor->m_events.constraintsChanged.emit();
        Screenshare::lastCursor->m_events.stopped.emit();
        assert(constraints == beforeConstraints && cursorSessions == 1);
        if (order & 8) source->m_monitor.reset();
        if (!(order & 1)) wire.request(4, 3);
        const bool sourceFailed = (order & 8) && !(order & 1);
        auto finish = std::exchange(completion, {});
        assert(sourceFailed || finish);
        if (order & 2) {
            wire.request(4, 0);
            assert(cursorSessions == 0);
            if (finish) finish(0);
            auto [ready, failed] = wire.frameEvents(4);
            assert(ready == 0 && failed == (sourceFailed ? 1 : 0));
        } else {
            if (finish) { finish(0); finish(1); }
            auto [ready, failed] = wire.frameEvents(4);
            assert(ready == (sourceFailed ? 0 : 1) && failed == (sourceFailed ? 1 : 0));
            wire.request(4, 0);
            assert(cursorSessions == 0);
        }
        assert(PROTO::imageCopyCapture->m_cursorFrames.empty());
        if (!(order & 4)) wire.request(2, 0);
        PROTO::imageCopyCapture.reset();
    }
    {
        Wire wire;
        PROTO::imageCopyCapture = makeUnique<CImageCopyCaptureProtocol>();
        auto monitor = makeShared<Monitor>();
        auto source = makeShared<CImageCaptureSource>();
        source->m_monitor = monitor;
        auto resource = makeShared<CExtImageCopyCaptureCursorSessionV1>(wire.client, 1, 2);
        auto parent = makeShared<CImageCopyCaptureCursorSession>(resource, source, SP<CWLPointerResource>{});
        PROTO::imageCopyCapture->m_cursorSessions.push_back(parent);
        parent.reset(); resource.reset();
        wire.request(2, 1, 3);
        wire.request(3, 0, 4);
        Screenshare::lastCursor->m_events.stopped.emit();
        assert(cursorSessions == 1 && wl_client_get_object(wire.client, 3) && "source stop must not destroy capture session or native owner inside its signal");
        wire.request(4, 3);
        auto oldCompletion = std::exchange(completion, {});
        wire.request(4, 0);
        assert(cursorSessions == 1);
        wire.request(3, 0, 5);
        oldCompletion(0);
        auto [oldReady, oldFailed] = wire.frameEvents(5);
        assert(oldReady == 0 && oldFailed == 0);
        wire.request(5, 3);
        auto newCompletion = std::exchange(completion, {});
        newCompletion(0); oldCompletion(0);
        auto [ready, failed] = wire.frameEvents(5);
        assert(ready == 1 && failed == 0);
        wire.request(2, 0);
        assert(cursorSessions == 1);
        wire.request(5, 0);
        assert(cursorSessions == 0);
        PROTO::imageCopyCapture.reset();
    }
    std::puts("8 ordinary + 16 cursor ownership cases + cursor source-stop/replacement group passed; actual generated protocol and Wayland dispatch, CPU native mocks, real Hyprutils owners/signals");
}
