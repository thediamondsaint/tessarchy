#!/usr/bin/env bash
# Assemble a profile without root. Never edit /usr/share/archiso.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
base=${ARCHISO_RELENG:-/usr/share/archiso/configs/releng}
profile=$root/build/iso-profile
[[ -f "$base/profiledef.sh" ]] || { echo "Missing releng profile: install archiso explicitly first" >&2; exit 1; }
[[ ! -e "$profile" ]] || { echo "Move/remove $profile before staging a fresh profile" >&2; exit 1; }
mkdir -p "$root/build"
cp -a -- "$base" "$profile"
# Keep releng's boot machinery, but deliberately replace its rescue-tool suite.
# Include the firmware and desktop services needed by Intel/AMD tablet testing.
sort -u "$root/iso/packages.x86_64" > "$profile/packages.x86_64"
# Keep the installed releng bootloader layout, mkinitcpio hooks and permissions.
cat >> "$profile/profiledef.sh" <<'PROFILE'

# Tessarchy overrides: stock releng boot placeholders and install_dir retained.
iso_name="tessarchy"
iso_label="TESSARCHY_$(date +%Y%m)"
iso_publisher="Tessarchy"
iso_application="Tessarchy live image"
iso_version="0.1.0-$(date +%Y%m%d)"
arch="x86_64"
kernel_params_x86_64="quiet splash loglevel=3 systemd.show_status=false"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '3' '-b' '1M')
file_permissions+=(
  ["/etc/shadow"]="0:0:400"
  ["/home/tess"]="1000:1000:750"
  ["/home/tess/.bash_profile"]="1000:1000:644"
  ["/home/tess/.config/fish/config.fish"]="1000:1000:644"
  ["/usr/bin/tessarchy-install"]="0:0:755"
  ["/usr/bin/tessarchy-install-ui"]="0:0:755"
  ["/etc/sudoers.d/tessarchy-install"]="0:0:440"
  ["/etc/sudoers.d/tessarchy-update"]="0:0:440"
  ["/etc/tessarchy/version"]="0:0:644"
  ["/etc/pacman.d/tessarchy.conf"]="0:0:644"
  ["/usr/bin/tessarchy-update"]="0:0:755"
  ["/usr/bin/tessera-update-notify"]="0:0:755"
  ["/usr/bin/start-tessarchy"]="0:0:755"
  ["/usr/bin/tessera-shell"]="0:0:755"
  ["/usr/bin/tessarchy-osk"]="0:0:755"
  ["/usr/bin/tessera-screenshot"]="0:0:755"
  ["/usr/bin/tessarchy-session-services"]="0:0:755"
  ["/usr/bin/tessarchy-readiness"]="0:0:755"
  ["/usr/bin/tessera-brightness"]="0:0:755"
  ["/usr/bin/tessera-nightlight"]="0:0:755"
  ["/usr/bin/tessera-rotate"]="0:0:755"
  ["/usr/bin/tessarchy-autorotate"]="0:0:755"
  ["/usr/bin/tessarchy-theme"]="0:0:755"
  ["/usr/bin/tessarchy-run"]="0:0:755"
)
PROFILE
# Replace releng's Arch-branded boot menus with Tessarchy's. Anything NOT
# overridden here is copied from releng and ships as Arch branding — which is
# how "Arch Linux install medium", Arch's menu splash and the HDT entry kept
# reaching the medium. The override tree mirrors the profile layout
# (syslinux/, grub/, efiboot/), and its files keep the %INSTALL_DIR% / %ARCH%
# / %ARCHISO_UUID% / %KERNEL_PARAMS% tokens mkarchiso substitutes.
rm -f "$profile"/syslinux/archiso_head.cfg \
      "$profile"/syslinux/archiso_sys.cfg \
      "$profile"/syslinux/archiso_sys-linux.cfg \
      "$profile"/syslinux/archiso_tail.cfg \
      "$profile"/syslinux/archiso_pxe-linux.cfg \
      "$profile"/syslinux/splash.png \
      "$profile"/syslinux/hdt.c32
rm -rf -- "$profile/syslinux/hdt"
rm -f "$profile"/grub/loopback.cfg \
      "$profile"/efiboot/loader/loader.conf
