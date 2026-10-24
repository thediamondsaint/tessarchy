#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ $EUID != 0 ]] || { echo "Run this wrapper as your normal user; it invokes sudo only for mkarchiso" >&2; exit 1; }
command -v mkarchiso >/dev/null || { echo "Install archiso explicitly first" >&2; exit 1; }
profile=$root/build/netinstall-profile
[[ -f $profile/profiledef.sh ]] || { echo "Run ./scripts/stage-netinstall.sh first" >&2; exit 1; }
work=$root/build/netinstall-work
[[ ! -e $work ]] || { echo "Move/remove $work before a fresh build" >&2; exit 1; }
mkdir -p "$root/dist"
sudo mkarchiso -v -w "$work" -o "$root/dist" "$profile"
shopt -s nullglob
images=("$root"/dist/tessarchy-netinstall-*.iso)
(( ${#images[@]} == 1 )) || { echo "Expected one netinstall ISO, found ${#images[@]}" >&2; exit 1; }
bytes=$(stat -c %s "${images[0]}")
printf 'ISO: %s\nBytes: %s\n' "${images[0]}" "$bytes"
if (( bytes > 1073741824 )); then
    echo "Netinstall image exceeds the 1 GiB target; trim the package profile before release." >&2
    exit 1
fi
sha256sum "${images[0]}" | tee "${images[0]}.sha256"
