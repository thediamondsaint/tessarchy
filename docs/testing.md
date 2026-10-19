# Validation and manual acceptance

## Actually performed, 2026-10-16

Environment: Omarchy/Arch, Hyprland 0.56.2-2, Quickshell 0.3.1-1,
QEMU 11.1.1, Foot 1.28.0. archiso and Firefox were not installed in this session.
The repository was new; no earlier Tessarchy prototype files were found in the
workspace. Existing projects and host session configuration were preserved.

`./scripts/check.sh` passed:

- Bash syntax for scripts, launchers and package recipes.
- Six integration tests: install/uninstall preservation, existing-path refusal,
  modified-launcher refusal, removal-marker/extra-file safety, nested-session
  refusal, and ISO staging against a minimal fixture with boot-asset and
  account-database preservation. This is not an archiso build test.
- Lua syntax and Hyprland's actual `--verify-config` parser: `config ok`.
- Qt qmllint against installed Quickshell metadata: exit 0. It warns that
  PanelWindow is not creatable; Quickshell chooses its backend at runtime, and
  the warning does not demonstrate working rendering. Shellcheck was absent
  and was explicitly skipped.

A sparse 32GiB qcow2 was created and inspected using qemu-img; initially only
about 200KiB was allocated. The launcher printed a TCG VM plan. A headless,
paused QEMU/TCG smoke test with the disk in snapshot mode initialized and stayed
alive for three seconds; then it was terminated. This tests the emulator engine
and disk attachment only, not firmware, boot, graphics, NAT, or the OS.

A Quickshell offscreen attempt failed because no PanelWindow backend exists
without a Wayland/X11 backend. The session also restricts local IPC sockets.
It is **not** a GUI pass. The installed host desktop was not altered or used
to run the prototype. Outbound download DNS is blocked here; /dev/kvm is not
exposed and privilege escalation is unavailable. Real ISO staging stops with
an explicit missing-archiso diagnostic. No Arch guest or Tessarchy ISO boot was
performed. Both local Arch packages were subsequently built successfully with
`./scripts/package.sh`; package metadata and file lists were inspected. They
have not been installed or runtime-tested. No built ISO is claimed.

## Manual checklist (detailed acceptance pending)

Record guest package versions, output mode/scale, input device, and logs. Treat
any failure below as a blocker for claiming the first session milestone works.

- [ ] Boot a stock Arch VM and install the documented dependencies explicitly.
- [ ] Install the dev copy as a normal user; confirm existing host/guest configs survive.
- [ ] Launch from a local TTY; verify no Hyprland configuration error banner.
- [ ] At 320×480 and 360×640 logical portrait sizes: all three dock buttons fit,
      labels remain usable, drawer scrolls, all controls are at least 48px, and
      close confirmation remains reachable. Test touch scrolling on hardware.
- [ ] At 800×1280 and 1280×800 tablet sizes: panels fit without excessive stretching,
      no unexpected tiling/split claims, dialogs and app minimum sizes are usable.
- [ ] Repeat at 1×, 1.5× and 2× scale, including output resize/rotation.
- [ ] Apps opens Firefox and Foot; rapid separate taps are not silently dropped.
- [ ] New ordinary windows maximize initially; multiple open apps can be switched
      through Windows, including windows on another workspace/output.
- [ ] Maximize and Restore affect exactly the chosen window; the dock stays visible,
      remains 72px reserved, and the label follows actual compositor state.
- [ ] Restore with several windows demonstrates tiling; document any policy gaps.
- [ ] Close asks confirmation, Cancel preserves the window, confirm closes only the
      named window. Unsaved apps may show their own dialog. Test spontaneous
      target exit while confirmation is open; no crash or wrong-window close.
- [ ] With text typed into Foot/Firefox, opening/closing Apps and Windows keeps
      keyboard focus in the app. Explicitly selecting another window changes focus.
- [ ] No hover is required. Test actual touchscreen input separately from the VM
      absolute pointer; trackpad gesture behavior is not a touchscreen test.
- [ ] Exclusive fullscreen behavior is recorded: dock may be hidden. App controls
      must provide a touch exit or keyboard recovery is required. No universal
      touch-only escape from exclusive fullscreen is implemented in milestone 1.
- [ ] Session → Cancel preserves session; Session → End returns to TTY; restarting
      works. Recovery shortcuts and alternative TTY work through QEMU Send Key.
- [ ] Uninstall preserves preferences/other configs; install again successfully.
- [ ] Build local packages and explicitly install/remove them in the guest.
- [ ] Stage with actual archiso, review profile, build, record output/hash and log.
- [ ] Boot Tessarchy ISO in BIOS and OVMF modes; test user creation, autologin,
      ownership, non-root rendering, apps, networking, audio and session exit.
- [ ] Confirm root rescue behavior, disabled SSH, no accidental sudo grant, and
      lack of persistence; review services/sockets before distributing an image.

Secure locking and on-screen typing are not implemented and cannot be marked
passed. First-milestone touch accessibility is limited to shell navigation with
maximized apps; application UI and exclusive fullscreen escape remain constraints.

## Basic guest conversion workflow, 2026-10-16

The user reports that the official Basic image boots. This is user-reported
Arch boot success, not an agent-observed Tessera GUI pass. Added a launcher for
that existing image, fresh read-only source sharing, guest-only setup, and a
reversible tty1 login hook. All nine workflow tests pass, including a QEMU stub
that checks disk selection/share contents and preserves the guest image, plus
login-hook roundtrip, idempotence and modified/symlinked profile refusal.
The real launcher command was inspected using `run-basic-vm.sh plan`.
Hyprland config parsing and QML static checks still pass (same known tooling
warning); shellcheck remains unavailable. The actual guest has not been changed
by the agent. Dependency installation, Tessera graphics, tty1 login startup and
VM graphics compatibility still require running the documented guest commands.

## First graphical smoke test, 2026-10-16

The user confirms Tessera runs in the Basic Arch QEMU guest and its dock is
visible and working. This is a user-reported graphical smoke test; the agent
has not observed the guest screen. Exact guest package versions and detailed
results for switching/maximize/close/focus/scaling were not captured. The full
manual checklist remains pending; actual touch hardware and ISO boots remain
untested. Before the initial Git commit, all nine workflow tests and available
static checks passed again, with the previously documented qmllint warning and
shellcheck skip. Generated VM images, downloaded data, packages and build output
are excluded from Git.

## Phone shell and SSH guest validation, 2026-10-16

Actually performed by the agent on the existing Basic Arch qcow2 through SSH
on host loopback port 2222. The VM runs with KVM, 2GiB RAM, Hyprland 0.56.2-4
and Quickshell 0.3.2-1. Guest source and installed defaults were archived under
`~/tessarchy-backups/` before updating; the host desktop configuration was not
modified. No dependencies were installed.

- `./scripts/check.sh` passed on host and guest: nine workflow tests (including
  scratch-HOME install/uninstall), Lua parsing, Hyprland `--verify-config` and
  QML checks. Shellcheck is unavailable. qmllint retains its PanelWindow backend
  warning; an additional guest type-inference warning was resolved by using the
  screen model directly. Installed host/guest QML metadata was inspected.
- Guest `hyprctl reload` succeeds and `hyprctl configerrors` is empty.
- The agent inspected guest screenshots at 664×480 landscape and 432×768 logical
  portrait (1920×1080 output, transform 1, scale 2.5). Status and bottom navigation
  reserve 48 and 72 logical pixels respectively. The final app tiles and dialogs
  were inspected in portrait.
- Injected pointer clicks through a temporary guest-only uinput device: Home
  opens the launcher, Terminal launches Foot, and Recents shows the window.
  Foot is maximized at position (0,48), size 432×648, between both bars. Opening
  Recents keeps Foot as the active keyboard window. Close opens confirmation;
  Cancel preserves Foot. The top power control opens session confirmation.
- The gradient background, date/time, navigation icon alignment, launcher, recent
  apps, and confirmation screens were visually inspected. Evidence is local in
  ignored `build/phone-*.png`; no VM image or credentials are tracked.
- The guest lacks UPower and desktop portals. Battery status shows an unavailable
  indicator rather than an invented charge value. Live tray registration, tray
  menus, battery changes, browser launch, actual touch, and session exit have not
  been tested in this pass. The VM remains running.

ISO/publishing result: pushing the existing `build/live-iso` branch was rejected
by GitHub because the current OAuth login lacks the `workflow` scope. The workflow
dispatch consequently returned 404. `archiso` is absent locally, local Docker
access requires administrator authentication, and no build has run. No Tessarchy
ISO artifact or ISO boot success is claimed. Grant the GitHub workflow scope,
push the branch, and dispatch `.github/workflows/build-iso.yml` to continue.

Remaining manual checks: destructive close/session exit, multiple windows,
restore/resize, 320×480 and tablet layouts, hardware touch and battery, tray menus,
ISO build and BIOS/UEFI ISO boots. Back dismisses shell panels; it does not inject
a browser/application Back key. Home opens the app launcher above running apps.

## QEMU orientation correction, 2026-10-16

The user reported that the rotated phone display appeared sideways in QEMU.
The earlier screenshot validated the compositor rendering, not the viewer's
orientation. Over SSH, backed up the guest preference and set Virtual-1 to
1280×960@60, scale 2, transform 0. Reload succeeded; `hyprctl configerrors` is
empty, and monitor state confirms transform 0 and 640×480 logical dimensions.
The updated compositor screenshot is `build/phone-upright.png`. User confirmation
of the viewer presentation is still pending. Host desktop configuration is unchanged.

## Native phone view, artwork, and status controls, 2026-10-16

Actually performed:

- Backed up guest source, installed shell, and Tessarchy preferences under
  `~/tessarchy-backups/` before deployment. No dependencies were installed.
- Selected a native 400×800@60 mode at scale 1, transform 0, over guest SSH.
  `hyprctl reload` succeeded and `configerrors` is empty; actual monitor state
  confirms 400×800 with 48px status and 72px navigation reservations.
- Made only the host's `QEMU (Tessarchy)` client float, then resized it to
  350×700. No host compositor configuration was edited. Inspected the viewer
  at its intermediate 390×700 size and final 350×700 size with the menu hidden:
  the full upright phone content fits without clipping or letterboxing.
- Generated and deployed an original wallpaper and editable SVG Tessarchy logo.
  Inspected guest screenshots showing both, translucent status/navigation bars,
  wireless/cellular unavailable indicators, volume and battery symbols.
- Clicked Home/Back with guest uinput and inspected the final launcher and
  wallpaper. Clicked the speaker and inspected Quick Controls: Wi-Fi
  unavailable, no modem, no audio output; sound buttons are disabled. The guest
  has no PipeWire service. Optional audio code loads only when its socket exists.
- Host checks pass: nine workflow tests including scratch-HOME installation and
  complete removal of the new artwork/components, Hyprland config verification,
  Lua and QML checks. qmllint retains the known PanelWindow warning; shellcheck
  remains unavailable. The final guest run of the same checks also passes.

During restart, Quickshell 0.3.2 aborted (guest PID 1131). `coredumpctl info`
shows SIGABRT in Qt's `QWindow::unsetCursor`/QQuickItem destruction path. Guest
memory remained available and no OOM kill was shown. This supports a Qt/window
teardown problem during restart; the exact upstream cause is unresolved.
Quickshell's crash handler restarted the shell and opened a crash dialog. The
old handler/dialog were stopped and the final configuration started cleanly.
PipeWire separately reported missing context configuration before the optional
backend guard was added; the core does not establish it as the crash cause.
No core dump or crash memory was copied into the repository.

Evidence: ignored `build/phone-branded.png`, `build/phone-controls.png`, and
`build/vm-phone-window-final.png`. Live Wi-Fi/cellular backends, real audio adjustment,
battery changes, hardware touch, and ISO builds/boots remain untested.

