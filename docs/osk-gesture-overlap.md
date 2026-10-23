# OSK and bottom gesture input overlap — issue #78

## Scope published before implementation

The reported portrait Tablet keyboard rectangle ends at the output bottom,
while a higher-layer, full-width 16 logical pixel gesture strip occupies the
same bottom pixels. The visible pill overlaps the spacebar; lost key presses
are user-reported, not yet independently injected.

Inspect upstream/open PR equivalents, keyboard visibility/geometry discovery,
and bottom/side gesture input surfaces before choosing a fix. Resolve actual
input-region overlap, not only drawing. Prefer a coherent policy that keeps
keys fully accessible and navigation reachable without overlaying keyboard
keys. Preserve gestures when the OSK hides, Phone/Tablet Recents buttons,
auto-hide dock protection and Desktop behavior. No hard-coded theme colours.

Dependencies/overlap: shell.qml, gesture components/policies and tests;
coordinate #63/#64/#70 and current #76. Test the public integration combination
as well as the independent patch. No ASUS restart, config mutation or input
injection during development. Use QEMU with an exclusive test window; another
worker is currently using that VM and must finish/restore before this test.

## Acceptance

Add regression tests for keyboard shown/hidden and input regions. Real VM
touch at the formerly intercepted bottom spacebar must produce spaces in a
real editor, not navigate the shell. Verify actual layer rectangles, keyboard
hide restoring normal navigation, Phone/Tablet portrait and landscape, and a
Desktop smoke check. Inspect before/after screenshots. Preserve shell PID and
apps across normal live reload, and restore guest source/settings/monitor
byte-for-byte. Publish actual results, limitations and takeover commands.

## Owner decision (after scope publication)

Reserve a small, physical-bottom navigation strip so the compositor lifts the
keyboard *above* the input surface. Keep the visible gesture pill at the
physical bottom on an opaque black, theme-token background. Do not move the
strip above the OSK, clip keys, or infer visibility from OSK availability.
Use the existing gesture target dimensions as the reservation geometry and
retain the hidden-dock reveal target in Buttons mode. Verify the reservation
against real mapped layers and typed spaces in QEMU.

## Verification and mechanism

`PanelWindow` exclusion modes cannot both keep a single gesture input window
at the physical edge and reserve space: with `ExclusionMode.Normal`, Hyprland
places the window *above* the Top-layer OSK, while `Ignore` leaves the OSK
underneath it. A Bottom-layer reservation using the policy-computed height
is therefore paired with a physically bottom-anchored Overlay input surface.
The reservation is black via `Theme.gestureBackground`; the OSK (Top layer)
ends immediately above it. The input surface remains available to swipe.
No OSK visibility guess, D-Bus polling, or OSK app layout patch is needed.

On the exclusive QEMU session, after staging the **whole** combined shell
(`sync/upstream-20261021` plus this feature), the 800×1280 rotated portrait
output had a Bottom reservation at y1256..1280, OSK at y990..1256, and
Overlay input at y1264..1280. The 1280×800 landscape output had reservation
y776..800, OSK y510..776, and Overlay input y784..800. A VM-only uinput
multitouch driver tapped the actual visible spacebar three times and Enter;
a real focused Foot terminal recorded exact bytes `20 20 20 0a` in Tablet
landscape, Tablet portrait, and Phone portrait. A bottom-edge swipe in Phone
portrait opened the apps page; its expanded strip contracted to 12px.
Phone Buttons with an app kept its 16px hidden-dock reveal target and raised
the forced-mapped OSK above it (OSK y998..1264). Desktop with the same OSK
mapped had no gesture/reservation layer. Quickshell's PID survived normal
live source reload; switching externally edited QSettings for Desktop required
a manual shell restart in the VM. No ASUS actions.

`./scripts/check.sh` passed on the feature branch (215 Python, 4 Node,
77 QML tests) and on the combined branch (228 Python, 4 Node, 89 QML tests).
`fish` and `shellcheck` were unavailable and skipped on the host. Baseline
VM shell entrypoint and shell.ini hashes were restored, the candidate-only
file removed, the output rotation restored to 0, test Foot process closed,
and test-started squeekboard stopped. All 131 backed-up shell files matched
the restored live tree byte-for-byte. **Baseline limitation:** the backed-up
shell tree is internally inconsistent: a reload of its `shell.qml` logs
`RecentsBackdrop is not a type` at line 373 because the backed-up
`components/qmldir` does not register its existing `RecentsBackdrop.qml`.
Quickshell kept its previously
loaded runtime configuration running (PID 80385); do not restart that VM
shell from this backup until the missing baseline qmldir registration is
supplied.
The OSK wrapper's private GSettings state was not snapshotted prior to
starting squeekboard, so any generated scale value there cannot be claimed
byte-for-byte restored. Physical ASUS touch and the exact owner's preferred
black/pill aesthetic remain for visual acceptance; this QEMU input is virtual
touch, not physical hardware.
