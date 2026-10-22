#!/usr/bin/env python3
"""Exercise shutdown failure and explicit-release gates with deliberate scratch defects."""
import hashlib
import json
import os
from pathlib import Path
import resource
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HEADERS = ROOT / 'patches/hyprland/shutdown'
OUTPUT = ROOT / 'build/native-fit/shutdown-controls'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    receipt = OUTPUT / 'verification.json'
    receipt.unlink(missing_ok=True)
    names = ['ShutdownSequence.hpp', 'SubmittedWork.hpp', 'ScopedReadable.hpp']
    before = {name: digest(HEADERS / name) for name in names}
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'wayland-server', 'hyprutils'], text=True))
    cases = [
        ('failed-drain-reaches-release', 'ShutdownSequence.hpp',
         'if (!std::forward<Drain>(drain)(deadline))\n                    std::_Exit(EXIT_FAILURE);',
         '(void)std::forward<Drain>(drain)(deadline);',
         '''#include "ShutdownSequence.hpp"
int main() {
    NativeShutdown::CShutdownSequence sequence;
    sequence.run(std::chrono::steady_clock::now(), [] {}, [](auto) { return false; }, [] { std::_Exit(42); }, [] {});
    return 43;
}
''', 1, 42),
        ('explicit-release-context-bypassed', 'SubmittedWork.hpp',
         'if (!state->beforeRetire(it->second->payload)) {', 'if (false) {',
         '''#include "SubmittedWork.hpp"
struct Payload {};
int main() {
    NativeRetirement::CSubmittedWork<Payload> queue([](int) { return NativeRetirement::EFence::COMPLETE; }, [](Payload&) { return false; });
    auto id = queue.submit({}, {}, [] { std::_Exit(42); });
    if (queue.drain(std::chrono::steady_clock::now()) || !queue.failed(id) || queue.size() != 1)
        std::_Exit(43);
    std::_Exit(0);
}
''', 0, 42),
    ]
    results = []
    for name, header, old, new, unit, green, red in cases:
        folder = OUTPUT / name
        folder.mkdir(exist_ok=True)
        original = (HEADERS / header).read_text()
        assert original.count(old) == 1, name
        statuses = []
        for broken in [False, True]:
            for item in names:
                text = (HEADERS / item).read_text()
                (folder / item).write_text(text.replace(old, new) if broken and item == header else text)
            source = folder / 'test.cpp'
            source.write_text(unit)
            binary = folder / ('red' if broken else 'green')
            subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++23', '-Wall', '-Wextra', '-Werror', '-g', '-fsanitize=address,undefined',
                            '-fno-omit-frame-pointer', str(source), *flags, '-o', str(binary)], check=True)
            result = subprocess.run([str(binary)], capture_output=True, text=True,
                                    preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_CORE, (0, 0)))
            (folder / ('red.log' if broken else 'green.log')).write_text(result.stdout + result.stderr)
            assert result.returncode == (red if broken else green), (name, broken, result.returncode, result.stderr)
            statuses.append(result.returncode)
        results.append({'name': name, 'production_exit': statuses[0], 'defect_exit': statuses[1]})
        print(f'PASS GREEN/RED {name}: {statuses}', flush=True)
    assert before == {name: digest(HEADERS / name) for name in names}
    receipt.write_text(json.dumps({'controls': results, 'production_header_hashes': before, 'production_headers_unchanged': True}, indent=2) + '\n')


if __name__ == '__main__':
    main()
