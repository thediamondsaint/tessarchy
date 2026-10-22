# Notification popup lifecycle (T06 subset)

## Scope published before implementation

Branch `fix/notification-popup-lifecycle` from current upstream main. Existing
open notification-related changes were checked; PR94 concerns the screenshot
helper, not popup ownership. This change is independent of other draft features.

Current `shell/shell.qml` keeps popup objects in a separate array (lines 186–220).
New deliveries unconditionally prepend; popup timers/user dismissal remove
entries, but application withdrawal/removal from the tracked model does not
(lines 1328–1369). A withdrawn alert can retain a popup slot until its timer
fires (or indefinitely for an urgent alert without a popup timeout).

Correction established during actual private-bus testing/source inspection:
Quickshell updates a replaced object in place without re-emitting its delivery
signal. The initial scope overstated duplicate replacement delivery as a native
protocol bug. Deduplication remains a defensive caller guard, not a reproduced
protocol defect. Native delivery also precedes insertion into the tracked model;
`notification.tracked = true` requests retention but cannot justify a membership
check inside that callback. Both orderings are covered by the private-bus test.

Keep the server's tracked model as history truth. Make the ephemeral popup queue
follow model removal and deduplicate replacement delivery by object identity.
Preserve newest-first order, the three-popup limit, body-tap versus close
semantics, existing timeout policy, DND delivery suppression and non-focusable
popup windows. Never requeue an older alert merely because a newer one closes.
No expiry/history-policy change, source-generation/update work, native builds,
ASUS deployment/input, service restart, package or VM lifecycle changes.

Extract the existing queue behaviour into a small ordinary Qt component so real
queue logic and model-change connections can be exercised without a live
notification bus. Installed `Quickshell/ObjectModel` metadata exposes
`valuesChanged`; no generic QML signal guessing is required.

## Acceptance and verification

RED-first controlled Qt objects/models for: replacement deduplication, app
withdrawal, urgent withdrawal, bulk removal, three-item overflow/order,
body-hide retaining history, close/removal retaining other alerts, no old alert
resurrection and empty/no-op removals. Exercise actual production component,
not only a reimplemented policy. Run current Qt and repository checks; document
actual results separately from later bus/UI acceptance. Remain draft while
unexercised live cases remain. No personal desktop capture.

## Status

Implemented and software-verified 2026-10-22. The production queue follows the
server model's removal signal without changing history. Original behaviour,
extracted unchanged, produced eight controlled Qt failures and failed an actual
private-bus withdrawal: its array retained a dead object (`null`) while server
history had already removed it. The corrected native run passed 12 actual
snapshot steps: delivery, in-place replacement, overflow, app withdrawal,
body-hide versus dismissal, muted history/unmute and urgent withdrawal/cleanup.
No original/native replacement-duplication defect is claimed.

A controlled test also covers native emit-before-model-insertion ordering. An
unrelated history change preserves the popup array identity, avoiding accidental
timer restarts. Existing timers/window focus/layering and DND caller guard remain
unchanged. `scripts/check.sh` now runs the isolated native test when its existing
qs/dbus-run-session/gdbus dependencies are present.

Final repository checks: 214 Python tests run, one GI-dependent skip; 93 Qt
results pass; four website tests pass; available syntax, config and QML checks
pass. Optional fish and shellcheck are absent. Actual private-bus data and source
hashes are in `docs/evidence/notification-popup-lifecycle.json`. No installed
source or device changed. Desktop rendering, physical touch and the rest of the
T06 matrix are not claimed. Draft remains open.

Test isolation notes: native qs resolves the configuration under `qs:@/qs`, so
stage exact fixture/production queue bytes beneath one scratch config root
instead of importing above it. Use a short `/tmp` runtime root for Unix IPC;
separate session bus, offscreen platform and scratch HOME/config/cache/runtime;
no system bus/display environment or existing shell restart. The test reaps only
its owned qs child. A private bus is always created by the runner entry point.

Authoritative ordering reference inspected during diagnosis:
https://github.com/quickshell-mirror/quickshell/blob/master/src/services/notifications/server.cpp
(`Notify`: emit new notification, test retention, then insert model; replacement
updates existing properties without another delivery signal). The actual tested
native version is recorded in the artifact; source-reference master is not a
claim about every Quickshell version.

AI-assisted contribution.
