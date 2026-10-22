# Touch and widget research

This first pass keeps the Hyprland compositor close to its defaults and puts
touch behavior in Tessa's QML layer. No external widget code was copied.

## Patterns reviewed

- [short-circuit/qml-widgets](https://github.com/short-circuit/qml-widgets) uses
  thin edge `PanelWindow` strips, `keyboardFocus: None`, accumulated drag
  distance, and orientation-aware anchors. These constraints fit the existing
  Tessa edge wheel and gesture surfaces.
- [caelestia-dots/shell](https://github.com/caelestia-dots/shell) provides a
  large Quickshell widget/dashboard architecture with weather, media, calendar,
  visualizer, and settings widgets. It is GPL-3.0; only interaction ideas were
  reviewed.
- [sluets/quickshell-hyprland](https://github.com/sluets/quickshell-hyprland)
  demonstrates a modular widget catalog, shared theme singleton, desktop
  widgets, weather/clock/media services, and live theme changes. Tessa already
  has equivalent service boundaries, so no dependency was added.
- [AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
  documents a shared QML widget library and plugin surface. Tessa keeps its
  smaller local component set and theme tokens until a stable plugin contract
  is needed.

## Current implementation

`DesktopWidgets.qml` is the first native Tessa widget surface. It provides
calendar, weather, media, and battery cards with large touch targets, a
single-column phone layout, a two-column tablet layout, and a four-column
desktop layout. Cards use `Theme.glass`, theme borders, and existing Quickshell
weather/MPRIS/UPower services. Weather refresh and media transport actions are
signals, so the cards do not spawn new daemons or bypass the shell backends.

Next widgets should follow the same rules: no hard-coded palette, no permanent
desktop reservation, no keyboard focus theft, and no new dependency without a
measured need. Candidate additions are notifications/calendar agenda, network
and audio controls, clipboard, system health, and a configurable widget grid.
