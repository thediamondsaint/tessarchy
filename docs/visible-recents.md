# Visible Recents entry in Phone and Tablet — issue #66

Owner decision (verbatim): "ok, I think just put the button back on the bar for both"

Restore a visible Recents button in both Phone and Tablet dock bars, including
when gesture navigation is selected. Keep the swipe-and-hold gesture as an
alternative. Preserve the existing switcher and Desktop taskbar behavior.

Splitting remains Tablet-only: restoring Phone Recents does not enable Phone
split controls. Do not treat a working hidden gesture as solving discoverability.

## Acceptance and coordination

Verify buttons and gestures modes in both touch layouts, a single-row narrow
320-pixel dock with horizontal overflow scrolling, touch activation of Recents,
and coexistence with the hiding dock from #64. Targets stay at least 48 pixels.
Desktop must remain unchanged. Run regression tests and inspect VM screenshots.

The change overlaps shell.qml with #63/#64/#67/#68; retain their functionality
when integrating. Do not replace installed source without comparing live edits,
and preserve the restored Quickshell.Networking Wi-Fi binding.

## Implementation and QEMU acceptance

Branch `fix/visible-recents` keeps the Recents NavButton visible in gesture and
button navigation, counts its slot in `dockLayout()`, and leaves Back/Home hidden
only in gesture mode. Both layouts share the same button; the Tablet-only
`SplitDivider.allowed` guard remains unchanged. No Desktop taskbar change.
Regression assertions cover touch dock counts and the actual button visibility;
the integrated one-row layout continues to scroll horizontally with 48px slots.

`./scripts/check.sh` on this branch: 214 Python tests, 76 Qt tests, zero
failures; fish and shellcheck unavailable. Integration with #62/#63/#64/#67/
#68/#74: public `verify/visible-recents` branch (based on
`sync/upstream-20261021` at `e7dc6b7`), 227 Python tests and 88 Qt tests,
zero failures. Python's one expected skip is environment-specific. Focused
workflow navigation test passed. Integration resolved two cherry-pick conflicts
in the policy and workflow test, retaining gesture dock shrink-to-fit and the
single #64 edge handler.

QEMU VM: virtual uinput touch, 1280x800 physical, scale 1 except for the
320x200 logical narrow pass at scale 4. On actual shell and real Foot clients:

- Phone Gestures: three dock buttons without OSK initially (Phone, Messages,
  **Recents**), four with OSK; touched Recents to open switcher, side Back
  gesture dismissed it, and a separate bottom swipe-and-hold reopened it.
  [Phone dock](evidence/visible-recents/phone-gesture.jpg),
  [gesture-open switcher](evidence/visible-recents/phone-hold-open.jpg).
- Phone Buttons: six buttons including keyboard; virtual touch on Recents
  opened the switcher, and Back dismissed it.
  [Phone Buttons](evidence/visible-recents/phone-buttons-ready.jpg).
- Tablet Gestures: four dock buttons with OSK including Recents; tapped Recents
  to open, tapped it again to close, and tested bottom swipe-and-hold.
  [Tablet dock](evidence/visible-recents/tablet-gesture.jpg).
- Tablet Buttons: six buttons. Tapped Recents to open and Back to dismiss.
  With a Foot window on the active workspace, bottom reservation changed
  `[0,48,0,84]` to `[0,48,0,0]`; virtual touch at the bottom edge revealed
  the dock above Foot and a Recents tap opened the page. More than five seconds
  later the page was still present and reservation stayed zero.
  [Open after timeout](evidence/visible-recents/tablet-open-after-timeout.jpg).
  The split action remained present in Tablet Recents and absent from Phone.
- Narrow Tablet Buttons: scale 4 yields 320 logical width; collapsed layer
  `x=16,y=116,w=288,h=84`, **one row**. Dock content is at least
  `6*48 + 5*4 = 308` logical px plus frame padding, so it overflows and
  horizontal virtual-touch flick reveals Recents. A subsequent touch on the
  scrolled Recents opened the page (`x=12,y=64,w=296,h=136`).
  [Scrolled dock](evidence/visible-recents/narrow-flick2.jpg),
  [tap opened page](evidence/visible-recents/narrow-open.jpg).
  The 200px logical height makes page content too short to use; the test is
  specifically for dock scroll/touch geometry, not narrow-screen page usability.
- Desktop single regression: full-width taskbar layer `x=0,y=736,w=1280,h=64`,
  bottom reservation 64, no touch gesture layer.
  [Desktop](evidence/visible-recents/desktop-regression.jpg).

Screenshots inspected before publication: Recents glyphs render, the dock stays
one row at 320px, no compositor error banner. `hyprctl -j configerrors` was
empty. Quickshell reported missing optional VM network backend, nightlight,
brightness, UPower and render-device fallback; configuration loaded.

## Guest restoration and remaining gaps

Installed shell tree was backed up before deployment because it predated the
integrated code and had unrelated changes; a staged complete shell tree was
installed via atomic per-file replacement, with `shell.qml` last. Atomic rename
alone did not trigger the watched file's reload; touching the now-installed
`shell.qml` did, without changing the process PID. Mode/navigation setting
changes did not take effect on that live reload, so the **VM only** shell was
restarted between preference modes; its original three Foot clients survived.
No ASUS device was touched.

After the pass, every installed file SHA256 matched the backup (131 files),
`shell.ini` was byte-identical (`cmp` exit 0), and monitor width/height/scale/
transform/position/active workspace/reservation matched the captured original
(`1280x800`, scale 1, transform 0, workspace 7, `[0,48,0,76]`). The test Foot
was closed; original Foot PIDs 829, 5305, 5437 survived. Restored shell loaded,
compositor configerrors was empty. Guest test scripts and raw captures are
untracked and not required to continue.

**Remaining:** physical ASUS touchscreen interaction and device rollout have
not been run; #65 integrated acceptance/deployment remains a coordination
prerequisite. QEMU scale-4 narrow test did not validate a usable portrait
320x640 switcher page. Existing #63 split drag/ratio, XWayland and multiple
monitors are not retested here. Maintainer can review this branch independently
or fetch `verify/visible-recents` for the tested combined shell; rerun
`./scripts/check.sh`, then virtual touch in QEMU before physical acceptance.
