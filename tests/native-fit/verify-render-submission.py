#!/usr/bin/env python3
"""Execute actual endRender wiring with CPU dependencies; never start a compositor."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'build/native-fit/render-submission'
PATCHES = ROOT / 'patches/hyprland/shutdown'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    args = parser.parse_args()
    source = args.source.resolve()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    receipt = OUTPUT / 'verification.json'
    receipt.unlink(missing_ok=True)
    core = load('native_core_build', ROOT / 'tests/native-fit/build-core.py')
    methods = load('native_shutdown_methods', ROOT / 'tests/native-fit/verify-shutdown-methods.py')
    before = {name: digest(source / name) for name in core.SOURCE_FILES}
    patch_hashes = {path.name: digest(path) for path in PATCHES.glob('*.patch')}
    header_hashes = {path.name: digest(path) for path in PATCHES.glob('*.hpp')}
    overlay_output = ROOT / 'build/native-fit/core-shutdown'
    (overlay_output / 'verification.json').unlink(missing_ok=True)
    overlay = core.prepare(source, overlay_output)
    text = (overlay / 'src/render/GLRenderer.cpp').read_text()
    generated = ''.join(methods.extract(text, signature) for signature in [
        'bool CHyprGLRenderer::retireResources(SSubmittedResources& resources)',
        'void CHyprGLRenderer::endRender(const std::function<void()>& renderingDoneCallback)'])
    include = OUTPUT / 'render-submission.inc'
    include.write_text(generated)
    unit = ROOT / 'tests/native-fit/test-render-submission.cpp'
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'hyprutils', 'wayland-server'], text=True))

    def compile_run(label, content):
        directory = OUTPUT / label
        directory.mkdir(exist_ok=True)
        (directory / include.name).write_text(content)
        binary = directory / 'test'
        subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++23', '-Wall', '-Wextra', '-Werror', '-g',
                        '-fsanitize=address,undefined', '-fno-omit-frame-pointer', '-I', str(directory), '-I', str(PATCHES),
                        str(unit), *flags, '-o', str(binary)], check=True)
        result = subprocess.run([str(binary)], capture_output=True, text=True)
        (directory / 'result.log').write_text(result.stdout + result.stderr)
        return result

    green = compile_run('green', generated)
    print(green.stdout + green.stderr, end='', flush=True)
    green.check_returncode()
    controls = [
        ('fake-early-return', '    auto eglSync = createSyncFDManager();',
         '    if (m_renderMode == RENDER_MODE_FULL_FAKE) return;\n    auto eglSync = createSyncFDManager();', 'every render path submits ownership'),
        ('implicit-early-success', '        resources.sources = std::move(m_usedAsyncBuffers);\n        m_submittedWork.submit(std::move(resources), {}, {});',
         '        if (renderingDoneCallback) renderingDoneCallback();\n        resources.sources = std::move(m_usedAsyncBuffers);\n        m_submittedWork.submit(std::move(resources), {}, {});', 'no early completion or explicit release'),
        ('missing-explicit-import', '                releaser->addSyncFileFd(eglSync->fd());',
         '                (void)releaser;', 'explicit release points imported before source unlock'),
        ('lost-transient-release', '    resources.explicitReleases = std::move(m_pendingFBReleases);',
         '    m_pendingFBReleases.clear();', 'explicit temporary framebuffer retained'),
    ]
    rejected = []
    for label, old, new, assertion in controls:
        assert generated.count(old) == 1, label
        result = compile_run(label, generated.replace(old, new))
        assert result.returncode != 0 and assertion in result.stderr, (label, result.stdout, result.stderr)
        rejected.append(label)
        print('PASS exact RED:', label, flush=True)
    checked = core.syntax_check(source, overlay)
    assert before == {name: digest(source / name) for name in before}
    assert patch_hashes == {path.name: digest(path) for path in PATCHES.glob('*.patch')}
    assert header_hashes == {path.name: digest(path) for path in PATCHES.glob('*.hpp')}
    receipt.write_text(json.dumps({'cases': 96, 'red_controls': rejected, 'test_hash': digest(unit),
        'runner_hash': digest(Path(__file__)), 'extracted_hash': digest(include), 'patch_hashes': patch_hashes,
        'header_hashes': header_hashes, 'original_source_hashes': before, 'original_source_unchanged': True,
        'overlay_source_hashes': {name: digest(overlay / name) for name in before}, 'syntax_checked': checked,
        'sanitizers': ['address', 'undefined'], 'fence_success': 'injected; eventfd is not a native sync_file',
        'actual_gpu_or_egl': False}, indent=2) + '\n')
    print('PASS current-source receipt:', receipt, flush=True)


if __name__ == '__main__':
    main()