## Adaptive layouts, Settings, and logo animation, 2026-10-16

Actually performed:

- Archived guest source, installed defaults and preferences under
  `~/tessarchy-backups/` before updating. Host compositor configuration was not
  changed, and no dependencies were installed.
- `./scripts/check.sh` passes on host and guest: ten workflow tests and fifteen
  Qt Quick Test results (including fixture setup/cleanup). Tests cover auto-mode
  thresholds, portrait/landscape geometry, narrow manual override, Lua app policy
  with scaling/rotation and saved overrides, preservation of floating/fullscreen
  windows, finite logo playback, reduced-motion cancellation, and scratch-HOME
  install/uninstall preserving shell preferences and removing new assets.
  Hyprland verification returns `config ok`; QML checks retain only the known
  PanelWindow backend warning. Shellcheck remains unavailable.
- Resized the running guest to 400×800 Phone, 800×1280 Tablet, 1280×800 Desktop,
  and 320×480 Phone. Inspected Settings, header mode labels, adaptive navigation,
  launcher columns, scrollable controls, and a Desktop override at phone size.
  The final launcher uses row-based height rather than a mostly empty drawer.
- Used guest uinput to select Desktop/Automatic and Iris appearance. The actual
  `shell.ini` changed and the mode/accent loaded again after restarting Tessera.
  Inspected the longer Settings page after scrolling, including appearance,
  branded sliders, clock, labels, and motion controls.
- Guest `hyprctl reload` succeeds and `configerrors` is empty with the new Lua
  window-open policy. A temporary Foot test at 400×800 opens maximized at
  (0,48), size 400×680, fullscreen flag 1. Two temporary Foot windows opened
  at 1280×800 start tiled at (0,48) and (640,48), each 640×672, fullscreen
  flag 0. The test apps run `sleep` and exit naturally, with no user work in them.
- Rendered the actual BrandMark QML component offscreen into animation frames;
  inspected intermediate and final frames and produced the local preview
  `build/tessarchy-logo-animation.gif`. This is the component's animation, not
  a generated mockup. It assembles six original faces with rotation, runs once
  for 1.6 seconds, and settles. Qt tests verify no idle loop and reduced motion.

## Bundled fish live shell, 2026-10-17

Actually performed:

- Added `fish` to `iso/packages.x86_64`, changed the sysusers shell for `tess`
  to `/usr/bin/fish`, and gave the skel tree a fish profile: greeting off, two
  abbreviations, and the same gated tty1 one-shot Tessera start as
  `.bash_profile` (interactive only, tty1 only, no DISPLAY/WAYLAND_DISPLAY).
- `scripts/stage-iso.sh` now copies the whole skel tree to `/home/tess` and
  records `file_permissions` for the fish config; tmpfiles keeps the `.config`
  directories owned by `tess`.
- `fish -n` accepts the profile on the development host; `scripts/check.sh`
  now runs that syntax check whenever fish is installed.
- The ISO staging workflow test asserts fish in the package list, the fish
  login shell, the staged profile path, and the profiledef permission entry;
  all ten workflow tests pass on the development host.
- Not performed: building and booting the live image, verifying autologin
  lands in fish, or ending a session and returning to the fish prompt. Those
  remain part of the pending ISO boot checklist.

Screenshots are ignored under `build/`, including adaptive/tablet/desktop and
Settings captures. Hardware touch, real Wi-Fi/modem/audio/battery integration,
multiple physical outputs, exhaustive fractional scaling, and ISO builds/boots
remain pending. Auto detection classifies logical display size; it does not
identify physical device type or available input hardware. No secure lock claim.

## On-screen keyboard, 2026-10-17