find "$profile/efiboot/loader/entries" -name '*.conf' -delete
cp -a -- "$root/iso/boot/." "$profile/"
airoot=$profile/airootfs
mkdir -p "$airoot/usr/share/tessarchy/session" "$airoot/usr/bin" "$airoot/usr/share/wayland-sessions"
cp -R -- "$root/shell" "$root/themes" "$airoot/usr/share/tessarchy/"
find "$airoot/usr/share/tessarchy/shell" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete
find "$airoot/usr/share/tessarchy/shell" -depth -type d -name __pycache__ -empty -delete
cp -R -- "$root/docs" "$airoot/usr/share/tessarchy/"
cp -- "$root/session/hyprland.lua" "$root/session/window-controls.lua" "$root/session/hypridle.conf" "$airoot/usr/share/tessarchy/session/"
cp -R -- "$root/session/osk" "$airoot/usr/share/tessarchy/session/"
install -m755 "$root/session/tessarchy-install" "$root/session/tessarchy-install-ui" "$airoot/usr/bin/"
install -m755 "$root/session/start-tessarchy" "$root/session/tessera-shell" "$root/session/tessarchy-osk" "$root/session/tessarchy-theme" "$root/session/tessarchy-run" "$root/session/tessera-screenshot" "$root/session/tessera-brightness" "$root/session/tessera-nightlight" "$root/session/tessera-rotate" "$root/session/tessarchy-autorotate" "$root/session/tessarchy-session-services" "$root/session/tessarchy-readiness" "$airoot/usr/bin/"
install -m755 "$root/session/tessarchy-update" "$root/session/tessera-update-notify" "$airoot/usr/bin/"
install -m644 "$root/session/tessarchy.desktop" "$airoot/usr/share/wayland-sessions/"
install -Dm644 "$root/session/tessera-shell.service" "$airoot/usr/lib/systemd/user/tessera-shell.service"
# File dialogs (compiled here: needs gcc, make, pkgconf and gtk3 headers).
make -s -C "$root/portal" O="$root/build/portal" DESTDIR="$airoot" PREFIX=/usr install
cp -a "$root/iso/airootfs/." "$airoot/"
# A mirror, a lab or a CI job can point the medium — and every machine installed
# from it — at another repository, without editing a tracked file:
#   TESSARCHY_REPO_URL=http://mirror.test/pkgs ./scripts/stage-iso.sh
if [[ -n ${TESSARCHY_REPO_URL:-} ]]; then
    sed -i "s|^Server = .*|Server = ${TESSARCHY_REPO_URL%/}/\$arch|" \
        "$airoot/etc/pacman.d/tessarchy.conf"
fi
# Convert the supplied clip for initramfs playback; no video decoder runs at boot.
theme=$airoot/usr/share/plymouth/themes/tessarchy
python3 "$root/scripts/export-boot-assets.py" --output "$theme"
install -m644 "$root/session/boot/tessarchy.plymouth" "$root/session/boot/tessarchy.script" "$theme/"
install -Dm644 "$root/session/boot/plymouthd.conf" "$airoot/etc/plymouth/plymouthd.conf"
install -Dm644 "$root/session/boot/retain-splash.conf" "$airoot/etc/systemd/system/plymouth-quit.service.d/tessarchy.conf"
mkdir -p "$airoot/etc/mkinitcpio.conf.d"
cat > "$airoot/etc/mkinitcpio.conf.d/zz-tessarchy-plymouth.conf" <<'HOOKS'
# Keep releng hooks and add graphical startup immediately after KMS.
if [[ ! " ${HOOKS[*]} " == *" plymouth "* ]]; then
    tessarchy_boot_hooks=()
    for tessarchy_boot_hook in "${HOOKS[@]}"; do
        tessarchy_boot_hooks+=("$tessarchy_boot_hook")
        if [[ $tessarchy_boot_hook == kms ]]; then tessarchy_boot_hooks+=(plymouth); fi
    done
    HOOKS=("${tessarchy_boot_hooks[@]}")
    unset tessarchy_boot_hook tessarchy_boot_hooks
