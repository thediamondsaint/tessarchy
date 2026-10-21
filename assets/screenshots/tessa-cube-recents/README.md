# Tessa cube recent-app shelf

Actual, unedited QEMU guest captures of runtime `cf0a0e8`, not concept renders.

- [Tablet recent apps, 1024×768](tablet-recents-three.png)
- [Phone recent apps, 400×800](phone-recents.png)
- [Phone after horizontal touch browsing](phone-recents-swiped.png)
- [Phone radial actions](phone-radial.png)
- [Collapsed cube and navigation wheel](phone-cube.png)

Tapping the cube shows recently used windows through Tessa's existing AppSwitcher.
Available native previews are shown; unavailable captures use app icons/titles.
Tapping a card switches to the real application and collapses the shelf. Its
controls use the wheel's cyan theme token. The keyboard and wheel are hidden
while choosing. Physical-device touch latency remains untested.

[Capture provenance and hashes](manifest.json).
[Implementation/reuse audit](../../../docs/tessa-integration.md).
