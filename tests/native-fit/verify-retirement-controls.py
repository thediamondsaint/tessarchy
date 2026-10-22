#!/usr/bin/env python3
"""Reject loss of submitted ownership and false native-fence success in scratch."""

import hashlib
import json
import os
from pathlib import Path
import resource
import shlex
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HEADERS = ROOT / "patches/hyprland/shutdown"
OUTPUT = ROOT / "build/native-fit/retirement-controls"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    receipt = OUTPUT / "verification.json"
    receipt.unlink(missing_ok=True)
    before = {name: digest(HEADERS / name) for name in ("ScopedReadable.hpp", "SubmittedWork.hpp")}
    flags = shlex.split(subprocess.check_output(["pkg-config", "--cflags", "--libs", "wayland-server", "hyprutils"], text=True))
    original = (HEADERS / "SubmittedWork.hpp").read_text()
    cases = [
        ("cancellation-releases-gpu-owners", "            it->second->waiter.reset();\n        }\n\n        void cancelAllDelivery()", "            it->second->waiter.reset();\n            m_state->records.erase(it);\n        }\n\n        void cancelAllDelivery()", "registry.size() == 0 && q.size() == 1"),
        ("ioctl-error-is-success", "if (fd < 0 || ioctl(fd, SYNC_IOC_FILE_INFO, &info) < 0)\n            return EFence::ERROR;", "if (fd < 0 || ioctl(fd, SYNC_IOC_FILE_INFO, &info) < 0)\n            return EFence::COMPLETE;", "nativeFenceStatus(fd.get()) == EFence::ERROR"),
    ]
    results = []
    for name, old, new, diagnostic in cases:
        assert original.count(old) == 1, name
        folder = OUTPUT / name
        folder.mkdir(exist_ok=True)
        (folder / "SubmittedWork.hpp").write_text(original.replace(old, new))
        (folder / "ScopedReadable.hpp").write_bytes((HEADERS / "ScopedReadable.hpp").read_bytes())
        source = folder / "test.cpp"
        unit = (ROOT / "tests/native-fit/test-submitted-work.cpp").read_text()
        source.write_text(unit.replace('#include "../../patches/hyprland/shutdown/SubmittedWork.hpp"', '#include "SubmittedWork.hpp"'))
        binary = folder / "test"
        subprocess.run([os.environ.get("CXX", "c++"), "-std=c++23", "-Wall", "-Wextra", "-Werror", "-g", "-fsanitize=address,undefined",
                        "-fno-omit-frame-pointer", str(source), *flags, "-o", str(binary)], check=True)
        env = os.environ.copy()
        env["ASAN_OPTIONS"] = "disable_coredump=1"
        result = subprocess.run([str(binary)], capture_output=True, text=True, env=env,
                                preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_CORE, (0, 0)))
        log = result.stdout + result.stderr
        (folder / "result.log").write_text(log)
        assert result.returncode == -signal.SIGABRT and diagnostic in log, f"Unexpected control result: {name}: {result.returncode}\n{log}"
        results.append({"name": name, "returncode": result.returncode, "required_diagnostic": diagnostic})
        print(f"PASS RED control {name}", flush=True)
    assert before == {name: digest(HEADERS / name) for name in before}
    receipt.write_text(json.dumps({"controls": results, "production_header_hashes": before, "production_headers_unchanged": True}, indent=2) + "\n")


if __name__ == "__main__":
    main()
