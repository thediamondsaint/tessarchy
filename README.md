# Tessarchy

**Touch-first Arch Linux, built around the Tessa shell.**

Tessarchy combines Arch Linux, Hyprland and Quickshell into a mobile interface
that adapts from phone-sized screens to tablets and desktops. Its Quiet Edge
design uses shallow glass, mint accents, a glacier wallpaper and floating icon
navigation.

The experimental [Tessa scrolling interface](docs/tessa-integration.md) adds a
floating cube, edge wheel, radial actions and searchable launcher. Use Super+T
to enter or leave its dedicated workspace, and Super+Space to open applications.

[Website](https://thediamondsaint.github.io/tessarchy/) ·
[Tester ISO](https://github.com/thediamondsaint/tessarchy/releases/tag/v0.1.0-alpha.4) ·
[Agent workspace](AGENT-README.md) · [Contributing](CONTRIBUTING.md) ·
[Device roadmap](docs/device-roadmap.md) · [Testing](docs/testing.md)

## Current project

| Area | Status |
| --- | --- |
| Development target | x86_64 Arch in QEMU/KVM |
| Interface | Quiet Edge status bar, pull-down controls, launcher, settings and glass card switcher |
| Layouts | Automatic Phone/Tablet/Desktop selection with a saved manual override |
| Navigation | Touch-sized icon controls, Alt+Tab, workspace controls and confirmed close/exit |
| Login | Four-digit account-password entry through greetd/PAM; real VM login cycle tested |
| Radios | rfkill power/airplane controls; Bluetooth discovery and connections to already-paired devices |
| Phone and messages | Dock apps, contacts/photos, ModemManager call/SMS backend and SIM/eSIM settings; [guide](docs/communications.md) |
| Sounds | Five VoidRing tones, ringtone/message/alarm selection, previews and MP3 import |
| Power | Battery status and supported power modes, with missing-service guards |
| Display controls | Backlight slider and keys; persisted 4000 K night light when supported |
| Audio and media | Optional PipeWire controls and MPRIS playback integration |
| Keyboard and captures | Optional squeekboard; Print and pull-down screenshot actions |
| Latest checks | 105 Python tests, 62 Qt Quick results and 4 website tests in the current audit; see the validation record |
| Next device milestone | Select and bring up one physical reference device |

The [validation record](docs/testing.md) tracks runtime results for each feature.
Bluetooth pairing currently uses an external manager. The [agent task
board](AGENT-README.md#claiming-and-extending-tasks) lists the next contributions.

- A top status bar with clock, registered tray icons, battery status when available,
  and session controls.
- Automatic Phone/Tablet/Desktop shell layouts with a saved manual override.
- A persistent navigation bar with 56px touch targets and a compact desktop dock.
- An original mint-and-navy wallpaper, animated tessellated logo, and responsive
  tile launcher.
- Settings for layout mode, system theme, opacity, wallpaper shade, clock, navigation
  labels, and reduced motion.
- Translucent bars, Wi-Fi/cellular indicator slots, and optional PipeWire volume
  controls. Wireless and modem backends remain to be connected.
- An expandable launcher for Chromium and Foot.
- One system theme, Omarchy-style: a theme is a directory with an Omarchy
  `colors.toml` (and optional `backgrounds/`), so Omarchy themes work unchanged.
  `tessarchy-theme set <name>` (or Settings) restyles the shell, the keyboard,
  Foot, and GTK dark/light for apps launched through `tessarchy-run`.
- Optional squeekboard on-screen keyboard: it appears for focused text fields, and
  a Keyboard navigation button shows or hides it in Phone/Tablet modes.
- Touch file dialogs (optional `tessarchy-portal` package): on Phone/Tablet, apps'
  Open/Save dialogs are drawn by Tessa full-screen instead of GTK's dialog,
  which can't shrink below ~726 px. Portal-aware apps get it directly; GTK3 apps
  launched through `tessarchy-run` are routed there by a GTK module. Desktop
  keeps GTK's own dialog.
- A scrollable window overview with application switching and maximize/restore.
- Confirmation before closing a window or ending the session.
- A dedicated Hyprland session, user installation, and reversible tty1 startup.
- A QEMU development workflow, local Arch package recipes, and an initial
  archiso staging/build pipeline.

## Tester download

[Alpha 4 — tablet pilot with today's fixes](https://github.com/thediamondsaint/tessarchy/releases/tag/v0.1.0-alpha.4)
carries everything from Alpha 3 (curated app picker, general desktop
applications, firmware, audio, wireless tools, on-screen keyboard and the
supplied power-on animation) plus the desktop tray-icon fix, on-screen keys at
the 48px height floor, five-minute idle blanking, the notification center and
display rotation. BIOS and non-Secure-Boot UEFI QEMU/KVM boots reached Tessa
with networking absent. The release includes checksums, package lists and
inspected boot captures.

| Image behavior | Alpha 4 |
| --- | --- |
| Login | Live-account autologin |
| Storage | Disposable live session; no disk installer or persistence |
| Text input | Included on-screen keyboard; keep a physical keyboard for recovery |
| ISO source | `0f71636a0aecb20cd76359a71d2e911eb082cb57` |
| Installed Arch tablet | Separate package bundle and [manual install guide](docs/tablet-install.md) |

Physical-tablet acceptance is pending. The release distinguishes the ISO's source
from the later package bundle's recorded source revision.

## Alpha login details

| Build | Account | Password / PIN |
| --- | --- | --- |
| PIN-login development demo | `arch` | **`1234`** |
| Downloadable Alpha 4 ISO | `tess` | Automatic login |

`1234` is the owner-designated public PIN for the alpha login demo.

## Quick start: use the basic Arch VM

Use the existing Basic Arch guest described in [docs/vm.md](docs/vm.md). Launch
its disk once, with the previous instance shut down:

```bash
./scripts/run-basic-vm.sh
```

The launcher uses `vm/Arch-Linux-x86_64-basic.qcow2`, a read-only source share,
2 GiB RAM and 2 vCPUs by default. `VM_SSH_PORT=2222` enables the optional local
SSH forwarding path.

In a prepared Arch guest, mount the source share and copy it into a fresh workspace:

```bash
sudo modprobe 9pnet_virtio
sudo modprobe 9p
sudo mkdir -p /mnt/tessarchy
sudo mount -t 9p -o trans=virtio,version=9p2000.L,ro tessarchy /mnt/tessarchy
cp -r /mnt/tessarchy/tessarchy ~/tessarchy
cd ~/tessarchy
./scripts/setup-guest.sh --autostart
```

Start the installed session from a local TTY:

```bash
~/.local/bin/start-tessarchy
```

Required guest tools and the full setup/recovery procedure are in the
[VM guide](docs/vm.md). Dependency installation is an explicit setup step.

## Development

The API baseline is Hyprland 0.56 Lua, Quickshell 0.3.1 and Qt 6. Read
[AGENTS.md](AGENTS.md), then use the [agent workspace](AGENT-README.md) to choose
and claim a task.

```bash
./scripts/check.sh
```

For a development install inside the guest:

```bash
./scripts/install-dev.sh
```

Source installs under `~/.local/share/tessarchy` and launchers under
`~/.local/bin`. A user development copy takes precedence over system packages.
Shell preferences are in `~/.config/tessarchy/shell.ini`; compositor preferences
use `~/.config/tessarchy/preferences.lua`.

To remove the development startup hook and installation:

```bash
./scripts/login-session.sh disable
./scripts/uninstall-dev.sh
```

The installer keeps Tessarchy namespaced and records installed launcher originals.
Uninstall preserves user preferences and edited launchers, and can remove an
unchanged development copy after the source checkout is updated.
Automated install tests use scratch HOME directories.

## VM testing update

The Basic VM launcher provides sound, two audio outputs and virtual multitouch.
Quick controls have a separate top handle and a fixed collapse handle; the dock
groups app shortcuts before navigation. Audio output selection, mute, volume and
touch scrolling were exercised in the guest. Software display rendering is the
accepted default; KVM CPU acceleration remains enabled. See [VM setup](docs/vm.md)
and the [validation record](docs/testing.md).

## Intel/AMD tablet pilot

The [tablet install guide](docs/tablet-install.md) covers an installed Arch target,
the `tessarchy-tablet` package profile, service setup and a read-only device
preflight. It includes everyday apps, firmware, wireless tools, audio, an OSK,
authorization and portals. The app picker keeps one installed primary app per role.
The supplied eight-second video is the new optional Plymouth power-on animation.
The Alpha 4 live ISO remains a live demonstration, not a disk installer.

## Packages and images

```bash
./scripts/package.sh
```

This builds five Arch packages into `dist/`: `tessera-shell`,
`tessarchy-session`, the `tessarchy-tablet` profile, the opt-in `tessarchy-greeter` and `tessarchy-bootsplash`. Package installation and
service activation are separate operations. The [PIN login guide](docs/phone-login.md)
covers greetd setup and the tested VM configuration. The [power-on screen guide](docs/boot-screen.md)
covers the animated Plymouth theme and quiet VM startup.

The [ISO guide](docs/iso.md) covers staging, an explicitly requested image build,
boot validation and release publication. Image files are distributed as GitHub
release assets. Generated build output stays in `build/`, `dist/` and `vm/`.

## Project map

| Path | Contents |
| --- | --- |
| `shell/` | Tessa QML, policy, helpers, icons and canonical artwork |
| `session/` | Hyprland Lua, launchers, OSK, screenshots and greeter |
| `packaging/`, `iso/` | Arch package recipes and live-image overlay |
| `scripts/`, `tests/` | Development workflows and validation |
| `assets/`, `website/` | Actual captures, roadmap and GitHub Pages source |
| `docs/` | Architecture, operating guides, roadmap and evidence |

The opt-in [window tape prototype](docs/window-tape-proposal.md) adds live scrolling
windows with an auto-hiding touch control while retaining Hyprland. It includes an
optional bridge to native continuous movement, a column-step fallback and remaining
pilot acceptance gates.

## Roadmap, branding and sharing

The [project site](https://thediamondsaint.github.io/tessarchy/) contains twenty-one
real VM captures, the [device roadmap image](assets/roadmap/tessarchy-device-roadmap.png),
sharing controls and official branding downloads. The
[logo release](https://github.com/thediamondsaint/tessarchy/releases/tag/brand-kit-20261017)
includes transparent sizes, SVG, WebP, JPG, ICO, PDF and a spinning GIF.

Agents can claim one of 56 starter tasks in [AGENT-README.md](AGENT-README.md).
Local session notes belong in the ignored `.HANDOFF.local.md`. A ready-to-copy channel
update is in [docs/community-update.md](docs/community-update.md).
