#!/usr/bin/env python3
"""Execute exact ordinary protocol frame methods with CPU-only native dependencies."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'build/native-fit/child-lifetime'
OVERLAY = ROOT / 'build/native-fit/core-shutdown/source'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, help='Prepare and syntax-check the overlay without rerunning unchanged primitive suites')
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('core', ROOT / 'tests/native-fit/build-core.py')
    assert spec and spec.loader
    core = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(core)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    receipt = OUTPUT / 'verification.json'
    receipt.unlink(missing_ok=True)
    inputs = [*core.SOURCE_FILES, 'protocols/ext-image-copy-capture-v1.cpp', 'protocols/ext-image-copy-capture-v1.hpp']
    before = {name: core.digest(args.source / name) for name in inputs} if args.source else {}
    checked = []
    if args.source:
        (ROOT / 'build/native-fit/core-shutdown/verification.json').unlink(missing_ok=True)
        mirror = core.prepare(args.source.resolve(), ROOT / 'build/native-fit/core-shutdown')
        checked = core.syntax_check(args.source.resolve(), mirror)
        assert before == {name: core.digest(args.source / name) for name in before}
    spec = importlib.util.spec_from_file_location('methods', ROOT / 'tests/native-fit/verify-shutdown-methods.py')
    assert spec and spec.loader
    methods = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(methods)
    source = OVERLAY / 'src/protocols/ImageCopyCapture.cpp'
    header = OVERLAY / 'src/protocols/ImageCopyCapture.hpp'
    text = source.read_text()
    definitions = text[text.index('SCursorCaptureState::~SCursorCaptureState()'):].splitlines()[0] + '\n' + ''.join(methods.extract(text, signature) for signature in [
        'CImageCopyCaptureSession::~CImageCopyCaptureSession()',
        'void CImageCopyCaptureSession::detachResource()',
        'CImageCopyCaptureFrame::CImageCopyCaptureFrame(',
        'CImageCopyCaptureFrame::~CImageCopyCaptureFrame()',
        'bool CImageCopyCaptureFrame::good()',
        'void CImageCopyCaptureProtocol::destroyResource(CImageCopyCaptureSession* resource)',
        'void CImageCopyCaptureProtocol::destroyResource(CImageCopyCaptureFrame* resource)',
        'CImageCopyCaptureCursorSession::CImageCopyCaptureCursorSession(',
        'CImageCopyCaptureCursorSession::~CImageCopyCaptureCursorSession()',
        'bool CImageCopyCaptureCursorSession::good()',
        'void CImageCopyCaptureCursorSession::destroyCaptureSession()',
        'void CImageCopyCaptureCursorSession::createFrame(',
        'CImageCopyCaptureCursorFrame::CImageCopyCaptureCursorFrame(',
        'CImageCopyCaptureCursorFrame::~CImageCopyCaptureCursorFrame()',
        'void CImageCopyCaptureProtocol::destroyResource(CImageCopyCaptureCursorSession* resource)',
        'void CImageCopyCaptureProtocol::destroyResource(CImageCopyCaptureCursorFrame* resource)',
    ])
    declarations = ''.join(methods.extract(header.read_text(), kind + ' ' + name + ' {').rstrip() + ';\n' for kind, name in [('class', 'CImageCopyCaptureFrame'), ('class', 'CImageCopyCaptureSession'), ('struct', 'SCursorCaptureState'), ('class', 'CImageCopyCaptureCursorFrame'), ('class', 'CImageCopyCaptureCursorSession')])
    (OUTPUT / 'child-declarations.inc').write_text(declarations)
    (OUTPUT / 'child-methods.inc').write_text(definitions)
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'hyprutils', 'wayland-server'], text=True))
    protocol = OVERLAY / 'protocols/ext-image-copy-capture-v1.cpp'
    protocol_header = OVERLAY / 'protocols/ext-image-copy-capture-v1.hpp'
    unit = ROOT / 'tests/native-fit/test-child-lifetime.cpp'
    command = [os.environ.get('CXX', 'c++'), '-std=c++23', '-Wall', '-Wextra', '-Werror', '-Wno-unused-parameter', '-g',
               '-fsanitize=address,undefined', '-fno-omit-frame-pointer', '-I', str(OUTPUT), '-I', str(protocol.parent), '-I', str(ROOT / 'patches/hyprland/shutdown'), str(unit), str(protocol), *flags]
    results = {}
    for name, code in [('green', definitions), ('red-parent-stop', definitions.replace('resource->detachResource();', 'resource->m_session->stop();\n    resource->detachResource();')),
                       ('red-weak-parent', definitions), ('red-parent-resource-retained', definitions.replace('auto resource = std::move(m_resource);', 'auto resource = m_resource;')),
                       ('red-cursor-native-reset', definitions.replace('    m_captureState.reset();', '    if (m_captureState) m_captureState->session.reset();\n    m_captureState.reset();')),
                       ('red-cursor-stop-erases-parent', definitions.replace('                m_sessionResource->sendStopped();', '                destroyCaptureSession();'))]:
        if name != 'green' and name != 'red-weak-parent':
            assert code != definitions, name
        decl = declarations
        if name == 'red-weak-parent':
            decl = decl.replace('SP<CImageCopyCaptureSession>       m_session;', 'WP<CImageCopyCaptureSession>       m_session;')
            assert decl != declarations
        (OUTPUT / 'child-declarations.inc').write_text(decl)
        (OUTPUT / 'child-methods.inc').write_text(code)
        binary = OUTPUT / name
        subprocess.run([*command, '-o', str(binary)], check=True)
        result = subprocess.run([str(binary)], capture_output=True, text=True)
        log = result.stdout + result.stderr
        (OUTPUT / (name + '.log')).write_text(log)
        print(name, result.returncode, log, flush=True)
        if name == 'green':
            result.check_returncode()
        else:
            expected = {
                'red-parent-resource-retained': 'parent destroy must destroy its protocol resource immediately',
                'red-cursor-native-reset': 'cursor parent destruction must preserve native child state',
                'red-cursor-stop-erases-parent': 'source stop must not destroy capture session or native owner inside its signal',
            }.get(name, 'parent destruction must preserve native child state')
            assert result.returncode != 0 and expected in log, log
        results[name] = result.returncode
    (OUTPUT / 'child-declarations.inc').write_text(declarations)
    (OUTPUT / 'child-methods.inc').write_text(definitions)
    if args.source:
        assert before == {name: core.digest(args.source / name) for name in before}
    receipt.write_text(json.dumps({'results': results, 'source_hash': core.digest(source), 'header_hash': core.digest(header),
                                  'overlay_source_hashes': {name: core.digest(OVERLAY / name) for name in core.SOURCE_FILES},
                                  'header_hashes': {name: core.digest(ROOT / 'patches/hyprland/shutdown' / name) for name in core.HEADERS},
                                  'runner_hash': core.digest(Path(__file__)),
                                  'test_hash': core.digest(unit), 'original_source_hashes': before, 'original_source_unchanged': bool(before),
                                  'syntax_checked': checked, 'patch_hashes': {p.name: core.digest(p) for p in (ROOT / 'patches/hyprland/shutdown').glob('*.patch')},
                                  'protocol_hashes': {p.name: core.digest(p) for p in (protocol, protocol_header)},
                                  'sanitizers': ['address', 'undefined'], 'native_dependencies': 'explicit CPU native mocks; actual generated protocol, Wayland dispatch and Hyprutils owners',
                                  'compositor_or_gpu_launched': False}, indent=2) + '\n')


if __name__ == '__main__':
    main()
