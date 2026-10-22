#pragma once

#include <chrono>
#include <cstdlib>
#include <utility>

namespace NativeShutdown {
    // The process must not unwind unresolved owners or resume a partially run cleanup.
    class CShutdownSequence {
      public:
        enum class EState { IDLE, RUNNING, COMPLETE };
        using Clock = std::chrono::steady_clock;

        template <typename Quiesce, typename Drain, typename Release, typename Teardown>
        void run(Clock::time_point deadline, Quiesce&& quiesce, Drain&& drain, Release&& release, Teardown&& teardown) noexcept {
            if (m_state == EState::COMPLETE)
                return;
            if (m_state != EState::IDLE)
                std::_Exit(EXIT_FAILURE);
            m_state = EState::RUNNING;
            try {
                std::forward<Quiesce>(quiesce)();
                if (!std::forward<Drain>(drain)(deadline))
                    std::_Exit(EXIT_FAILURE);
                std::forward<Release>(release)();
                std::forward<Teardown>(teardown)();
                m_state = EState::COMPLETE;
            } catch (...) {
                std::_Exit(EXIT_FAILURE);
            }
        }

        EState state() const { return m_state; }

      private:
        EState m_state = EState::IDLE;
    };
}
