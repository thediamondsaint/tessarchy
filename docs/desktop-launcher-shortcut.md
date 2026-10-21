# Desktop app-menu keyboard shortcut — issue #69

Report: the Desktop app menu needs keyboard access, without a mouse. No key
combination was specified. Choose the conventional Super+Space shortcut if
upstream and runtime inspection confirm it is unassigned; document that choice.

## Scope before code

Inspect upstream main and open PRs for equivalent work. Add a named shell IPC
entry for opening/toggling the existing Desktop Start/app menu and a Hyprland
binding to invoke it. Reuse the same menu as the taskbar Start button, not a
separate launcher. Preserve Escape dismissal, app launch lifetime isolation,
settings, native Wi-Fi and all Phone/Tablet navigation behavior. Do not replace
Alt+Tab window switching or change the user's personal config.

Coordinate shell.qml/hyprland.lua with #62/#63/#64/#67/#68/#70/#74. The public
sync/upstream-20261021 integration is the device source; validate the combination
without editing the parent's worktree. Source changes should live-reload, not
restart the shell. Never mutate/restart the ASUS during development.

## Acceptance and takeover

Add focused IPC/binding regression tests and run check.sh. In the VM, actual
keyboard input must open the Desktop app menu, support dismissal/toggling,
and allow launching a real app through the isolated lifetime path. Verify
no config errors, stable shell PID and no lost apps during source reload.
Document behavior outside Desktop and preserve touch layout controls. Back up
and restore VM state byte-for-byte. Push checkpoints and actual screenshot/
input evidence; distinguish static wiring from actual keyboard acceptance.

Current state: feature implemented and published on `fix/desktop-launcher-shortcut`;
the scratch combination is published as `verify/desktop-launcher-shortcut`,
stacked on `sync/upstream-20261021`. Actual QEMU keyboard acceptance, test
counts, screenshots and byte-identical VM restore are in `docs/testing.md`.
Directional selection of the second app tile was not shown working in QEMU;
the first tile launched successfully with Enter. Upstream review/merge and
hardware verification remain outstanding. #66 visible Recents is integrated
and deployed via atomic live overlay with original apps and shell PID preserved.
Next queue after this issue: #71 taskbar selector alignment, then #73 truthful
status indicators, then #75 atomic package/config update design. Do not land on
upstream main or assert a draft PR is merged.
