# OSK overflow placement — issue #80

## Scope published before implementation

After a Phone/Tablet floating dialog receives a resize request, inspect its
compositor goal geometry, including later declared-minimum corrections. If it
remains too tall to clear the visible keyboard,
move that window upward beneath the status bar, leaving the bar above the app.
Overflow beyond the status-bar height may place the top farther off-screen.
Restore the policy-owned placement when the keyboard closes; hiding the keyboard
must also make upper application content reachable again.

First verify the target Hyprland Lua layer/window/event APIs. A dispatched resize
is not evidence that a toolkit accepted the requested size. Do not treat a
compositor allocation as proof of the client's actual content dimensions.

Keep changes per-window. Preserve normal fitting dialogs, Desktop behavior,
fullscreen/tiling/split policy, monitor origins, rotation and fractional scale.
Do not remove top reservations globally, change app settings or scale application
content. Avoid repeated resize/move loops and do not overwrite a user's later
manual placement with stale saved coordinates.

## Dependencies and overlap

Base: current upstream main. Existing `session/hyprland.lua` fitting/refit events
and workflow tests. Coordinate #78 keyboard reservations and #89 dismissal.
PR83/#77 native fitting and shutdown remain parked and are not dependencies or
authorization for native work. No equivalent open #80 implementation was found.

## Verified mechanism and implementation

Hyprland v0.56.2 `CWindow::commitWindow()` clamps floating-window geometry to
client-declared minimum sizes via `clampWindowSize(minSize, maxSize)`.
That correction preserves the window centre. Lua `window.size` and `window.at`
read compositor **goal geometry**, not client buffers or configure acknowledgements.
There is no exposed Lua client-commit/ack/size-change event. The fallback observes
goal geometry every 150 ms while tracked dialogs and a mapped keyboard remain;
it never interprets a timeout as acknowledgement and does not repeatedly resize.
This can observe the declared-minimum correction, not arbitrary buffer overflow.

`hl.get_layers({})` supplies mapped layer objects. Match monitor and namespace,
then add the monitor origin to layer-local y. Squeekboard's upstream `src/panel.c`
sets namespace `osk`. A layer-close callback precedes unmapping/reservation
updates, so both keyboard presence and restoration are checked after the event.

The existing resize/centre request runs first. If the later goal remains too
tall, move that window so its bottom clears the keyboard. Track policy ownership,
recognize centre-preserving minimum corrections, and leave later manual placement
alone. Repeated events with unchanged bounds do not repeat resize requests.
On hide, restore the original position when it still fits; otherwise constrain it
to the current work area. A delayed initial pass also handles existing dialogs
after config load, including an old off-screen placement whose dialog now fits.
Reload cannot recover coordinates from the old Lua VM; that recovery constrains
placement to the current work area when the keyboard hides. Manual placement
made after recovery is still respected. No bar, reservation, native fitting or
application settings change.

Sources:
- [Hyprland v0.56.2 Window.cpp](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/desktop/view/Window.cpp)
- [Lua window binding](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/objects/LuaWindow.cpp)
- [Lua layer binding](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/objects/LuaLayerSurface.cpp)
- [Squeekboard panel](https://gitlab.gnome.org/World/Phosh/squeekboard/-/blob/main/src/panel.c)

## Verification

- RED-first isolated Lua tests model a requested resize followed by a delayed
  floating-commit minimum-size correction; they do not model raw client buffers.
- Cover successful resize (no lift), minimum-height overflow, keyboard hide and
  repeated events, moved/closed windows, multi-output origins, rotation and scale.
- Desktop/fullscreen/nonfloating controls must remain unchanged.
- Run applicable software/static checks. Do not launch a compositor/config
  verifier, compile native code, run VM/GPU tests or change the ASUS for this work.
- If the required Lua observable/event is absent, document that exact blocker
  rather than inventing an API or claiming a synthetic model is live acceptance.
- Actual compositor/touch/visual acceptance remains outstanding until separately
  exercised; source tests alone cannot establish the requested user behavior.

### Software checkpoint — 2026-10-22 UTC

`python3 scripts/probe-osk-window-lift.py` completed successfully:

- Baseline includes its real Lua dependencies and passes two positive controls.
- Baseline: 15 failing behavioral assertions in the 20-test suite; no setup errors.
- Changed source: all 20 policy tests pass, including origin/rotation/scale subcases.
- Existing workflows: 65 pass. The native portal-build test is explicitly excluded,
  not counted as passed. This is not a full `scripts/check.sh` result.
- `luac -p session/hyprland.lua` passes.

Detailed logs: ignored `build/osk-window-lift/`. [Aggregate evidence](evidence/issue80-lua-policy.json)
records source hashes, exclusions and `compositor_or_device_acceptance: false`.

The software checkpoint above preceded separately authorized live acceptance;
its `compositor_or_device_acceptance: false` describes that software run only.

### Live feature acceptance — 2026-10-22 UTC

Implemented feature, not a regression repair. On the ASUS, used a disposable
native GTK3 dialog with a declared 850px minimum height, real Squeekboard and
1920x1080 landscape output at scale 1. Integrated only this placement feature
into backed-up installed Lua, preserving existing session changes; replaced the
watched file atomically and reloaded configuration without restarting services.

- Baseline bottom action was behind the keyboard. Candidate exposes the whole
  action with 24px clearance; screenshot inspected, top bar preserved.
- Keyboard-hide restoration, config-reload recovery and externally moved-dialog
  preservation passed. The external-move control is not a physical finger drag.
- A guarded temporary uinput direct-multitouch device targeted only the owned
  dialog. GTK logged touch BEGIN/END and the actual bottom action activated.
  This is delivered native input, not an invocation of the button callback.
- Removed the virtual touchscreen, closed only the disposable fixture and hid
  the keyboard. Original shell/compositor process identities, preferences and
  monitor settings remained unchanged; no compositor configuration errors.
- Private fixture initially logged early unmapped-coordinate callback errors;
  later mapped bounds and delivered-input evidence are valid. Added an unmapped
  guard afterward; that instrumentation-only guard was not rerun on the device.

[Sanitized live evidence](evidence/issue80-asus-acceptance.json) is distinct from
the software-model report. Raw device backups and connection details stay private.
No native compositor build, package installation or shell restart was performed.
No physical sensor retest is needed for this feature. Phone, other orientations/
scales and Desktop were software-tested, not live-tested in this pass. PR remains
draft and #80 open for upstream review; deployment does not imply upstream landing.

AI-assisted implementation and verification.
