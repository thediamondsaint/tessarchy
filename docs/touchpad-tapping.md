# Touchpad tap-to-click — issue #81

## Scope published before implementation

Investigate the reported missing tap-to-click behavior on the ASUS dogfood
session. The recorded global Hyprland option is already true and not explicitly
set; adding the same global value is not a demonstrated solution.

First inspect shipped defaults, per-device override precedence, running device
inventory and libinput capability/default reporting. Separate a compositor's
current libinput handle state from a separate diagnostic context's defaults.
A fresh libinput context does not report the running compositor's configuration.
Do not treat synthetic pointer-button injection as proof of touchpad tapping.

No cause or implementation selected yet. Publish actual findings before changing
input policy. A device driver/compositor change or a need to capture real input
requires a separately bounded plan; no native builds, package installation,
input injection, physical-device configuration changes or session restarts are
part of this initial read-only investigation.

## Dependencies / overlap

Independent of #80/PR91's new OSK overflow placement feature. That feature now
has bounded live geometry/input acceptance. #77/PR83 native scaling and shutdown,
#82 scaling defaults, and #75 runtime-copy/update-policy expansion remain parked.
No equivalent touchpad implementation was found among current open PRs.

## Verification plan

- Read actual target Hyprland Lua/config and libinput API documentation.
- Check device capability and override paths without recording unrelated input.
- Add focused tests only once an owned behavior/cause is established.
- Preserve settings, running apps and original compositor/shell processes.
- State unresolved measurements explicitly rather than substituting defaults
  or a fresh diagnostic context for actual running-handle state.

## Read-only checkpoint — 2026-10-22 UTC

Actual ASUS observations (not inferred from defaults):

- Running compositor global `input:touchpad:tap-to-click` is true, `set:false`.
- ELAN touchpad is present and libinput reports tapping support for three fingers.
- Fresh, separate libinput context reports tapping default/current disabled.
  This is the library default, **not** the running compositor handle's state.
- No `hl.device`, tap-disable or touchpad override was found in the inspected
  installed session and user Hyprland/Tessarchy Lua files.
- `EVIOCGSW` on Asus WMI reports `SW_TABLET_MODE` active; lid switch is open.
  This is the current switch state, not proof of state when originally reported.
- No input events read, no libinput setters/dispatch, no grabs or injection;
  no package install, configuration modification or service restart.

Mechanism checked against Hyprland source: `InputManager.cpp` calls
`libinput_device_config_tap_set_enabled()` for supported devices using the
resolved per-device/global value. Lua `getDeviceInt()` normalizes names and falls
back to global values; `CLuaConfigBool::asInt()` converts true to1. No missing
boolean conversion or demonstrated missing tap-enable implementation was found.

Libinput documents that an active tablet-mode switch disables the internal
keyboard and touchpad transparently, while the device continues to appear
configured/enabled. This is a concrete current suppression candidate, **not a
proven cause of the original tap-only report**. Do not defeat tablet-mode safety
or add a redundant true setting as an unverified repair.

Next unresolved measurement: current compositor-handle tapping state and behavior
with tablet mode disengaged, distinguishing touchpad movement, physical clicking
and tapping. Current IPC device inventory does not expose that handle's tap flag.
A fresh context cannot supply it. Any wider instrumentation requires a separately
bounded plan; issue81 remains open, no implementation or resolution claimed.

References:
- [libinput tapping](https://wayland.freedesktop.org/libinput/doc/latest/tapping.html)
- [libinput tablet-mode handling](https://wayland.freedesktop.org/libinput/doc/latest/switches.html#tablet-mode-switch-handling)
- [libinput context API](https://wayland.freedesktop.org/libinput/doc/latest/api/group__base.html)
- Hyprland source: `src/managers/input/InputManager.cpp`,
  `src/config/lua/ConfigManager.cpp`, `src/config/lua/types/LuaConfigBool.cpp`.

AI-assisted investigation.
