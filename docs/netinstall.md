# Tessarchy network installer

The netinstall image contains ArchISO startup, the Linux kernel, common Wi-Fi
firmware, network tools, disk utilities, package download support, and the
guided installer. Wi-Fi firmware covers Intel, Atheros, Broadcom, MediaTek,
and Realtek devices. The Tessa desktop and its applications are fetched after
the computer joins a network. The ISO target is below 1 GiB so it stays a
single easy download; the hard GitHub Releases per-file limit is 2 GiB.

The alpha installer targets x86_64 UEFI computers with EFI variables enabled
and a 24 GiB or larger install disk. It supports wired networking and Wi-Fi
through NetworkManager. Wi-Fi can be joined from the installer with `nmtui`.
The selected disk is erased after typing its displayed `ERASE /dev/...`
confirmation. The installer creates a 1 GiB EFI system partition and an ext4
system partition, installs the Tessarchy tablet package profile, configures
the account, time zone and UEFI GRUB, then restarts.

After signing in with the password selected in the installer, Tessa opens a
first-run flow for the theme and accent color. The same choices remain
available later in Tessa Settings. The installer asks for the account only
once; first run does not ask for the password again.

## Build

On Arch Linux with `archiso` installed:

```sh
./scripts/stage-netinstall.sh
./scripts/build-netinstall-iso.sh
```

The profile and build workspace are under ignored `build/`; the ISO and
SHA-256 file are under ignored `dist/`. The build wrapper stops if the ISO is
larger than 1 GiB. GitHub Actions builds the same profile for pull requests and
manual dispatches, then captures diskless BIOS and UEFI QEMU boots in the build
artifact. Review those screenshots; capture completion alone does not prove a
successful boot.

## VM install check

Use a disposable VM with UEFI firmware, at least 4 GiB RAM, a 24 GiB blank
virtual disk and a working NAT connection. Do not attach a host disk. At the
disk confirmation screen, verify that the VM disk path is shown before
continuing. After setup, remove the ISO and confirm that GRUB starts the
installed system and that the account can sign in and reach Tessa's first-run
theme and accent screens.
