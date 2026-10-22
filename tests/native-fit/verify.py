#!/usr/bin/env python3
"""Exercise the private native fixture: clipping RED, fitting, pointer, disable/unload."""
import argparse
import json
import math
import os
from pathlib import Path
import re
import subprocess
import time
from typing import cast

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/native-fit"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--session", type=Path)
    args = parser.parse_args()
    session = args.session or Path((OUT / "latest-session.txt").read_text().strip())
    session = session.resolve(strict=True)
    if session.parent != OUT.resolve() or not session.name.startswith("nested-"):
        raise SystemExit("Refusing a non-harness session path")
    state = json.loads((session / "session.json").read_text())
    assert state["compositor_pid"] != state["parent_pid"]
    env = os.environ.copy()
    env.update(state["environment"])
    env["TESSARCHY_FIT_INPUT_PROBE"] = "1"
    assert Path(env["XDG_RUNTIME_DIR"]).name.startswith("t77-")
    assert Path(env["HOME"]) == session / "home"

    def run(*command):
        return subprocess.check_output(command, env=env, text=True, stderr=subprocess.STDOUT, timeout=15).strip()

    def ctl(*command):
        return run("hyprctl", *command)

    def checked_plugin_image():
        lines = Path(f"/proc/{state['compositor_pid']}/maps").read_text().splitlines()
        mapped = [line for line in lines if str(OUT / "native-fit.so") in line]
        inode = str((OUT / "native-fit.so").stat().st_ino)
        assert mapped and all(line.split()[4] == inode for line in mapped), (
            "Stale plugin image: start a fresh private compositor after rebuilding; unload may retain the old DSO")

    clients = json.loads(ctl("-j", "clients"))
    fixture = next(c for c in clients if c["pid"] == state["client_pid"])
    assert fixture["class"] == "tessarchy-native-fit-fixture" and not fixture["xwayland"]
    assert fixture["size"] == [410, 800]
    baseline_plugins = json.loads(ctl("-j", "plugin", "list"))
    assert not baseline_plugins, "Require a fresh private compositor without plugins"
    client_log = session / "client.log"
    frames = re.findall(r"FRAME configured=(\d+)x(\d+) committed=(\d+)x(\d+)", client_log.read_text())
    assert frames and list(map(int, frames[-1])) == [410, 800, 832, 800]
    scale = min(1, 410 / 832, 800 / 800)

    def capture(name):
        path = session / (name + ".png")
        run("grim", "-o", "FIT-1", str(path))
        image = Image.open(path).convert("RGB")
        assert image.size == (410, 800)
        colors = cast(list[tuple[int, tuple[int, int, int]]], image.getcolors(image.width * image.height))
        assert colors is not None
        red = sum(n for n, c in colors if c[0] > 180 and c[1] < 100 and c[2] < 100)
        cyan = sum(n for n, c in colors if c[0] < 100 and c[1] > 150 and c[2] > 150)
        return image, {"name": name, "size": list(image.size), "red_pixels": red, "cyan_pixels": cyan}

    def click(expected):
        start = len(client_log.read_text())
        run(str(OUT / "pointer-client"), "400", "200", "410", "800", str(state["compositor_pid"]))
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            found = re.findall(r"BUTTON 272 1 ([\d.-]+) ([\d.-]+)", client_log.read_text()[start:])
            if found:
                actual = list(map(float, found[-1]))
                assert all(math.isclose(a, b, abs_tol=0.01) for a, b in zip(actual, expected)), (actual, expected)
                return {"screen": [400, 200], "expected_native": expected, "actual_native": actual}
            time.sleep(0.03)
        raise AssertionError("No genuine fixture button-press event received")

    pointer_control = click([400, 200])
    baseline, red = capture("baseline")
    assert red["red_pixels"] == 0 and red["cyan_pixels"] > 1000, red
    assert ctl("plugin", "load", str(OUT / "native-fit.so")) == "ok"
    checked_plugin_image()
    assert any(p["name"] == "tessarchy-native-fit-probe" for p in json.loads(ctl("-j", "plugin", "list")))
    assert ctl("eval", 'hl.plugin.tessarchy_fit.target("tessarchy-native-fit-fixture")') == "ok"
    fitted, green = capture("fitted")
    assert green["red_pixels"] > 1000 and green["cyan_pixels"] > 1000, green
    red_pixel = cast(tuple[int, int, int], fitted.getpixel((400, 200)))
    background = cast(tuple[int, int, int], fitted.getpixel((100, 600)))
    assert red_pixel[0] > 180 and max(red_pixel[1:]) < 100, red_pixel
    assert max(background) < 32, background
    pointer_fit = click([400 / scale, 200 / scale])
    cycles = []
    for index in range(5):
        _, receipt = capture(f"fitted-repeat-{index}")
        assert receipt["red_pixels"] > 1000, receipt
        cycles.append(receipt)
    assert ctl("eval", 'hl.plugin.tessarchy_fit.target("")') == "ok"
    disabled, control = capture("disabled-control")
    assert control["red_pixels"] == 0
    assert ImageChops.difference(baseline, disabled).getbbox() is None, "Disable must restore baseline pixels"
    pointer_disabled = click([400, 200])
    assert ctl("plugin", "unload", str(OUT / "native-fit.so")) == "ok"
    assert not json.loads(ctl("-j", "plugin", "list"))
    unloaded, unload_control = capture("unloaded-control")
    assert ImageChops.difference(baseline, unloaded).getbbox() is None, "Unload must restore baseline pixels"
    # A module's globals can outlive dlclose; a second load/unload must not retain
    # old hook pointers after Hyprland has deleted the corresponding objects.
    assert ctl("plugin", "load", str(OUT / "native-fit.so")) == "ok"
    checked_plugin_image()
    assert ctl("eval", 'hl.plugin.tessarchy_fit.target("tessarchy-native-fit-fixture")') == "ok"
    _, reload_control = capture("reloaded-fitted")
    assert reload_control["red_pixels"] > 1000
    pointer_reloaded = click([400 / scale, 200 / scale])
    assert ctl("eval", 'hl.plugin.tessarchy_fit.target("")') == "ok"
    assert ctl("plugin", "unload", str(OUT / "native-fit.so")) == "ok"
    restored, reload_unload_control = capture("reloaded-unloaded-control")
    assert ImageChops.difference(baseline, restored).getbbox() is None
    assert not json.loads(ctl("-j", "plugin", "list"))
    current = json.loads(ctl("-j", "clients"))
    assert any(c["pid"] == state["client_pid"] for c in current), "Original fixture process must survive all controls"
    parent_instances = json.loads(subprocess.check_output(["hyprctl", "-j", "instances"], text=True))
    assert any(i["pid"] == state["parent_pid"] for i in parent_instances)
    receipt = {"status": "PASS", "compositor_pid": state["compositor_pid"], "client_pid": state["client_pid"],
               "native": [832, 800], "allocation": [410, 800], "fit_scale": scale,
               "baseline": red, "fitted": green, "pointer_control": pointer_control,
               "pointer_fitted": pointer_fit, "pointer_disabled": pointer_disabled,
               "repeat_captures": cycles, "disable_control": control, "unload_control": unload_control,
               "reload_fitted": reload_control, "pointer_reloaded": pointer_reloaded,
               "reload_unload_control": reload_unload_control,
               "not_verified": ["touch", "popups/subsurfaces", "rotation", "fractional output scale", "real desktop apps", "OSK/IME", "incremental damage"]}
    (session / "proof.json").write_text(json.dumps(receipt, indent=2))
    combined = Image.new("RGB", (baseline.width * 2 + 12, baseline.height + 28), "#101010")
    combined.paste(baseline, (0, 28))
    combined.paste(fitted, (baseline.width + 12, 28))
    draw = ImageDraw.Draw(combined)
    draw.text((8, 8), "Before: native right edge clipped", fill="white")
    draw.text((baseline.width + 20, 8), "Prototype: whole native client fitted", fill="white")
    combined.save(session / "comparison.png")
    print(json.dumps(receipt, indent=2))
    print("EVIDENCE", session)


if __name__ == "__main__":
    main()
