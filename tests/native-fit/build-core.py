#!/usr/bin/env python3
"""Build shutdown primitives and syntax-check their isolated Hyprland overlay."""

import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PATCHES = ROOT / "patches/hyprland/shutdown"
RELATIVE_UNITS = [
    "src/managers/eventLoop/EventLoopManager.cpp",
    "src/protocols/ImageCopyCapture.cpp",
    "src/managers/screenshare/ScreenshareFrame.cpp",
    "src/render/GLRenderer.cpp",
    "src/managers/screenshare/ScreenshareManager.cpp",
    "src/Compositor.cpp",
]
SOURCE_FILES = [*RELATIVE_UNITS, "src/managers/eventLoop/EventLoopManager.hpp", "src/protocols/ImageCopyCapture.hpp", "src/protocols/ImageCaptureSource.hpp", "src/render/GLRenderer.hpp", "src/render/Renderer.hpp", "src/managers/screenshare/ScreenshareManager.hpp", "src/Compositor.hpp"]
HEADERS = {
    "ScopedReadable.hpp": "src/managers/eventLoop/ScopedReadable.hpp",
    "TerminalDelivery.hpp": "src/helpers/TerminalDelivery.hpp",
    "SubmittedWork.hpp": "src/managers/eventLoop/SubmittedWork.hpp",
    "ShutdownSequence.hpp": "src/helpers/ShutdownSequence.hpp",
}


def run(argv, **kwargs):
    print("+", shlex.join(map(str, argv)), flush=True)
    subprocess.run(list(map(str, argv)), check=True, **kwargs)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def mirror_tree(source, target):
    target.mkdir(parents=True, exist_ok=True)
    if target.is_symlink():
        raise RuntimeError(f"Refusing symlinked overlay directory: {target}")
    for child in source.iterdir():
        if child.name in {".git", "build"}:
            continue
        destination = target / child.name
        if child.is_dir() and not child.is_symlink():
            mirror_tree(child, destination)
        elif not destination.exists() and not destination.is_symlink():
            destination.symlink_to(child.resolve())


def prepare(source, output):
    mirror = output / "source"
    stamp = output / "overlay.json"
    if mirror.exists() and not stamp.exists():
        raise RuntimeError("Existing overlay has no ownership receipt")
    identity = {"source": str(source), "repository": str(ROOT)}
    if stamp.exists() and json.loads(stamp.read_text()) != identity:
        raise RuntimeError("Existing overlay belongs to a different source/repository")
    stamp.write_text(json.dumps(identity, indent=2) + "\n")
    mirror_tree(source, mirror)
    for name in SOURCE_FILES:
        relative = Path(name)
        destination = mirror / relative
        if destination.is_symlink():
            destination.unlink()
        shutil.copy2(source / relative, destination)
    patch = "".join((PATCHES / name).read_text() for name in ("event-loop.patch", "terminal-delivery.patch", "renderer-retirement.patch", "cleanup-integration.patch", "child-lifetime.patch", "cursor-lifetime.patch"))
    for name, header in HEADERS.items():
        destination = mirror / header
        if (source / header).exists():
            raise RuntimeError(f"Upstream already contains {header}")
        if destination.exists() or destination.is_symlink():
            destination.unlink()
        added = (PATCHES / name).read_text()
        patch += "".join(difflib.unified_diff([], added.splitlines(True), fromfile="/dev/null", tofile="b/" + header))
    patchfile = output / "native-shutdown.patch"
    patchfile.write_text(patch)
    env = os.environ.copy()
    env.pop("GIT_DIR", None)
    env.pop("GIT_WORK_TREE", None)
    env["GIT_CEILING_DIRECTORIES"] = str(mirror.parent)
    run(["git", "-C", mirror, "apply", "--check", patchfile], env=env)
    run(["git", "-C", mirror, "apply", patchfile], env=env)
    return mirror


def syntax_check(source, mirror):
    database = json.loads((source / "build/compile_commands.json").read_text())
    checked = []
    for relative in RELATIVE_UNITS:
        entries = [entry for entry in database if Path(entry["file"]).resolve() == source / relative]
        if len(entries) != 1:
            raise RuntimeError(f"Expected one compile command for {relative}")
        entry = entries[0]
        original = entry.get("arguments") or shlex.split(entry["command"])
        alias = str(Path(entry["file"]).parents[len(Path(relative).parts) - 1])
        args = []
        skip = False
        for arg in original:
            if skip:
                skip = False
                continue
            if arg in {"-o", "-include"}:
                skip = True
                continue
            if arg in {"-c", entry["file"], "-Winvalid-pch"} or arg.startswith(("-flto", "-O")):
                continue
            args.append(arg.replace(alias, str(mirror)).replace(str(source), str(mirror)))
        args.extend(["-O0", "-fsyntax-only", "-include", str(mirror / "src/pch/pch.hpp"), str(mirror / relative)])
        run(args, cwd=mirror)
        checked.append(relative)
    return checked


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="Existing configured Hyprland source; never modified")
    parser.add_argument("--test", action="append", choices=["test-scoped-readable", "test-terminal-delivery", "test-submitted-work", "test-shutdown-sequence"], help="Select focused primitive tests; default runs all")
    args = parser.parse_args()
    output = ROOT / "build/native-fit/core-shutdown"
    output.mkdir(parents=True, exist_ok=True)
    receipt_path = output / "verification.json"
    receipt_path.unlink(missing_ok=True)
    source = args.source.resolve() if args.source else None
    if source and (source == output or source in output.parents or output in source.parents):
        raise RuntimeError("Source and output trees must be separate")
    units = SOURCE_FILES
    before = {name: digest(source / name) for name in units} if source else {}
    flags = shlex.split(subprocess.check_output(["pkg-config", "--cflags", "--libs", "wayland-server", "hyprutils"], text=True))
    compiler = os.environ.get("CXX", "c++")
    tests = args.test or ["test-scoped-readable", "test-terminal-delivery", "test-submitted-work", "test-shutdown-sequence"]
    for name in tests:
        binary = output / name
        run([compiler, "-std=c++23", "-Wall", "-Wextra", "-Werror", "-g", "-fsanitize=address,undefined", "-fno-omit-frame-pointer",
             ROOT / f"tests/native-fit/{name}.cpp", *flags, "-o", binary])
        run([binary])
    checked = syntax_check(source, prepare(source, output)) if source else []
    after = {name: digest(source / name) for name in units} if source else {}
    if before != after:
        raise RuntimeError("Original upstream source changed")
    receipt = {"unit_tests": tests, "test_hashes": {name: digest(ROOT / f"tests/native-fit/{name}.cpp") for name in tests}, "sanitizers": ["address", "undefined"],
               "header_hashes": {name: digest(PATCHES / name) for name in HEADERS},
               "patch_hashes": {name: digest(PATCHES / name) for name in ("event-loop.patch", "terminal-delivery.patch", "renderer-retirement.patch", "cleanup-integration.patch", "child-lifetime.patch", "cursor-lifetime.patch")},
               "overlay_source_hashes": {name: digest(output / "source" / name) for name in units} if source else {},
               "syntax_checked": checked, "original_source_hashes": before, "original_source_unchanged": before == after if source else None}
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2), flush=True)


if __name__ == "__main__":
    main()
