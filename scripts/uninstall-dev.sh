#!/usr/bin/env bash
set -euo pipefail
data=${XDG_DATA_HOME:-$HOME/.local/share}/tessarchy
[[ -f "$data/.tessarchy-dev-install" && ! -L "$data" ]] || {
    echo "No marked Tessarchy development installation at $data" >&2; exit 1;
}
version=$(cat "$data/.tessarchy-dev-install")
[[ $version == tessarchy-dev-v1 || $version == tessarchy-dev-v2 || $version == tessarchy-dev-v3 ]] || exit 1
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
manifest=$data/.tessarchy-dev-files
entries=()
if [[ $version != tessarchy-dev-v1 ]]; then
    [[ -f $manifest && ! -L $manifest ]] || { echo "Missing or unsafe install manifest" >&2; exit 1; }
    mapfile -t entries < "$manifest"
    [[ ${#entries[@]} -gt 0 ]] || { echo "Empty install manifest" >&2; exit 1; }
    for relative in "${entries[@]}"; do
        [[ -n $relative && $relative != /* ]] || { echo "Unsafe install manifest entry" >&2; exit 1; }
        IFS=/ read -r -a components <<< "$relative"
        parent=$data
        for component in "${components[@]}"; do
            [[ -n $component && $component != . && $component != .. ]] || { echo "Unsafe install manifest entry" >&2; exit 1; }
            [[ ! -L $parent ]] || { echo "Symlink in install manifest path" >&2; exit 1; }
            parent=$parent/$component
        done
    done
fi
# New installs retain the installed bytes so a source update is not a user edit.
launchers=(start-tessarchy tessera-shell tessarchy-osk tessarchy-theme tessarchy-run tessera-screenshot tessera-brightness tessera-nightlight tessera-rotate tessarchy-session-services)
originals=$root/session
if [[ $version == tessarchy-dev-v3 ]]; then
    originals=$data/.tessarchy-dev-launchers
    [[ -d $originals && ! -L $originals ]] || { echo "Missing or unsafe launcher snapshots" >&2; exit 1; }
    launchers=()
    for relative in "${entries[@]}"; do
        if [[ $relative == .tessarchy-dev-launchers/* ]]; then
            launcher=${relative#.tessarchy-dev-launchers/}
            [[ $launcher =~ ^(start-tessarchy|tessera-[a-z0-9-]+|tessarchy-[a-z0-9-]+)$ ]] || {
                echo "Unsafe launcher snapshot entry" >&2; exit 1;
            }
            launchers+=("$launcher")
        fi
    done
    [[ ${#launchers[@]} -gt 0 ]] || { echo "Missing launcher snapshot entries" >&2; exit 1; }
fi
# Preserve launchers edited since installation; report instead of deleting them.
for launcher in "${launchers[@]}"; do
    target=$HOME/.local/bin/$launcher
    if [[ $version == tessarchy-dev-v3 && ( ! -f $originals/$launcher || -L $originals/$launcher ) ]]; then
        echo "Missing or unsafe launcher snapshot: $launcher" >&2; exit 1
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        cmp -s -- "$originals/$launcher" "$target" || {
            echo "Modified launcher: $target; preserve or remove it manually before uninstalling" >&2; exit 1;
        }
    fi
done

for launcher in "${launchers[@]}"; do rm -f -- "$HOME/.local/bin/$launcher"; done
# Remove only files recorded by this installation.
if [[ $version != tessarchy-dev-v1 ]]; then
    for relative in "${entries[@]}"; do rm -f -- "$data/$relative"; done
    rm -f -- "$manifest"
    find "$data" -depth -type d -exec rmdir -- {} \; 2>/dev/null || true
else
    rm -f -- "$data/shell/shell.qml" "$data/shell/components/TouchButton.qml" "$data/shell/components/NavButton.qml" "$data/shell/components/AppTile.qml" "$data/shell/components/StatusIcon.qml" "$data/shell/components/AudioStatus.qml" "$data/shell/components/BrandMark.qml" "$data/shell/components/SettingsPage.qml" "$data/shell/components/LevelSlider.qml" "$data/shell/components/AppSwitcher.qml" "$data/shell/components/SplitDivider.qml" "$data/shell/components/RadioBackend.qml" "$data/shell/components/RadioTile.qml" "$data/shell/components/QuickSettings.qml" "$data/shell/LayoutPolicy.js" "$data/shell/SwitcherPolicy.js"
    for icon in back home recents power browser terminal wifi cellular volume volume-muted battery settings phone tablet desktop auto controls return close airplane bluetooth split swap; do rm -f -- "$data/shell/icons/$icon.svg"; done
    rm -f -- "$data/shell/artwork/aurora-fold.png" "$data/shell/artwork/tessarchy-mark.svg"
    for face in 0 1 2 3 4 5; do rm -f -- "$data/shell/artwork/mark-face-$face.svg"; done
    rm -f -- "$data/session/hyprland.lua" "$data/.tessarchy-dev-install"
    rm -f -- "$data/shell/helpers/radios.py"
    rmdir -- "$data/shell/helpers" "$data/shell/artwork" "$data/shell/icons" "$data/shell/components" "$data/shell" "$data/session" "$data" 2>/dev/null || true
fi
echo "Development copy removed. ~/.config/tessarchy preferences retained."
