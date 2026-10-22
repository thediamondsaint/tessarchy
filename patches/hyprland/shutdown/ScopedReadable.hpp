#pragma once

#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <poll.h>
#include <utility>
#include <wayland-server-core.h>
#include <hyprutils/os/FileDescriptor.hpp>

class CScopedReadableRegistry {
  private:
    struct SState;
    struct SWaiter;

  public:
    enum class EOutcome { READABLE, ERROR };
    enum class EArmResult { ARMED, COMPLETED, INVALID_FD, POLL_FAILED, REGISTRATION_FAILED, CLOSED };
    using FCallback = std::function<void(EOutcome)>;

    class CHandle {
      public:
        CHandle() = default;
        CHandle(const CHandle&) = delete;
        CHandle& operator=(const CHandle&) = delete;
        CHandle(CHandle&& other) noexcept : m_state(std::move(other.m_state)), m_id(std::exchange(other.m_id, 0)) {}
        CHandle& operator=(CHandle&& other) noexcept {
            if (this != &other) {
                reset();
                m_state = std::move(other.m_state);
                m_id = std::exchange(other.m_id, 0);
            }
            return *this;
        }
        ~CHandle() { reset(); }
        void reset();
        bool active() const;

      private:
        CHandle(const std::shared_ptr<SState>& state, uint64_t id) : m_state(state), m_id(id) {}
        std::weak_ptr<SState> m_state;
        uint64_t m_id = 0;
        friend class CScopedReadableRegistry;
    };

    struct SRegistration {
        EArmResult result;
        CHandle handle;
    };

    explicit CScopedReadableRegistry(wl_event_loop* loop);
    CScopedReadableRegistry(const CScopedReadableRegistry&) = delete;
    CScopedReadableRegistry& operator=(const CScopedReadableRegistry&) = delete;
    ~CScopedReadableRegistry() { close(); }

    // Failed registration never calls fn; COMPLETED calls it inline.
    [[nodiscard]] SRegistration arm(Hyprutils::OS::CFileDescriptor fd, FCallback fn);
    void close();
    size_t size() const;

  private:
    struct SWaiter {
        std::weak_ptr<SState> state;
        uint64_t id;
        Hyprutils::OS::CFileDescriptor fd;
        FCallback fn;
        wl_event_source* source = nullptr;
        SWaiter(const std::shared_ptr<SState>& state_, uint64_t id_, Hyprutils::OS::CFileDescriptor fd_, FCallback fn_) :
            state(state_), id(id_), fd(std::move(fd_)), fn(std::move(fn_)) {}
        SWaiter(const SWaiter&) = delete;
        SWaiter& operator=(const SWaiter&) = delete;
        ~SWaiter() { detach(); }
        void detach() {
            if (source)
                wl_event_source_remove(std::exchange(source, nullptr));
        }
    };
    struct SState {
        explicit SState(wl_event_loop* loop_) : loop(loop_) {}
        wl_event_loop* loop;
        uint64_t nextID = 1;
        std::map<uint64_t, std::unique_ptr<SWaiter>> waiters;
    };
    std::shared_ptr<SState> m_state;
    static int onEvent(int, uint32_t mask, void* data);
};

inline CScopedReadableRegistry::CScopedReadableRegistry(wl_event_loop* loop) : m_state(std::make_shared<SState>(loop)) {}

inline void CScopedReadableRegistry::CHandle::reset() {
    const auto id = std::exchange(m_id, 0);
    auto state = m_state.lock();
    m_state.reset();
    if (!state || !id)
        return;
    auto it = state->waiters.find(id);
    if (it == state->waiters.end())
        return;
    auto taken = std::move(it->second);
    state->waiters.erase(it);
}

inline bool CScopedReadableRegistry::CHandle::active() const {
    const auto state = m_state.lock();
    return state && m_id && state->waiters.find(m_id) != state->waiters.end();
}

inline size_t CScopedReadableRegistry::size() const {
    return m_state ? m_state->waiters.size() : 0;
}

inline void CScopedReadableRegistry::close() {
    auto state = std::move(m_state);
    if (!state)
        return;
    state->loop = nullptr;
    // Detach first: destroying a closure may cancel another waiter.
    auto waiters = std::move(state->waiters);
}

inline CScopedReadableRegistry::SRegistration CScopedReadableRegistry::arm(Hyprutils::OS::CFileDescriptor fd, FCallback fn) {
    const auto state = m_state;
    if (!state || !state->loop)
        return {EArmResult::CLOSED, {}};
    if (!fd.isValid())
        return {EArmResult::INVALID_FD, {}};
    pollfd pfd{fd.get(), POLLIN, 0};
    const auto ready = poll(&pfd, 1, 0);
    if (ready < 0)
        return {EArmResult::POLL_FAILED, {}};
    if (pfd.revents & POLLNVAL)
        return {EArmResult::INVALID_FD, {}};
    if (pfd.revents & (POLLERR | POLLHUP))
        return {EArmResult::POLL_FAILED, {}};
    if (pfd.revents & POLLIN) {
        if (fn)
            fn(EOutcome::READABLE);
        return {EArmResult::COMPLETED, {}};
    }
    if (state->nextID == 0)
        return {EArmResult::REGISTRATION_FAILED, {}};
    const auto id = state->nextID++;
    auto waiter = std::make_unique<SWaiter>(state, id, std::move(fd), std::move(fn));
    auto* raw = waiter.get();
    state->waiters.emplace(id, std::move(waiter));
    raw->source = wl_event_loop_add_fd(state->loop, raw->fd.get(), WL_EVENT_READABLE, onEvent, raw);
    if (!raw->source) {
        auto taken = std::move(state->waiters.at(id));
        state->waiters.erase(id);
        return {EArmResult::REGISTRATION_FAILED, {}};
    }
    return {EArmResult::ARMED, CHandle(state, id)};
}

inline int CScopedReadableRegistry::onEvent(int, uint32_t mask, void* data) {
    auto* waiter = static_cast<SWaiter*>(data);
    const auto state = waiter->state.lock();
    if (!state)
        return 0;
    const auto it = state->waiters.find(waiter->id);
    if (it == state->waiters.end())
        return 0;
    auto taken = std::move(it->second);
    state->waiters.erase(it);
    taken->detach();
    const auto outcome = mask & (WL_EVENT_ERROR | WL_EVENT_HANGUP) ? EOutcome::ERROR : EOutcome::READABLE;
    auto fn = std::move(taken->fn);
    if (fn)
        fn(outcome);
    return 0;
}
