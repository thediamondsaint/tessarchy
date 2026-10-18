# First live ISO pipeline (experimental)

`stage-iso.sh` copies `/usr/share/archiso/configs/releng` into
`build/iso-profile`. It preserves the installed bootloader templates, hooks and
bootmode syntax rather than hardcoding a stale upstream layout. It uses the VM-focused
package set in `iso/packages.x86_64` and stages the shell/session directly into
`/usr/share/tessarchy` and `/usr/bin`. These overlay files are not pacman-owned;
using the local packages in a signed repository is a later milestone.

The profile appends Tessarchy metadata, uses x86_64, and selects a relatively
light zstd squashfs compression. Upstream Arch boot menu branding is retained
for now. The image includes both the boot methods of the installed releng
profile; BIOS and UEFI must both be tested. It does not install onto a disk.

The live user `tess` is created through systemd-sysusers with a locked password,
no sudo grant, tty1 autologin, and fish as the login shell (`fish` is added to
the package list). tmpfiles and `file_permissions` establish home ownership for
the Bash and fish login profiles; both start Tessera once on tty1 and return to
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
a 64M runtime cap, and enables `systemd-timesyncd` alongside NetworkManager so
guests without a working RTC still get a sane clock and Wi-Fi works through the
shell's quick controls (`networkmanager` and `wpa_supplicant` are packaged). `noto-fonts-emoji` is included so
browser pages render emoji. None of this changes development installs.

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
recommended for building. `archiso` pulls in its own auxiliary tools, and
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
BIOS and non-Secure-Boot UEFI QEMU/KVM boots: Tessera's GUI was running after
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
BIOS and non-Secure-Boot UEFI captures were inspected: Tessera reached its
graphical home screen with the current glass status bar and floating dock.
The disposable QEMU/KVM guests had 2 GiB RAM, 2 vCPUs, virtio graphics, no
guest disk and no network adapter. Boot screenshots, capture commands, package
manifest, source provenance and build log accompany the image.

These are graphical boot smoke tests, not full application or device acceptance.
Physical touch, real radio changes, networking, audio, Secure Boot and phone
hardware remain unverified in this ISO. Contributor pull requests were left
unchanged and are not included; see the [GitHub review](github-review.md).
