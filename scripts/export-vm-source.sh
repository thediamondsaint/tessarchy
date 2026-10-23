#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
share=$root/build/vm-share
[[ ! -e "$share" ]] || { echo "Keeping existing snapshot: $share. Move/remove it to refresh."; exit 0; }
mkdir -p "$share/tessarchy"
cp -R "$root/shell" "$root/session" "$root/scripts" "$root/packaging" "$root/iso" "$root/docs" "$root/tests" "$root/assets" "$root/website" "$root/themes" "$root/portal" "$root/plugins" "$share/tessarchy/"
cp "$root/README.md" "$root/AGENTS.md" "$root/LICENSE" "$share/tessarchy/"
echo "Read-only snapshot ready. Start VM with VM_SHARE=1. See docs/vm.md."
