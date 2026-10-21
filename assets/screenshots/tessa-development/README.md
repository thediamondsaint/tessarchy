# Tessa development VM captures

These PNGs are actual, unedited `grim` screenshots from the existing running
QEMU/KVM guest on 2026-10-21. They are not generated design concepts.
[manifest.json](manifest.json) records source, environment, dimensions and hashes.

| View | Capture |
| --- | --- |
| Phone home / launcher | `phone-home.png`, `phone-launcher.png` |
| Real scrolling windows / held edge-wheel drag | `phone-two-scrolling-windows.png`, `phone-edge-wheel-in-use.png` |
| Expanded cube / radial actions | `phone-cube-expanded.png`, `phone-radial-menu.png` |
| Fuzzy search / live entry install and removal | `phone-fuzzy-search.png`, `phone-app-discovery.png`, `phone-app-removed.png` |
| Actual Squeekboard and constrained launcher | `phone-launcher-keyboard.png` |
| Recents / Quick Settings | `phone-recents.png`, `phone-quick-settings.png` |
| Exclusive fullscreen / GTK dialog | `phone-fullscreen-cube.png`, `phone-application-dialog.png` |
| 320×640 phone | `phone-narrow-launcher.png`, `phone-narrow-cube-expanded.png` |
| 1024×768 tablet | `tablet-launcher.png`, `tablet-cube-expanded.png` |
| 1280×800 desktop | `desktop-launcher.png`, `desktop-cube-expanded.png`, `desktop-normal-workspace.png` |
| Output rotation | `desktop-rotated.png` |

Dragging translates full-width native windows: the portions visible in the two
window capture are clipped by the output, not scaled into cards. The native
bridge was enabled for that capture. Recents uses the existing fallback when
software rendering cannot provide a live preview. Normal-workspace captures
retain the existing navigation; scrolling mode uses the cube instead.
