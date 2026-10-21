#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
for script in scripts/*.sh session/tessarchy-session-services session/start-tessarchy session/tessera-shell session/tessarchy-osk session/tessarchy-theme session/tessarchy-run session/tessera-screenshot session/tessera-brightness session/tessera-nightlight session/tessera-rotate session/tessarchy-autorotate session/tessera-update-notify session/tessarchy-greeter session/tessarchy-install-ui packaging/*/PKGBUILD; do bash -n "$script"; done
# Arch ships only python; Debian/Ubuntu split out python3. Accept either.
py=$(command -v python || command -v python3 || true)
[[ -n "$py" ]] || { echo "FAIL: neither python nor python3 is installed" >&2; exit 1; }
"$py" -m py_compile session/tessarchy-install session/tessarchy-update session/tessarchy-readiness
"$py" -m unittest discover -s tests -v
if command -v node >/dev/null; then node --test tests/website.test.cjs; else echo "SKIP: Node.js website checks unavailable"; fi
# Discover the installed Qt tools and import root on Arch and Debian.
qml_root=""
for dir in /usr/lib/qt6/qml /usr/lib/*/qt6/qml; do
    if [[ -d "$dir/QtTest" ]]; then qml_root=$dir; break; fi
done
runner=$(command -v qmltestrunner || true)
if [[ -z "$runner" && -x /usr/lib/qt6/bin/qmltestrunner ]]; then runner=/usr/lib/qt6/bin/qmltestrunner; fi
if [[ -n "$runner" && -n "$qml_root" ]]; then
    HOME="$scratch" XDG_CONFIG_HOME="$scratch/config" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME='' \
        QML2_IMPORT_PATH="$qml_root" "$runner" -input tests/qml
else echo "SKIP: Qt Quick Test unavailable"; fi
compiler=$(command -v luac || command -v luac5.4 || true)
if [[ -n "$compiler" ]]; then "$compiler" -p session/hyprland.lua session/window-controls.lua session/preferences.example.lua session/greeter.lua; else echo "SKIP: luac unavailable"; fi
if command -v fish >/dev/null; then fish -n iso/airootfs/etc/skel/.config/fish/config.fish; else echo "SKIP: fish unavailable"; fi
if command -v desktop-file-validate >/dev/null; then
    # Ignore only the known DesktopNames validator false positive.
    validated=$(desktop-file-validate session/tessarchy.desktop 2>&1) || true
    serious=$(printf '%s\n' "$validated" | grep -viE 'key "DesktopNames"' || true)
    if [[ -n "$serious" ]]; then
        printf '%s\n' "$serious" 1>&2
        exit 1
    fi
else echo "SKIP: desktop-file-validate unavailable"; fi
if command -v Hyprland >/dev/null; then
    # Verification must not load the current user's preferences.
    mkdir -m 700 "$scratch/runtime"
    XDG_RUNTIME_DIR="$scratch/runtime" XDG_CONFIG_HOME="$scratch" Hyprland --verify-config -c "$root/session/hyprland.lua"
    XDG_RUNTIME_DIR="$scratch/runtime" XDG_CONFIG_HOME="$scratch" Hyprland --verify-config -c "$root/session/greeter.lua"
else echo "SKIP: Hyprland config parser unavailable"; fi
# Prefer the linter shipped with the installed Qt.
if [[ -x /usr/lib/qt6/bin/qmllint ]]; then lint=/usr/lib/qt6/bin/qmllint; else lint=$(command -v qmllint || true); fi
if [[ -n "$lint" ]] && command -v qs >/dev/null; then
    if [[ -n "$qml_root" ]]; then
        "$lint" -I "$qml_root" shell/shell.qml shell/greeter.qml shell/login-preview.qml shell/components/*.qml
    else
        "$lint" shell/shell.qml shell/greeter.qml shell/login-preview.qml shell/components/*.qml
    fi
else echo "SKIP: complete QML lint requires qmllint and Quickshell type metadata"; fi
if command -v shellcheck >/dev/null; then
    shellcheck scripts/*.sh session/tessarchy-session-services session/start-tessarchy session/tessera-shell session/tessarchy-osk session/tessarchy-theme session/tessarchy-run session/tessera-screenshot session/tessera-brightness session/tessera-nightlight session/tessera-rotate session/tessarchy-autorotate session/tessera-update-notify session/tessarchy-greeter
else echo "SKIP: shellcheck unavailable"; fi
echo "Available static/integration checks passed; GUI and ISO boot tests remain manual."
