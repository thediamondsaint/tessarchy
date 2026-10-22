# Direct OSK dismissal — issue #89

## Scope published before implementation

Add one discoverable glyph button while the OSK is mapped in Phone or Tablet
mode. It must dismiss the keyboard directly, without opening the navigation
pill/dock, closing the app or submitting/discarding text. Button touch target
at least48x48 logical pixels; preserve the text field's keyboard focus.

Selected implementation route: a separate shell layer with only the button's
input region, immediately above the keyboard's right edge. Do not cover keys or
the physical-bottom navigation strip. Show only for a mapped `osk` layer on the
same output; availability alone is insufficient. Keep Desktop unchanged. Use
theme tokens and an accessible name. Existing `tessarchy-osk hide` supplies the
hide action; no new Squeekboard native action, raw key binding or YAML keymap
modification. Upstream Squeekboard's `Action` enum has no direct Hide action.

First verify installed Quickshell APIs and per-output layer coordinate handling.
Keep geometry decisions in a small testable policy, not duplicate magic numbers.
No background keyboard show/hide loops and no app focus grabs. Remove the layer
when the keyboard closes. Handle monitor origins and insufficient free space
without placing a target over typing keys.

## Dependencies / overlap

Based on current upstream main; no equivalent open implementation found.
Coordinate #78/PR79's physical-bottom reserved gesture strip; do not alter that
strip. #80/PR91 placement feature is independent but benefits when dismissal
restores a lifted dialog. #81 investigation found an active tablet-mode switch
and needs further measurements; no speculative tap setting change is selected.
#82 scaling and #77/PR83 native scaling/shutdown remain parked.

## Acceptance

- Focused policy/component checks: Phone/Tablet, mapped/unmapped/wrong-output
  keyboard, Desktop unchanged, origins, rotation/scale and small-space bounds.
- Hide request exactly once from the button; no text submission or app closure.
- Verify button stays outside keyboard and bottom gesture input region.
- Live acceptance must inspect screenshots and delivered touch through a
  disposable app, confirm text unchanged and continued typing after reopening.
- Software rendering and isolated CPU tests first. No host desktop changes,
  native builds, package installs, personal-app input or service restarts.
  New live-device actions require their own bounded authorization; prior #80
  device acceptance is not claimed as #89 verification.

AI-assisted feature implementation and verification.

## Implementation and CPU checkpoint — 2026-10-22 UTC

Implemented the button and no-focus Overlay layer. A read-only Lua query reads
only mapped `osk` layers, emits numeric output IDs and output-local geometry,
and excludes unmapped, orphaned and zero-sized layers. Shell monitor matching
uses the observable Hyprland monitor collection. The watcher refreshes on layer
changes plus a 500ms fallback while a touch layout is active. Desktop-only
sessions do not poll. Unknown geometry/query errors remove the button.

The 48px target sits 8px above the highest keyboard on its output and at least
24px inside the screen edge, avoiding the existing side gesture input region.
It uses the current status bar height as its top bound. If no such free rectangle
exists it hides rather than covering keys/status controls; this is an explicit
small-space limitation pending live acceptance. The touch target and layer share
one policy constant. The glyph uses theme colours and a keyboard/down-chevron.

Actual results:

- Initial policy stub: four focused Qt failures (RED).
- Final complete Qt suite:87 results passed,0 failed, offscreen software backend
  with a scratch HOME/config. Includes actual button click, unchanged draft,
  retained input focus and subsequent typing. This is a Qt component check,
  not actual application/compositor focus acceptance.
- Four Python checks pass, running the actual fixed query through a real Lua
  interpreter against fixture layer objects. Mapped/unmapped, zero-size,
  orphaned and multi-output cases covered. Not an upstream compositor test.
- `qmllint` exits0 with metadata-resolution warnings for PanelWindow/margins,
  BluetoothAdapter and QProcess::ExitStatus; it is not claimed warning-free.
- Copy-only installer in a fresh scratch HOME produced byte-identical policy,
  watcher, button, qmldir and shell entrypoint. No launcher executed.
- Actual software-rendered button preview inspected: keyboard/down-chevron
  visible, no clipping, 48px touch target. Private preview is not live evidence.

[Machine-readable checkpoint](evidence/issue89-cpu-checkpoint.json) includes
source hashes and explicitly records no live-device acceptance/native build.

Reproduce CPU checks from the repository root (the installer creates no live
session):

```sh
python3 -m unittest discover -s tests -p test_osk_dismiss.py -v
scratch=$(mktemp -d)
HOME="$scratch" XDG_CONFIG_HOME="$scratch/config" QT_QPA_PLATFORM=offscreen \
  QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME='' \
  /usr/lib/qt6/bin/qmltestrunner -input tests/qml
```

## ASUS deployment — 2026-10-22 UTC

Deployed at the owner's request, integrating only the five runtime patch paths
into the actual installed source rather than overwriting it with the topic
branch. Full source/preferences backup verified before writes; dependencies and
qmldir staged atomically before the root entrypoint, then normal live reload.
This is per-file atomic replacement, not a whole-generation atomic deployment.

The first native read caught a transport defect: `hyprctl eval` executes the
query but returns only `ok`, not its printed JSON. Corrected the watcher to
`hyprctl repl`, confirmed against native `evalRequest`/`CConfigManager::eval`
source and actual ASUS JSON. The new wiring assertion failed before correction;
all five Python checks and all87 Qt results pass after correction. Standalone
Lua print tests alone had not covered the native IPC response contract.

Actual compositor observations: mapped OSK at y704, dismiss layer at y648 with
48x48 bounds, leaving an8px gap. Real button-only capture visually inspected:
keyboard/down-chevron visible and unclipped. The query returned valid mapped
layer JSON. Normal reload logged `Configuration Loaded`; compositor configuration
errors empty. Original shell/compositor process start identities and both original
application clients unchanged; shell service restart count0. Preferences and all
unrelated installed source bytes unchanged. No service/compositor restart, input
injection, application interaction or native/package build was performed.

[Sanitized deployment evidence](evidence/issue89-asus-deployment.json) separates
source/rendering acceptance from input acceptance. Private full backups and
session metadata remain on-device/off-repository. Device-installed root/qmldir
include preserved differences; their hashes are not topic-file hashes.

Still draft: real delivered dismissal, application focus/draft/reopen and full
Phone/Tablet/Desktop mode matrix have not been exercised in this deployment.
The owner can dogfood the visible control; no personal-app input was injected.
