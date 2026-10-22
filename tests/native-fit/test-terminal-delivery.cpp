#include "../../patches/hyprland/shutdown/TerminalDelivery.hpp"

#include <iostream>
#include <stdexcept>
#include <vector>

enum class EEvent { TIMESTAMP, READY, FAILED };
using CDelivery = CTerminalDelivery<EEvent>;

static void require(bool condition, const char* message) {
    if (!condition)
        throw std::runtime_error(message);
}

static void terminalOnce() {
    std::vector<EEvent> events;
    CDelivery delivery([&](auto event) { events.push_back(event); });
    auto asyncCopy = delivery;
    require(delivery.notify(EEvent::TIMESTAMP), "timestamp rejected");
    require(asyncCopy.finish(EEvent::READY), "ready rejected");
    require(!delivery.finish(EEvent::FAILED), "double terminal accepted");
    require(!asyncCopy.notify(EEvent::TIMESTAMP), "metadata after terminal accepted");
    require(events == std::vector{EEvent::TIMESTAMP, EEvent::READY}, "unexpected delivery");
}

static void failureBeforeSuccess() {
    int calls = 0;
    CDelivery delivery([&](auto event) { require(event == EEvent::FAILED, "late success delivered"); ++calls; });
    require(delivery.finish(EEvent::FAILED), "failure rejected");
    require(!delivery.finish(EEvent::READY), "success after failure accepted");
    require(calls == 1, "failure not exactly once");
}

static void reentrantFinish() {
    int calls = 0;
    CDelivery* current = nullptr;
    CDelivery delivery([&](auto) {
        ++calls;
        require(!current->pending(), "terminal not committed before callback");
        require(!current->finish(EEvent::FAILED), "reentrant terminal accepted");
        current->cancel();
    });
    current = &delivery;
    require(delivery.finish(EEvent::READY), "completion rejected");
    require(calls == 1, "reentrant callback delivered twice");
}

static void metadataFinishesReentrantly() {
    std::vector<EEvent> events;
    CDelivery* current = nullptr;
    CDelivery delivery([&](auto event) {
        events.push_back(event);
        if (event == EEvent::TIMESTAMP)
            current->finish(EEvent::FAILED);
    });
    current = &delivery;
    delivery.notify(EEvent::TIMESTAMP);
    require(!delivery.finish(EEvent::READY), "ready accepted after reentrant failure");
    require(events == std::vector{EEvent::TIMESTAMP, EEvent::FAILED}, "unexpected reentrant events");
}

static void cancellationReleasesClosure() {
    auto payload = std::make_shared<int>(7);
    std::weak_ptr<int> weak = payload;
    int calls = 0;
    CDelivery delivery([payload, &calls](auto) { ++calls; });
    payload.reset();
    auto callbackCopy = delivery;
    require(!weak.expired(), "closure released early");
    delivery.cancel();
    require(weak.expired(), "cancellation retained closure");
    require(!callbackCopy.finish(EEvent::READY), "cancelled callback delivered");
    require(calls == 0, "cancellation invoked callback");
}

static void callbackDestroysOwner() {
    int calls = 0;
    std::unique_ptr<CDelivery> owner;
    owner = std::make_unique<CDelivery>([&](auto) { ++calls; owner.reset(); });
    auto callbackCopy = *owner;
    require(owner->finish(EEvent::READY), "completion rejected");
    require(!owner && calls == 1, "owner survived callback");
    require(!callbackCopy.finish(EEvent::FAILED), "callback copy delivered after owner destruction");
}

static void cancelledOldFrameCannotCompleteNewFrame() {
    std::vector<int> frames;
    CDelivery current([&](auto) { frames.push_back(1); });
    const auto oldCallback = current;
    current.cancel();
    current = CDelivery([&](auto) { frames.push_back(2); });
    require(!oldCallback.finish(EEvent::READY), "old frame callback accepted");
    require(current.pending(), "old callback completed new frame");
    current.finish(EEvent::READY);
    require(frames == std::vector{2}, "completion targeted wrong frame");
}

static void closureDestructorReentersCancellation() {
    struct SReenter {
        CDelivery* delivery = nullptr;
        ~SReenter() { if (delivery) delivery->cancel(); }
    };
    auto payload = std::make_shared<SReenter>();
    CDelivery delivery([payload](auto) {});
    payload->delivery = &delivery;
    payload.reset();
    delivery.cancel();
    require(!delivery.pending(), "cancellation did not complete");
}

int main() {
    const std::vector<std::pair<const char*, void (*)()>> cases = {
        {"terminal-once", terminalOnce},
        {"failure-before-success", failureBeforeSuccess},
        {"reentrant-finish", reentrantFinish},
        {"metadata-reentrant-failure", metadataFinishesReentrantly},
        {"cancel-releases-closure", cancellationReleasesClosure},
        {"callback-destroys-owner", callbackDestroysOwner},
        {"old-frame-cannot-complete-new", cancelledOldFrameCannotCompleteNewFrame},
        {"closure-destructor-reentrancy", closureDestructorReentersCancellation},
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
    std::cout << cases.size() << " terminal-delivery cases passed\n";
}
