#pragma once

#include <functional>
#include <memory>
#include <utility>

// Copies share one request identity; the resource owner cancels before destruction.
template <typename T>
class CTerminalDelivery {
  public:
    using FCallback = std::function<void(T)>;
    explicit CTerminalDelivery(FCallback fn = {}) : m_state(std::make_shared<SState>(std::move(fn))) {}

    bool pending() const { return !m_state->terminal; }

    bool notify(T value) const {
        const auto state = m_state;
        if (state->terminal)
            return false;
        auto fn = state->fn;
        if (fn)
            fn(value);
        return true;
    }

    bool finish(T value) const {
        const auto state = m_state;
        if (std::exchange(state->terminal, true))
            return false;
        auto fn = std::move(state->fn);
        if (fn)
            fn(value);
        return true;
    }

    void cancel() const {
        const auto state = m_state;
        if (std::exchange(state->terminal, true))
            return;
        auto fn = std::move(state->fn);
    }

  private:
    struct SState {
        explicit SState(FCallback callback) : fn(std::move(callback)) {}
        FCallback fn;
        bool terminal = false;
    };
    std::shared_ptr<SState> m_state;
};
