#!/usr/bin/env bash
# Assemble a compact network installer from ArchISO's stock boot profile.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
base=${ARCHISO_RELENG:-/usr/share/archiso/configs/releng}
profile=$root/build/netinstall-profile
[[ -f $base/profiledef.sh ]] || { echo "Missing releng profile: install archiso explicitly first" >&2; exit 1; }
[[ ! -e $profile ]] || { echo "Move/remove $profile before staging a fresh profile" >&2; exit 1; }
mkdir -p "$root/build"
cp -a -- "$base" "$profile"
sort -u "$root/iso/packages.netinstall.x86_64" > "$profile/packages.x86_64"
cat >> "$profile/profiledef.sh" <<'PROFILE'

iso_name="tessarchy-netinstall"
iso_label="TESSA_NET_$(date +%Y%m)"
iso_publisher="Tessarchy"
iso_application="Tessarchy network installer"
iso_version="0.1.0-$(date +%Y%m%d)"
arch="x86_64"
kernel_params_x86_64="quiet loglevel=3 systemd.show_status=false"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-Xdict-size' '100%' '-b' '1M')
file_permissions+=(
  ["/etc/systemd/system/getty@tty1.service.d/autologin.conf"]="0:0:644"
  ["/root/.bash_profile"]="0:0:644"
  ["/usr/bin/tessarchy-netinstall"]="0:0:755"
  ["/etc/pacman.d/tessarchy.conf"]="0:0:644"
)
PROFILE
airoot=$profile/airootfs
mkdir -p "$airoot/usr/bin" "$airoot/etc/pacman.d" \
    "$airoot/etc/systemd/system/multi-user.target.wants"
install -Dm755 "$root/session/tessarchy-netinstall" "$airoot/usr/bin/tessarchy-netinstall"
cp -a "$root/iso/netinstall/airootfs/." "$airoot/"
sed -i 's|^\(root:[^:]*:0:0:[^:]*:[^:]*:\).*|\1/usr/bin/bash|' "$airoot/etc/passwd"
mkdir -p "$airoot/etc/systemd/system/multi-user.target.wants"
find "$airoot/etc/systemd/system" -type l \( -name 'systemd-networkd*' -o -name 'systemd-resolved*' -o -name 'iwd.service' -o -name 'sshd.service' \) -delete
rm -f "$airoot/etc/systemd/system/sysinit.target.wants/systemd-time-wait-sync.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$airoot/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sf /run/NetworkManager/resolv.conf "$airoot/etc/resolv.conf"
install -m644 "$root/iso/airootfs/etc/pacman.d/tessarchy.conf" "$airoot/etc/pacman.d/tessarchy.conf"
pacman_conf=${PACMAN_CONF:-/etc/pacman.conf}
if [[ -f $pacman_conf ]]; then
    install -Dm644 "$pacman_conf" "$airoot/etc/pacman.conf"
    if ! grep -q 'pacman.d/tessarchy.conf' "$airoot/etc/pacman.conf"; then
        cat >> "$airoot/etc/pacman.conf" <<'PACMAN'

# Tessarchy packages (netinstall target and updates)
Include = /etc/pacman.d/tessarchy.conf
PACMAN
    fi
else
    echo "stage-netinstall: /etc/pacman.conf is required to build the installer" >&2
    exit 1
fi
if [[ -n ${TESSARCHY_REPO_URL:-} ]]; then
    sed -i "s|^Server = .*|Server = ${TESSARCHY_REPO_URL%/}/\$arch|" \
        "$airoot/etc/pacman.d/tessarchy.conf"
fi
rm -f "$profile"/syslinux/archiso_head.cfg \
      "$profile"/syslinux/archiso_sys.cfg \
      "$profile"/syslinux/archiso_sys-linux.cfg \
      "$profile"/syslinux/archiso_tail.cfg \
      "$profile"/syslinux/archiso_pxe-linux.cfg \
      "$profile"/syslinux/splash.png \
      "$profile"/syslinux/hdt.c32
rm -rf -- "$profile/syslinux/hdt"
rm -f "$profile"/grub/loopback.cfg "$profile"/efiboot/loader/loader.conf
find "$profile/efiboot/loader/entries" -name '*.conf' -delete
cp -a -- "$root/iso/boot/." "$profile/"
rm -f "$profile/efiboot/loader/entries/01-tessarchy-linux.conf" \
      "$profile/efiboot/loader/entries/02-tessarchy-speech-linux.conf" \
      "$profile/efiboot/loader/entries/03-memtest86+x64.conf"
cp -a -- "$root/iso/netinstall/boot/." "$profile/"
printf '%s\n' "Tessarchy network installer — connects to Arch and Tessarchy repositories to install onto a selected disk." > "$airoot/etc/issue"
echo "Netinstall profile staged: $profile"
echo "Review it, then run ./scripts/build-netinstall-iso.sh"
