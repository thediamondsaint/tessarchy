# Automatic touch dock hiding

## Scope

Hide the bottom dock while application windows are open in Phone and Tablet,
reclaim its reserved space, and allow touch reveal over the application.
Preserve Desktop taskbar behavior and existing navigation choice. Keep the
gesture-handle preference separate from automatic dock hiding.

## Coordination

The dock geometry and horizontal-scrolling carry-forward in PR #63 must be
preserved when integrated. This change does not redesign dock contents, system
navigation or top-bar tools.

## Acceptance

- Hidden dock reserves no application space.
- Touch reveal remains reachable and overlays application windows.
- Shell pages retain usable navigation.
- Keyboard and split layouts do not acquire blocked controls.
- Desktop behavior is unchanged.

## Verification plan

Automated policy tests and VM touch/screenshot checks across Phone, Tablet and
Desktop; Buttons and Gestures; app/no-app and keyboard visible/hidden states.

## Current status

The dock policy is implemented on upstream main without importing #63: Phone
and Tablet hide the dock on an active workspace with an app; the collapsed dock
has zero exclusive zone, and a bottom-edge Overlay strip accepts a tap to reveal
it for five seconds. Gesture navigation still swipes to Home/Recents; Buttons
mode can reveal the dock by tap or upward swipe. Shell pages remain visible and
overlay apps without claiming space. Desktop retains its taskbar and reservation.
`showGestureHandle` only controls the pill; it never controls dock visibility.

This changes visibility and the reserved zone, not geometry or button layout.
When #63 merges, retain its single-row horizontal scrolling and frame widths;
no #63 commits are copied here. The gesture strip is a separate layer so it
stays touchable when the dock window is hidden. A revealed dock automatically
hides again after five seconds unless a shell page is open.

## Validation and takeover

`./scripts/check.sh` passed on this branch: 215 Python tests (one skip), four
Node tests and 77 Qt tests; Hyprland configs parsed. Qt covers policy across
modes, navigation choices, keyboard availability, pages, and strip tap/swipe.
Upstream Quickshell 0.2.1 type documentation lists
`HyprlandWorkspace.monitor` and `HyprlandMonitor.activeWorkspace`.
No QEMU screenshot/touch acceptance was performed; runtime window-model
reactivity, keyboard overlap, multilayer ordering, split layouts and physical
interaction remain unverified. Next: deploy safely to a controlled QEMU guest,
exercise the matrix and preserve screenshots; then rebase after #63 lands and
check its scrolling dock with this visibility policy. No ASUS deployment.
