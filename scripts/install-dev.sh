#!/usr/bin/env bash
# Copy-only, namespaced, non-root installation. Refuse unknown existing files.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ $EUID != 0 ]] || { echo "Run as a development user, not root" >&2; exit 1; }
data=${XDG_DATA_HOME:-$HOME/.local/share}/tessarchy
bin=$HOME/.local/bin
marker=$data/.tessarchy-dev-install
for path in "$data" "$bin/start-tessarchy" "$bin/tessera-shell" "$bin/tessarchy-osk" "$bin/tessarchy-theme" "$bin/tessarchy-run" "$bin/tessera-screenshot" "$bin/tessarchy-session-services" "$bin/tessera-brightness" "$bin/tessera-nightlight" "$bin/tessera-rotate" "$bin/tessarchy-autorotate"; do
    if [[ -e "$path" || -L "$path" ]]; then
        echo "Refusing existing path: $path (uninstall this dev copy first)" >&2; exit 1
    fi
done
mkdir -p -- "$data/session" "$data/.tessarchy-dev-launchers" "$bin"
cp -R -- "$root/shell" "$root/themes" "$data/"
cp -R -- "$root/session/osk" "$data/session/"
find "$data/shell" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete
find "$data/shell" -depth -type d -name __pycache__ -empty -delete
cp -- "$root/session/hyprland.lua" "$root/session/window-controls.lua" "$root/session/hypridle.conf" "$data/session/"
cp -- "$root/session/start-tessarchy" "$root/session/tessera-shell" "$root/session/tessarchy-osk" "$root/session/tessarchy-theme" "$root/session/tessarchy-run" "$root/session/tessera-screenshot" "$root/session/tessarchy-session-services" "$root/session/tessera-brightness" "$root/session/tessera-nightlight" "$root/session/tessera-rotate" "$root/session/tessarchy-autorotate" "$data/.tessarchy-dev-launchers/"
cp -- "$data/.tessarchy-dev-launchers/"* "$bin/"
printf '%s\n' 'tessarchy-dev-v3' > "$marker"
# Record installed data files relative to the private data directory.
manifest=$data/.tessarchy-dev-files
{
    find "$data" -mindepth 1 \( -type f -o -type l \) ! -name '.tessarchy-dev-files' -printf '%P\n' | sort
} > "$manifest"
echo "Installed to $data. From a local TTY: $bin/start-tessarchy"
