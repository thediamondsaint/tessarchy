#!/usr/bin/env python3
"""Require the native regressions to reject two deliberately broken primitives."""

import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PATCHES = ROOT / "patches/hyprland/shutdown"
OUTPUT = ROOT / "build/native-fit/core-controls"


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    receipt = OUTPUT / "verification.json"
    receipt.unlink(missing_ok=True)
    flags = shlex.split(subprocess.check_output(["pkg-config", "--cflags", "--libs", "wayland-server", "hyprutils"], text=True))
    compiler = os.environ.get("CXX", "c++")
    cases = [
        ("close-map-reentrancy", "ScopedReadable.hpp", "test-scoped-readable.cpp",
         "auto waiters = std::move(state->waiters);", "state->waiters.clear();",
         ["AddressSanitizer: heap-use-after-free", "closureDestructionCancelsSibling"]),
        ("terminal-not-consumed", "TerminalDelivery.hpp", "test-terminal-delivery.cpp",
         "if (std::exchange(state->terminal, true))\n            return false;", "state->terminal = true;",
         ["double terminal accepted"]),
    ]
    results = []
    for name, header, test, old, new, diagnostics in cases:
        original = (PATCHES / header).read_text()
        assert original.count(old) == 1, f"Mutation anchor changed: {name}"
        digest = hashlib.sha256(original.encode()).hexdigest()
        folder = OUTPUT / name
        folder.mkdir(exist_ok=True)
        mutated = folder / header
        mutated.write_text(original.replace(old, new, 1))
        unit = (ROOT / "tests/native-fit" / test).read_text()
        include = f'#include "../../patches/hyprland/shutdown/{header}"'
        assert unit.count(include) == 1, f"Include anchor changed: {name}"
        source = folder / test
        source.write_text(unit.replace(include, f'#include "{mutated}"', 1))
        binary = folder / "test"
        subprocess.run([compiler, "-std=c++23", "-Wall", "-Wextra", "-Werror", "-g", "-fsanitize=address,undefined",
                        "-fno-omit-frame-pointer", str(source), *flags, "-o", str(binary)], check=True)
        env = os.environ.copy()
        env["ASAN_OPTIONS"] = "abort_on_error=0:disable_coredump=1:detect_leaks=1"
        result = subprocess.run([str(binary)], env=env, capture_output=True, text=True)
        log = result.stdout + result.stderr
        (folder / "result.log").write_text(log)
        assert result.returncode == 1, f"Control returned {result.returncode}, expected diagnostic exit 1: {name}"
        assert all(text in log for text in diagnostics), f"Control failed for an unexpected reason: {name}"
        assert hashlib.sha256((PATCHES / header).read_bytes()).hexdigest() == digest, "Production header changed"
        results.append({"name": name, "expected_exit": 1, "actual_exit": result.returncode,
                        "diagnostics": diagnostics, "production_header_unchanged": True})
        print(f"PASS RED control {name}", flush=True)
    receipt.write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
