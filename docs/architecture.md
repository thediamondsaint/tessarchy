# Architecture and API evidence

Tessarchy is an Arch session, not Android/AOSP. Tessera runs as a normal user
under Hyprland, using Quickshell's layer-shell panels and window integration.
No privileged daemon or compositor fork is involved.

A per-output status bar reserves 48 logical pixels. Navigation reserves 72 in
Phone mode, 80 in Tablet and 64 in Desktop. Phone navigation spans the output;
Tablet uses a centered, rounded panel bounded to 720 pixels. Desktop uses a
full-width taskbar instead of the floating dock, laid out like Windows XP's but
rendered in the same glass: a narrow logo-only Start button and weather,
quick-launch buttons, wide bevelled task buttons (the focused window reads as
pressed), and a sunken tray holding the built-in status indicators (moved off the
status strip in this mode), the application tray icons and the clock. The task
strip scrolls within available space and reveals the active window. Tray glyphs
share a pale-mint palette and 18px size, with uniform 32px tray slots
that are 48px tall; NetworkManager uses the
matching outlined network glyph. Built-in Wi-Fi and cellular indicators read
actual NetworkManager/ModemManager percentages through a separate typed D-Bus
helper; unknown or unavailable radios have no invented strength. Tapping either
indicator opens its connection controls. See [networking](networking.md). The taskbar stays full width while a page is open so the page reads as a centered sheet. The
Start button toggles a Windows-XP-style Start menu: a blue-tinted panel with a
compact grid of floating app icons and labels, without tile backgrounds. It sits
flush on the taskbar's top edge and is frosted by the
same compositor blur rule as the bar and status strip. Desktop
ordinary windows open floating at a conventional size and centred ("windowed"), or
join the dwindle tile layout ("tiled"), per the Desktop setting in Settings; the
Hyprland config reads the same value. Launcher
columns and panel height follow available space, including manual modes on small
screens. Settings is loaded only when opened. Navigation preserves application
focus. While Start is open, its menu takes keyboard focus for Tab, Enter and
Escape; clicking outside also dismisses it through a Hyprland focus grab.
Keyboard application search is not implemented.

`LayoutPolicy.js` classifies logical screen geometry: a shortest edge below 600
is Phone; otherwise a landscape width >=1100 and height >=650 is Desktop;
remaining sizes are Tablet. This is a display-size heuristic, not physical device
or input-hardware identification. Automatic mode is evaluated per output whenever
geometry changes; an explicit override applies across outputs. The override and
appearance preferences persist through QtCore Settings in
`$XDG_CONFIG_HOME/tessarchy/shell.ini` (default `~/.config/tessarchy/shell.ini`).
Dev uninstall preserves this user-owned file.

The status strip also carries current conditions. `shell/helpers/weather.py`
resolves the location from `[Shell] weatherPlace` — a city name, or `auto` (the
default) to place the machine by IP — and reads Open-Meteo's keyless current
weather. `weatherUnits` selects metric or imperial. The last observation is
cached under `$XDG_STATE_HOME/tessarchy/weather.json` so the chip can show a
stale reading, marked as such, across an offline spell rather than disappearing.

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
desktop top edge shows only the centered pulldown control. Weather sits next
to the narrow logo-only Start button; time remains in the taskbar. Phone and
tablet retain their top-strip clock and indicators. Application tray indicators live in the taskbar, not the
status strip, because their pixmaps are supplied by the applications and cannot
match the shell's own icons. The Lua config adds fixed keybindings
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
forgetting and passkey agents are out of scope.

## Notification delivery

Tessera registers Quickshell's `NotificationServer`, which claims
`org.freedesktop.Notifications` on the session bus, so ordinary D-Bus
notifications reach the shell without any extra daemon. Every delivered
notification is marked tracked, which is the history model the alert center
lists; `dismiss()` removes an item from both pop-ups and history, and an
application withdrawing a notification does the same. The server advertises
only what the card renders: a plain-text body. Markup, hyperlinks, inline
images, actions and persistence are explicitly disabled rather than advertised
and ignored. Notification text is untrusted input and is only ever displayed
as plain text; no body content reaches IPC, a command line or a filename.

Pop-ups are views over at most the three newest tracked items and render once,
on the first screen. Phones show full-width cards below the status bar;
tablet/desktop right-align a column of at most 360/420 logical pixels. Tapping
a pop-up hides it but keeps it in the center; the close button dismisses it
everywhere. Low-urgency pop-ups leave after 4 seconds, normal after 8, and
critical ones stay until acted on. The "pop-ups muted" preference persists in
`shell.ini`; muted notifications still collect in the center. Nothing is
persisted across sessions, and no notification history is written to disk.

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
- Quickshell 0.3.1 notification service source (`NotificationServer`,
  `Notification`): `tracked` keeps an item in `trackedNotifications`, and
  `dismiss()`/`expire()` remove it from the model via `deleteNotification`.
  The capability properties are honored exactly; unsupported features are
  advertised as false rather than silently dropped.

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
added to Desktop mode. Desktop mode also disarms the key through
`tessarchy-osk disable` (and re-arms it with `enable`), so a focused text field
never raises a keyboard panel over a desktop window; the shell applies this on
every layout change. Without squeekboard nothing starts and no button appears.
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

## Power panel

Quick controls reads the UPower display device for battery charge state, time
estimates and health. Missing UPower state is shown as unavailable. Power modes
come from a separate Gio helper using power-profiles-daemon's current or legacy
D-Bus interface. The helper reads the service's supported profiles before every
write and rereads the active profile afterward. Unavailable/unsupported controls
stay disabled. Profile polling runs only while the panel is visible.

## Idle blanking

Idle handling is one hypridle listener: five minutes without input blanks the
panel with `hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'`, and resume
brings it back with the matching enable dispatch. The session starts hypridle
from the existing `hyprland.start` hook with the same data-directory resolution
as `tessera-shell`; key presses and mouse movement explicitly wake the panel
through `misc.key_press_enables_dpms` and `misc.mouse_move_enables_dpms`. No
lock command is configured: Tessarchy makes no session-locking claim.
## Display rotation

Screen rotation in Settings cycles the focused output through 90-degree steps.
The panel calls the fixed-argument tessera-rotate helper, which rewrites only
Tessarchy's generated display.lua with the currently applied mode, position and
scale plus the new transform, reloads Hyprland and verifies the result. The
previous file is restored when verification fails; user preferences.lua is
never modified. Touch remapping after rotation remains a hardware check.

## Display controls

Quick controls probes the first backlight when opened, then coalesces brightness
changes through `tessera-brightness`. The helper targets the same backlight for
reads and writes, uses brightnessctl when available and falls back to writable
sysfs. Hardware brightness keys use the same helper. Failed writes show an error
and read back the actual level; devices without a backlight hide the control.

`tessera-nightlight` starts hyprsunset at 4000 K in the transient user service
`tessera-nightlight.service`. Systemd owns and stops its process; the helper does
not trust PID files. The toggle persists its preference in shell.ini and reads
back service state. Missing hyprsunset or an unavailable user manager hides it.
The ISO includes both backends; the session package lists them as optional.

Alt+Tab uses `QuickSwitcher.qml` in a separate transparent overlay centered on
the focused output. It displays only application icons, ordered by recent focus;
the selected icon is larger and brighter. Tab/Shift+Tab cycle, Alt release or
Enter activates after the keyboard grab is released, and Escape cancels. The
icon row scrolls to keep selection visible when many windows are open. The
touch Recents action continues to use `AppSwitcher.qml` and its preview cards.
