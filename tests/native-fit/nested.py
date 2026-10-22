#!/usr/bin/env python3
"""Bounded isolated compositor/fixture session; no live config or account data."""
import argparse
import json
import os
from pathlib import Path
import signal
import socket
import stat
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
CONFIG = '''hl.monitor({output="", mode="410x800", position="auto", scale=1})
hl.config({
 general={gaps_in=0,gaps_out=0,border_size=0,layout="dwindle"},
 decoration={rounding=0,blur={enabled=false},shadow={enabled=false}},
 animations={enabled=false}, xwayland={enabled=false},
 misc={disable_hyprland_logo=true,disable_splash_rendering=true,force_default_wallpaper=0},
 debug={damage_tracking=0,disable_logs=false,vfr=false},
 input={kb_layout="us",follow_mouse=1}
})
'''


def wait_until(action, predicate, proc, seconds=15):
    deadline = time.monotonic() + seconds
    last = None
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            raise RuntimeError(f"Compositor exited {proc.returncode}")
        try:
            last = action()
            if predicate(last):
                return last
        except (subprocess.SubprocessError, ValueError, OSError):
            pass
        time.sleep(0.1)
    raise RuntimeError(f"Readiness condition timed out; last result: {last}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=int, default=900)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 3600:
        parser.error("--seconds must be 1..3600")
    binary = ROOT / "build/native-fit/oversized-client"
    if not binary.is_file():
        raise SystemExit("Run tests/native-fit/build.py first")
    parent_runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not parent_runtime:
        raise SystemExit("XDG_RUNTIME_DIR is unavailable")
    instances = json.loads(subprocess.check_output(["hyprctl", "-j", "instances"], text=True))
    valid = [i for i in instances if i.get("wl_socket") and
             Path(parent_runtime, i["wl_socket"]).is_socket()]
    if len(valid) != 1:
        raise SystemExit("Require exactly one discoverable parent compositor; refusing to guess")
    parent_socket = Path(parent_runtime, valid[0]["wl_socket"])
    if not stat.S_ISSOCK(parent_socket.stat().st_mode):
        raise SystemExit("Parent display is not a socket")
    out = ROOT / "build/native-fit"
    session = Path(tempfile.mkdtemp(prefix="nested-", dir=out))
    env = os.environ.copy()
    for key in ("HYPRLAND_INSTANCE_SIGNATURE", "DISPLAY", "NOTIFY_SOCKET", "DBUS_STARTER_ADDRESS", "DBUS_STARTER_BUS_TYPE"):
        env.pop(key, None)
    for key, subdir in (("HOME", "home"), ("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
                        ("XDG_STATE_HOME", "state"), ("XDG_CACHE_HOME", "cache"), ("XDG_RUNTIME_DIR", "run")):
        path = session / subdir
        path.mkdir(mode=0o700)
        env[key] = str(path)
    # Short private runtime avoids AF_UNIX event-socket path truncation.
    runtime = Path(tempfile.mkdtemp(prefix="t77-"))
    env["XDG_RUNTIME_DIR"] = str(runtime)
    env.update(WAYLAND_DISPLAY=str(parent_socket), LIBSEAT_BACKEND="seatd",
               SEATD_SOCK=str(runtime / "no-seatd.sock"),
               DBUS_SESSION_BUS_ADDRESS=f"unix:path={runtime}/no-session-bus",
               HYPRLAND_NO_SD_VARS="1", HYPRLAND_NO_SD_NOTIFY="1", TESSARCHY_FIT_PROTOTYPE="1")
    config = session / "hyprland.lua"
    config.write_text(CONFIG)
    (out / "latest-session.txt").write_text(str(session) + "\n")
    subprocess.run(["Hyprland", "--config", str(config), "--verify-config"], env=env, check=True)
    processes = []
    try:
        with (session / "compositor.log").open("w") as log:
            compositor = subprocess.Popen(["Hyprland", "--config", str(config)], env=env,
                                          stdout=log, stderr=subprocess.STDOUT)
        processes.append(compositor)
        def instance_list():
            return json.loads(subprocess.check_output(["hyprctl", "-j", "instances"], env=env, text=True, stderr=subprocess.DEVNULL, timeout=2))
        child = wait_until(instance_list, lambda xs: any(x.get("pid") == compositor.pid for x in xs), compositor)
        child = next(x for x in child if x.get("pid") == compositor.pid)
        env.update(HYPRLAND_INSTANCE_SIGNATURE=child["instance"], WAYLAND_DISPLAY=child["wl_socket"])
        def ctl(*command):
            return subprocess.check_output(["hyprctl", *command], env=env, text=True, stderr=subprocess.DEVNULL, timeout=3)
        # A responding IPC server may have no nested Wayland output yet.
        wait_until(lambda: json.loads(ctl("-j", "version")), lambda v: bool(v.get("commit")), compositor)
        errors = [error for error in json.loads(ctl("-j", "configerrors")) if error.strip()]
        if errors:
            raise RuntimeError(f"Nested configuration errors: {errors}")
        result = ctl("output", "create", "headless", "FIT-1").strip()
        if result != "ok":
            raise RuntimeError(f"Headless creation failed: {result}")
        monitors = wait_until(lambda: json.loads(ctl("-j", "monitors")),
                              lambda ms: any(m["name"] == "FIT-1" for m in ms), compositor)
        lua = 'hl.monitor({output="FIT-1",mode="410x800",position="auto",scale=1});'
        for monitor in monitors:
            if monitor["name"] != "FIT-1":
                lua += 'hl.monitor({output=' + json.dumps(monitor["name"]) + ',disabled=true});'
        # Plugin loading reloads Lua; preserve the output policy in that file,
        # rather than relying solely on ephemeral eval changes.
        staged_config = config.with_suffix(".lua.new")
        staged_config.write_text(CONFIG + "\n" + lua + "\n")
        staged_config.replace(config)
        if ctl("eval", lua).strip() != "ok":
            raise RuntimeError("Could not configure isolated output")
        monitors = wait_until(lambda: json.loads(ctl("-j", "monitors")),
            lambda ms: len(ms) == 1 and ms[0]["name"] == "FIT-1" and ms[0]["width"] == 410 and ms[0]["height"] == 800,
            compositor)
        state = {"compositor_pid": compositor.pid, "instance": child["instance"],
                 "parent_pid": valid[0]["pid"], "parent_socket": str(parent_socket),
                 "session": str(session), "environment": {k: env[k] for k in
                 ("HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR",
                  "HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS")}}
        (session / "session.json").write_text(json.dumps(state, indent=2))
        with (session / "client.log").open("w") as log:
            client = subprocess.Popen([str(binary)], env=env, stdout=log, stderr=subprocess.STDOUT)
        processes.append(client)
        clients = wait_until(lambda: json.loads(ctl("-j", "clients")),
                            lambda cs: any(c.get("pid") == client.pid for c in cs), compositor)
        state.update(client_pid=client.pid, monitors=monitors, clients=clients)
        (session / "session.json").write_text(json.dumps(state, indent=2))
        print(json.dumps({"ready": True, "session": str(session), "pid": compositor.pid,
                          "client_pid": client.pid, "monitors": monitors}), flush=True)
        deadline = time.monotonic() + args.seconds
        def stopping(signum, frame):
            nonlocal deadline
            deadline = 0
        signal.signal(signal.SIGTERM, stopping)
        signal.signal(signal.SIGINT, stopping)
        while time.monotonic() < deadline:
            if compositor.poll() is not None or client.poll() is not None:
                raise RuntimeError("Nested process exited before session completion")
            time.sleep(0.25)
    finally:
        (session / "teardown.json").write_text(json.dumps(
            [{"pid": p.pid, "exit_before_cleanup": p.poll()} for p in processes], indent=2))
        for proc in reversed(processes):
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=3)
        print(f"Nested session stopped; evidence retained at {session}", flush=True)


if __name__ == "__main__":
    main()
