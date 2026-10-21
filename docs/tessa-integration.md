# Tessa integration

Tessa is the desktop environment running on Tessarchy. Internal `tessera-*`
commands, package names, namespaces and theme sections remain compatible.

This branch starts from #85 on #61, then integrates #58's native installed-app
inventory. #84 is a design audit. #63's tablet split policy and #64's general
dock hiding are independent work and are not merged here. Only the experimental
scrolling workspace hides its dock and app-edge gesture interception.

Super+Space opens the launcher; type to search, arrows select, Enter launches and
Escape dismisses it.

Enter Settings → Try Window Tape or Super+T. Tap the floating cube for Apps,
previous/next windows, a radial Menu and exit. Drag the lower edge wheel to move
real windows; release snaps through the existing #61 bridge. Without the optional
bridge, the existing 120px stepped fallback remains available. The × action and
Super+T return to the preceding normal workspace. Apps stay on the tape for reentry.
Settings → Window Wheel selects Bottom slider, Left edge wheel or Right edge
wheel. The curved dark-glass rail, illuminated ticks and bright center marker
follow the supplied wheel-style reference. The bottom rail takes horizontal
drags; the side rails map up/down drags to the same native horizontal tape.
The cube and wheel remain separate, with no reserved bottom dock.

The cube does not request keyboard focus. Apps and Settings request it on demand.
Radial actions use the existing launcher, Settings, Recents, Quick Settings and
on-screen keyboard. Reduced motion disables the control reveal animation.

## Reuse and licenses

Actual upstream files and repository license files were inspected on 2026-10-21:

| Source | Inspected file | Decision |
| --- | --- | --- |
| [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) | `dots/.config/quickshell/ii/modules/common/widgets/FloatingActionButton.qml`, GPL-3.0 | Retain existing TouchButton; use compact/expanded sizing and reveal pattern without importing its theme/widget framework |
| [doannc2212/quickshell-config](https://github.com/doannc2212/quickshell-config) | `app-launcher/AppLauncher.qml`; no root license file found | No code copied; retain DesktopEntries, add metadata search and grid keyboard navigation |
| [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | `modules/launcher/services/Apps.qml`, GPL-3.0 | Retain native entries and execution; avoid its database and search dependencies |
| [neruson27/hypr-radial-menu](https://github.com/neruson27/hypr-radial-menu) | `daemon.py`, GPL-3.0 | Use standard circular placement and center cancellation in QML; no daemon or source copied |
| Hyprland 0.56.2 | installed native scrolling headers and #61 bridge | Keep compositor-owned layout, focus and snapping; matching ABI required |
| [Qt Quick Controls ScrollBar](https://doc.qt.io/qt-6/qml-qtquick-controls-scrollbar.html) | attached/non-attached API | Use for launcher GridView. Its normalized position has no compositor connection; retain #61 relative drag signals for the edge wheel |

No upstream source was copied and no dependency was added. The existing MIT
license and existing #61 bridge attribution remain intact. Runtime acceptance
and limitations are recorded in [testing.md](testing.md).
