#!/usr/bin/env bash
# Launch the downloaded disk with a fresh read-only source snapshot.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
disk=$root/vm/Arch-Linux-x86_64-basic.qcow2
[[ -f "$disk" ]] || { echo "Missing basic Arch VM disk: $disk" >&2; exit 1; }
mkdir -p "$root/build"
share=$(mktemp -d "$root/build/source-share.XXXXXX")
trap 'rm -rf -- "$share"' EXIT
mkdir -p "$share/tessarchy"
for directory in shell session scripts packaging iso docs tests assets website themes portal plugins; do
    cp -R -- "$root/$directory" "$share/tessarchy/"
done
cp -- "$root/README.md" "$root/AGENTS.md" "$root/LICENSE" "$share/tessarchy/"
# Keep the software viewer by default; Virgl remains opt-in for comparison.
export VM_GL=${VM_GL:-0} VM_TOUCH=${VM_TOUCH:-1} VM_AUDIO_USB=${VM_AUDIO_USB:-1}
export VM_DISK="$disk" VM_SOURCE_SHARE="$share" VM_SHARE=1
"$root/scripts/vm.sh" "${1:-run}"
