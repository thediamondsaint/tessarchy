"""Scratch-only real libalpm ownership probe; never uses the host package DB."""
import ctypes
import io
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tarfile
import tempfile

PACKAGE = 'tessarchy-source-probe'
PREFIX = 'usr/share/tessarchy-probe/'
NAMES = ['shell.qml', 'helper.py', 'hyprland.lua']
libc = ctypes.CDLL(None, use_errno=True)


def archive(base, version, names):
    target = base / f'{PACKAGE}-{version}-any.pkg.tar.gz'
    entries = {PREFIX + n: f'version={version}\n'.encode() for n in names}
    entries['.PKGINFO'] = (
        f'pkgname = {PACKAGE}\npkgbase = {PACKAGE}\npkgver = {version}\n'
        'pkgdesc = Isolated source ownership fixture\nurl = https://example.invalid\n'
        f'builddate = 0\npackager = Test fixture\nsize = {sum(map(len, entries.values()))}\narch = any\n'
    ).encode()
    with tarfile.open(target, 'w:gz') as tf:
        for name, data in entries.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            info.mode = 0o644
            tf.addfile(info, io.BytesIO(data))
    return target


def probe(base, noupgrade):
    base.mkdir()
    root, db, cache, gpg, hooks = [base / n for n in ('root', 'db', 'cache', 'gpg', 'hooks')]
    for p in (root, db, cache, gpg, hooks):
        p.mkdir()
    # Override ALL installed host hooks; no host commands may run from this test.
    for folder in ('/usr/share/libalpm/hooks', '/etc/pacman.d/hooks'):
        for hook in Path(folder).glob('*.hook'):
            override = hooks / hook.name
            if not override.is_symlink():
                override.symlink_to('/dev/null')
    conf = base / 'pacman.conf'
    conf.write_text('[options]\nArchitecture = auto\nSigLevel = Never\nLocalFileSigLevel = Never\n' +
                    (f'NoUpgrade = {PREFIX}*\n' if noupgrade else ''))
    common = ['fakeroot', 'pacman', '--root', str(root), '--dbpath', str(db),
              '--config', str(conf), '--cachedir', str(cache), '--gpgdir', str(gpg),
              '--hookdir', str(hooks), '--logfile', str(base / 'pacman.log'),
              '--noconfirm', '--noprogressbar', '--disable-sandbox']

    def install(version, names):
        pkg = archive(base, version, names)
        r = subprocess.run(common + ['--noscriptlet', '-U', str(pkg)],
                           capture_output=True, text=True, timeout=15)
        if r.returncode:
            raise RuntimeError(r.stdout + r.stderr)

    install('1-1', NAMES)
    directory = root / PREFIX
    fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
    assert fd >= 0
    try:
        assert libc.inotify_add_watch(fd, os.fsencode(directory), 0x00000200 | 0x00000100 | 0x00000008) >= 0

        def events():
            try:
                data = os.read(fd, 65536)
            except BlockingIOError:
                return []
            result = []
            offset = 0
            while offset < len(data):
                wd, mask, cookie, length = struct.unpack_from('iIII', data, offset)
                offset += 16
                name = data[offset:offset + length].split(b'\0')[0].decode()
                offset += length
                result.append({'name': name, 'mask': mask})
            return result

        install('2-1', NAMES)
        upgrade_events = events()
        result = {'NoUpgrade': noupgrade,
                  'upgrade_events': upgrade_events,
                  'original_content_after_upgrade': (directory / 'shell.qml').read_text().strip(),
                  'pacnew_created': (directory / 'shell.qml.pacnew').is_file()}
        install('3-1', ['shell.qml', 'hyprland.lua'])
        result['dropped_helper_exists'] = (directory / 'helper.py').exists()
        result['drop_events'] = events()
        q = subprocess.run(['pacman', '--root', str(root), '--dbpath', str(db),
                            '--config', str(conf), '-Q', PACKAGE],
                           capture_output=True, text=True, timeout=10)
        if q.returncode:
            raise RuntimeError(q.stdout + q.stderr)
        result['private_db_version'] = q.stdout.strip()
        return result
    finally:
        os.close(fd)


if __name__ == '__main__':
    assert all(shutil.which(x) for x in ('pacman', 'fakeroot'))
    with tempfile.TemporaryDirectory(prefix='tessarchy-pacman-probe-') as t:
        result = [probe(Path(t) / 'ordinary', False), probe(Path(t) / 'noupgrade', True)]
        print(json.dumps({'real_pacman': True, 'private_root_and_database': True,
                          'all_host_hooks_masked': True, 'cases': result}, indent=2))
