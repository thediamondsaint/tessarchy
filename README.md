# Tessarchy

**Touch-first Arch Linux, built around the Tessera shell.**

Tessarchy combines Arch Linux, Hyprland and Quickshell into a mobile interface
that adapts from phone-sized screens to tablets and desktops. Its Quiet Edge
design uses shallow glass, mint accents, a glacier wallpaper and floating icon
navigation.

[Website](https://thediamondsaint.github.io/tessarchy/) ·
[Tester ISO](https://github.com/thediamondsaint/tessarchy/releases/tag/v0.1.0-alpha.2) ·
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
| Radios | rfkill power/airplane controls; Bluetooth discovery/connections to paired devices; NetworkManager Wi-Fi scanning, connect/disconnect and passphrase entry |
| Audio and media | Optional PipeWire controls and MPRIS playback integration |
| Keyboard and captures | Optional squeekboard; Print and pull-down screenshot actions |
| Latest checks | 49 Python tests and 39 Qt Quick results; Ubuntu/Arch CI passed |
| Next device milestone | Select and bring up one physical reference device |

The [validation record](docs/testing.md) tracks runtime results for each feature.
Bluetooth pairing currently uses an external manager. The [agent task
board](AGENT-README.md#claiming-and-extending-tasks) lists the next contributions.

## Tester download

[Alpha 2](https://github.com/thediamondsaint/tessarchy/releases/tag/v0.1.0-alpha.2)
is an x86_64 live VM tester image with Quiet Edge, app cards and pull-down
radio/layout controls. BIOS and non-Secure-Boot UEFI boots reached Tessera in
QEMU/KVM. The release includes the ISO, SHA-256 checksum, package list, build log
and boot evidence.

| Image behavior | Alpha 2 |
| --- | --- |
| Login | Live-account autologin |
| Storage | Disposable live session; no disk installer or persistence |
| Text input | Physical keyboard |
| Source | `aa8b59a73a8d5d6b1d3fab6c17272e68e0bfac58` |
| Later development additions | PIN login, expanded Bluetooth, media/audio panels and screenshot actions |

## Alpha login details

| Build | Account | Password / PIN |
| --- | --- | --- |
| PIN-login development demo | `arch` | **`1234`** |
| Downloadable Alpha 2 ISO | `tess` | Automatic login |

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

The installer keeps Tessarchy namespaced; uninstall preserves user preferences.
Automated install tests use scratch HOME directories.

## Packages and images

```bash
./scripts/package.sh
```

This builds four Arch packages into `dist/`: `tessera-shell`,
`tessarchy-session`, the opt-in `tessarchy-greeter` and `tessarchy-bootsplash`. Package installation and
service activation are separate operations. The [PIN login guide](docs/phone-login.md)
covers greetd setup and the tested VM configuration. The [power-on screen guide](docs/boot-screen.md)
covers the animated Plymouth theme and quiet VM startup.

The [ISO guide](docs/iso.md) covers staging, an explicitly requested image build,
boot validation and release publication. Image files are distributed as GitHub
release assets. Generated build output stays in `build/`, `dist/` and `vm/`.

## Project map

| Path | Contents |
| --- | --- |
| `shell/` | Tessera QML, policy, helpers, icons and canonical artwork |
| `session/` | Hyprland Lua, launchers, OSK, screenshots and greeter |
| `packaging/`, `iso/` | Arch package recipes and live-image overlay |
| `scripts/`, `tests/` | Development workflows and validation |
| `assets/`, `website/` | Actual captures, roadmap and GitHub Pages source |
| `docs/` | Architecture, operating guides, roadmap and evidence |

## Roadmap, branding and sharing

The [project site](https://thediamondsaint.github.io/tessarchy/) contains eleven
real VM captures, the [device roadmap image](assets/roadmap/tessarchy-device-roadmap.png),
sharing controls and official branding downloads. The
[logo release](https://github.com/thediamondsaint/tessarchy/releases/tag/brand-kit-20261017)
includes transparent sizes, SVG, WebP, JPG, ICO, PDF and a spinning GIF.

Agents can claim one of 56 starter tasks in [AGENT-README.md](AGENT-README.md).
Local session notes belong in the ignored `.HANDOFF.local.md`. A ready-to-copy channel
update is in [docs/community-update.md](docs/community-update.md).
