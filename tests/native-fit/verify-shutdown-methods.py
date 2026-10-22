#!/usr/bin/env python3
"""Compile exact overlay shutdown method bodies against explicit CPU-only dependencies."""
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'build/native-fit/shutdown-methods'
OVERLAY = ROOT / 'build/native-fit/core-shutdown/source'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def extract(text, signature):
    start = text.index(signature)
    opening = text.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end] + '\n'


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    receipt = OUTPUT / 'verification.json'
    receipt.unlink(missing_ok=True)
    build_receipt = ROOT / 'build/native-fit/core-shutdown/verification.json'
    build = json.loads(build_receipt.read_text())
    for name, value in {**build['patch_hashes'], **build['header_hashes']}.items():
        assert digest(ROOT / 'patches/hyprland/shutdown' / name) == value, name
    for name, value in build['overlay_source_hashes'].items():
        assert digest(OVERLAY / name) == value, name
    methods = {
        'src/managers/screenshare/ScreenshareManager.cpp': ['void CScreenshareManager::quiesceForShutdown()', 'void CScreenshareManager::releaseShutdownResources()'],
        'src/render/GLRenderer.cpp': ['bool CHyprGLRenderer::checkedContext()', 'bool CHyprGLRenderer::retireResources(SSubmittedResources& resources)'],
    }
    generated = ''.join(extract((OVERLAY / name).read_text(), signature) for name, signatures in methods.items() for signature in signatures)
    include = OUTPUT / 'shutdown-methods.inc'
    include.write_text(generated)
    unit = ROOT / 'tests/native-fit/test-shutdown-methods.cpp'
    binary = OUTPUT / 'test'
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'hyprutils'], text=True))
    subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++23', '-Wall', '-Wextra', '-Werror', '-g', '-fsanitize=address,undefined',
                    '-fno-omit-frame-pointer', '-I', str(OUTPUT), str(unit), *flags, '-o', str(binary)], check=True)
    result = subprocess.run([str(binary)], capture_output=True, text=True)
    (OUTPUT / 'result.log').write_text(result.stdout + result.stderr)
    print(result.stdout + result.stderr, end='', flush=True)
    result.check_returncode()
    receipt.write_text(json.dumps({'source_hashes': {name: digest(OVERLAY / name) for name in methods}, 'test_hash': digest(unit),
                                   'extracted_methods_hash': digest(include), 'patch_hashes': build['patch_hashes'], 'sanitizers': ['address', 'undefined'],
                                   'actual_gpu_or_egl': False}, indent=2) + '\n')


if __name__ == '__main__':
    main()
