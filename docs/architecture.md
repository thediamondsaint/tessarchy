# Architecture and API evidence

Tessarchy is an Arch session, not Android/AOSP. Tessera runs as a normal user
under Hyprland, using Quickshell's layer-shell panels and window integration.
No privileged daemon or compositor fork is involved.

A per-output status bar reserves 48 logical pixels. Navigation reserves 72 in
Phone mode and 80 in Tablet/Desktop. Phone navigation spans the output;
Tablet/Desktop use centered, rounded panels bounded to 720/760 pixels. Launcher
columns and panel height follow available space, including manual modes on small
screens. Settings is loaded only when opened. Panels never acquire application
keyboard focus; buttons and sliders use NoFocus. No keyboard search or outside
click dismissal is implemented.

`LayoutPolicy.js` classifies logical screen geometry: a shortest edge below 600
is Phone; otherwise a landscape width >=1100 and height >=650 is Desktop;
remaining sizes are Tablet. This is a display-size heuristic, not physical device
or input-hardware identification. Automatic mode is evaluated per output whenever
geometry changes; an explicit override applies across outputs. The override and
appearance preferences persist through QtCore Settings in
`$XDG_CONFIG_HOME/tessarchy/shell.ini` (default `~/.config/tessarchy/shell.ini`).
Dev uninstall preserves this user-owned file.

Hyprland.toplevels supplies window identity/title/state; each `.wayland` handle
provides activate(), close() and writable maximized. Close confirmation retains
the selected object rather than whichever window later becomes active. Closed
handles clear the confirmation. Windows lacking a handle have disabled actions.
These requests can be ignored by a compositor/application and need manual tests.
Only fixed `hl.dsp.exit()` goes through Hyprland.dispatch. No application title
is interpolated into IPC or a shell command. App launch uses
Quickshell.execDetached([executable]) per action, so no shared Process can drop
rapid clicks. Startup executables in the Lua config are fixed strings.

The Lua `window.open` and `window.active` handlers read the saved mode for each
ordinary window. They use the same size thresholds, accounting for monitor
scale/rotation. Mobile modes request maximization on open and on every
activation, so switching apps or closing the top one leaves a maximized app;
Desktop leaves ordinary dwindle tiling. Windows already fullscreen are left alone.
Floating windows (dialogs) are not maximized: on `window.open` in mobile modes,
one larger than the monitor's logical size minus `reserved` (bars and keyboard)
is resized to fit and centered. The app may enforce a larger minimum (GTK's file
chooser stays 726px wide on a 720px output). A mode switch does not rearrange
existing windows. Tablet split layouts remain future work. Multi-output navigation lists global windows;
per-output geometry is used for automatic mode and each new window's monitor.

Desktop mode extends the same shell with standard desktop affordances rather
than a second configuration. The status bar shows numbered workspace slots
(1-5, extended through 8 by higher existing ids) unless the output is too narrow; a tap
activates the workspace. Named workspaces have negative ids and get no slot.
When a workspace exists, `HyprlandWorkspace.activate()` is used because it
correctly emits Lua or classic dispatchers depending on `Hyprland.usingLua`;
for a not-yet-created workspace the shell dispatches a fixed
`hl.dsp.focus({ workspace = <n> })` expression containing only a number. The
focused window title sits next to the tray and is display-only; no title text
reaches IPC or shells. The Lua config adds fixed keybindings
(Super+1-5, Super+Shift+1-5, Super+Q, Super+Tab, directional focus/move,
Super+left-drag/resize, and XF86Audio* volume keys). All are fixed strings and
safe in every layout mode; close/exit shortcuts open the shell confirmation
pages, and volume keys require wpctl at press time.

