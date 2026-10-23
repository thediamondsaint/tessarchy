# Tessa integration

Tessa is the desktop environment running on Tessarchy. Internal `tessera-*`
commands, package names, namespaces and theme sections remain compatible.

This branch starts from #85 on #61, then integrates #58's native installed-app
inventory. #84 is a design audit. #63's tablet split policy and #64's general
dock hiding are independent work and are not merged here. Only the experimental
scrolling workspace hides its dock and app-edge gesture interception.

Super+Space opens the launcher; type to search, arrows select, Enter launches and
Escape dismisses it.

Enter Settings → Try Window Tape or Super+T. Tap the floating cube for recent apps in most-recently-used order, Apps,
previous/next windows, a radial Menu and exit. Swipe the recent app icons horizontally
and tap an icon to switch. The cube and radial menu use icons throughout;
labels remain available to assistive technology. The shelf dismisses the keyboard and hides the edge wheel
to keep its touch controls clear, then collapses on selection, the close icon
or inactivity. Browsing postpones idle collapse. Drag the lower edge wheel to move
real windows; release snaps through the existing #61 bridge. Without the optional
bridge, the existing 120px stepped fallback remains available. The × action and
Super+T return to the preceding normal workspace. Apps stay on the tape for reentry.
Settings → Window Wheel selects Bottom slider, Left edge wheel or Right edge
wheel. The curved dark-glass rail, illuminated ticks and bright center marker
follow the supplied wheel-style reference. The bottom rail takes horizontal
drags; the side rails map up/down drags to the same native horizontal tape.
Thumb travel scales with the output width so tablet and desktop windows remain
reachable with the same short gesture. The cube and wheel remain separate,
with no reserved bottom dock.

The cube does not request keyboard focus. Apps and Settings request it on demand.
Radial actions use the existing launcher, Settings, Recents, Quick Settings and
on-screen keyboard. Reduced motion disables the control reveal animation.

## Reuse and licenses

Actual upstream files and repository license files were inspected on 2026-10-21:

