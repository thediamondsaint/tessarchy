#!/usr/bin/env bash
# Boot the aarch64 development disk on QEMU's virt machine; no root access or bridge.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
usage() { echo "Usage: $0 run | plan"; }
operation=${1:-help}
case "$operation" in run|plan) ;; *) usage; exit 2;; esac
vm=$root/vm/aarch64
disk=$vm/rootfs.img
kernel=$vm/Image
initrd=$vm/initramfs-linux.img
for file in "$disk" "$kernel" "$initrd"; do
    [[ -f "$file" ]] || { echo "Missing $file; run ./scripts/build-aarch64-disk.sh first" >&2; exit 1; }
done
# qemu -drive uses comma-separated options. Reject ambiguous path names.
[[ "$vm" != *,* ]] || { echo "VM paths must not contain commas" >&2; exit 1; }
# Boot the kernel installed on the disk so guest kernel upgrades take effect.
if [[ $operation == run ]] && command -v debugfs >/dev/null; then
    for file in Image initramfs-linux.img; do
        debugfs -R "dump -p /boot/$file $vm/.$file.new" "$disk" 2>/dev/null
        if [[ -s "$vm/.$file.new" ]]; then mv -- "$vm/.$file.new" "$vm/$file"; else rm -f -- "$vm/.$file.new"; fi
    done
fi
# x86_64 hosts emulate aarch64; KVM applies only on an aarch64 host.
accel=${VM_ACCEL:-auto}
if [[ $accel == auto ]]; then
    if [[ $(uname -m) == aarch64 && -r /dev/kvm && -w /dev/kvm ]]; then accel=kvm; else accel=tcg; fi
fi
case "$accel" in kvm) cpu=host;; tcg) cpu=max;; *) echo "VM_ACCEL must be auto, kvm or tcg" >&2; exit 2;; esac
[[ ${VM_RAM:-4096} =~ ^[1-9][0-9]*$ ]] || { echo "VM_RAM must be a number of MiB" >&2; exit 2; }
[[ ${VM_CPUS:-4} =~ ^[1-9][0-9]?$ ]] || { echo "VM_CPUS must be a CPU count" >&2; exit 2; }
network=user,id=net0
if [[ -n ${VM_SSH_PORT:-} ]]; then
    if [[ ! $VM_SSH_PORT =~ ^[1-9][0-9]{3,4}$ ]] || ((VM_SSH_PORT < 1024 || VM_SSH_PORT > 65535)); then
        echo "VM_SSH_PORT must be a port between 1024 and 65535" >&2; exit 2
    fi
    network+=",hostfwd=tcp:127.0.0.1:$VM_SSH_PORT-:22"
fi
display=${VM_DISPLAY:-gtk}
[[ $display =~ ^(gtk|sdl|none|vnc=[0-9.]+:[0-9]{1,2})$ ]] || { echo "VM_DISPLAY must be gtk, sdl, none or vnc=ADDRESS:DISPLAY" >&2; exit 2; }
cmd=(qemu-system-aarch64 -name "Tessarchy aarch64" -machine virt -accel "$accel" -cpu "$cpu"
    -m "${VM_RAM:-4096}" -smp "${VM_CPUS:-4}"
    -kernel "$kernel" -initrd "$initrd"
    -append "root=/dev/vda rw console=ttyAMA0 console=tty0"
    -drive "file=$disk,format=raw,if=virtio"
    -device virtio-gpu-pci -display "$display"
    -device qemu-xhci -device usb-kbd -device usb-tablet
    -device virtio-rng-pci
    -netdev "$network" -device "virtio-net-pci,netdev=net0,romfile="
    -serial mon:stdio -no-reboot)
if [[ ${VM_TOUCH:-1} == 1 ]]; then cmd+=(-device virtio-multitouch-pci); fi
if [[ -n ${VM_QMP:-} ]]; then
    [[ $VM_QMP != *,* ]] || { echo "VM_QMP must not contain commas" >&2; exit 2; }
    cmd+=(-qmp "unix:$VM_QMP,server=on,wait=off")
fi
if [[ ${VM_SHARE:-0} == 1 ]]; then
    share=${VM_SOURCE_SHARE:-$root/build/vm-share}
    [[ -d "$share" && "$share" != *,* ]] || { echo "Run ./scripts/export-vm-source.sh first" >&2; exit 1; }
    cmd+=(-virtfs "local,path=$share,mount_tag=tessarchy,security_model=none,readonly=on")
fi
printf 'VM command:'; printf ' %q' "${cmd[@]}"; printf '\n'
[[ $operation == plan ]] && exit 0
[[ $accel != tcg ]] || echo "Emulating aarch64 in software: expect slow startup and rendering." >&2
exec "${cmd[@]}"