The original T logo is built from six SVG faces. BrandMark animates assembly and
rotation once, settles after 1.6 seconds, and supports tap/replay and reduced
motion. It has no idle animation loop. The clock updates once per minute; mode
selection is reactive, with no polling. Optional PipeWire integration is loaded
only when the service socket exists at launch. Radio power controls use the rfkill helper. Bluetooth quick controls bind only when BlueZ
exposes an adapter: the pull-down panel toggles the radio, requests discovery only while
expanded and powered on, and connects or disconnects already-paired devices; pairing,
forgetting and passkey agents are out of scope. Wi-Fi quick controls bind only when
NetworkManager exposes a Wi-Fi device: the panel scans only while expanded with the radio
on, orders networks connected-first then by strength, connects saved and open networks,
disconnects the connected one, and asks for a passphrase on unsaved secured networks.
Passphrases go straight to NetworkManager through `connectWithPsk`; the field is masked,
cleared before the attempt and on cancel, and the panel stores no copy. The live image
enables NetworkManager with `wpa_supplicant`; development hosts without NetworkManager
fall back to the "no NetworkManager backend" row.

## Verified against installed files, 2026-10-16

- Hyprland 0.56.2: `/usr/share/hypr/hyprland.lua`,
  `/usr/share/hypr/stubs/hl.meta.lua`, and `Hyprland --verify-config`.
- Quickshell 0.3.1: installed QML metadata under `/usr/lib/qt6/qml/Quickshell/`,
  especially Hyprland/_Ipc, Wayland/_ToplevelManagement and _WlrLayerShell;
  `qs --help` confirms path selection and duplicate protection.
- [Quickshell Toplevel API](https://quickshell.org/docs/types/Quickshell.Wayland/Toplevel/)
  documents activation, close and maximize as compositor requests.
- [Quickshell Hyprland workspace API](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/HyprlandWorkspace/)
  documents `workspaces`, `focused`/`active`, `toplevels` and `activate()`.
- Hyprland 0.56 source (`LuaBindingsDispatchers.cpp`, `LuaBindingsToplevel.cpp`)
  confirms `hl.dsp.focus`, `window.move/close/cycle_next/drag/resize` and bind
  flags `mouse`/`locked`/`repeating`.
- [Hyprland window rules](https://wiki.hypr.land/configuring/core/rules/window-rules/)
  documents the Lua maximize rule.
- [Official archiso profile specification](https://github.com/archlinux/archiso/blob/master/docs/README.profile.rst)
  and [releng profile](https://github.com/archlinux/archiso/blob/master/configs/releng/profiledef.sh)
  inform the overlay; installed archiso supplies the actual bootloader files.

Session authentication is provided by the separate greetd greeter; a Wayland
session-lock implementation is tracked independently in the agent backlog.

## On-screen keyboard

The session starts `tessarchy-osk start` after Tessera. When squeekboard is
installed it runs as an ordinary client and reserves its own `osk` layer above
the navigation bar, so maximized apps shrink rather than being covered.
squeekboard shows itself for focused text fields only when the GNOME a11y key
`screen-keyboard-enabled` is true. Rather than change that global user setting,
the wrapper starts it with a keyfile GSettings backend under
`$XDG_STATE_HOME/tessarchy/osk` (default `~/.local/state/tessarchy/osk`), seeded
once with the key enabled. Users may edit that file; it is never overwritten.
The Keyboard navigation button calls `tessarchy-osk toggle`, which uses
squeekboard's `sm.puri.OSK0` D-Bus `Visible`/`SetVisible` on the session bus. Tessera
panels never take keyboard focus, so the app keeps its text field. The button
appears only when `tessera-shell` finds squeekboard and the wrapper, and is not
added to Desktop mode. Without squeekboard nothing starts and no button appears.
The guest test observed squeekboard load its terminal layout for Foot and its
text layout for Firefox's address bar, so text-input content purpose reached it;
the exact protocol traffic was not traced.

Advanced audio controls live in the pull-down. Expanding the section loads the
optional PipeWire panel and tracks nodes before inspecting their audio metadata.
It lists ready audio outputs and playback audio streams only; closing the section
releases the tracker. Writes validate current backend/node readiness and model
membership. The shared basic mute/volume controls remain accessible above it.

Screenshots use the fixed-argument tessera-screenshot helper. Print captures the
full Wayland desktop; the pull-down camera action closes controls before a short
capture delay. Each successful capture has a unique private PNG path under the
configured pictures directory's Screenshots folder. Capture failure removes the
partial output, and notification failure does not discard a saved capture.
