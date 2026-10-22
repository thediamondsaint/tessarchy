#!/usr/bin/env python3
"""Exercise global cancellation reentrancy using actual overlay methods and CPU owners."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'build/native-fit/teardown-producers'


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tests/native-fit' / filename)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    args = parser.parse_args()
    core = load('core', 'build-core.py')
    methods = load('methods', 'verify-shutdown-methods.py')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    receipt = OUTPUT / 'verification.json'
    receipt.unlink(missing_ok=True)
    (ROOT / 'build/native-fit/core-shutdown/verification.json').unlink(missing_ok=True)
    source = args.source.resolve()
    before = {name: core.digest(source / name) for name in core.SOURCE_FILES}
    overlay = core.prepare(source, ROOT / 'build/native-fit/core-shutdown')
    path = overlay / 'src/managers/screenshare/ScreenshareManager.cpp'
    text = path.read_text()
    code = ''.join(methods.extract(text, signature) for signature in [
        'void CScreenshareManager::quiesceForShutdown()',
        'void CScreenshareManager::releaseShutdownResources()',
    ])
    unit = ROOT / 'tests/native-fit/test-teardown-producers.cpp'
    include = OUTPUT / 'teardown-methods.inc'
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'hyprutils', 'wayland-server'], text=True))
    command = [os.environ.get('CXX', 'c++'), '-std=c++23', '-Wall', '-Wextra', '-Werror', '-g',
               '-fsanitize=address,undefined', '-fno-omit-frame-pointer', '-I', str(OUTPUT), '-I', str(core.PATCHES), str(unit), *flags]
    # Each scratch control delays marking until after the first closure destruction.
    ordinary = '''    for (auto& session : m_sessions) {
        if (!session)
            continue;
        session->m_stopped = true;
        session->m_sharing = false;
    }
'''
    cursor = '''    for (auto& session : m_cursorSessions) {
        if (session)
            session->m_stopped = true;
    }
'''
    frame = '''    for (auto& frame : m_pendingFrames) {
        if (frame)
            frame->m_failed = true;
    }
'''
    anchor = '    for (auto& managed : m_managedSessions)\n        managed->stoppedListener.reset();\n'
    variants: list[tuple[str, str, str | None]] = [('green', code, None)]
    for name, block, assertion in [
        ('red-late-session-stop', ordinary, 'all native owners must be inert before callback destruction'),
        ('red-late-cursor-stop', cursor, 'all cursor owners must be inert before callback destruction'),
        ('red-late-frame-failure', frame, 'all frames must be failed before callback destruction'),
    ]:
        assert code.count(block) == 1 and code.count(anchor) == 1
        variants.append((name, code.replace(block, '').replace(anchor, anchor + block), assertion))
    results = {}
    for name, contents, expected in variants:
        include.write_text(contents)
        binary = OUTPUT / name
        subprocess.run([*command, '-o', str(binary)], check=True)
        result = subprocess.run([str(binary)], capture_output=True, text=True)
        log = result.stdout + result.stderr
        (OUTPUT / (name + '.log')).write_text(log)
        print(name, result.returncode, log, flush=True)
        if expected:
            assert result.returncode != 0 and expected in log, log
        else:
            result.check_returncode()
        results[name] = result.returncode
    include.write_text(code)
    checked = core.syntax_check(source, overlay)
    assert before == {name: core.digest(source / name) for name in before}
    receipt.write_text(json.dumps({
        'results': results, 'test_hash': core.digest(unit), 'runner_hash': core.digest(Path(__file__)),
        'extracted_methods_hash': core.digest(include),
        'overlay_source_hashes': {name: core.digest(overlay / name) for name in core.SOURCE_FILES},
        'header_hashes': {name: core.digest(core.PATCHES / name) for name in core.HEADERS},
        'patch_hashes': {p.name: core.digest(p) for p in core.PATCHES.glob('*.patch')},
        'original_source_hashes': before, 'original_source_unchanged': True,
        'syntax_checked': checked, 'sanitizers': ['address', 'undefined'],
        'compositor_or_gpu_launched': False,
        'dependencies': 'real Hyprutils owners/signals and Wayland timers; CPU native resource mocks',
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
