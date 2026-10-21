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
previous/next windows, a radial Menu and exit. Swipe the recent shelf horizontally
and tap a preview to switch. Available native previews fall back to app icons and
titles when unavailable. The shelf dismisses the keyboard and hides the edge wheel
to keep its touch controls clear, then collapses on selection, the header chevron
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