Performed by an agent (Hermes) in a fresh official Basic
Arch qcow2 (sha256 checked against the mirror's `.SHA256`) under QEMU/KVM, 4GiB,
virtio-vga at 720×1440 scale 1 (Auto · Tablet), VNC/SSH on host loopback only.
Guest packages: Hyprland 0.56.2-4, Quickshell 0.3.2-1, squeekboard 1.43.1-6,
linux 7.2.10. Dependencies were installed explicitly in the guest only; tty1
autologin was enabled in the guest for testing. The host desktop was not used.

- `./scripts/check.sh` passes on host and guest: thirteen workflow tests (new:
  optional keyboard wrapper with stub squeekboard/busctl and a restricted PATH,
  private keyfile seeding without overwriting user edits, toggle in both
  directions, session start order), fifteen Qt Quick results, `config ok`.
  qmllint keeps the known PanelWindow warning; shellcheck is unavailable.
- Input was driven with `scripts/guest-touch.py`, a uinput multitouch device
  with `INPUT_PROP_DIRECT` inside the guest. These are real touch events through
  libinput and Hyprland, but synthetic: not a hardware touchscreen test.
- Session start launched squeekboard via `tessarchy-osk start`; its environment
  showed `GSETTINGS_BACKEND=keyfile` and the private config directory, while the
  guest's global `screen-keyboard-enabled` remained `false`.
- Home → Terminal tile opened Foot maximized; the keyboard appeared by itself
  with squeekboard's terminal layout (Esc/Tab/Ctrl/Alt/arrows). Foot resized
  from 720×1312 to 720×1087 above the keyboard. `echo hi` and `ls` typed by
  touch ran correctly. Firefox's address bar showed the text layout; Firefox
  without a focused field left it hidden.
- The Keyboard navigation button hid the keyboard (`osk` layer removed, Foot
  back to 1312) and showed it again; Foot kept keyboard focus and received the
  following keystrokes.
- Defect found and fixed during the pass: with the keyboard visible, Recents
  opened behind it. Opening any shell page now hides the keyboard; observed
  `osk` layer count 1 → 0 and a fully visible Recents drawer.

Not tested: hardware touch, GTK/Qt app text fields beyond Firefox, Phone mode
at 400×800, rotation and fractional scale, Desktop mode (intentionally not
changed), squeekboard theming, the ISO with squeekboard, and package installs.
Hyprland also shows a "started without start-hyprland" warning banner for a
short time after `start-tessarchy` launches it; this predates the keyboard
work and is unchanged.
## Portable checks and a source-checks workflow, 2026-10-17

Actually performed:

- `scripts/check.sh` no longer assumes Arch paths: it accepts `python` or
  `python3`, `luac` or `luac5.4`, and discovers Qt tools and the QML import
  root under both `/usr/lib/qt6` and multiarch libdirs. `qmllint` now runs
  whenever it is installed instead of additionally requiring Quickshell.
- On this Ubuntu ARM host the full pass now executes: ten workflow tests, the
  seventeen-result Qt Quick Test run, `luac -p`, `qmllint` (warnings only) and
  `shellcheck`; only the Hyprland parser check skips.
- Added `.github/workflows/checks.yml` running the same script on
  ubuntu-24.04 with python3, lua5.4, fish, shellcheck and the Qt QML modules.
- Not performed: observing the new workflow run on GitHub, and the pre-existing
  `qs`-gated behavior change on a host with Quickshell installed.
## Live rootfs hardening, 2026-10-17

Actually performed:

- Staged profile now pins hostname `tessarchy`, en_US.UTF-8 generation, a plain
  `us` virtual console, a live-console motd, a volatile journald drop-in
  (64M runtime cap), a `systemd-timesyncd` enablement link, and a `docs/`
  snapshot under `/usr/share/tessarchy/docs`; `noto-fonts-emoji` joined the
  package list.
- The ISO staging workflow test asserts each of those artifacts in the staged
  profile, and `./scripts/check.sh` passes on the development host.
- Not performed: building the image and reviewing the live console; autologin,
  motd rendering and the volatile journal still need a real ISO boot.
## First published tester ISO, 2026-10-17 UTC

Actually performed:

- Fixed CI-only ShellCheck findings and archiso's package manifest collection
  path. The hosted CI ShellCheck step now passes; unavailable GUI/Lua tools in
  the Ubuntu pre-build check are explicitly skipped, not counted as passing.
- Actions run 38997819650 built the ISO in a disposable Arch container using
  archiso 91-1 from source commit `90c5eee58f8be68ae9b9a670c3479f0ff453449b`.
  Included versions: Hyprland 0.56.2-4, Quickshell 0.3.2-1, Linux
  7.2.10.arch1-1 and Mesa 1:26.2.4-1. No host dependencies were installed.
- The ISO is 1,070,628,864 bytes. SHA-256:
  `7bdacc213975c3c1b863100eff4686973d1a315389f6360ee4c7d3af68842608`.
  Verification passed in CI and matches GitHub's uploaded asset digest.
- Two diskless QEMU/KVM VMs (2 GiB, 2 vCPUs, virtio-vga, no NIC) booted the
  exact image through BIOS and non-Secure-Boot UEFI. The agent visually
  inspected both final screenshots at 90 seconds: each shows the Tessera GUI,
  wallpaper, clock, logo, status bar, mode badge and navigation after autologin.
  The first 120-second TCG attempts only reached Linux userspace, so they were
  not treated as graphical boot passes. Full capture evidence is attached.
- Published [v0.1.0-alpha.1](https://github.com/thediamondsaint/tessarchy/releases/tag/v0.1.0-alpha.1)
  as a prerelease with ISO, SHA256SUMS, package/build provenance and boot notes.
  The ISO is a release asset, never a Git-tracked binary.

Still pending for this exact ISO: app launch/actions, networking, audio, actual
touch hardware, multiple monitors, session exit, physical-device compatibility
and persistence acceptance. The installed development VM's broader tests above
do not establish these as passing in the ISO. No secure locking or Secure Boot
support claim. Testers should begin in a disposable VM with a physical keyboard.

## Mobile window policy, 2026-10-17

Performed by an agent (Hermes) in the development QEMU
guest described above (720×1440, Auto · Tablet, Hyprland 0.56.2-4), with the
installed `session/hyprland.lua` swapped between the `feat/phone-shell` version
and this one and reloaded with `hyprctl reload`.

- Two Foot windows, focus moved to the lower one: old config left both tiled at
  720×543/544; new config maximized the focused one to 720×1087. Closing the
  maximized window: the remaining one is maximized.
- Restoring the active window (maximize unset) left it tiled; it was maximized
  again only after focus moved to the other window and back.
- Firefox Save As with GTK's remembered size forced to 1232×949: old config
  placed it at x=-256, Cancel and Save off-screen; new config resized it to
  726×996 (GTK's minimum width exceeds 720) at x=-3, both buttons visible.
- `./scripts/check.sh`: new Lua-stub workflow test for activation, nil/desktop
  windows, dialog fitting with keyboard reservation, rotation and Desktop mode.
  It fails against the old config and passes now.

Not tested: dialogs that grow after mapping, Phone 400×800, real rotation or
fractional scale, hardware touch, Desktop mode (intentionally unchanged).

## Phone size (400x800), 2026-10-17

Performed by an agent (Hermes) in the same guest, with
the output at scale 1.8 (720x1440 physical, 400x800 logical) via `hyprctl eval`:

- Status bar, nav bar (Back/Home/Recents/Keyboard) and a maximized Foot fit
  without clipping; Firefox maximized to 400x567 above the keyboard.
- Firefox Save As does not fit: GTK3's file chooser will not go below 726
  logical px, so it sits at x=-163 and its header bar (Cancel/Save) is off
  screen. Setting `org.gtk.Settings.FileChooser` window-size to (360, 500) and
  sidebar-width to 0 still reopened it at 726. Unresolved.
- squeekboard picked its short tablet ("Wide") layout, 113 logical px tall. It
  sizes from the output's reported physical size, and QEMU reports 180x360 mm;
  a short side of 115 mm or more counts as a tablet. A real phone (about 65 mm
  wide) should get the taller phone layout; not verified on hardware.
- Reloading `hyprland.lua` resets the scale to 1; set it again after a reload.
## Quiet Edge and card switcher — 2026-10-17

Implemented in the development source and installed Arch VM; **not included in
published Alpha 1**. No replacement tester ISO was published during this UI/website change.
PR CI subsequently built an ISO successfully in run `39056992759`; that new
artifact has not been boot-tested and is not presented as the published tester release.

Actual validation:

- Reopened the existing QEMU/KVM guest with 2 GiB RAM and 2 vCPUs; retained native
  400×800 portrait output. Made its host window float using runtime dispatches;
  no host Hyprland/Omarchy configuration files were changed.
- Verified installed Quickshell QML type metadata for screencopy, desktop entries,
  IPC and layer keyboard focus, and Hyprland Lua metadata for layer rules/binds.
  Guest reload/configerrors was clean with the Tessera-only frosted layer rule.
- Visually inspected status bar, floating navigation, launcher, settings and
  card switcher. Switcher headings/instructions are absent; return/close actions
  are glass icon controls with accessible names and >=48px targets. App names
  and window titles remain visible. Close still opens an explicit confirmation;
  Cancel returned to the switcher without closing a window.
- Injected a real relative pointer drag through the guest's uinput interface and
  observed selection move between two real Foot cards. Window previews rendered
  through shared-memory screencopy; unavailable previews have an explicit fallback.
- Tested Alt+Tab using guest key input. Verified a change from the Project notes
  window (PID 503) to the development terminal (PID 502), with the selected app
  maximized at 400×676 below/above the reserved bars after releasing Alt. Fixed
  selection drift during dock expansion and deferred activation until the layer
  keyboard grab is released. Left/right and Enter were exercised in the switcher.
- Captured real development-VM screenshots at Phone 400×800, Tablet 800×1280,
  Desktop 1280×800, then restored the guest to 400×800. Source originals and
  capture limitations are in `assets/screenshots/README.md`.
- `./scripts/check.sh` passed on the host and guest: workflow safety tests,
  19 Qt Quick test results including lifecycle setup/cleanup, Lua syntax,
  `Hyprland --verify-config`, and qmllint. Known PanelWindow type-metadata
  warnings remain; ShellCheck was unavailable locally and in the guest.
- Website preview returned HTTP 200. Chromium/ChromeDriver rendered the site at
  1440×1000 and 390×844, with no horizontal overflow or broken sourced images.
  Layout tabs and screenshot dialog open/close worked; JavaScript syntax passed.
  The website builder also checks refusal to overwrite an existing destination
  and exact original screenshot bytes in the downloadable ZIP.

Still planned/manual: physical touch, multi-touch swipe tuning, additional app
classes and keymaps, multi-monitor keyboard routing, GPU-backed preview behavior,
performance on real mobile hardware, and a newly built/booted Quiet Edge ISO.
The VM lacks UPower and desktop portal services and falls back from DMA-BUF to
SHM preview buffers; these are not claims of working battery/network/audio devices.

## Pull-down quick controls and mobile clock — 2026-10-17

Actual validation in the installed development guest:

- Restyled the status clock with compact semibold digits, no leading zero or
  visible AM/PM suffix. Verified the saved 12-hour preference remains intact and
  the expanded clock/accessibility text still identifies AM/PM.
- Injected relative pointer drags from the status strip. A downward drag opened
  the glass sheet to 400×549; an upward drag collapsed it to 400×48, verified
  against compositor layer geometry. Tapping the clock also opened the sheet.
  The exclusive zone stays at 48px and keyboard focus is not requested.
- Confirmed the installed helper reports no Wi-Fi/Bluetooth/WWAN radios in this
  QEMU guest. Airplane mode and each radio tile correctly show Unavailable and
  remain disabled. No hardware state was simulated in the screenshot.
- Six radio tests cover absent devices, soft/hard blocks, independent radios,
  bulk airplane actions, permission failures, input validation and re-reading
  partially changed hardware after a failed bulk command. Commands are mocked;
  no host radio was changed. See docs/radio-controls.md for exact semantics.
- Host and guest `./scripts/check.sh` passed: 17 Python tests and 19 Qt Quick
  results, Lua/config validation and qmllint. Only the known PanelWindow metadata
  warnings remain. ShellCheck was unavailable locally/in the guest.
- Updated website preview rendered at 1440×1000 and 390×844, with working layout
  tabs and screenshot dialog, no horizontal overflow or broken sourced images.
  Added the real quick-controls image to the site's downloadable screenshot pack.

Still unverified: physical touch input, real transmitter changes, radio permission
policy on target hardware, modem-specific behavior and devices without rfkill.
These controls do not select networks, pair Bluetooth devices or provision mobile
service. Airplane off unblocks detected radios; previous per-radio selections are
not restored. No dependencies, services or host desktop configuration were installed
or changed. This UI update is not included in the published Alpha 1 tester ISO.

## Pull-down layout selector — 2026-10-17

Actual validation:

- `./scripts/check.sh` passed with 17 Python tests and 19 Qt Quick results;
  known PanelWindow metadata warnings remain and ShellCheck is unavailable.
- Installed the updated QML in the existing 400×800 development guest. Verified
  that the home-screen mode button is absent and the glass pull-down shows
  Auto, Phone, Tablet, and Desktop controls with targets at least 48px.
- Clicked Desktop in the pull-down, observed the active label and desktop dock
  update, and verified `layoutMode=desktop` persisted in the guest preferences.
  Clicked Auto, verified `layoutMode=auto` and the Phone layout returned.
- Collapsed the sheet using its handle and captured updated home and controls
  screenshots directly from the guest. No host desktop configuration changed.

Still planned/manual: physical touch and the selector on larger displays.
The published Alpha 1 ISO does not contain this change.

## Alpha 2 release rebuild — 2026-10-17

Actual validation:

- Reviewed open GitHub issues, pull-request status and Actions history. Recorded
  the inventory in `docs/github-review.md`; pending collaborator PRs are unchanged.
- Host `./scripts/check.sh` passed: 17 Python tests, 19 Qt Quick results, Lua
  syntax, Hyprland configuration verification and qmllint. Known PanelWindow
  metadata warnings remain; ShellCheck is unavailable locally.
- Actions run 39063437439 built the ISO from
  `aa8b59a73a8d5d6b1d3fab6c17272e68e0bfac58`, verified its checksum,
  and captured diskless BIOS and non-Secure-Boot UEFI QEMU/KVM boots.
- Inspected both final 1280×800 screenshots: Tessera's graphical home screen,
  current wallpaper/logo, glass status bar and floating dock are visible.
  Each guest used 2 GiB RAM, 2 vCPUs and virtio graphics, with no disk or NIC.
- Downloaded the published Alpha 2 ISO and verified its complete local SHA-256
  against `SHA256SUMS` and the GitHub release asset digest.
- Corrected the GitHub Pages environment policy to permit `v*` release tags
  alongside the existing `main` and `build/live-iso` branches. The release-event
  deployment passed on retry; no collaborator access or branch history changed.
- Built the website with public Alpha 2 metadata and verified its download
  selection and all seven screenshot originals in the bundled ZIP.
- Package manifest identifies Hyprland 0.56.2-4, Quickshell 0.3.2-1, Python
  3.14.8-1 and util-linux 2.42.4-1. Alpha 2 checksum matches the release digest.

Earlier development-VM interaction tests remain separate from these ISO boot
checks. Physical touch, network/radio/audio behavior, Secure Boot, phone
hardware and application acceptance are still unverified in this exact image.


## Script hardening and validation record, 2026-10-17

Environment: Omarchy/Arch host, Hyprland 0.56.2, Quickshell 0.3.1, Qt 6.11.2
(`/usr/lib/qt6/bin/qmllint`), desktop-file-utils 0.28, python 3.14, qemu absent.
All work ran as the normal user; no host session config, `dist/`, `build/` or
`vm/` content was disturbed beyond this project's own ignored directories.

- The host had a stray `qmllint` (reports version "1.0") on PATH which fails
  silently with exit 255 on the shell QML. `scripts/check.sh` now prefers
  `/usr/lib/qt6/bin/qmllint` matched to the installed Qt before a PATH entry;
  after the fix `./scripts/check.sh` exits 0, still reporting the known
  PanelWindow warning.
- `desktop-file-validate` on `session/tessarchy.desktop` flags the spec-valid
  `DesktopNames` Wayland-session key as an extension-key error ("0.28"). The
  check tolerates only that specific quirk and fails on any other finding.
- Integration tests grew from nine to seventeen with stub-based checks:
  `vm.sh plan` command printing, missing-disk, usage and `VM_SSH_PORT`
  refusals; `fetch-arch-iso.sh` seeded-manifest stubs proving an existing
  download is never overwritten and a failed download leaves no partial ISO or
  download directory; `build-iso.sh` explicit archiso refusal;
  `export-vm-source.sh` snapshot idempotence; `run-basic-vm.sh` missing-disk
  refusal. All 17 tests pass (grep count 17 `. ok`).
- Development install/uninstall now writes a `.tessarchy-dev-files` manifest;
  tests confirm installed files are removed, untracked extras are preserved,
  v1 markers still uninstall through the legacy fixed set, and the manifest
  itself is removed. `cmp` launcher-modification refusal was unchanged and
  still passes.
- `./scripts/package.sh` was run unprivately with the current source: both
  packages built (`--nodeps`, fakeroot). File lists and `.PKGINFO` were
  inspected by bsdtar; nothing was installed.
- The QML app launcher now derives entries from Quickshell `DesktopEntries`
  (validated against installed `quickshell-core.qmltypes`: `applications`,
  `noDisplay`, `command`, `execute`). Only qmllint validated it; no GUI run.

Not performed: archiso staging/build, ISO boot, VM launch, shellcheck (still
absent locally; covered if CI is enabled), touchscreen tests, guest installs.

## PR 2 integration review — 2026-10-17

Actual validation: resolved the app-drawer changes onto the Alpha 2 shell;
checked installed DesktopEntry/iconPath QML metadata; `./scripts/check.sh`
passed 26 Python tests and 19 Qt Quick results, Lua/Hyprland validation and
qmllint (known PanelWindow metadata warnings only; ShellCheck unavailable).
Scratch-HOME tests cover manifest install/uninstall, preserving unknown files,
legacy installs, traversal and symlink-parent rejection before any removal.
The development VM rendered the installed applications with their real icons
and truncated long names within the glass launcher.

Still planned/manual: additional desktop-entry command formats and theme changes.
No host desktop configuration or dependencies changed.


## Desktop mode workspace strip and keybindings, 2026-10-17

Implemented, static validation only; GUI and guest acceptance pending.

- `LayoutPolicy.js` gains `showWorkspaces(mode, width)` and
  `workspaceSlots(ids)`; `tests/qml/tst_layout.qml` covers placement at
  desktop/tablet/phone widths and slot extension beyond five workspaces.
- The status bar renders numbered workspace buttons from
  `Hyprland.workspaces`, highlights the focused/active workspace, and falls
  back to a numeric-only `hl.dsp.focus` dispatch for not-yet-created
  workspaces. Existing workspaces use `HyprlandWorkspace.activate()`.
- Desktop shows the focused window title beside the tray (display-only text).
- `session/hyprland.lua` adds fixed desktop bindings: Super+1-5,
  Super+Shift+1-5, Super+Q, Super+Tab, directional focus and window move,
  Super+drag/resize, and XF86Audio volume keys.
- Performed on the development host (Ubuntu ARM, no Wayland session):
  `luac -p` accepts the Lua config; `qmllint` (Qt 6.10) exits 0 for edited QML
  with only unresolved-module warnings; the Qt Quick Test suite was run
  directly against the multiarch Qt install and reports 17 passed, including
  the new `test_workspace_slots` and `test_workspace_strip_placements`.
  `scripts/check.sh` passes ten workflow tests with the documented skips
  (Hyprland and Quickshell absent).
- Not performed here: `Hyprland --verify-config`, Quickshell rendering,
  workspace strip taps, keybinding behavior, multi-output focus, or reduced
  width clipping. These require the Arch guest and remain on the manual list.

## PR 3 integration review — 2026-10-17

Actual validation: `./scripts/check.sh` passed 26 Python tests and 21 Qt Quick
results, Lua/Hyprland validation and QML lint. Inspected installed Hyprland
monitor/workspace/toplevel metadata. The guest rendered the desktop status
strip and focused title at 1280×800, and the close shortcut's IPC action opened
the confirmation page without closing Foot. The 400×800 status strip remains
uncrowded. Active-window lookup falls back to the activated Wayland handle
after shell restart. Workspace count is bounded and narrow overrides hide it.
Close and exit bindings route through the shell confirmations.

Still planned/manual: real keyboard layouts, physical touch and many workspaces.
This changes development source, not the already published Alpha 2 image.

## PR 4 integration review — 2026-10-17

Actual validation: reviewed tty1-only fish startup, live-user shell selection,
skel staging and ownership; `./scripts/check.sh` passed 26 Python tests and
21 Qt Quick results, Lua/Hyprland validation and QML lint. Staging tests confirm
fish package, sysusers shell, home profile and profile permission entries.
The host has no fish executable, so fish syntax validation skipped locally.
No dependencies were installed. The full live-image fish autologin/exit cycle
remains a planned boot check; Alpha 2 is unchanged.

## PR 5 integration review — 2026-10-17

Actual validation: reviewed declarative hostname, locale, console, motd and
volatile journal settings, time-sync enablement, emoji package and offline docs.
`./scripts/check.sh` passed 26 Python tests and 21 Qt Quick results plus the
available static checks. Scratch staging assertions verify the emitted files
and service link. Fish and ShellCheck are unavailable locally. No dependencies
were installed. Live locale generation, fish autologin and journal operation
remain planned boot checks; the published Alpha 2 image is unchanged.

## PR 6 integration review — 2026-10-17

Actual validation: retained fish syntax and desktop-entry checks while adding
Python/Lua/Qt discovery for Arch and Debian layouts. Local source checks passed
26 Python tests, 21 Qt Quick results, Lua/Hyprland verification and QML lint.
Full shell lint explicitly requires Quickshell metadata; missing imports are
not counted as successful API validation. The workflow adds an Ubuntu portable
job and an Arch target-toolchain job running as a non-root user in a disposable
container. No host or guest dependencies were installed. CI results must be
checked separately; fish and ShellCheck are unavailable on the host.

## PR 8 integration review — 2026-10-17

Actual validation: inspected installed Hyprland Lua event/monitor metadata.
`./scripts/check.sh` passed 27 Python tests and 21 Qt Quick results plus
Lua/Hyprland and QML validation. The guest reloaded the candidate configuration
without config errors. A new Foot opened maximized at 400×676; restoring it
left it tiled at 400×338, and focusing the older Foot then the new one maximized
each back to 400×676. The candidate retains confirmed close/exit bindings.
Dialog requests now skip fullscreen windows and clamp unusable dimensions.

Planned/manual: oversized real dialogs and application minimum-size behavior
under the combined source, physical touch, fractional scaling and rotation.
Earlier contributor dialog tests are recorded separately above. Alpha 2 is unchanged.

## PR 7 integration review — 2026-10-17

Actual validation: reviewed the optional squeekboard wrapper, private GSettings
backend, fixed D-Bus calls, helper packaging/staging and mobile toggle. Retained
manifest-based install/uninstall safety and added the helper to preflight and
cleanup lists. Opening either bottom pages or the new pull-down hides the OSK
without requesting app keyboard focus. `./scripts/check.sh` passed 30 Python
tests and 21 Qt Quick results plus available static/API checks. Stub tests cover
missing backend, private settings preservation, show/hide/toggle and startup.

Planned/manual: typing with the complete integrated source and the supported
keyboard version, actual 400×800 sizing, focus across applications, and the new
ISO. Earlier contributor VM results remain separate. The owner explicitly allows
keyboard keys narrower than 48px, retaining >=48px key height. No dependencies
were installed on the host or development guest; Alpha 2 is unchanged.

## Bluetooth PR #24 integration, 2026-10-17

Actual validation:
- `./scripts/check.sh` passed: 31 Python integration tests and 22 Qt Quick
  checks, scratch-HOME install/uninstall, Lua/Hyprland parsing and QML lint.
- A new scratch, offscreen Quickshell harness exercised the real BluetoothPanel
  with mock adapter/device objects: missing adapter, adapter replacement,
  hidden/powered-off discovery cleanup, preserving pre-existing discovery, and
  stale/busy/blocked/unpaired device action guards. This is not hardware testing.
- Installed Quickshell 0.3.1 Bluetooth metadata checked for adapter state,
  discovery, device actions and battery types. Its defaultAdapter metadata
  produces an unresolved-type lint warning; the real shell loads successfully.
- Existing portrait VM (400x800) loaded the candidate shell. The glass pull-down
  and expanded “Bluetooth · no adapter available” state were visually inspected.
  Capture: `assets/screenshots/phone-bluetooth.png`. Runtime logs showed the
  expected absent BlueZ/UPower services and software-buffer fallback.
- Local fish and ShellCheck were unavailable; target CI covers both.

Pending/manual:
- Physical adapter power/discovery, reconnect/disconnect, permission failures,
  device battery accuracy and hot unplug during operations. No adapter or BlueZ
  service is present in this VM; none of these hardware paths is claimed tested.
- Pairing/passkey agents, forgetting devices and adapter selection are not
  implemented. Use an external Bluetooth manager for pairing.
- No new ISO was built or boot-tested during this PR review; Alpha 2 is unchanged.

## Media PR #15 review, 2026-10-17

Actual: `./scripts/check.sh` passed (31 Python, 26 Qt Quick checks), including
scratch install/uninstall, current Lua parser and QML lint. Installed Quickshell
0.3.1 MPRIS metadata was checked for capability properties, togglePlaying,
previous/next and seek(double). The real MediaPanel was tested with a mutable
mock player: unsupported actions, capability changes, control refusal, seek
amounts and player disappearance. The panel uses plain-text metadata and glass
icon controls in the current pull-down; the older status page is not restored.

Pending: end-to-end MPRIS D-Bus behavior with real media applications, VM visual
inspection and touch input. The previous VM SSH control socket expired and no
new credentials/key were available at review time. Local fish and ShellCheck
were unavailable; target CI covers them. No ISO boot claim or release change.

## Audio PR #17 review, 2026-10-17

Actual: `./scripts/check.sh` passed (32 Python, 30 Qt Quick checks), including
scratch installs, Lua parsing and QML lint. Installed Quickshell 0.3.1 PipeWire
metadata was checked for readiness, nodes, audio and preferred-default output.
A scratch offscreen Quickshell instance loaded the real AudioPanel with no
PipeWire service and reported unavailable state without writable controls.
AudioControls was tested with mock nodes for backend loss, stale nodes,
unsupported readiness, volume clamping/NaN and mute behavior. Playback filtering
accepts only `Stream/Output/Audio`, excluding capture and video streams.

The panel is loaded only when expanded with the existing audio backend enabled;
its tracker follows candidates before filtering on audio readiness, and is
destroyed when hidden. The original basic volume controls remain available.
External metadata uses plain text. Device/app controls remain in the current
pull-down and are covered by the manifest installer.

Pending: real PipeWire/WirePlumber output switching, per-app playback volume,
backend restart/device removal, touch and VM visual inspection. VM SSH access
has expired; no host/guest dependency was installed. No new ISO boot claim.

## Screenshot PR #14 review, 2026-10-17

Actual: `./scripts/check.sh` passed (35 Python, 30 Qt Quick checks), including
scratch install/uninstall, staging, Lua/Hyprland parsing and QML lint. Tests use
stub capture/notification tools in a scratch HOME; they verify two captures in
the same second remain distinct, existing files survive, file mode is 0600,
notification failure is optional, failed captures remove partial files, missing
grim is reported, unexpected arguments are rejected and an existing unrelated
screenshot helper is refused before installation. ISO staging includes the
executable helper and declarative grim/libnotify packages. No host package was
installed. Print is bound through the current Lua API.

The pull-down has a glass camera icon. It closes the drawer and defers capture
briefly so controls can repaint before grim runs. The helper is covered by
launcher preflight and modified-launcher uninstall checks; manifest safety is
retained. Screenshot paths use a unique mktemp name, fixing the original
same-second overwrite risk.

Pending: actual grim capture, notification appearance, Print key and camera
button in the VM, including whether the drawer is absent from captured pixels.
VM SSH access has expired. These helper tests are not real image captures and
there is no new ISO boot or release claim. Local fish/ShellCheck are unavailable;
target CI covers those tools.

## Phone PIN greeter candidate, 2026-10-17

Actual validation:
- `./scripts/check.sh` passed: 42 Python and 37 Qt Quick results, scratch
  install/uninstall, Lua syntax, both session and greeter Hyprland config parsers,
  and QML lint. Local fish/ShellCheck were unavailable; CI covers those tools.
- Installed Quickshell 0.3.1 Greetd metadata and official API/protocol docs checked.
- Real Quickshell Greetd module was exercised against an isolated mock UNIX
  socket: single-secret success/fixed command, rejection, visible prompt, second
  secret, passwordless success refusal and disconnect/deadline failure. No real
  account or PAM authentication was used in these tests. The synthetic test PIN
  did not appear in captured logs; Quickshell censored its secret response.
- QML component tests cover exact four-digit entry, leading zero, duplicate
  submission prevention, deletion, busy/unavailable clearing, minimum key size,
  capability/state guards and refusal to launch before authentication succeeds.
- Three local packages built without dependency installation: tessera-shell,
  tessarchy-session, tessarchy-greeter. Final outputs/logs are under ignored
  build/phone-login-packages-final/. These are candidates, not installed packages.
- VM SSH access was restored using owner-provided credentials; credentials were
  not written to repository files. The isolated preview was visually inspected
  at 400x800 and 320x568. Keypad taps filled masked dots; deletion and synthetic
  keyboard entry/automatic clear worked. Native 400x800 portrait was restored.
- Captures: assets/screenshots/login-preview-phone.png and login-preview-small.png.
  Preview logs show software rendering and a Qt Wayland text-input focus warning,
  with no QML component-load failure. The preview explicitly cannot authenticate.

Pending/manual acceptance:
- greetd is missing in the VM. Installing it needs explicit permission under
  AGENTS.md. No dependency, password, PAM, getty or display-manager setting was
  changed. The owner selected a four-digit account password but has not chosen
  the new PIN. Current account credentials remain unchanged.
- Real PAM success/wrong PIN, greeter compositor exit and user-session handoff,
  boot/session-exit return, failure recovery, actual account policy/rate limits
  and touchscreen hardware. Follow docs/phone-login.md after approval.
- Greeter packaging is opt-in and not enabled in ISO staging. Live-account PIN
  enrollment is not implemented. Published Alpha 2 and boot evidence are unchanged.
- This is pre-session authentication, not a Wayland session locker; no secure
  locking claim. Do not call mock protocol success a real login or boot test.

## Activated phone login, startup warnings and logo kit, 2026-10-17

Actual validation after explicit owner approval:
- Installed greetd/greetd-agreety and the local Tessarchy packages in the VM.
  Local package dependencies grim/libnotify were also installed. Host packages
  and configuration were not changed. Password was set through hidden stdin;
  no credential is in Git, docs, helper files or command arguments.
- One VM reboot completed. Because QEMU used -no-reboot it exited; the old process
  was confirmed gone before relaunching the same disk. The removed temporary
  read-only share was recreated; no concurrent disk writer or image rebuild.
- Real PAM rejected an incorrect PIN, with no Tessera process started. The chosen
  PIN opened the authenticated desktop. The real session-exit confirmation was
  used and the phone greeter returned. Fixed a follow-up backend error overwriting
  the rejection message; confirmed the corrected message in the VM.
- Both greeter and desktop now run through start-hyprland. Before the change logs
  contained the unsupported direct-launch warning. After it, the greeter log had
  no such warning and the final desktop reported watchdog=true, warnings=[], and
  an empty configerrors result. No errors/notifications were suppressed.
- Separate virtio software-GPU gamma/page-flip/EGL fallback diagnostics remain
  in logs; they are not claimed eliminated. No persistent config-error overlay
  was present in the inspected greeter or authenticated desktop captures.
- Final ./scripts/check.sh passed: 43 Python and 37 Qt Quick checks, both Lua
  parsers and QML lint. Includes an argument-safe watchdog launch test using a
  config path with spaces. Log: build/pr-review/phone-login-final-check.log.
- All three v4 local packages built. VM greeter uses a private writable HOME and
  VM-only persistent native 400x800 output settings. User clock/motion preferences
  were preserved. Actual captures are phone-login.png, phone-login-rejected.png
  and phone-login-home.png under assets/screenshots/.
- Official logo ZIP exported: 59 files, 5,544,035 bytes; CRC and all manifest hashes
  passed. Canonical SVG byte identity, all PNG dimensions/alpha, ICO resolutions,
  GIF/WebP frame counts (72), loop flags, transparency/disposal and 3D contact
  sheet were inspected. No third-party console artwork or new logo redesign.

Remaining: physical touch/boot hardware, account policy/recovery acceptance on
other machines, unattended lifecycle soak and live-ISO PIN enrollment. There is
no new ISO release or secure session-lock claim. Generated branding artifacts
remain under dist/tessarchy-logo-kit-20261017/.

## Roadmap and website refresh — 2026-10-17

Actual validation:

- `./scripts/check.sh`: 44 Python tests and 37 Qt Quick results passed. Local
  fish and ShellCheck remain unavailable; no host dependencies were installed.
- Website build passed into a fresh `dist/website-refresh-20261017` directory.
  Screenshot ZIP now includes eleven actual VM captures, including real login,
  rejected-PIN and post-login home evidence. Earlier preview captures are excluded.
- Added regression coverage for skipping branding-only and draft releases when
  selecting the tester ISO. Existing-output refusal and original-byte screenshot
  packaging remain covered.
- The built-in image generation tool produced the roadmap; the final selected
  poster was visually inspected, including its 00–06 sequence, six milestone gates
  and explicit concept-phone/tablet labels. It is presentation artwork, not a new
  hardware test. The original official logo was the visual reference.

Publication and browser results are recorded in the final checkpoint below once
completed. Physical-device validation and a fresh ISO boot remain pending; this
website change does not rebuild or replace the Alpha 2 download.

Browser validation completed using the installed Chromium headless browser
(the computer-use browser surface was unavailable): all static images loaded;
1440px desktop and 390px phone layouts had no horizontal overflow; keyboard
layout tabs retained focus and selection; screenshot enlargement and Escape
close worked; no uncaught JavaScript exceptions were observed. Desktop evidence,
phone sharing and phone roadmap screenshots were visually inspected under
`build/site-refresh/`. Native mobile share sheets were not exercised.

The branding release assets were uploaded and GitHub-reported digests match the
local ZIP, GIF and roadmap hashes. ISO asset bytes and Alpha 2 release provenance
were not changed. Deployment/public URL checks are a separate publication step.

The initial showcase commit 78ea96d deployed successfully in Pages run
39082172625. A separate release-event run 39081997323 was rejected before any
steps because tag brand-kit-20261017 is not allowed by the existing Pages
branch protection policy. Removed that obsolete release-event trigger; source
pushes/manual dispatch remain enabled, and visitors still read current release
metadata from the public API. No environment protection rules were weakened.

Live publication validation passed against the public GitHub Pages URL: current
sections and social preview metadata are present, the roadmap bytes match the
selected local image hash, the screenshot ZIP passes CRC and contains eleven
original PNGs, and bundled release metadata selects an ISO release. Updated
Pages run39082298291 and Ubuntu/Arch runs39082298295 / 39082301438 passed before
PR #26 merged as e1ff6a5891f04c5751630f7991bf3fb55665197d. No new ISO was built
or boot-tested as part of the showcase update.

## Agent guide and current tablet/desktop captures — 2026-10-18 UTC

Actual validation:

- Source checks passed: 44 Python tests and 37 Qt Quick results. Local fish and
  ShellCheck were skipped; Ubuntu/Arch CI supply those tools.
- Markdown file links resolve and the agent task board contains 56 unique IDs.
- Fresh site build includes thirteen original screenshots and capture metadata.
- Current shell/session source from commit
  9c1f4a3f400a6358066b41ab9fb6720e4af33fb0 was archived and staged in the VM at
  ~/tessarchy-capture-9c1f4a3. It ran with a private copy of shell preferences.
- Auto selected Tablet at 800x1280 and Desktop at 1280x800. Home and expanded
  quick-controls views were captured with grim and visually inspected. The new
  views include current Bluetooth, audio, camera and media controls. File hashes
  and dimensions are in assets/screenshots/capture-manifest.json.
- Hyprland configerrors remained empty. The original private shell was restored
  at 400x800; its preferences compare byte-for-byte with the pre-capture copy.
- The site mode preview now offers a matching quick-controls capture. Versioned
  tablet/desktop image URLs and social preview URLs refresh cached assets.

These checks cover rendering, sizing, capture provenance and the website. Real
service/player acceptance remains assigned in the agent task board.

The updated site passed installed-Chromium checks at desktop and phone widths:
all static images loaded, no horizontal overflow, keyboard mode navigation kept
focus, the Desktop quick-controls button opened the matching new capture, and
gallery/Escape close worked. No uncaught JavaScript exceptions were observed.

PR #27 passed Ubuntu/Arch runs39083726072 and39083730802 and Pages39083726075,
then merged as 3f512bc9ed76388ee82611f1654a914896700a4a. Public checks matched
all four new capture hashes, validated the thirteen-PNG screenshot ZIP and
confirmed the agent-guide link and per-mode controls viewer.

## Public documentation privacy

The operational handoff is kept in an ignored local file. Public documentation
uses project-relative paths and generic machine/account descriptions. Published
validation evidence remains in this file.

## Quiet Edge startup validation — 2026-10-18 UTC

Actual validation:

- `./scripts/check.sh`: 47 Python tests and 37 Qt Quick tests passed, including
  scratch-HOME install/uninstall, both Hyprland Lua configuration parsers and
  QML checks. Existing QML metadata warnings remain; local fish/ShellCheck are
  unavailable and covered by CI.
- All four Arch packages built with existing host tools and `--nodeps`; no host
  dependency was installed. The bootsplash package contains the theme, 64 logo
  frames and retained-splash service override. It leaves Plymouth's own config
  under the distribution package's ownership.
- With explicit approval, installed Plymouth and wireless-regdb in the QEMU/KVM
  development VM. Installed the rebuilt session, greeter and bootsplash packages.
  Saved boot/config backups before activation and regenerated the initramfs/GRUB
  configuration inside the VM.
- Recorded cold boots through QMP. Corrected an initial VT7 handoff stall by
  retaining VT1 for both Plymouth and greetd. The final cold boot shows the
  spinning mark, then the PIN keypad. No service-status scrolling appeared in
  the Linux startup phase.
- A transient missing-guiutils banner came from the greeter's absent `PATH`.
  `hyprland-guiutils` was already installed and its package files were intact.
  Added an explicit system PATH; the final capture has no such banner. Disabled
  the default Hyprland slogan, with `Hyprland --verify-config` passing.
- Actual PIN authentication entered the user session; session output appeared
  under `tessarchy-session` in the journal. Exiting the test session returned to
  the graphical greeter. `systemctl --failed` reported zero failed units. The
  missing regulatory.db diagnostic is gone after wireless-regdb installation.
- Exported an actual 400x800, 35-second MP4 from continuous capture seconds 10–45.
  Exported a 320x640, 14.6-second GIF from seconds 10–19.6 and 39.5–44.5, shortening
  only the idle transition. Inspected decoded GIF frames and confirmed dimensions,
  frame counts and durations with ffprobe. Assets are in the presentation release.
- Built the website and checked it in installed Chromium at phone/desktop widths:
  images loaded, no horizontal overflow, keyboard tabs retained focus, gallery
  open/Escape close worked, and no uncaught JavaScript exceptions occurred.

Remaining work:

- Firmware and GRUB still emit brief text before Plymouth; the published clip
  begins at the branded OS screen. The tested firmware artwork covers the menu
  pause, rather than replacing every firmware/bootloader message.
- Physical display/touch validation, graphical encrypted-disk prompts and recovery
  acceptance remain planned. No new ISO was built or boot-tested in this task.

## Live boot without a network — 2026-10-18 UTC

Actually performed:

- Debug boots of the live line exposed a boot hang: on a QEMU guest with no NIC
  and no battery-backed clock, the releng-enabled
  `systemd-time-wait-sync.service` held sysinit open with systemd reporting
  `(no limit)`, and a `plymouth-quit-wait` companion stuck behind it, so the
  graphical session never started (two runs, one stuck for 8+ minutes).
- `scripts/stage-iso.sh` now deletes the `sysinit.target.wants` link for
  `systemd-time-wait-sync.service` from the staged profile, and the staging
  test seeds the link in its fake base and asserts the staged profile no
  longer carries it; the full check suite passes.
- Debug images used for the same validation mask the unit on the kernel
  command line (`systemd.mask=systemd-time-wait-sync.service`) and skip
  plymouth (`plymouth.enable=0`); with both, boots became deterministic.

Not performed: a live-image rebuild from this change and an on-hardware check
of a Wi-Fi-less boot (the staged-profile test covers the packaging step).

## Phone, Messages, sounds and SIM controls — 2026-10-18 UTC

Actual validation:

- Source checks passed 59 Python tests and 41 Qt Quick results. Tests cover private
  contact storage, malformed/remote inputs, photo decoding, sound persistence,
  invalid and unconfirmed actions, failed SMS, duplicate received SMS, modem/SIM
  inventory, eSIM identification and typed D-Bus arguments. The Quickshell harness
  exercises stdin request/response and a user action queued behind status polling.
- Qt pointer tests select an inline glass option and check its touch targets.
  Dock policy tests cover 320/360/400/800/1280 widths, all three manual modes and
  keyboard presence while keeping controls at least 48 pixels wide.
- Built all four Arch packages with existing host tools. No host package or
  desktop configuration changed. The source ISO package list includes the new
  runtime tools; no image build or ISO boot was performed.
- Installed the development source in the existing VM, preserving a rollback
  copy. Python GObject and FFmpeg were already present; no dependencies were
  installed during this task. ModemManager service installation remains pending
  the requested approval.
- In the VM, entered a synthetic contact using QEMU keyboard events, navigated
  the glass photo browser, selected a project-logo PNG and saved the contact.
  The copied avatar and local data persisted with mode 0600. Contact shortcuts
  opened the keypad and SMS composer. No real calls or messages were sent.
- Changed the ringtone through the on-screen selector and verified the saved
  preference. Preview launched ffplay; Stop preview terminated it. This verifies
  process control, rather than audible output on this VM's absent audio backend.
- Inspected Phone/contacts, Messages, sound settings and SIM settings at 400x800.
  At 1280x800, automatic Desktop mode showed the wider panel and two-column
  Messages. Refreshed Tablet home/controls at 800x1280.
- A dedicated 48-pixel status-handle area opens the pull-down by click. Guest
  uinput downward swipe also opens it. The volume button is separate; opening
  the drawer does not change volume. The unavailable VM sink stays disabled.
- Captured twelve current QMP frames, added six app screenshots and refreshed
  home/controls in all modes. The screenshot ZIP now contains nineteen images.
  Capture hashes and example-data descriptions are under assets/screenshots/.

Remaining device checks:

- Actual ModemManager service and authorization on a modem-equipped target;
  incoming/outgoing calls, voice audio routing and in-call keypad behavior.
- Real SMS receive/send/delivery and unplug/reconnect behavior.
- Physical SIM/PIN/slot switching and eUICC profile changes/enrollment through
  the selected reader. The VM's unavailable state is not cellular hardware proof.
- Audible alerts through real speakers/headsets and alarms app scheduling.

The updated site passed installed-Chromium phone/desktop checks: all images
loaded, no horizontal overflow, keyboard mode tabs retained focus, gallery and
Escape close worked, and no uncaught JavaScript exceptions were observed.

## VM audio, touch and bar refinement — 2026-10-18

Validated the working tree based on `aec7ac8`, including the preserved unfinished
power integration. The implementation was checked in an isolated worktree before
copying the affected files back. The original merge/index state was retained.
Local evidence and source hashes are in `build/vm-touch-review/`.

Actual environment: QEMU 11.1.1, KVM, two vCPUs, 1536 MiB RAM, virtio VGA with
Virgl. The guest compositor log identifies `virgl (Mesa Intel UHD Graphics 605)`.
The Basic launcher now enables GL, virtio multitouch, HDA output, a USB audio
output and virtio RNG. The guest audio packages were installed with owner approval;
no host packages or desktop configuration were changed.

Actual results:

- 68 Python tests and 42 Qt Quick results passed, both Hyprland configurations
  verified, and QML lint completed with existing service/type-metadata warnings.
  Shellcheck was unavailable. Scratch HOME was used by the check script.
- Guest ALSA and PipeWire detected the HDA and USB outputs. A host PipeWire
  recording linked directly to QEMU's playback ports captured a real test tone:
  480,000 stereo frames at 48 kHz, signed-16-bit peak 2563 and RMS 1273.25.
  Host speakers were muted and their mute preference was retained. This checks
  the guest-to-host signal path; audible speaker output was not assessed.
- Genuine QMP multitouch opened the drawer with a downward swipe, closed it with
  an upward swipe on the fixed bottom handle, scrolled its content, selected the
  USB output, toggled mute and dragged volume from 40% to 60%. Volume was restored
  to 40% and unmuted in the guest. No uinput device or guest root input helper was
  required for these tests.
- Home and controls were inspected at 320×640, 400×800, 800×1000 and 1280×800.
  The central controls handle is separate from audio; the phone header omits the
  speaker shortcut. Wide content is capped at 720 logical pixels. Radio labels
  wrap, and the collapse handle remains outside the scrolling content.
- Opening/closing controls and opening Home then Back preserved the active Foot
  window address and its focus. The disposable test terminal was closed afterward.
  Final compositor config errors were empty; the development shell was installed
  back into the guest's normal development path and left at 400×800.

Idle optimization: absent cellular/radio hardware now polls every 30 seconds;
cellular remains at 5 seconds when available and 1.5 seconds during a call.
Opening communications pages immediately requests current state; opening controls
refreshes radios. In one 30-second idle sample per version, Quickshell child CPU
ticks decreased from 177 to 51 (71%); its own ticks decreased from 67 to 4.
These short samples measure idle work, not frame rate or touch-to-display latency.
Virgl was verified, but no before/after graphics benchmark was performed.

Remaining device acceptance: physical multitouch, Wi-Fi, Bluetooth, cellular,
camera, microphone, battery and real-time audio scheduling. The VM has no radios,
modem, camera or battery. RTKit is absent; audio services use ordinary scheduling.

### Viewer regression follow-up

The owner still found the accelerated presentation unacceptable after a trial
800×1600 framebuffer at scale 2. That trial was reverted to the saved 400×800,
scale-1 preference. The VM was shut down cleanly and relaunched with `virtio-vga`
and `gtk,gl=off`, retaining KVM CPU acceleration, both audio outputs and multitouch.
The Basic launcher now defaults to `VM_GL=0`; Virgl remains an explicit opt-in.
The earlier accelerated screenshots and CPU samples describe that earlier test,
not the final viewer choice. Shell syntax and both QMP gesture-driver tests pass.
The software-viewer guest booted and signed in successfully. Both sinks remained
available, compositor config errors were empty, and QMP swipe-open/close was
retested. `build/vm-touch-review/viewer-software.png` records the resulting host
presentation. Owner visual acceptance remains pending.

The owner accepted the software viewer's appearance. It is the final default;
the earlier Virgl and higher-resolution trials were rejected.

## Publication checks — 2026-10-18

The software display was accepted by the owner. The publication includes the
preserved PR #18 contributor merge and guarded power-profile backend, the final
VM audio/touch profile, the bar/drawer changes and reduced absent-device polling.
Four Arch packages were rebuilt locally without installing host dependencies.

The site refresh contains seventeen current captures from source commit
`0b17d39`, plus the three retained historical PIN-login captures. The twenty-image
ZIP passed CRC and per-image SHA-256 checks; the manifest covers every image.
Chromium desktop and phone checks passed for image loading, horizontal fit,
keyboard layout tabs, gallery selection and Escape dismissal, with no JavaScript
exceptions. The VM was restored to 400×800 with its normal development shell.

Remote Ubuntu and Arch checks caught ShellCheck SC2054 on two comma-containing
QEMU device arguments after all Python and Qt Quick tests passed. Both arguments
were quoted explicitly; workflow tests were rerun for that command-only fix.

## Intel/AMD tablet pilot and supplied animation — 2026-10-18

Scope: source, package builds and publication. The owner requested no changes to
the host or existing development VM. Neither was configured, installed into,
restarted or updated during this work.

The tablet profile supplies firmware, wireless tools, a full PipeWire stack,
authorization/portal integration, an OSK and general desktop applications.
Live-image staging switches its own overlay to NetworkManager, adds the supplied
Plymouth animation and retains the upstream boot machinery. Installed systems
use the documented manual Arch package path; no disk installer is provided.
`tessarchy-readiness` reads packages and service state without writing settings.

The app picker uses an explicit primary-application policy: one installed choice
per role, excluding helpers and hidden entries. Qt Quick tests cover duplicates,
hidden/missing apps and preferred alternatives. Startup reuses an existing login
user bus; scratch-HOME tests cover that path and dev install/uninstall.

Actual local checks: 72 Python tests and 46 Qt Quick results passed, both Hyprland
configs verified and QML lint completed. ShellCheck is absent locally and runs in
CI. All five packages built without installing host dependencies. Animation export
produced 160 480×480 PNGs at 20 fps (8 seconds), about 5.3 MiB on disk. The original
silent 1080×1080 MP4 is preserved with its checksum. The site labels it as a
supplied animation preview. No current-VM or physical-tablet boot claim is made.

Physical acceptance remains pending the tablet model and tester feedback: firmware
and mixed-UEFI compatibility, native touch/OSK dialogs, Wi-Fi/Bluetooth, audio,
charging, suspend/wake and boot/recovery. Automatic rotation, secure session
locking and native network association remain separate work.

### Alpha 3 live boot inspection

Actions run 39127243527 built source `566a4385432697ffbb21147355476bed5727d9f5`
using archiso 91-1. The diskless BIOS and non-Secure-Boot UEFI QEMU/KVM captures
were inspected: both reached Tessera and opened the curated main-app picker.
The guests had 2 GiB RAM, 2 vCPUs, no NIC and software virtio graphics, at 1280×800.
The supplied Plymouth video is visible in the early captures; a blank interval
remains during compositor handoff before the desktop appears. No physical tablet
or installed-disk boot was tested. `live-launcher.png` and `tablet-startup.png`
retain actual CI frames; full boot evidence accompanies the release.

ISO: `tessarchy-0.1.0-20261018-x86_64.iso`, 2,111,864,832 bytes.
SHA-256: `7e7f5267e096d7d3f0e1340835fd49ff4a59551e7ecca3a91efb18449f34cf38`.
CI checksum verification passed; GitHub's uploaded ISO asset digest independently matches the SHA-256 above.
Later source-only packaging hygiene and CI-bundle changes do not change this ISO's
recorded source revision. Installed tablet packages carry their own provenance.

A remote greeter test exposed an incidental collision between the synthetic PIN
and Quickshell's random shell-identity hash. The log check now ignores only that
strictly formatted identity line; an added regression check still detects an
actual plaintext response. This changes tests, not authentication behavior.

The Arch package build initially lacked Git for source provenance; the disposable
CI toolchain now installs it before checkout so Actions creates a Git repository
rather than a REST source archive. Local final checks pass 73 Python tests
and 46 Qt Quick results. Publication checks cover the 21-image manifest/ZIP and
the supplied MP4 hash, plus desktop/phone browser behavior and video decoding.

### Existing installed development VM updated — 2026-10-18

After publication, the owner authorized updating the existing guest. Its previous
user session/source, system boot configuration and package list were backed up
inside the VM. The host received no packages or configuration changes.

The guest was fully upgraded, then the four verified Alpha 3 CI packages from
source `644c34dfb728f09d0b995ee32d35b87c7eb2cdf5` were installed with their
repository dependencies. Its private development copy was refreshed from that
same revision, preserving its preferences. NetworkManager now owns Ethernet;
networkd is disabled/masked to prevent socket reactivation. The existing resolved
integration remains. The preflight reports no missing packages or manager conflict.

The installed guest rebooted with Linux 7.2.11-arch1-1. Actual boot frames show
the supplied animation, followed by the existing PIN greeter. Touch PIN login
reached the updated desktop at the accepted 400×800, scale 1 software display.
The curated picker, Text Editor launch, OSK visibility and a typed character were
inspected; the empty test document was discarded. Native touch swipes opened and
closed the controls drawer. Both audio outputs were detected at their retained
volume; playback produced a nonzero monitor capture (RMS 503.76 over 241,920 signed
16-bit samples). Hyprland reported no configuration errors, and neither the system
nor user manager reported failed units. The VM was left running on the home screen.

This is installed-disk VM evidence. Physical touch hardware, radios, power and
suspend acceptance remain pending. Stock OSK sizing still needs the separate
keyboard sizing/accessibility work listed on the task board.

## Mobile status tray fix, 2026-10-18

The installed Alpha 3 VM at 400×800, scale 1, software graphics showed
NetworkManager’s wired-network tray icon clipped into the phone status bar.
The development shell now displays application tray indicators only in Desktop
layout. Phone and Tablet retain their built-in status indicators; Connections
remains in the app picker and the NetworkManager applet continues running.

The updated development copy was loaded in the existing VM. Actual QMP captures
confirmed the computer icon was gone and the clock, pull-down handle and status
indicators remained visible. A touch tap opened the drawer and a second closed
it. Hyprland reported no config errors. `./scripts/check.sh` passed 73 Python
tests, 46 Qt Quick results, QML lint and both Hyprland config checks; fish and
shellcheck were unavailable. Desktop/Tablet runtime checks remain pending;
the published Alpha 3 ISO has not been rebuilt for this fix.

## On-screen keyboard key height, 2026-10-18

Stock squeekboard layouts size their panel from the output width, so the
400x800 phone geometry produced key rows shorter than the 48 logical-pixel
touch target (about 29 px per row at 400 px wide, four rows). `session/tessarchy-osk`
now derives the portrait panel multiplier from the focused output's logical
short side and writes `scale-in-vertical-screen-orientation` into the private
keyfile, targeting a panel that keeps every key row at or above 48 px. The
setting applies to portrait outputs; landscape panels are already tall enough.

Actual measurement in the development VM, from Hyprland `layers` geometry and
framebuffer row analysis of QMP captures:

- 400x800 scale 1: multiplier 1.80, panel 225 px, four rows of 50, 50, 50, 51 px.
- 360x800 scale 1: multiplier clamps to the 2.00 maximum, key rows 50 px.

`./scripts/check.sh` covers the multiplier calculation with stubbed
`hyprctl`/`gsettings` (400 px to 1.80, 800 px at scale 2 to 1.80, 300 px to the
clamped 2.00). squeekboard caps the multiplier at 2.00, so outputs below about
346 logical px wide cannot reach 48 px keys through this setting and need a
custom layout; that limit is a documented remaining gap. Hardware touch
acceptance remains pending.

## On-screen keyboard suppression in Desktop mode, 2026-10-18

Owner report: in Desktop mode a focused text field raised a keyboard panel that
covered the window. squeekboard shows itself whenever the GNOME a11y key
`screen-keyboard-enabled` is true, which the wrapper seeds, so the panel appeared
regardless of layout.

`session/tessarchy-osk` gained `enable` and `disable`, which flip only that key
through the private keyfile backend, and `tessera-shell` now calls them whenever
the layout for the primary output changes (`Policy.oskArmed`): Desktop disarms,
Phone and Tablet arm. Setting the key alone hides a keyboard already on screen
and re-arms auto-show later; calling `SetVisible false` as well was tested and
discarded because squeekboard then stays forced-hidden across a re-arm.

Actual VM checks at the accepted 400x800 and at 1200x800 Desktop:

- Desktop 1200x800: key false; a touch tap into a focused Foot terminal left the
  `osk` layer absent, before and after switching layouts.
- Phone 400x800: key true; the same tap raised the keyboard, so the touch layouts
  are unchanged.
- `./scripts/check.sh` covers the wrapper's `enable`/`disable` (stubbed
  `gsettings`) and `Policy.oskArmed` in the Qt Quick suite.

## Display rotation through generated Lua, 2026-10-18 UTC

Actually performed:

- Reworked the rotation PR for the Lua session: the Settings control calls the
  fixed-argument `tessera-rotate` helper, which rewrites only Tessarchy's
  generated `display.lua` with the current mode, position and scale plus the
  next transform, reloads Hyprland and verifies the applied transform. On
  failure it restores the previous file and reloads again; `preferences.lua`
  is never touched. `session/hyprland.lua` loads `display.lua` after the user
  preferences.
- New helper tests use a stubbed `hyprctl` and scratch HOME: 90-degree cycling
  with settings preserved and the user preferences untouched, state restore
  when the reload does not apply, `reset` removing the generated file, and
  argument/unknown-output rejection without writing files. A wiring test keeps
  the fixed argv and the generated-file flow, and asserts no `keyword` path
  returns.
- `session/hyprland.lua` and a generated `display.lua` example pass
  `Hyprland --verify-config` on Hyprland 0.56 with a private runtime directory.

- Guest cycle on the build 10 debug line (QEMU x86_64, Hyprland 0.56.2, 1280x800):
  with the session live, the generated `display.lua` carrying `transform = 1`
  reloaded through Hyprland and `hyprctl monitors` reported `transform: 1`; the
  Tessera shell re-laid out to the portrait canvas (capture
  `rotate-applied-90deg.png`). Running `tessera-rotate` itself as the live user
  then uncovered a real reload race: the helper writes `display.lua` inside the
  watched config directory, Hyprland's own watcher starts a reload, and the
  explicit `hyprctl reload` issued moments later can lose the IPC handshake
  (`Hyprland IPC didn't respond in time`), so the helper reported a rejected
  reload and restored the previous state. Fixed by retrying the explicit reload
  in `reload_hyprland()` (20 x 0.5 s, used by apply, reset and restore) and by
  forcing mode 0644 on the generated file so a helper started from a rescue
  console still writes a file the session user can read. Debug-image runs as
  root had also been writing the file outside the live user's config
  (`/root/.config`); the guest harness now exports `HOME`, `XDG_CONFIG_HOME`
  and `HYPRLAND_INSTANCE_SIGNATURE` for the helper, which is a harness fix, not
  a product change.

Not performed: rotating a physical display, wake/rotation cycles and touch
remapping. These stay in T37 hardware validation.
## Notification center and pop-ups, 2026-10-17

Implemented, static validation only; live-session acceptance pending.

- `Quickshell.Services.Notifications` (verified in Quickshell 0.3.1 source):
  the shell registers `NotificationServer` on `org.freedesktop.Notifications`.
  Delivered items are marked `tracked` and listed in the alert center until
  `dismiss()`ed; capability flags advertise only plain-body support.
- `NotificationCard.qml` and `NotificationCenter.qml` render app name, summary,
  body (three lines max, elided) and an IMPORTANT tag for critical urgency;
  every interactive control is a TouchButton with at least 48 logical pixels.
  Pop-ups hide on tap, dismiss via the close button, and expire after 4s/8s
  for low/normal urgency (critical stays until dismissed). The "pop-ups muted"
  toggle persists in `shell.ini` and is also offered in Settings.
- `LayoutPolicy.notificationPlacement/timeout` were unit-tested: the Qt Quick
  suite reports 17 passed including the two new notification cases.
- `uninstall-dev.sh` no longer hardcodes the shell file list; it mirrors the
  repository tree so new shell files (such as these components) cannot leave
  stray files behind. The install/uninstall workflow test asserts the new
  component and icon are removed; 10/10 workflow tests pass.
- Not performed: running the shell against a live session bus, delivering a
  real `notify-send`, tapping cards, pop-up stacking on multiple outputs, and
  DND persistence across a restart. These stay on the manual list.
## Idle blanking through hypridle, 2026-10-18 UTC

Actually performed:

- Reworked the idle PR on the current Lua session: hypridle is started from
  the existing `hl.on("hyprland.start")` hook using the session data directory,
  the config keeps one 300-second listener (`hyprctl dispatch dpms off` /
  `dpms on`) with no lock command, and `misc.key_press_enables_dpms` plus
  `misc.mouse_move_enables_dpms` are set explicitly so wake input is handled
  by Hyprland.
- The Lua stub test now drives the real `hyprland.start` callback and asserts
  the exact hypridle command with `TESSARCHY_DATA_DIR`; a config test checks
  the timeout, both dpms commands and the absence of any lock command; the
  staging test checks the config lands in the image session directory and the
  packaging installs it; the boot-test script wakes the panel before each
  capture so idle blanking cannot look like a failed boot.
- The guest run of the first integration image caught the legacy listener
  commands failing: under the Lua config, `hyprctl dispatch dpms off` is
  rewritten to `hl.dispatch(dpms off)` and rejected. The listener now uses the
  documented Lua dispatch form, `hyprctl dispatch 'hl.dsp.dpms({ action =
  "disable" })'`, with the matching enable command on resume (see the Hyprland
  0.56 dispatcher and hypridle documentation).
- `session/hypridle.conf` parses under hypridle 0.1.8: `Registered timeout
  rule for 300s` with both dpms commands; a deliberately broken config is
  rejected by the same parser.
- `session/hyprland.lua` with the new wake options and hypridle autostart
  passes `Hyprland --verify-config` (`config ok`) on 0.56.2.

- Full idle-to-blank-and-wake cycle in the guest (build 10 debug image, QEMU
  x86_64, Hyprland 0.56.2, 20-second debug timeout): hypridle registered the
  shortened rule, logged `Idled` at 04:22:21, and the monitor read back
  `dpmsStatus: 0` (blanked output; screendumps of a blanked virtio output are
  black, so the dpms state is the evidence). Waking input on the session VT
  produced `Resumed`, then `[LOG] Running hyprctl dispatch 'hl.dsp.dpms({
  action = "enable" })'` with a plain `ok` and `dpmsStatus: 1` afterwards. A
  second cycle later in the same run (another `Idled` plus the disable
  dispatch) also succeeded, showing the Lua dispatch form is accepted in both
  directions. The idle listener only counts down while the session VT is
  active; console-side checks read dpms state via `hyprctl monitors` after
  switching back.

Not performed: hardware idle behavior. It stays in T37.

## Tester ISO Alpha 4, 2026-10-18

Built by Actions run 39144935780 from `main` = `0f71636a0aecb20cd76359a71d2e911eb082cb57`
(`build-info.txt` records that commit and archiso 91-1). The draft prerelease
`v0.1.0-alpha.4` was reviewed and published as a prerelease, not marked latest.

- Asset: `tessarchy-0.1.0-20261018-x86_64.iso`, 2,111,864,832 bytes.
  SHA-256 `8cae59e93b1043699fc5d568b5fb7bccb1ae71288703a358c874ded4ec636b03`,
  identical to the digest GitHub reports for the uploaded asset and to the
  checksum the workflow verified before upload. The download URL returns HTTP 200.
- Boot captures were inspected, not just collected: both `boot-bios.png` and
  `boot-uefi.png` show the live image reaching the graphical Tessera desktop
  (workspace strip, notification bell, tray indicator, dock, wallpaper and the
  Tessarchy mark), and both `launcher-bios.png` and `launcher-uefi.png` show the
  curated "Your space" picker with Firefox, Files, Text Editor, Document Viewer,
  Image Viewer, mpv, Calculator, network and Bluetooth managers, Foot, Phone,
  Messages, Settings, Controls and Alerts.
- Contents: Alpha 3 plus the desktop tray-icon fix, on-screen keys at the 48px
  height floor, five-minute idle blanking, the notification center, display
  rotation and the Tessy workflow. Live, nonpersistent, no disk installer.
- Physical hardware, touch, radios, rotation and Secure Boot remain untested;
  the boot checks are diskless QEMU/KVM smoke tests.

## Desktop taskbar and status-strip cleanup, 2026-10-18

Owner report: an out-of-place icon sat in the Desktop status bar, and the bottom
bar still looked like the mobile dock.

The icon was the application tray item (nm-applet's wired-network pixmap). An
app-supplied pixmap cannot be restyled to the shell's mint line icons, so the
tray moved out of the status strip and into the bottom bar. Desktop navigation is
now a full-width taskbar (64 px) with the launcher buttons, one task button per
open window and the tray on the right; Phone and Tablet keep the floating dock
unchanged. The taskbar stays full width while a page is open, and the page reads
as a centred sheet.

Actual VM checks at 1200x800 Desktop:

- Status bar left to right: clock, workspaces 1-5, pull-down handle, focused
  window title, notification bell, cellular, Wi-Fi, battery, volume, settings -
  no application tray tile.
- Taskbar left to right: Apps, Windows, Settings, one button per open window
  ("This is the deskto...", "arch@archlinux:~"), then the tray icon at the right.
- Tapping a task button focuses that window and dismisses the open page; opening
  Apps shows the full-width launcher grid with the taskbar still full width (the
  launcher page has no heading of its own).
- `./scripts/check.sh` passes 49 Qt Quick results, QML lint and both Hyprland
  config checks. Physical touch acceptance remains pending.

## Windows-XP-style glass taskbar, 2026-10-18

Owner asked how hard an XP-style taskbar would be. It is styling only: the
behaviour from the previous taskbar is unchanged. Added `StartButton.qml` (raised
accent pill with the project mark and an italic `start` label) and
`TaskButton.qml` (wide, bevelled, horizontally laid out; the focused window reads
as pressed), and wrapped the tray indicators plus the clock in a sunken
translucent segment.

Actual VM check at 1200x800 Desktop, from a QMP capture: left to right - the
`start` pill, quick-launch icons, a divider, two wide task buttons ("This is the
desktop mode (Dr...", "arch@archlinux:~"), spacer, then the sunken tray with the
tray icon and the clock. `./scripts/check.sh` passes 86 Python tests and 49 Qt
Quick results. Physical touch acceptance remains pending.

## Weather indicator, 2026-10-18

Owner asked for a weather integration in the top bar.

- `shell/helpers/weather.py` (no API key): location from `[Shell] weatherPlace`
  (a city name, or `auto` to place the machine by IP), current conditions from
  Open-Meteo, WMO code mapped to a description and one of eight new line icons.
  `[Shell] weatherUnits` picks metric or imperial. The last observation is cached
  in `$XDG_STATE_HOME/tessarchy/weather.json`, so a failed fetch shows a stale
  reading rather than nothing. The helper never exits non-zero in a way that
  blanks the shell.
- `WeatherBackend.qml` polls it every 15 minutes; the status strip shows a small
  icon + temperature chip next to the focused-window title (right-aligned in
  Desktop, where the indicator cluster moved to the tray).
- Tests: `tests/test_weather.py` covers the code/icon mapping, ini parsing,
  named-place geocoding, IP auto-location with cache reuse, the offline fallback
  and a corrupt cache.

Measured on this machine: `weather.py` returned
`{"ok": true, "place": "Miami, Florida", "temperature": 26.5, "unit": "°C",
"description": "Overcast", "icon": "weather-cloud", ...}`, and with the fetcher
forced to fail it returned the same observation with `"stale": true`.

In the VM the deployed helper returned the same live reading and the chip
rendered as a cloud glyph plus `26°C`: in Phone mode (400x800) it sits in the
status strip, and in Desktop mode (1200x800) it is right-aligned in the strip
because the indicator cluster has moved to the taskbar tray. `./scripts/check.sh`
passes 99 Python tests (7 new) and 49 Qt Quick results.

## Desktop taskbar tray, 2026-10-18

Owner asked for the top-bar status icons to move to the bottom-right of the
taskbar in Desktop mode, as Windows does.

The right-hand indicator cluster (bell, cellular, Wi-Fi, battery, volume,
settings) is now a shared `StatusIndicators.qml` component. The mobile status
strip keeps it along the top edge (`visible: surface.mode !== "desktop"`); the
desktop taskbar renders it `compact` inside the sunken tray, before the
application tray icons and the clock. The bell's unread count is a small badge
instead of a label so it fits the tray. Layout still follows the old width
breakpoints (battery text at 380 px, volume at 700 px, settings at 560 px).

Actual VM checks:

- 1200x800 Desktop: the status strip's right side is empty; the taskbar tray
  reads bell, cellular, Wi-Fi, battery, volume, settings, tray icon, clock.
- 400x800 Phone: the status strip keeps its icons and the floating dock is
  unchanged.
- `./scripts/check.sh` passes 92 Python tests and 49 Qt Quick results.

## Desktop window resize, 2026-10-18

Owner report: ordinary windows in Desktop mode could not be resized.

Cause: `general.resize_on_border` was left at its default `false` and
`border_size` is `0` in this theme, so there was no grabbable edge at all. The
`SUPER + right-drag` bind existed but nothing else did.

Fix: set `resize_on_border = true` and raise `extend_border_grab_area` to 24 so
the grab band is finger-sized even though the border is invisible.

Verified in the VM at 1200x800 with a QMP pointer drag (`usb-tablet`): dragging a
floating window's right edge outward took `foot` from 960x640 to 1057x640.
`hyprctl getoption general:resize_on_border` reads `true` and
`general:extend_border_grab_area` reads `24`. A QMP *touch* drag does not resize
(border resize is pointer-only), which matters on real touch hardware.

## Start menu and windowed Desktop, 2026-10-18

Owner asked for a modernised Windows-XP Start menu above the Start button (apps
in a grid, smaller and more professional, blue-tinted like the button), for a
second press of Start to close it, for the "Your space" label to go, and for
Desktop windows to open windowed like Windows rather than tiled, with a Settings
toggle between the two.

- The Start menu is a Desktop-only `PanelWindow` (`namespace tessera-start`)
  anchored above the Start button on the primary output. It carries a blue header
  band and a 4-column grid of `StartMenuTile`s (40 px icon over a 12 px label in
  a blue-tinted glass chip), tinted from the same accent as the Start pill.
  Choosing a tile closes the menu and launches the app.
- The panel matches the taskbar's glass: the same translucent accent fill, a
  zero bottom margin so it sits flush on the taskbar's top edge (Hyprland already
  offsets by the taskbar's exclusive zone), square bottom corners and rounded top
  corners. `tessera-start` is added to the compositor blur rule
  (`tessera(-status|-start)?`), so the panel is frosted like the bar and status
  strip.
- `StartButton.onClicked` now toggles `panel.startMenuOpen`, so a second press
  closes the menu; opening any shell page also closes it.
- The launcher page no longer renders a heading, so "Your space" is gone.
- Desktop window style is a saved preference (`desktopWindows`, `windowed` by
  default). `session/hyprland.lua` reads it on `window.open`: in `windowed` mode
  an ordinary Desktop window is floated, sized to a capped/ floored conventional
  size (960x640 at 1200x800) and centred; `tiled` leaves the dwindle layout
  intact. The Settings DESKTOP toggle flips the preference and reloads the
  compositor so the config re-reads it.
- Tests: `tests/test_workflows.py` adds
  `test_windowed_desktop_floats_new_windows_and_honors_settings_toggle` (float +
  resize + center for windowed, none for tiled, phones still maximize).

Actual VM checks at 1200x800 Desktop (QMP captures, guest shell deployed from
`shell/`):

- Taskbar left to right: blue `start` pill, quick-launch icons, empty task area,
  sunken tray with tray icon and clock.
- Tapping Start opens the blue-header 4-column app grid above the button; tapping
  Start again closes it. `hyprctl -j layers` reports the panel at
  `x 12 y 382 w 452 h 354`, so its bottom edge (736) meets the taskbar top.
- Frosting verified by comparison: a strip beside the panel shows crisp Nautilus
  folder icons and text, while the same content under the panel is a smooth blur.
- New app window (`foot`) is `floating=True size=[960,640] at=[120,72]`; with
  `desktopWindows=tiled` a new window is `floating=False size=[1200,688]` and the
  taskbar shows its task button. `./scripts/check.sh` passes 87 Python tests and
  49 Qt Quick results. Physical touch acceptance remains pending.

## Display controls integration — 2026-10-18

PR #16 was closed as superseded: AppSwitcher.qml already implements window
captures within the current horizontal switcher. PR #19 adds brightness and night
light to the current pull-down without replacing the shell or installer.

Actual validation:

- `./scripts/check.sh` passes: 91 Python tests and 49 Qt Quick results. QML
  lint and Hyprland config verification pass; fish and ShellCheck are unavailable
  locally and remain covered by CI.
- Helper regression tests exercise brightness reads, writes, stepping, leading
  zeros, zero brightness, exact backlight selection, failed writes and absent or
  invalid hardware using a temporary sysfs fixture.
- Night-light tests cover on/off/status, duplicate starts, missing backend/user
  manager, start failure and invalid arguments. A stale PID file referencing a
  live unrelated process is ignored; that process survives both off calls.
- An offscreen Quickshell harness verifies persisted night-light application,
  toggle readback, coalesced brightness changes and actual-level restoration
  after a failed write. Installer round-trip and ISO staging checks include both
  helpers and the image's backend packages.

Physical backlight permissions, brightness keys on hardware, compositor color
changes from hyprsunset, and a new ISO boot remain pending. The development guest
has neither backend installed; no dependencies or host configuration were changed.

## Website tablet screenshot repair — 2026-10-18

Replaced the stretched tablet home screenshot with the intact 800×1280 VM
capture preserved in commit `aec7ac8`. The replacement is an original screenshot;
its pixels were not reconstructed. Updated the tablet image and application
script cache versions so returning visitors receive the corrected asset.
Visually inspected the replacement, built the site, and verified that both the
published asset and screenshot ZIP contain the replacement bytes.

## Repository audit — 2026-10-18

Reviewed session helpers, development install/uninstall, package and bundle
scripts, local communications storage and Tessy event formatting in an isolated
worktree. Confirmed regressions before changing their implementations:

- At 600×1200 with scale `1.5`, the OSK helper emitted `1.26` rather than the
  `1.80` multiplier used for the same geometry at `1.50`. Decimal fractions are
  now padded before conversion; coverage includes integer, one- and two-digit
  monitor scales.
- An unchanged development installation could not be removed from an updated
  source checkout because the uninstaller compared installed launchers against
  the newer source. New v3 installs retain original launcher bytes and derive
  their owned launcher list from the install manifest. Changed launchers, unsafe
  manifests and missing originals still stop removal before any files are
  deleted. v1/v2 uninstall compatibility is retained; those older installations
  still use source comparisons because they have no recorded originals.
- Tessy could crash on an empty commit message and exceed Discord's embed
  limits on long summaries or PR titles. Summaries now have a fallback and are
  shortened; payload construction enforces per-field and total limits from the
  [Discord message specification](https://docs.discord.com/developers/resources/message#embed-limits).
  Formatting tests use synthetic events and make no network requests.

Actual validation: `./scripts/check.sh` passes 97 Python tests and 49 Qt Quick
results, plus available QML and Hyprland checks. Fish and ShellCheck are absent
locally and are checked in CI. Coverage includes uninstall from a different
source tree, rejection of edited/missing launcher originals, legacy uninstall
and long/empty event messages. No host settings, development
installation or running VM were modified. Fractional-scale acceptance on a
physical display remains pending.

## PR #20 rebase VM touch verification (2026-10-19)

Actually exercised the rebased branch in the Arch QEMU guest at 720×1440
physical, scale 0.9 (800×1600 logical), with `TESSARCHY_OSK=1` and two Foot
windows. Deployed this branch's complete `shell/` and `session/` tree (removed
an unrelated stale guest `components/qmldir` before launch). A synthetic
uinput **touchscreen** tapped Recents at physical (154,1410); the page opened
and `busctl --user get-property sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0
Visible` returned `b false`. Launching/focusing a second Foot from outside
while Recents stayed open also returned `b false`; the page screenshot shows
both previews and no keyboard (`vm/rebase-guard-focus.png`). After touch
closed Recents, explicitly focusing the first then second Foot with Hyprland's
`hl.dsp.focus({ window = "address:…" })` returned `b true`, with keys visible
(`vm/rebase-guard-osk-visible.png`). The intermediate page screenshot is
`vm/rebase-guard-page.png`. The first post-close focus attempt that left the
same Foot focused did not cause a keyboard re-show; a *change of focus* did.
The four focused OSK workflow tests passed; `qmllint` exited 0 with the
existing PanelWindow/type-metadata warnings. No change to this branch's
implementation was needed. These screenshots are ignored VM artifacts, not
physical-device validation.

## Keyboard suppression while a shell page stays open — PR #20

The shell already calls `tessarchy-osk hide` when a panel page opens and when
quick controls opens. That one-time call does not prevent squeekboard from
reappearing if a text-input app behind the open panel takes focus: it maps a new
`osk` layer. This branch also listens for Hyprland `openlayer>>osk` while a
shell page or quick-controls drawer is open, and hides the keyboard again.
The separate file picker layer is unaffected.

Earlier development-VM validation on the original PR branch (2026-10-17,
800×1600 logical at scale 0.9, four Foot windows, `TESSARCHY_OSK=1`): with
Recents open, shifting app focus showed the keyboard after each change on the
control shell (#11), but left it hidden after each change and after one second
with this guard; closing Recents restored auto-show on focus. This evidence is
for the old branch, **not** a live test of the current rebase. The current
rebase was checked with `./scripts/check.sh` on the host; guest behaviour and
physical touch still require separate acceptance.
