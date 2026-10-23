#!/usr/bin/env bash
# Build an aarch64 VM disk from the verified root filesystem without root access.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for tool in fakeroot bsdtar mke2fs; do command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 1; }; done
vm=$root/vm/aarch64
tarball=$vm/ArchLinuxARM-aarch64-latest.tar.gz
[[ -f "$tarball" ]] || { echo "Run ./scripts/fetch-alarm.sh first" >&2; exit 1; }
size=${VM_DISK_SIZE:-16G}
[[ $size =~ ^[1-9][0-9]*G$ ]] || { echo "VM_DISK_SIZE must be a whole number of GiB, such as 16G" >&2; exit 2; }
for output in rootfs.img Image initramfs-linux.img; do
    [[ ! -e "$vm/$output" ]] || { echo "Keeping existing $vm/$output; move it to rebuild" >&2; exit 1; }
done
work=$(mktemp -d "$vm/.build.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/rootfs"
# One fakeroot session keeps archive ownership from extraction through mke2fs.
# shellcheck disable=SC2016
fakeroot -- bash -c '
    set -euo pipefail
    bsdtar -xpf "$1" -C "$2/rootfs"
    printf "/dev/vda / ext4 rw,relatime 0 1\n" > "$2/rootfs/etc/fstab"
    mke2fs -q -t ext4 -L tessarchy-arm -d "$2/rootfs" "$2/rootfs.img" "$3"
' fakeroot "$tarball" "$work" "$size"
cp -- "$work/rootfs/boot/Image" "$work/rootfs/boot/initramfs-linux.img" "$work/"
mv -- "$work/rootfs.img" "$work/Image" "$work/initramfs-linux.img" "$vm/"
echo "Built $vm/rootfs.img ($size, sparse) with its kernel and initramfs"
