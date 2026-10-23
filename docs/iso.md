# First live ISO pipeline (experimental)

`stage-iso.sh` copies `/usr/share/archiso/configs/releng` into
`build/iso-profile`. It preserves the installed bootloader templates, hooks and
bootmode syntax rather than hardcoding a stale upstream layout. It uses the Intel/AMD tablet-pilot
package set in `iso/packages.x86_64` and stages the shell/session directly into
`/usr/share/tessarchy` and `/usr/bin`. These overlay files are not pacman-owned;
using the local packages in a signed repository is a later milestone.

The profile appends Tessarchy metadata, uses x86_64, and selects a relatively
light zstd squashfs compression. Upstream Arch boot menu branding is retained
for now. The image includes both the boot methods of the installed releng
profile; BIOS and UEFI must both be tested. It also carries `tessarchy-install`,
which copies the running live system onto an internal disk — see
[live-install.md](live-install.md).

The live user `tess` is created through systemd-sysusers with a locked password,
no sudo grant, tty1 autologin, and fish as the login shell (`fish` is added to
the package list). tmpfiles and `file_permissions` establish home ownership for
the Bash and fish login profiles; both start Tessa once on tty1 and return to
the TTY on exit. Nothing in the fish profile is needed for development installs
where Bash starts the session. No secure locking or
login protection is provided. Releng's root rescue account remains available
according to upstream defaults. SSH enablement links are removed from the
staged profile; user-mode VM NAT exposes no forwarded ports. This is a disposable
development live environment. Do not use it for sensitive work or install it as
a daily driver. Package-provided services and sockets need review before any
public release.

The staged rootfs pins the hostname to `tessarchy`, generates the en_US.UTF-8
locale, sets a live-console motd that points at `/usr/share/tessarchy/docs`
(a snapshot of `docs/` staged into the image), keeps the journal volatile with
a 64M runtime cap, and enables `systemd-timesyncd` alongside NetworkManager so guests
without a working RTC still get a sane clock. `noto-fonts-emoji` is included so
browser pages render emoji. None of this changes development installs.

## Tablet-pilot source profile

Current source expands the live image with broad Linux firmware, SOF audio
firmware, NetworkManager and its connection/secret agent, Bluetooth tools,
PipeWire audio/ALSA support, an authorization agent, portals and common apps.
The preloaded app suite covers browser, terminal, files, editor, calculator,
documents, images, media, archives and office work.
Only NetworkManager manages the live network; inherited networkd/resolved
activation links are removed and DNS points at NetworkManager's resolver file.
The supplied power-on video is converted to Plymouth frames during staging.
The profile keeps early KMS and adds Plymouth after it in the initramfs hooks.

Use [tablet-install.md](tablet-install.md) to install the packages on an existing
Arch tablet, or [live-install.md](live-install.md) to install from this image
onto a blank disk.
Alpha 4 contains this live profile; earlier alphas remain available as historical
releases.

## Alpha 4 tester ISO — 2026-10-18