| Source | Inspected file | Decision |
| --- | --- | --- |
| [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) | `dots/.config/quickshell/ii/modules/common/widgets/FloatingActionButton.qml`, GPL-3.0 | Retain existing TouchButton; use compact/expanded sizing and reveal pattern without importing its theme/widget framework |
| [doannc2212/quickshell-config](https://github.com/doannc2212/quickshell-config) | `app-launcher/AppLauncher.qml`; no root license file found | No code copied; retain DesktopEntries, retain metadata search and keyboard navigation |
| [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | `modules/launcher/services/Apps.qml`, GPL-3.0 | Retain native entries and execution; avoid its database and search dependencies |
| [neruson27/hypr-radial-menu](https://github.com/neruson27/hypr-radial-menu) | `daemon.py`, GPL-3.0 | Use standard circular placement and center cancellation in QML; no daemon or source copied |
| Hyprland 0.56.2 | installed native scrolling headers and #61 bridge | Keep compositor-owned layout, focus and snapping; matching ABI required |
| [Qt Quick Controls ScrollBar](https://doc.qt.io/qt-6/qml-qtquick-controls-scrollbar.html) | attached/non-attached API | Use for launcher ListView. Its normalized position has no compositor connection; retain #61 relative drag signals for the edge wheel |

The compact launcher replaces the large app grid with a search-first list.
GitHub popularity on inspection: end-4 about 16.4k stars, Caelestia 13k, and
DMS/Dux 8.5k. Stars describe each shell repository, not a standalone menu.
[DMS, now Dux Shell](https://github.com/duxlabs-dev/dux-shell) was also inspected:
`quickshell/Modals/DLauncherV2/{Components/LauncherRow.qml,Components/LauncherSearchField.qml,ResultsList.qml,SpotlightLauncherContent.qml}`
at revision `1b59a474dd0d33f4aeb71d1f5b545629f80eef16`.
The MIT application-row layout is adapted in `LauncherRow.qml`, with the
[upstream license and attribution](../shell/third-party/dms/NOTICE.md) preserved.
Its controller, Go backend and shell services are not required; Tessa keeps
DesktopEntries, application policies and execution. No dependency was added.
The existing #61 bridge attribution remains intact. Runtime acceptance
and limitations are recorded in [testing.md](testing.md).


For the cube's recent-app shelf, the actual GPL-3.0 end-4 files
`FloatingActionButton.qml`, `overview/OverviewWidget.qml` and
`overview/OverviewWindow.qml` were inspected again at revision
`2f2a376fdb2ad738bf55f693dd0b474b64bb0ab8`.
[Quickshell Overview](https://github.com/Shanu-Kumawat/quickshell-overview),
revision `47f0d402822b26805ed0ecea4a770c38c537b728`, was also inspected:
`modules/overview/{OverviewWidget.qml,OverviewWindow.qml}` uses native screencopy,
glass surfaces and configurable previews. No root LICENSE was found there and
its README credits end-4. Neither implementation is copied into Tessa. Their
preview and reveal patterns fit the existing `AppSwitcher` and cube; compact mode
reuses Tessa's capture lifetime, horizontal flicking, touch activation, swipe
closing and deferred compositor-focus handoff. No service or dependency is added.
The cube's cyan edge uses the same `wheel_glow` token as the navigation wheel.


## Themes

Open the cube → Menu → Settings → Appearance. The existing touch theme cards
apply the palette to Tessa, its on-screen keyboard and themed Foot terminals.
Tessa Night and Tessa Light retain their compatible internal `tessera` IDs.
23 additional unmodified Omarchy palettes are bundled, including Catppuccin,
Tokyo Night, Gruvbox, Nord, Everforest, Rose Pine and light variants. No download
or Omarchy installation is needed. Palette-only themes derive the existing glass
surfaces and cube/wheel glow from their own accent; Tessa Night keeps its explicit
cyan glow. Theme buttons pause while applying and show failures in Settings.

Imported from [Omarchy](https://github.com/omacom/omarchy), revision
`82662dd2627db3b22c63616d3cae025aeb0f1e47`. Only `themes/*/colors.toml` is copied;
[MIT attribution](../themes/OMARCHY-NOTICE.md) and the upstream license ship with
it. Wallpapers, icon packs and executable Hyprland configurations are not copied.
Custom compatible palettes can still be placed under
`$XDG_CONFIG_HOME/tessarchy/themes/<name>/colors.toml` (default `~/.config`).


## Icon-only glass cube

The current cube uses the existing QuickSwitcher in glass mode: large app icons,
translucent circular plates and a selection dot. Text headings, app captions and
action captions are removed. All actions use existing themed SVGs via Icon and
TouchButton, retaining accessible names and 48px minimum touch targets. Normal
Alt+Tab and full Recents keep their existing behavior. Hyprland now blurs the
`tessera-tape` layer too; Qt gradients and thin highlights form the glass surfaces.

Inspected actual source and licensing for
[MacShell](https://github.com/0-ss/MacShell), revision
`94f3b3b1b5239162a8a20ac2ba088bbb3a6d59e8`: `GlassSlab.qml`,
`GlassSegmented.qml` and `MacLock/Glass.qml`, MIT; and
[KDE Quickshell Dock](https://github.com/IFtiger-hu-hub/kde-quickshell-dock),
revision `08a36f98fc5f79971dd296d5bcf460afc32f44cb`: `DockIcon.qml`,
`FolderDockIcon.qml`, `UtilityCell.qml`, no declared license/root LICENSE found.
Their per-icon glass plates, press feedback and frosted fallback patterns informed
the design. Tessa reuses its own components and compositor blur; no upstream
source, shader, KDE service or new dependency is imported.


Activating a scrolling window uses the existing Lua window-control helper to
focus and then `fit_into_view` in one compositor operation. This also serves
normal Recents/taskbar activation of tape windows. Floating dialogs and normal
workspaces keep their previous behavior.
