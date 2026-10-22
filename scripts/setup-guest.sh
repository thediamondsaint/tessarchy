#!/usr/bin/env bash
# Run inside the basic Arch guest. Dependency installation is a separate step.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ $EUID != 0 ]] || { echo "Run as the guest's normal user, not root" >&2; exit 1; }
[[ ${1:-} == "" || ${1:-} == --autostart ]] || { echo "Usage: $0 [--autostart]" >&2; exit 2; }
# Reject the Omarchy host even when the host itself is virtualized.
# shellcheck source=/dev/null
source /etc/os-release
[[ ${ID:-} == arch || ${ID:-} == archarm ]] || { echo "This setup is for the Arch guest, not the host" >&2; exit 1; }
virt=$(systemd-detect-virt --vm || true)
case "$virt" in qemu|kvm) ;; *) echo "Expected a QEMU/KVM guest; detected: ${virt:-none}" >&2; exit 1;; esac
missing=()
for tool in Hyprland qs chromium foot python ffmpeg ffplay ssh sshd; do
    command -v "$tool" >/dev/null || missing+=("$tool")
done
if ((${#missing[@]})); then
    printf 'Missing guest dependencies: %s\n' "${missing[*]}" >&2
    echo "Inside the guest, install explicitly:" >&2
    echo "sudo pacman -Syu --needed openssh hyprland quickshell chromium foot mesa qt6-declarative qt6-wayland ttf-dejavu python python-gobject ffmpeg" >&2
    exit 1
fi
"$root/scripts/check.sh"
"$root/scripts/install-dev.sh"
if [[ ${1:-} == --autostart ]]; then "$root/scripts/login-session.sh" enable; fi
echo "Tessarchy installed. Start now: ~/.local/bin/start-tessarchy"
