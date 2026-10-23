#!/usr/bin/env bash
# Build the optional bridge using the same native layout API as Hyprland gestures.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for tool in c++ pkg-config; do
    command -v "$tool" >/dev/null || { echo "Missing build tool: $tool" >&2; exit 1; }
done
[[ $(pkg-config --modversion hyprland) == 0.56.2 ]] || {
    echo "This bridge requires Hyprland 0.56.2 headers." >&2; exit 1
}
tape_flags=$(pkg-config --cflags hyprland lua)
read -r -a tape_cflags <<< "$tape_flags"
mkdir -p -- "$root/dist"
c++ -std=c++23 -shared -fPIC -O2 -Wall -Wextra -Wno-unused-parameter \
    "${tape_cflags[@]}" "$root/plugins/window-tape/main.cpp" \
    -o "$root/dist/tessarchy-tape-0.56.2.so"
echo "Built dist/tessarchy-tape-0.56.2.so; use only with the matching Hyprland build."