fi
HOOKS
# Releng uses zsh for its root rescue login. Our smaller package set uses Bash.
sed -i 's|^\(root:[^:]*:0:0:[^:]*:[^:]*:\).*|\1/usr/bin/bash|' "$airoot/etc/passwd"
# Create the live user via systemd-sysusers, preserving base account databases.
# The home scaffolding comes from the skel tree: Bash and fish login profiles.
mkdir -p "$airoot/home/tess"
cp -a "$root/iso/airootfs/etc/skel/." "$airoot/home/tess/"
# Releng may enable SSH for rescue. Keep network services out of this prototype.
find "$airoot/etc/systemd/system" -type l -name 'sshd.service' -delete
# Releng waits for an NTP sync before sysinit completes. On a machine with no
# network and no battery-backed clock that wait never ends (systemd reports
# "no limit"), so the live image must not gate its boot on time sync.
rm -f "$airoot/etc/systemd/system/sysinit.target.wants/systemd-time-wait-sync.service"
mkdir -p "$airoot/etc/systemd/system/multi-user.target.wants"
# Use one network manager; remove inherited releng wired-only activation links.
find "$airoot/etc/systemd/system" -type l \( -name 'systemd-networkd*' -o -name 'systemd-resolved*' -o -name 'iwd.service' \) -delete
ln -sf /usr/lib/systemd/system/NetworkManager.service "$airoot/etc/systemd/system/multi-user.target.wants/"
ln -sf /usr/lib/systemd/system/bluetooth.service "$airoot/etc/systemd/system/multi-user.target.wants/"
ln -sf /usr/lib/systemd/system/systemd-timesyncd.service "$airoot/etc/systemd/system/multi-user.target.wants/"
ln -sf /usr/lib/systemd/system/ModemManager.service "$airoot/etc/systemd/system/multi-user.target.wants/"
ln -sf /run/NetworkManager/resolv.conf "$airoot/etc/resolv.conf"
# ---------------------------------------------------------------- self-update
# An installed machine updates from the project's package repository instead of
# a new ISO. Three things have to be in place before it can.
release_version="0.1.0-$(date +%Y%m%d)"
# 1. The repository in pacman's configuration. Arch's own file is copied in and
#    an Include appended, so the base configuration stays stock and updating
#    Tessarchy's copy of it is just another package.
if [[ -f /etc/pacman.conf ]]; then
    install -Dm644 /etc/pacman.conf "$airoot/etc/pacman.conf"
    if ! grep -q 'pacman.d/tessarchy.conf' "$airoot/etc/pacman.conf"; then
        cat >> "$airoot/etc/pacman.conf" <<'PACMAN'

# Tessarchy packages (see /etc/pacman.d/tessarchy.conf)
Include = /etc/pacman.d/tessarchy.conf
PACMAN
    fi
else
    echo "stage-iso: no /etc/pacman.conf here; the installed system will need tessarchy-update --enable-repo" >&2
fi
# 2. Which medium this is, so the installed system can say what it started from.
install -d "$airoot/etc/tessarchy"
printf '%s\n' "$release_version" > "$airoot/etc/tessarchy/version"
# 3. The packages themselves, so the installer can hand them to pacman and the
#    machine is package-managed from its first boot. Same packages the repo
#    serves, which is what makes a later update a download rather than an install.
packages_dir="$root/dist/repo/${TESSARCHY_ARCH:-x86_64}"
if compgen -G "$packages_dir/*.pkg.tar.zst" >/dev/null; then
    install -d "$airoot/usr/share/tessarchy/pkgs"
    cp "$packages_dir"/*.pkg.tar.zst "$airoot/usr/share/tessarchy/pkgs/"
else
    echo "stage-iso: no packages in $packages_dir — run ./scripts/build-packages.sh first" >&2
    exit 1
fi
# Look for updates once a day (system timer) and say so on the user's desktop
# (user timer, enabled through the skel tree the live user's home is built from).
install -d "$airoot/etc/systemd/system/timers.target.wants"
ln -sf /usr/lib/systemd/system/tessarchy-update-check.timer \
    "$airoot/etc/systemd/system/timers.target.wants/tessarchy-update-check.timer"
install -d "$airoot/home/tess/.config/systemd/user/timers.target.wants"
ln -sf ../tessarchy-update-notify.timer \
    "$airoot/home/tess/.config/systemd/user/timers.target.wants/tessarchy-update-notify.timer"
# Keep iso_version in the profile and /etc/tessarchy/version identical.
sed -i "s|^iso_version=.*|iso_version=\"$release_version\"|" "$profile/profiledef.sh"
printf '%b' '\n  \033[1;36mTESSARCHY\033[0m live image — nothing is saved, and the Tessera session starts on tty1 as "tess".\n  Copy it onto a disk with \033[1;36mtessarchy-install\033[0m. Root rescue login stays on this console.\n\n' > "$airoot/etc/issue"
echo "Profile staged: $profile"
echo "Review it, then run ./scripts/build-iso.sh"
