#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ $EUID != 0 ]] || { echo "makepkg must run as a normal user" >&2; exit 1; }
mkdir -p "$root/dist"
version=${TESSARCHY_VERSION:-0.1.0}
source_archive="$root/dist/tessarchy-$version.tar.gz"
# Package identity: only a clean, recorded checkout may be packaged, so a later
# bundle can never label one revision's files as another revision's package.
if ! git -C "$root" diff-index --quiet HEAD --; then
    echo "error: tracked files changed during validation:" >&2
    git -C "$root" status --short --untracked-files=no >&2
    echo "error: refuse to package a dirty source tree (commit your changes first)" >&2
    exit 1
fi
source_commit=$(git -C "$root" rev-parse HEAD)
# The source archive is what every PKGBUILD unpacks, so it carries the whole
# product: the shell, the session, the docs and the medium's own configuration
# (packaging/tessarchy-update installs files out of iso/airootfs).
tar --exclude=__pycache__ --exclude='*.pyc' --exclude='*.pyo' --exclude='*.ppm' \
    -czf "$source_archive" -C "$root" \
    shell session themes portal plugins docs iso LICENSE packaging \
    scripts/export-brand-assets.py scripts/export-boot-assets.py scripts/build-window-tape.sh
# Every directory under packaging/ that has a PKGBUILD is part of the release;
# adding a package means adding a directory, not editing this list.
mapfile -t packages < <(find "$root/packaging" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
for package in "${packages[@]}"; do
    work=$root/build/packages/$package
    rm -rf "$work"
    mkdir -p "$work"
    cp "$root/packaging/$package/PKGBUILD" "$source_archive" "$work/"
    (cd "$work"; PKGDEST="$root/dist" makepkg --force --cleanbuild --nodeps)
done
echo "packages built from tessarchy-$version.tar.gz at $source_commit: ${#packages[@]}"
# Record the exact source identity beside the packages; bundle-tablet.py
# verifies it before labelling a bundle.
printf '{\n  "commit": "%s",\n  "version": "%s",\n  "dirty": false\n}\n' "$source_commit" "$version" > "$root/dist/SOURCE.json"
# This script neither installs packages nor resolves dependencies with sudo.
