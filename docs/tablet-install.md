# Intel/AMD tablet installation pilot

The tablet profile targets x86_64 Intel/AMD hardware running current Arch Linux.
It provides the Tessarchy session, firmware, desktop apps, networking, audio,
on-screen keyboard, authorization agent, portals and removable-device support.
It does not partition disks or replace an existing operating system. The published
Alpha 4 ISO is a live, nonpersistent demonstration; it is not an installer.

## Before installation

Record the tablet model and CPU, firmware boot mode, storage, display resolution,
and Wi-Fi/touch devices. Back up the existing OS and prepare its recovery media.
Have a USB keyboard and wired network adapter available for initial setup.
Use the [Arch installation guide](https://wiki.archlinux.org/title/Installation_guide)
to install Arch on the intended tablet, with its own normal user account and
password. Choose disk layout, encryption and bootloader for that device.
Mixed 32-bit UEFI/64-bit CPU tablets require a separate bootloader assessment.
ARM and Secure Boot enrollment are outside this profile.

## Build and install the session packages

A published tablet pilot includes `Tessarchy-Tablet-Pilot-Packages.tar.gz`, built
on the disposable Arch CI runner. Extract it into a new directory, verify its
`SHA256SUMS`, then follow the target-tablet install commands below. It contains
the four packages, this guide and exact source provenance; it runs no installer.


Build on an Arch development checkout as a normal user:

```bash
./scripts/check.sh
./scripts/package.sh
```

Copy the resulting packages to the tablet. On the **tablet**, update Arch and
install the four session/profile packages together (select exact build filenames):

```bash
sudo pacman -Syu
sudo pacman -U dist/tessera-shell-0.1.0-3-any.pkg.tar.zst \
  dist/tessarchy-session-0.1.0-2-any.pkg.tar.zst \
  dist/tessarchy-bootsplash-0.1.0-2-any.pkg.tar.zst \
  dist/tessarchy-tablet-0.1.0-2-x86_64.pkg.tar.zst
```

Pacman resolves the profile's repository dependencies. Nothing in these packages
formats storage, enables services, sets a password or rewrites a user's Hyprland
configuration. Do not reuse the public demo PIN for an installed account.

From the tablet's local console, select NetworkManager as its single network
manager. If networkd currently owns the connection, plan that transition locally
with a wired fallback; do not disable the only remote connection over SSH.
Enable NetworkManager and Bluetooth explicitly:

```bash
sudo systemctl enable --now NetworkManager.service ModemManager.service bluetooth.service
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
```

UPower, sensors and the power-profile service activate through D-Bus. Session
startup imports its Wayland environment, starts the available authorization agent
and NetworkManager tray/secret agent, and starts the on-screen keyboard.
Choose Tessarchy in an existing Wayland-capable display manager, or log in on a
local TTY and run `start-tessarchy`. Keep your working login/session available.
The optional four-digit prototype greeter is not installed by this profile.

## Included everyday applications

Firefox, Files (Nautilus), Text Editor, Papers, Image Viewer (Loupe), mpv,
Calculator and Foot provide the general desktop experience. Connections opens
NetworkManager's editor; Bluetooth uses Blueman for pairing. Removable media and
MTP use GVfs/udisks. LibreOffice and fwupd are optional explicit additions.
The launcher shows one installed primary application per role, plus Tessarchy's
Phone, Messages, Settings and Controls. Background helpers and duplicate browsers
are omitted. The supported alternatives are listed in `shell/AppPolicy.js`.

## Power-on video

The profile includes the `tessarchy-bootsplash` package, which converts the supplied eight-second
animation into Plymouth frames at build time. It plays once and holds the final
frame until boot completes. It preserves the full square composition and supports
password/question prompts. See [boot-screen.md](boot-screen.md) for activation.
Do not use `configure-vm-boot.py` on physical hardware: it is intentionally
restricted to QEMU and hardcodes the virtual display.

For the tablet, use its bootloader's Plymouth integration: retain the `kms` hook,
place `plymouth` before encryption hooks, select the `tessarchy` theme, add `quiet
splash` to its kernel command line, then rebuild its initramfs. Preserve existing
encryption, root and resume arguments. Keep a working fallback boot entry.
The profile does not automate these device-specific boot changes.

## Acceptance and feedback

Run `tessarchy-readiness --json` on the tablet. It reads package/service state and
changes nothing; a passing result is a package/network preflight, not hardware
certification. Then check:

- Touch each edge, drag, scroll and test multi-finger input at the chosen scaling.
- Type in browser, password, multiline and file-dialog fields; dismiss the OSK.
- Connect/reconnect Wi-Fi, pair Bluetooth and test a headset and microphone.
- Open/save files, mount a USB device and test browser downloads and document viewing.
- Check battery reporting, charging, suspend/wake and an external display.
- Test a cold boot and recovery through the fallback session/boot entry.

Send the model, CPU architecture, kernel/graphics versions, logical display size,
preflight JSON and the steps/results above. Remove serial numbers, saved network
credentials, contact data and other personal information before posting logs.
Automatic rotation, secure session locking and
model-specific firmware fixes remain separate acceptance work. Use Connections for enterprise certificates and advanced IP/profile settings,
and the device's existing orientation controls during this pilot.
