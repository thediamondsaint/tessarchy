# Desktop unused top space — issue #65

## Report

The owner reports a large gap above open windows in Desktop mode. The issue's
ASUS capture shows unused wallpaper above Discord, with reservations
`[0,48,0,64]` at scale 1.5. This establishes the current window and reservation,
not the cause or behavior of all applications.

## Scope before implementation

Reproduce and diagnose the Desktop top gap, then correct the source responsible
for unused reserved space or inappropriate window placement. Preserve intentional
visible UI, useful top-bar controls, Desktop taskbar behavior, and Phone/Tablet
layouts. Do not assume the 48 px top reservation itself is erroneous without
checking which surface is actually rendered there.

## Verification and coordination

Inspect actual layers, reserved regions and client bounds, compare upstream main
and the public integration branch, then add a focused regression test and run
the full checks. Validate screenshots on the VM in all three layouts before a
hardware update. Coordinate shell.qml changes with #63/#64. #66 (visible Recents
button) is next in the owner's FIFO queue; do not implement it in this fix.

## Diagnosis and implementation

On the QEMU guest at 1280×800, Desktop showed a 48-pixel wallpaper strip above
Foot (both tiled clients started at y=48). `hyprctl layers -j` reported the
`tessera-status` layer at (0,0) size 1280×48 and the taskbar `tessera` at
(0,736) size 1280×64. The monitor reserved region was `[0,48,0,64]`. The
installed older shell *did* paint workspace buttons, a clock and weather in
that top strip; removing the reservation on that version would hide useful UI.
The upstream main shell instead moves Desktop indicators, weather, quick-launch
and the clock into the bottom taskbar. Its Desktop top status surface has no
visible contents when collapsed, yet still maps and reserves 48 pixels. The
integrated e4722ae (#62/#63/#64) retains the same top status surface and
reservation; its changes to the bottom dock do not address this cause.

The fix leaves the Desktop top sheet unmapped while collapsed and assigns it
no exclusive zone in Desktop, including when expanded. Opening the sheet via
`controls.toggle` or the Settings page still maps it as an overlay. Phone and
Tablet continue mapping and reserving 48 pixels for their visible status UI.
The bottom Desktop taskbar remains reserved and retains its tray controls.

## QEMU verification

Executed in the running guest with a backed-up installed shell and shell.ini.
Source files were staged via scp then replaced atomically per file; no session
config was removed. Screenshots (1280×800):

- [Older installed shell with visible top controls](images/issue65/issue65-before-desktop.png)
- [Upstream main before: unused strip](images/issue65/issue65-main-before-desktop.png)
- [After: Foot reaches y=0](images/issue65/issue65-main-after-desktop.png)
- [After: Desktop quick sheet open](images/issue65/issue65-main-after-drawer.png)
- [After: Tablet status and dock](images/issue65/issue65-after-tablet.png)
- [After: Phone status and dock](images/issue65/issue65-after-phone.png)

Before: Desktop `reserved=[0,48,0,64]`, Foot tiled bounds `(0,48)
640×688` and `(640,48) 640×688`. After: `reserved=[0,0,0,64]`,
Foot bounds `(0,0) 640×736` and `(640,0) 640×736`; status surface absent
until the sheet opens, at which point its 1280×724 overlay maps without
reserving the app area. Tablet `reserved=[0,48,0,84]`, Phone
`reserved=[0,48,0,76]`; both show top status controls and bottom docks.
All mode captures had empty `hyprctl -j configerrors`, and the shell stayed
running. `./scripts/check.sh`: 215 Python tests (one skipped), 4 site tests,
76 QML tests, two Hyprland configs parsed; existing lint warnings remain.

## Integrated VM acceptance, 2026-10-21

Executed against integration `sync/upstream-20261021` at `0e4a7e1` (Wi-Fi #68,
runtime #62, UI #63, auto-hide #64, gap #67). On Virtual-1, 1920×1200
physical at **actual scale 1.5** (1280×800 logical), Desktop reserved
`[0,0,0,64]`: tiled Foot windows began at logical y=0 and reached y=736,
with no collapsed top status layer. The 1280×64 bottom taskbar stayed visible.
Touching its Settings glyph at logical (1205,762) opened the Settings panel;
touching Start at (35,762) opened the app menu. `controls.toggle` opened the
1280×724 quick sheet over the apps without changing reservations. The Wi-Fi
card showed `Unavailable`, rather than a QML failure. Screenshot evidence:
[Desktop](images/issue65/integrated-desktop-15.png),
[touch-opened Settings](images/issue65/integrated-settings-touch-15.png),
[quick sheet overlay](images/issue65/integrated-drawer-overlay-15.png).

**Initial acceptance gap (resolved in targeted retest below):** Touching the
Desktop taskbar Wi-Fi glyph at logical (1117,763) did **not** open quick
controls at `0e4a7e1`: the tray's `StatusIndicators` omitted
`onPanelRequested`. This initial run was not a full acceptance of issue #65.
The VM's NetworkManager service is inactive and `nmcli` unavailable:
Quickshell logs `ERROR quickshell.network: Network will not work. Could not find
an available backend.` The native import/configuration loaded with no QML
`ReferenceError`, `TypeError`, or load failure, and the no-device fallback
rendered, but this VM cannot validate actual network backend/Wi-Fi operation.

With tiled Foot apps on the active workspace, Tablet and Phone retained the
1280×48 top status layer and `[0,48,0,0]` reservation while auto-hidden.
Bottom-edge touch swipes revealed their docks, measured as 238×84 at (521,716)
for Tablet and 196×76 at (542,724) for Phone; both re-hid after the reveal
interval. [Tablet capture](images/issue65/integrated-tablet-reveal-15.png) ·
[Phone capture](images/issue65/integrated-phone-reveal-15.png). `hyprctl -j
configerrors` was empty in all modes. The integrated `./scripts/check.sh` log
reports 223 Python tests (one skipped), 88 QML tests, and two configs parsed.

Before testing, backed up the complete 179-file installed Tessarchy tree and
`shell.ini` (SHA256 `9cbae91e98fe60c9e8aee0ceee6247b5aeeafd53556c38a3cf1daa556db776b0`), plus monitor JSON;
source was scp-staged and per-file atomically replaced, never removing the live
session config. After testing, restored the exact 179-file manifest and
preferences byte-for-byte, restarted the original shell, and restored
Virtual-1 1280×800 scale 1 transform 0; original Phone reservation
`[0,48,0,76]` and empty config errors returned. No ASUS changes.

Desktop's collapsed top-edge swipe/click target was removed; the taskbar
Settings/IPC alternative exists. The direct taskbar quick-sheet signal is
verified below. Working Wi-Fi hardware/backend and other monitors remain
unverified by this VM run.

## Targeted integrated Wi-Fi taskbar retest, 2026-10-21

Retested integrated `150a75d`'s shell/session source (unchanged in subsequent
integration commit `4999dc0`) in the QEMU guest. Virtual-1 was **1920×1200
physical, scale 1.5** (1280×800 logical). The 179-file installed tree,
`shell.ini`, and monitor state were backed up before atomic per-file staging;
the active shell was restarted. The VM virtual touchscreen was configured for
the **1280×800 logical** coordinate range: with a 1920×1200 input range it did
not activate even the Settings glyph, so that range cannot establish a failed
Wi-Fi hit test. The correct logical-range device opened Settings and closed it;
then tapping the actual bottom taskbar Wi-Fi glyph at (1117,763) opened the
quick sheet, without calling IPC. Its `tessera-status` overlay measured
1280×724, while Desktop reservation remained `[0,0,0,64]`; two tiled Foot
windows stayed at logical y=0, 616×736. The [touch-opened screenshot](images/issue65/integrated-wifi-touch-open-15.png)
shows the sheet and `Wi-Fi: Unavailable` fallback. Tapping the same glyph
closed it: `tessera-status` disappeared, no blank top surface returned,
reservation stayed `[0,0,0,64]`, and the tiled clients still began at y=0.
[Closed screenshot](images/issue65/integrated-wifi-touch-closed-15.png).
Tablet and Phone each received a single restart/smoke check at scale 1.5:
1280×48 top `tessera-status`, `[0,48,0,0]` reservation, and empty config
errors in both modes (no repeated full gesture matrix). The guest log retained
the expected unavailable network-backend warning; this confirms the fallback,
**not** actual Wi-Fi connectivity or radio signal. The real ASUS Wi-Fi signal
measurement (0.58) is separate hardware evidence, not a VM result.
The original 179-file manifest and `shell.ini` were restored byte-identically
(preferences SHA256 `9cbae91e98fe60c9e8aee0ceee6247b5aeeafd53556c38a3cf1daa556db776b0`),
the original shell restarted, and Virtual-1 returned to 1280×800, scale 1,
transform 0, with original `[0,48,0,76]` reservation and empty config errors.
No ASUS or parent integration worktree was changed for this retest.
