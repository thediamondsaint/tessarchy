#!/usr/bin/env python3
"""Bundle locally built tablet packages and their checksums without installing them."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PACKAGES = ('tessera-shell-0.1.0-4-any.pkg.tar.zst',
            'tessarchy-session-0.1.0-5-any.pkg.tar.zst',
            'tessarchy-bootsplash-0.1.0-2-any.pkg.tar.zst',
            'tessarchy-tablet-0.1.0-3-x86_64.pkg.tar.zst')


def source_identity():
    """Verify the built packages match the current, clean checkout.

    package.sh records the commit it built from; bundling from a different or
    dirty checkout would otherwise label stale files with a new revision.
    """
    identity = ROOT / 'dist' / 'SOURCE.json'
    if not identity.is_file():
        raise SystemExit('error: dist/SOURCE.json missing — build with scripts/package.sh first')
    recorded = json.loads(identity.read_text()).get('commit')
    if not recorded:
        raise SystemExit('error: dist/SOURCE.json records no source commit')
    current = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if recorded != current:
        raise SystemExit('error: packages were built from ' + recorded + ' but the checkout is at ' + current + ' — rebuild with scripts/package.sh')
    changes = subprocess.check_output(['git', 'status', '--porcelain',
                                       '--untracked-files=no'], cwd=ROOT, text=True)
    if changes:
        raise SystemExit('error: refuse to bundle a dirty source tree:\n' + changes)
    return recorded


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists() or args.output.is_symlink():
        parser.error('Choose a new output path')
    commit = source_identity()
    for name in PACKAGES:
        path = ROOT / 'dist' / name
        if not path.is_file() or path.is_symlink():
            parser.error('Missing built package: ' + name)
        files = subprocess.check_output(['bsdtar', '-tf', str(path)], text=True)
        if '__pycache__' in files or any(f.endswith(('.pyc', '.pyo')) for f in files.splitlines()):
            parser.error('Bytecode cache in package: ' + name)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        stage = Path(temporary)
        (stage / 'dist').mkdir()
        for name in PACKAGES:
            shutil.copy2(ROOT / 'dist' / name, stage / 'dist' / name)
        shutil.copy2(ROOT / 'docs/tablet-install.md', stage / 'INSTALL.md')
        (stage / 'SOURCE.json').write_text(json.dumps({'source_commit': commit,
            'platform': 'Arch Linux x86_64 Intel/AMD', 'packages': PACKAGES,
            'installs_automatically': False}, indent=2) + '\n')
        sums = [hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.relative_to(stage).as_posix()
                for p in sorted(stage.rglob('*')) if p.is_file()]
        (stage / 'SHA256SUMS').write_text('\n'.join(sums) + '\n')
        with tarfile.open(args.output, 'x:gz') as archive:
            for path in sorted(stage.rglob('*')):
                if path.is_file():
                    archive.add(path, arcname=path.relative_to(stage).as_posix())
    print('Tablet install bundle: ' + str(args.output))


if __name__ == '__main__':
    main()
