#pragma once

#include "ScopedReadable.hpp"
#include <cerrno>
#include <chrono>
#include <exception>
#include <functional>
#include <linux/sync_file.h>
#include <map>
#include <vector>
#include <memory>
#include <sys/ioctl.h>

namespace NativeRetirement {
    enum class EFence { ACTIVE, COMPLETE, ERROR };
    using Clock = std::chrono::steady_clock;
    using Deadline = Clock::time_point;

    inline EFence nativeFenceStatus(int fd) {
        sync_file_info info{};
        if (fd < 0 || ioctl(fd, SYNC_IOC_FILE_INFO, &info) < 0)
            return EFence::ERROR;
        return info.status == 1 ? EFence::COMPLETE : info.status == 0 ? EFence::ACTIVE : EFence::ERROR;
    }

    inline bool waitNativeFence(int fd, Deadline deadline) {
        for (;;) {
            const auto now = Clock::now();
            if (now >= deadline || fd < 0)
                return false;
            const auto remaining = std::chrono::duration_cast<std::chrono::nanoseconds>(deadline - now);
            const timespec timeout{static_cast<time_t>(remaining.count() / 1000000000), static_cast<long>(remaining.count() % 1000000000)};
            pollfd pfd{fd, POLLIN, 0};
            const int result = ppoll(&pfd, 1, &timeout, nullptr);
            if (result < 0 && errno == EINTR)
                continue;
            return result > 0 && (pfd.revents & POLLIN) && !(pfd.revents & (POLLERR | POLLHUP | POLLNVAL));
        }
    }

    // The renderer owns payloads; a readable registration owns only weak identity.
    template <typename Payload>
    class CSubmittedWork {
      public:
        using ID = uint64_t;
        using Probe = std::function<EFence(int)>;
        using Wait = std::function<bool(int, Deadline)>;
        using Arm = std::function<CScopedReadableRegistry::SRegistration(Hyprutils::OS::CFileDescriptor, CScopedReadableRegistry::FCallback)>;

        using BeforeRetire = std::function<bool(Payload&)>;

        explicit CSubmittedWork(Probe probe = nativeFenceStatus, BeforeRetire beforeRetire = [](Payload&) { return true; }) :
            m_state(std::make_shared<State>(std::move(probe), std::move(beforeRetire))) {}
        CSubmittedWork(const CSubmittedWork&) = delete;
        CSubmittedWork& operator=(const CSubmittedWork&) = delete;
        ~CSubmittedWork() {
            // Unresolved GPU ownership may not unwind with renderer dependencies.
            if (!m_state->records.empty())
                std::terminate();
        }

        ID submit(Payload payload, Hyprutils::OS::CFileDescriptor fence, std::function<void()> done) {
            const auto id = m_state->next++;
            if (!id)
                std::terminate();
            m_state->records.emplace(id, std::make_unique<Record>(std::move(payload), std::move(fence), std::move(done)));
            return id;
        }

        void arm(ID id, const Arm& armFn) {
            const auto state = m_state;
            const auto it = state->records.find(id);
            if (it == state->records.end() || it->second->failed || it->second->waiter.active())
                return;
            auto result = armFn(it->second->fence.duplicate(), [weak = std::weak_ptr<State>(state), id](auto outcome) {
                if (const auto locked = weak.lock())
                    settle(locked, id, outcome == CScopedReadableRegistry::EOutcome::ERROR);
            });
            // armFn can deliver inline and remove the record, or notification can reenter.
            const auto pending = state->records.find(id);
            if (pending == state->records.end())
                return;
            pending->second->waiter = std::move(result.handle);
            if (result.result != CScopedReadableRegistry::EArmResult::ARMED && result.result != CScopedReadableRegistry::EArmResult::COMPLETED)
                pending->second->failed = true;
        }

        void cancelDelivery(ID id) {
            const auto it = m_state->records.find(id);
            if (it == m_state->records.end())
                return;
            auto done = std::move(it->second->done);
            it->second->waiter.reset();
        }

        void cancelAllDelivery() {
            const auto state = m_state;
            std::vector<std::function<void()>> detached;
            for (auto& [id, record] : state->records) {
                record->waiter.reset();
                detached.emplace_back(std::move(record->done));
            }
        }

        // Call only with the actual rendering context and release dependencies alive.
        bool drain(Deadline deadline, const Wait& wait = waitNativeFence) {
            const auto state = m_state;
            while (!state->records.empty()) {
                const auto id = state->records.begin()->first;
                auto& record = *state->records.begin()->second;
                record.waiter.reset();
                if (record.failed)
                    return false;
                auto status = state->probe(record.fence.get());
                if (status == EFence::ACTIVE) {
                    if (!wait(record.fence.get(), deadline))
                        return false;
                    status = state->probe(record.fence.get());
                }
                if (status != EFence::COMPLETE) {
                    if (status == EFence::ERROR)
                        record.failed = true;
                    return false;
                }
                if (!retire(state, id))
                    return false;
            }
            return true;
        }

        size_t size() const { return m_state->records.size(); }
        bool failed(ID id) const {
            const auto it = m_state->records.find(id);
            return it != m_state->records.end() && it->second->failed;
        }

      private:
        struct Record {
            Payload payload;
            Hyprutils::OS::CFileDescriptor fence;
            std::function<void()> done;
            CScopedReadableRegistry::CHandle waiter;
            bool failed = false;
            Record(Payload payload_, Hyprutils::OS::CFileDescriptor fence_, std::function<void()> done_) :
                payload(std::move(payload_)), fence(std::move(fence_)), done(std::move(done_)) {}
        };
        struct State {
            explicit State(Probe probe_, BeforeRetire beforeRetire_) : probe(std::move(probe_)), beforeRetire(std::move(beforeRetire_)) {}
            Probe probe;
            BeforeRetire beforeRetire;
            ID next = 1;
            std::map<ID, std::unique_ptr<Record>> records;
        };
        std::shared_ptr<State> m_state;

        static void settle(const std::shared_ptr<State>& state, ID id, bool error) {
            const auto it = state->records.find(id);
            if (it == state->records.end() || it->second->failed)
                return;
            const auto status = error ? EFence::ERROR : state->probe(it->second->fence.get());
            if (status != EFence::COMPLETE) {
                if (status == EFence::ERROR)
                    it->second->failed = true;
                return;
            }
            retire(state, id);
        }

        static bool retire(const std::shared_ptr<State>& state, ID id) {
            const auto it = state->records.find(id);
            // This release hook must not reenter the queue; failure retains the complete payload.
            if (!state->beforeRetire(it->second->payload)) {
                it->second->failed = true;
                return false;
            }
            auto taken = std::move(it->second);
            state->records.erase(it);
            taken->waiter.reset();
            auto done = std::move(taken->done);
            taken.reset();
            if (done)
                done();
            return true;
        }
    };
}
