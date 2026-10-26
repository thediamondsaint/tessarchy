# Tessarchy power-on screen

Tessarchy's Plymouth theme uses the supplied eight-second power-on video.
The original 1080×1080 MP4 is retained in `session/boot/power-on.mp4`; packaging
exports 160 square 480×480 frames at 20 fps. Playback runs once and holds the
final frame until boot completes. The full composition fits portrait and landscape
displays. Frames are loaded as needed rather than preloading a scaled image array.

## Startup path

1. GRUB selects the normal boot entry with a hidden one-second menu.
2. Early virtio GPU support provides the VM framebuffer.
3. Plymouth displays the animated Tessarchy mark during system startup.
4. The retained splash hands off to greetd on the same graphical VT.
5. Session and compositor output goes to the journal instead of the display.

The greeter supplies a system `PATH` because profile loading is disabled. This
lets Hyprland find its installed dialog utilities during startup. The default
compositor slogan is disabled in both session configurations.

The theme includes graphical password and question prompts. Normal service text
stays in logs. Console recovery remains available through the other VTs.

## Source and packaging

- `session/boot/`: Plymouth script, theme descriptor, daemon config and retained-splash unit override.
- `scripts/export-boot-assets.py`: converts the supplied video with FFmpeg and records its source checksum.
- `packaging/tessarchy-bootsplash/PKGBUILD`: builds the theme package.
- `scripts/configure-vm-boot.py`: plans or applies the QEMU/KVM boot configuration.
- `session/start-tessarchy`: journals compositor/session output.
- `session/greetd/`: coordinated VT and journal routing for the greeter.

Build assets into a new directory:

```bash
python3 scripts/export-boot-assets.py --output build/boot-theme-review
python3 scripts/configure-vm-boot.py
```

`scripts/package.sh` builds the optional bootsplash package alongside the shell,
session, greeter and tablet profile. Its build tools are Python and FFmpeg; runtime uses Plymouth
and DejaVu fonts. Installation and boot activation are explicit operations.

## Physical tablet activation

Use the [Intel/AMD tablet guide](tablet-install.md). Install the optional splash
package on the target tablet, select the `tessarchy` theme, preserve KMS and the
existing root/encryption/resume arguments, and integrate Plymouth using that
device's bootloader and initramfs configuration. The VM helper below deliberately
does not support physical hardware. The live-image profile stages the frames and
adds Plymouth after KMS without applying VM-specific resolution arguments.

## Supplied preview and validation

The site hosts the original silent MP4 and a poster extracted from it. This is an
animation preview, not a recorded boot. Source checksum and conversion metadata
are in `assets/boot/power-on-video.json`. Frame export and package builds are
validated separately from actual boot behavior in [testing.md](testing.md).
The existing development VM has not been changed for this update.

## VM activation

After the packages and generated theme are installed in the VM:

```bash
sudo python3 scripts/configure-vm-boot.py --apply
```

The helper verifies the VM and expected boot layout, refuses unrelated managed
files, saves the previous initramfs/GRUB configuration, adds namespaced drop-ins,
rebuilds the initramfs, validates the generated GRUB file and installs it atomically.
It preserves kernel arguments and removes only normal loader progress messages.
The selected VM mode is 400x800 on the virtual output.

Boot backups are under `/var/lib/tessarchy/boot-backups/`. Reapply after changing
the kernel or bootloader configuration to regenerate the managed boot files.

## Inspection

```bash
systemctl --failed
journalctl -b -t tessarchy-session
journalctl -b -t tessarchy-greeter
journalctl -b -u greetd
```

The initial audit found no failed services. A previous Xwayland abort coincided
with a manual greetd restart; no later instance was present in the core list.
The VM also reported a missing regulatory database. Current VM test results and
screenshots are recorded in [testing.md](testing.md).

## References

- [Arch Plymouth integration](https://wiki.archlinux.org/title/Plymouth)
- [Arch silent boot controls](https://wiki.archlinux.org/title/Silent_boot)
- [greetd terminal configuration](https://man.archlinux.org/man/greetd.5.en)

## Earlier VM startup recording

- [Actual VM startup MP4](https://github.com/thediamondsaint/tessarchy/releases/download/brand-kit-20261017/Tessarchy-Boot-Preview.mp4): 400x800, 35 seconds.
- [Discord-ready startup GIF](https://github.com/thediamondsaint/tessarchy/releases/download/brand-kit-20261017/Tessarchy-Boot-Preview.gif): 320x640, 14.6 seconds.

These recordings show the earlier 64-frame turntable theme. The MP4 starts when Plymouth appears and continues through the PIN screen. The
GIF shortens the idle transition. Both use actual VM frames. Firmware and GRUB
run before this excerpt; their remaining text is tracked separately from Linux
service output. Capture provenance is in assets/boot/.
