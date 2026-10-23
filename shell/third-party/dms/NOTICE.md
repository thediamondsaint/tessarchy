# DMS / Dux launcher row

`components/LauncherRow.qml` adapts the application-row layout from
`quickshell/Modals/DLauncherV2/Components/LauncherRow.qml` in
https://github.com/duxlabs-dev/dux-shell, revision
`1b59a474dd0d33f4aeb71d1f5b545629f80eef16`.

Copyright (c) 2025 Avenge Media LLC. MIT license: see LICENSE in this directory.

Adaptations: use Tessa TouchButton, theme tokens and existing icon lookup;
retain app icon/name/subtitle row geometry; omit clipboard, plugin, dmenu,
RTL-service, controller and backend-specific features. Tessa retains native
Quickshell DesktopEntries discovery, app execution and search policy. The
search-first popup follows DMS's list presentation; the complete Dux shell and
Go backend are not installed or required.
