#!/usr/bin/env python3
"""Verify actual wl_touch events from a compositor-local synthetic AQ device."""
import argparse
import json
import math
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/native-fit"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--session", type=Path)
    args = parser.parse_args()
    session = (args.session or Path((OUT / "latest-session.txt").read_text().strip())).resolve(strict=True)
    assert session.parent == OUT.resolve() and session.name.startswith("nested-")
    state = json.loads((session / "session.json").read_text())
    assert state["compositor_pid"] != state["parent_pid"]
    env = os.environ.copy()
    env.update(state["environment"])
    env["TESSARCHY_FIT_INPUT_PROBE"] = "1"
    assert Path(env["XDG_RUNTIME_DIR"]).name.startswith("t77-")
    assert Path(env["HOME"]) == session / "home"
    instances = json.loads(subprocess.check_output(["hyprctl", "-j", "instances"], env=env, text=True))
    assert any(i["pid"] == state["compositor_pid"] and i["instance"] == state["instance"] for i in instances)

    def ctl(*args):
        return subprocess.check_output(["hyprctl", *args], env=env, text=True, stderr=subprocess.STDOUT, timeout=10).strip()

    def checked_plugin_image():
        lines = Path(f"/proc/{state['compositor_pid']}/maps").read_text().splitlines()
        mapped = [line for line in lines if str(OUT / "native-fit.so") in line]
        inode = str((OUT / "native-fit.so").stat().st_ino)
        assert mapped and all(line.split()[4] == inode for line in mapped), (
            "Stale plugin image: start a fresh private compositor after rebuilding; unload may retain the old DSO")

    client = next(c for c in json.loads(ctl("-j", "clients")) if c["pid"] == state["client_pid"])
    assert client["class"] == "tessarchy-native-fit-fixture" and not client["xwayland"]
    assert client["size"] == [410, 800]
    assert not json.loads(ctl("-j", "plugin", "list")), "Require an unloaded private compositor"
    log = session / "client.log"
    scale = min(1, 410 / 832, 800 / 800)

    def lua(code):
        result = ctl("eval", code)
        assert result == "ok", result

    def probe(action, *args):
        lua("hl.plugin.tessarchy_fit.touch(" + ",".join(json.dumps(a) for a in (action, *args)) + ")")

    def wait_for(predicate, message):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            text = log.read_text()
            if predicate(text):
                return text
            time.sleep(0.02)
        raise AssertionError(message + "\n" + log.read_text()[-2000:])

    def enable():
        offset = len(log.read_text())
        probe("enable")
        wait_for(lambda text: "TOUCH_READY" in text[offset:], "Fixture never bound wl_touch")

    def contact(id, divisor, broken_motion=False):
        start = len(log.read_text())
        down, move = [300, 100], [350, 150]
        probe("down", id, *down)
        probe("move", id, *move)
        probe("up", id)
        text = wait_for(lambda text: f"TOUCH_UP {id}\n" in text[start:], "No touch-up delivered")[start:]
        events = re.findall(r"TOUCH_(DOWN|MOTION|UP) (\d+)([^\n]*)", text)
        events = [(kind, [float(n) for n in coordinates.split()]) for kind, value, coordinates in events if int(value) == id]
        assert [kind for kind, _ in events] == ["DOWN", "MOTION", "UP"], events
        expected_down = [x / divisor for x in down]
        correct_move = [x / divisor for x in move]
        expected_move = [a + b - c for a, b, c in zip(expected_down, move, down)] if broken_motion else correct_move
        for (_, actual), expected in zip(events[:2], (expected_down, expected_move)):
            assert len(actual) == 2 and all(math.isclose(a, b, abs_tol=0.01) for a, b in zip(actual, expected)), (actual, expected)
        if broken_motion:
            assert not all(math.isclose(a, b, abs_tol=0.01) for a, b in zip(events[1][1], correct_move))
        return {"contact": id, "screen_down": down, "screen_move": move, "expected_down": expected_down,
                "expected_motion": expected_move, "actual_events": events, "motion_correction_disabled": broken_motion}

    def load():
        assert ctl("plugin", "load", str(OUT / "native-fit.so")) == "ok"
        checked_plugin_image()
        enable()

    def letterbox():
        start = len(log.read_text())
        probe("down", 98, 100, 600)
        probe("move", 98, 150, 650)
        probe("up", 98)
        contact(97, scale)
        touch_events = re.findall(r"TOUCH_(?:DOWN|MOTION|UP) 98[^\n]*", log.read_text()[start:])
        start = len(log.read_text())
        for x, y in [(100, 600), (400, 200)]:
            subprocess.run([str(OUT / "pointer-client"), str(x), str(y), "410", "800", str(state["compositor_pid"])],
                           env=env, check=True, timeout=10)
        def returned_to_content(text):
            events = re.findall(r"BUTTON 272 0 ([\d.-]+) ([\d.-]+)", text[start:])
            return bool(events) and all(math.isclose(float(a), b / scale, abs_tol=0.01) for a, b in zip(events[-1], (400, 200)))
        text = wait_for(returned_to_content, "Positive pointer barrier did not arrive")
        buttons = re.findall(r"BUTTON 272 [01] [^\n]+", text[start:])
        observed = {"black_area_touch_events": touch_events, "black_then_content_buttons": buttons}
        print("LETTERBOX_OBSERVATION", json.dumps(observed), flush=True)
        assert not touch_events and len(buttons) == 2, "Letterbox forwarded input to the fitted client"
        return observed

    load()
    baseline = contact(1, 1)
    lua('hl.plugin.tessarchy_fit.target("tessarchy-native-fit-fixture")')
    probe("motion_fix", False)
    red = contact(2, scale, broken_motion=True)
    probe("motion_fix", True)
    fitted = [contact(id, scale) for id in range(3, 6)]
    black_area = letterbox()
    lua('hl.plugin.tessarchy_fit.target("")')
    disabled = contact(6, 1)
    lua('hl.plugin.tessarchy_fit.target("tessarchy-native-fit-fixture")')
    start = len(log.read_text())
    probe("down", 99, 300, 100)
    assert ctl("plugin", "unload", str(OUT / "native-fit.so")) == "ok"
    wait_for(lambda text: "TOUCH_UP 99\n" in text[start:] and "TOUCH_REMOVED" in text[start:], "Unload left touch contact/device alive")
    assert not json.loads(ctl("-j", "plugin", "list"))
    load()
    lua('hl.plugin.tessarchy_fit.target("tessarchy-native-fit-fixture")')
    reloaded = contact(7, scale)
    start = len(log.read_text())
    assert ctl("plugin", "unload", str(OUT / "native-fit.so")) == "ok"
    wait_for(lambda text: "TOUCH_REMOVED" in text[start:], "Reloaded device was not removed")
    assert not json.loads(ctl("-j", "plugin", "list"))
    assert any(c["pid"] == state["client_pid"] for c in json.loads(ctl("-j", "clients")))
    devices = json.loads(ctl("-j", "devices"))
    assert "tessarchy-fit-private-touch" not in json.dumps(devices)
    result = {"status": "PASS", "source": "compositor-local synthetic Aquamarine ITouch; no uinput/kernel device",
              "baseline": baseline, "red_motion_control": red, "fitted_contacts": fitted, "letterbox": black_area, "disabled": disabled,
              "reloaded": reloaded, "unload_finishes_active_contact": True, "device_removed_after_unload": True,
              "not_verified": ["physical touch hardware", "libinput calibration", "multitouch", "touch cancellation", "popups/subsurfaces", "rotation"]}
    (session / "touch-proof.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
