#!/usr/bin/env python3
"""Build the isolated oversized Wayland fixture without installing anything."""
import argparse
import pathlib
import shlex
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build/native-fit"


def run(*args):
    subprocess.run(args, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plugin", action="store_true", help="Also build the isolated exact-ABI compositor probe")
    parser.add_argument("--pointer-xml", type=pathlib.Path, help="Path to upstream wlr-virtual-pointer-unstable-v1.xml; also build the guarded pointer probe")
    args = parser.parse_args()
    for tool in ("cc", "pkg-config", "wayland-scanner", *(("c++",) if args.plugin else ())):
        if not shutil.which(tool):
            raise SystemExit(f"Required build tool unavailable: {tool}; no packages installed")
    protocols = subprocess.check_output(
        ["pkg-config", "--variable=pkgdatadir", "wayland-protocols"], text=True
    ).strip()
    xml = pathlib.Path(protocols) / "stable/xdg-shell/xdg-shell.xml"
    if not xml.is_file():
        raise SystemExit("Required wayland-protocols xdg-shell.xml unavailable")
    flags = shlex.split(subprocess.check_output(
        ["pkg-config", "--cflags", "--libs", "wayland-client"], text=True
    ))
    OUT.mkdir(parents=True, exist_ok=True)
    run("wayland-scanner", "client-header", str(xml), str(OUT / "xdg-shell-client-protocol.h"))
    run("wayland-scanner", "private-code", str(xml), str(OUT / "xdg-shell-protocol.c"))
    run("cc", "-std=c11", "-O0", "-g", "-Wall", "-Wextra", "-Werror", f"-I{OUT}",
        str(ROOT / "tests/native-fit/oversized-client.c"), str(OUT / "xdg-shell-protocol.c"),
        "-o", str(OUT / "oversized-client.new"), *flags)
    (OUT / "oversized-client.new").replace(OUT / "oversized-client")
    print(OUT / "oversized-client")
    if args.pointer_xml:
        xml = args.pointer_xml.resolve(strict=True)
        run("wayland-scanner", "client-header", str(xml), str(OUT / "wlr-virtual-pointer-client-protocol.h"))
        run("wayland-scanner", "private-code", str(xml), str(OUT / "wlr-virtual-pointer-protocol.c"))
        run("cc", "-std=c11", "-O0", "-g", "-Wall", "-Wextra", "-Werror", f"-I{OUT}",
            str(ROOT / "tests/native-fit/pointer-client.c"), str(OUT / "wlr-virtual-pointer-protocol.c"),
            "-o", str(OUT / "pointer-client.new"), *flags)
        (OUT / "pointer-client.new").replace(OUT / "pointer-client")
        print(OUT / "pointer-client")
    if args.plugin:
        plugin_flags = shlex.split(subprocess.check_output(["pkg-config", "--cflags", "hyprland"], text=True))
        run("c++", "-std=c++23", "-O0", "-g", "-fPIC", "-shared", "-Wall", "-Wextra", "-Wno-unused-parameter",
            *plugin_flags, str(ROOT / "plugins/native-fit/main.cpp"), "-o", str(OUT / "native-fit.so.new"))
        (OUT / "native-fit.so.new").replace(OUT / "native-fit.so")
        print(OUT / "native-fit.so")


if __name__ == "__main__":
    main()
