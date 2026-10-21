# Scrolling UI reuse audit (2026-10-21)

## Starting point

PR #61 already implements an opt-in native Hyprland scrolling tape, a QML drag strip, previous/next and exit controls, 48px touch targets, theme integration, Lua guards, and an optional native gesture bridge. **Do not rebuild these.** Its regular QEMU VM and physical-touch acceptance are still outstanding. This branch is an isolated design/audit branch, not a deployment branch.

## Target UX

Phone/tablet: real app windows scroll horizontally as windows, not cards. Replace the always-visible bottom navigation concept in the experimental tape mode with a compact floating Tessarchy cube that expands to app launcher, navigation and controls. An optional thumb-operated edge wheel should move the real tape. Preserve existing normal workspaces and navigation until user acceptance.

## Reuse decision matrix

| Feature | Reuse first | Integration decision |
| --- | --- | --- |
| Native tape | PR #61, Hyprland built-in scrolling | Keep existing workspace isolation, full-width columns, Lua guards and bridge fallback. Avoid Niri or a second layout engine. |
| Floating cube | Existing Tessera TouchButton, theme and GestureHandle; compare end-4/dots-hyprland FloatingActionButton.qml | Borrow FAB visual/expansion patterns only if license compatible; don't copy a parallel theme or IPC stack. |
| Launcher | Tessarchy existing launcher and installed-app discovery (PR #58); compare doannc2212/quickshell-config AppLauncher.qml | Retain native DesktopEntries / AppPolicy and current launcher behavior; borrow GridView and keyboard handling selectively. |
| Edge wheel | Existing PR #61 drag strip, Qt Quick drag input; evaluate QQC2 ScrollBar | A scrollbar is a visual/input widget, **not** a Hyprland scroll bridge. Reuse PR #61's coalesced move/fallback and snap logic. |
| Radial actions | Existing Tessera components; compare neruson27/hypr-radial-menu | Only port geometry if genuinely needed; avoid Python daemon/socket unless existing IPC cannot support it. |
| Search | Existing launcher + PR #58; compare caelestia-dots/shell Apps.qml | Defer SQLite frequency DB and prefix commands to later iteration. |

## Build sequence

1. Inspect PR #61 changed files and Tessarchy shell component registration, navigation/gesture layering, theme tokens, installed-app policies and tests. Record precise reuse points.
2. Inspect upstream source files, versions and licenses before copying any implementation; prefer concepts and small adaptations over wholesale imports.
3. Prototype floating cube in **tape workspace only**, with minimum 48 logical-pixel hit targets, keyboard accessibility and non-stealing focus.
4. Connect launcher to existing Tessarchy app source. Keep current launcher operational in ordinary modes.
5. Replace experimental drag-strip presentation with edge-wheel control using PR #61's real tape movement and release/snap; avoid driving focus with a series of synthetic keypresses.
6. Test phone portrait, tablet landscape, OSK/IME, Recents/Quick Settings, app dialogs, fullscreen, rotation, narrow widths, multiple outputs, and no-input-grab behavior.
7. Run ./scripts/check.sh and QEMU VM with real Wayland clients; document any missing physical device validation. Keep PR draft until acceptance.

## Key source references

- Existing prototype: https://github.com/thediamondsaint/tessarchy/pull/61
- Installed app launcher improvements: https://github.com/thediamondsaint/tessarchy/pull/58
- Hyprland native scrolling: https://wiki.hypr.land/configuring/layouts/scrolling-layout/
- FAB candidate: https://github.com/end-4/dots-hyprland
- Launcher candidate: https://github.com/doannc2212/quickshell-config
- Radial candidate: https://github.com/neruson27/hypr-radial-menu
- Search candidate: https://github.com/caelestia-dots/shell

## Verification boundary

This commit is a design and integration audit only. External candidate source files/licenses have not been fetched or vetted, and no code has been copied. No test, VM run, or live device change is claimed. Do not use Hermes's time/token estimate as a measured budget.

## Naming and cost policy (owner decision)

- **Tessarchy** is the OS/distribution/installer/ISO/project identity.
- **Tessa** is the desktop environment: shell, launcher, panels, navigation, theme and user-facing UI.
- Prefer changing user-visible strings first; preserve internal names, package IDs and IPC identifiers unless a migration is necessary.
- Token discipline: inspect exact files and diffs, avoid repeated full-repository reads, reuse existing code and upstream APIs, implement in small increments, and run focused tests before the full suite.
- Open-source reuse requires verifying the actual source version and license, preserving attribution and complying with redistribution terms. Do not blindly copy incompatible or unlicensed code.
