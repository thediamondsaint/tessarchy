#!/usr/bin/env bash
# Download the Arch Linux ARM aarch64 root filesystem; verify its detached signature.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for tool in curl gpg gpgv md5sum; do command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 1; }; done
# Arch Linux ARM Build System <builder@archlinuxarm.org>
fingerprint=68B3537F39A313B3E574D06777193F152BDBE6A6
filename=ArchLinuxARM-aarch64-latest.tar.gz
destination=$root/vm/aarch64
[[ ! -e "$destination/$filename" ]] || { echo "Root filesystem already exists; use it or move it before downloading" >&2; exit 1; }
base=${ALARM_MIRROR:-http://os.archlinuxarm.org/os}
base=${base%/}
[[ $base == http://* || $base == https://* ]] || { echo "ALARM_MIRROR must be an HTTP(S) directory" >&2; exit 1; }
keyserver=${ALARM_KEYSERVER:-https://keyserver.ubuntu.com}
[[ $keyserver == https://* ]] || { echo "ALARM_KEYSERVER must be an HTTPS keyserver" >&2; exit 1; }
mkdir -p "$destination"
work=$(mktemp -d "$destination/.download.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
mkdir -m 700 "$work/gnupg"
# Fetch the key by full fingerprint and refuse any other key in the response.
curl --fail --location --connect-timeout 15 --retry 2 \
    "$keyserver/pks/lookup?op=get&options=mr&search=0x$fingerprint" -o "$work/key.asc"
imported=$(GNUPGHOME="$work/gnupg" gpg --batch --with-colons --show-keys "$work/key.asc" | awk -F: '$1 == "fpr" { print $10; exit }')
[[ $imported == "$fingerprint" ]] || { echo "Keyserver returned an unexpected key" >&2; exit 1; }
GNUPGHOME="$work/gnupg" gpg --batch --quiet --dearmor --output "$work/keyring.gpg" "$work/key.asc"
for name in "$filename" "$filename.sig" "$filename.md5"; do
    curl --fail --location --connect-timeout 15 --retry 2 "$base/$name" -o "$work/$name"
done
(cd "$work"; md5sum -c "$filename.md5")
gpgv --keyring "$work/keyring.gpg" "$work/$filename.sig" "$work/$filename"
mv -- "$work/$filename" "$destination/"
echo "Verified Arch Linux ARM root filesystem: $destination/$filename"
