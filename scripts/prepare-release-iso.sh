#!/usr/bin/env bash
# Make checksum-verified release parts while keeping the original ISO intact for VM tests.
set -euo pipefail
if [[ $# != 1 || ! -f $1 ]]; then
    echo "Usage: $0 path/to/tessarchy.iso" >&2
    exit 2
fi
image=$(realpath -- "$1")
directory=$(dirname -- "$image")
base=$(basename -- "$image")
cd -- "$directory"
if compgen -G "$base.part???" >/dev/null; then
    echo "Refusing existing release parts for $base" >&2
    exit 1
fi
split --bytes="${TESSARCHY_ISO_PART_SIZE:-1900M}" --numeric-suffixes=1 \
    --suffix-length=3 "$base" "$base.part"
sha256sum "$base" "$base".part??? > SHA256SUMS
cat > DOWNLOAD-ISO.md <<EOF
# Assemble the Tessarchy ISO

GitHub Releases limits each file to 2 GiB. Download every \`$base.partNNN\` file into the same directory, then run:

\`\`\`sh
cat $base.part??? > $base
sha256sum -c SHA256SUMS
\`\`\`

The checksum file includes the reassembled ISO and every part. Write the resulting \`$base\` to a USB drive or boot it in a VM.
EOF