[Download Alpha 4](https://github.com/thediamondsaint/tessarchy/releases/tag/v0.1.0-alpha.4).
Actions run [39144935780](https://github.com/thediamondsaint/tessarchy/actions/runs/39144935780)
built source `0f71636a0aecb20cd76359a71d2e911eb082cb57` with archiso 91-1.
Both diskless BIOS and non-Secure-Boot UEFI boots reached Tessa and the curated
launcher; no NIC was present. It carries Alpha 3 plus the desktop tray-icon fix,
on-screen keys at the 48 px height floor, five-minute idle blanking, the
notification center, display rotation, the Desktop-mode keyboard suppression and
the Tessy workflow. The desktop taskbar postdates this image.
Physical tablet and installed-disk acceptance remain pending.

`tessarchy-0.1.0-20261018-x86_64.iso` is 2,111,864,832 bytes. SHA-256:
`8cae59e93b1043699fc5d568b5fb7bccb1ae71288703a358c874ded4ec636b03`.

## Alpha 3 Intel/AMD tablet pilot — 2026-10-18

[Download Alpha 3](https://github.com/thediamondsaint/tessarchy/releases/tag/v0.1.0-alpha.3).
Actions run [39127243527](https://github.com/thediamondsaint/tessarchy/actions/runs/39127243527)
built source `566a4385432697ffbb21147355476bed5727d9f5` with archiso 91-1.
Both diskless BIOS and non-Secure-Boot UEFI boots reached Tessa without a NIC;
the supplied animation and curated launcher were inspected in the captures.
A blank interval remains between the animation and desktop during boot.
Physical tablet and installed-disk acceptance remain pending.

`tessarchy-0.1.0-20261018-x86_64.iso` is 2,111,864,832 bytes. SHA-256:

```text
7e7f5267e096d7d3f0e1340835fd49ff4a59551e7ecca3a91efb18449f34cf38
```

The release includes build metadata, package list, checksums and boot evidence.
Its separate `Tessarchy-Tablet-Pilot-Packages.tar.gz` is for an existing Arch
x86_64 installation and records its own later source revision in `SOURCE.json`.
Follow [tablet-install.md](tablet-install.md), or boot the live image and run
`tessarchy-install --check` to see whether the machine is a good fit.

## Build explicitly on Arch

```bash
sudo pacman -S --needed archiso
./scripts/check.sh
./scripts/stage-iso.sh
# Review build/iso-profile/profiledef.sh and airootfs before building.
./scripts/build-iso.sh
./scripts/vm.sh run dist/<actual-ISO-filename>.iso
VM_UEFI=1 ./scripts/vm.sh run dist/<actual-ISO-filename>.iso
```

Prerequisites: internet, a consistent current Arch installation, administrator
access for mkarchiso, and roughly 15–25GiB free disk. More than 2GiB memory is
recommended for building. Staging also needs Python and FFmpeg for the animation. `archiso` pulls in its own auxiliary tools, and
`iso/packages.x86_64` includes `memtest86+`, whose EFI payload needs `mtools`
on the build host. Hyprland's system-wide dependencies are resolved by pacman;
shell-level guesses (`wlogout`, extras) are intentionally absent. ISO builds are not bit-reproducible yet: repository
versions and date metadata change. Record `pacman -Q archiso`, build log and
`build/iso-work/iso/arch/pkglist.x86_64.txt` if generated
by your archiso version. No automatic system upgrades occur.

Staging refuses to overwrite its destination. For a fresh build, stop the VM,
check `findmnt` for any remaining mkarchiso mounts after a failed build, and
remove only `build/iso-profile` and `build/iso-work` after mounts are released.
The latter may require sudo because mkarchiso owns it. Scripts never recursively
clean a privileged build directory themselves.

## Alpha 1 tester prerelease, 2026-10-17 UTC

[Alpha 1](https://github.com/thediamondsaint/tessarchy/releases/tag/v0.1.0-alpha.1)
contains the approximately 1 GiB `tessarchy-0.1.0-20261017-x86_64.iso`, checksum,
package manifest, build log, source provenance and BIOS/UEFI boot evidence.
The ISO is a Release asset; disk images remain excluded from Git history.

GitHub Actions run [38997819650](https://github.com/thediamondsaint/tessarchy/actions/runs/38997819650)
built the image with archiso 91-1 from commit
`90c5eee58f8be68ae9b9a670c3479f0ff453449b`. The checksum passed in CI and matches
the GitHub asset digest. The agent inspected final captures of both diskless
BIOS and non-Secure-Boot UEFI QEMU/KVM boots: Tessa's GUI was running after
live-user autologin. These used 2 GiB RAM, 2 vCPUs and virtio graphics.

To create a new tester draft, dispatch `Build Tessarchy ISO` on the desired
branch and supply a new `release_tag`. It builds, verifies the checksum,
collects BIOS/UEFI screenshots, and creates a draft prerelease. KVM is used when
available; software emulation gets a longer capture window. **Inspect the actual
captures before publishing or claiming graphical boot success.** The capture
script deliberately does not infer GUI success from a running QEMU process.

Application/device acceptance, networking/audio, touch, physical hardware,
Secure Boot and persistence behavior were not tested in this exact image.
Read the attached `BOOT-TESTING.md` and [validation record](testing.md).

## Alpha 2 tester prerelease, 2026-10-17 UTC

[Alpha 2](https://github.com/thediamondsaint/tessarchy/releases/tag/v0.1.0-alpha.2)
updates the live image with Quiet Edge, the card switcher, mobile clock,
pull-down radio controls, and the pull-down layout selector. It was built from
`aa8b59a73a8d5d6b1d3fab6c17272e68e0bfac58` by
[Actions run 39063437439](https://github.com/thediamondsaint/tessarchy/actions/runs/39063437439)
using archiso 91-1. The image contains Hyprland 0.56.2-4 and Quickshell 0.3.2-1.
Source API targets remain Hyprland 0.56 and Quickshell 0.3.1.

The release ISO is `tessarchy-0.1.0-20261017-x86_64.iso` (1,070,628,864 bytes).
Alpha 1 uses the same date-based filename; select the release tag and verify
the checksum to distinguish images. Alpha 2 SHA-256:

```text
3bc2565684d9a2a1de62946f6f7d59117dafc71abf75d226be14b5214d9209ee
```

The checksum passed in CI and matches the release asset digest. Both final
BIOS and non-Secure-Boot UEFI captures were inspected: Tessa reached its
graphical home screen with the current glass status bar and floating dock.
The disposable QEMU/KVM guests had 2 GiB RAM, 2 vCPUs, virtio graphics, no
guest disk and no network adapter. Boot screenshots, capture commands, package
manifest, source provenance and build log accompany the image.

These are graphical boot smoke tests, not full application or device acceptance.
Physical touch, real radio changes, networking, audio, Secure Boot and phone
hardware remain unverified in this ISO. Contributor pull requests were left
unchanged and are not included; see the [GitHub review](github-review.md).
