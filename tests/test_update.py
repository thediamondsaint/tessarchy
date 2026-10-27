"""Tests for tessarchy-update — the tool an installed machine updates itself with.

Everything here runs against a real HTTP server on 127.0.0.1 serving a real
repository layout, and a stand-in `pacman` on PATH that records what it was
asked to do. Nothing touches this machine's packages.
"""
import contextlib
import functools
import http.server
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import threading
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
UPDATE = ROOT / 'session' / 'tessarchy-update'


def load_update():
    """The updater is an executable script, not an importable module."""
    loader = importlib.machinery.SourceFileLoader('tessarchy_update', str(UPDATE))
    spec = importlib.util.spec_from_loader('tessarchy_update', loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):  # keep the test output readable
        pass


def serve(directory: Path):
    """A real HTTP server on a free port, as a context manager root URL."""
    handler = functools.partial(QuietHandler, directory=str(directory))
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, f'http://127.0.0.1:{server.server_address[1]}'


FAKE_PACMAN = '''#!/usr/bin/env bash
set -u
printf '%s\\n' "$*" >> "$PACMAN_LOG"
case ${1:-} in
    -Q)
        shift
        for name in "$@"; do
            grep -m1 "^$name " "$PACMAN_DB" 2>/dev/null || true
        done
        ;;
    -Syu|-Sy|-S)
        # Stand in for an install or upgrade: move the database to the version
        # the test asked for, so a second pass sees nothing left to do. A named
        # package that was not installed at all becomes installed, because that
        # is what pacman does with it.
        if [[ -n ${PACMAN_UPGRADE_TO:-} ]]; then
            while read -r name version; do
                printf '%s %s\\n' "$name" "$PACMAN_UPGRADE_TO"
            done < "$PACMAN_DB" > "$PACMAN_DB.new"
            for argument in "$@"; do
                case $argument in -*) continue;; esac
                printf '%s %s\\n' "$argument" "$PACMAN_UPGRADE_TO" >> "$PACMAN_DB.new"
            done
            mv "$PACMAN_DB.new" "$PACMAN_DB"
        fi
        ;;
esac
exit 0
'''


class UpdateCase(unittest.TestCase):
    """Common fixtures: a repository directory, a fake pacman, a state dir."""

    @classmethod
    def setUpClass(cls):
        cls.update = load_update()

    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.log = self.root / 'pacman.log'
        self.log.write_text('')
        self.db = self.root / 'pacman.db'
        self.db.write_text('')
        bindir = self.root / 'bin'
        bindir.mkdir()
        fake = bindir / 'pacman'
        fake.write_text(FAKE_PACMAN)
        fake.chmod(0o755)
        self.environment = {
            'PATH': f'{bindir}:{os.environ["PATH"]}',
            'PACMAN_LOG': str(self.log),
            'PACMAN_DB': str(self.db),
            'XDG_STATE_HOME': str(self.root / 'state'),
        }
        self.pacman = str(fake)
        self.state = self.root / 'state/tessarchy/update-state.json'

    def publish(self, versions: dict, version='9.9.9', commit='deadbee'):
        """Write a repository's repo-info.json."""
        (self.repo / 'repo-info.json').write_text(json.dumps({
            'version': version,
            'commit': commit,
            'architecture': 'x86_64',
            'packages': {name: {'version': value, 'file': f'{name}-{value}.pkg.tar.zst'}
                         for name, value in versions.items()},
        }))

    def installed(self, versions: dict):
        self.db.write_text(''.join(f'{name} {value}\n' for name, value in versions.items()))

    def run_cli(self, *arguments, expect=None):
        """Run the CLI the way the timer and a user would, with a fake pacman."""
        with mock.patch.dict(os.environ, self.environment):
            status = self.update.main(list(arguments))
        if expect is not None:
            self.assertEqual(status, expect)
        return status

    def configure_repo(self, url):
        """Point this machine's own repository configuration at url.

        --apply installs through pacman, which reads /etc/pacman.d/tessarchy.conf,
        so a test that installs has to configure the machine the way an installed
        one is configured by its medium.
        """
        conf = self.root / 'etc/tessarchy.conf'
        conf.parent.mkdir(parents=True, exist_ok=True)
        conf.write_text('[tessarchy]\nSigLevel = Optional TrustAll\n'
                        f'Server = {url}/$arch\n')
        patcher = mock.patch.object(self.update, 'REPO_CONF', conf)
        patcher.start()
        self.addCleanup(patcher.stop)
        return conf

    def repo_server(self):
        server, url = serve(self.repo)
        self.addCleanup(server.server_close)  # cleanups run LIFO: close after shutdown
        self.addCleanup(server.shutdown)
        self.configure_repo(url)
        return url

    def recorded(self) -> list:
        return [line for line in self.log.read_text().splitlines() if line.strip()]

    def invocations(self, *prefixes) -> list:
        """Recorded pacman calls that a real machine would change state with."""
        return [line for line in self.recorded()
                if any(line.startswith(prefix) for prefix in prefixes)]

    def state_json(self) -> dict:
        return json.loads(self.state.read_text())

    def all_packages(self, version='0.1.0-2'):
        return {name: version for name in self.update.PACKAGES}


class VersionComparison(UpdateCase):
    def test_orders_simple_versions(self):
        cases = [
            ('0.1.0-1', '0.1.0-2', -1),
            ('0.1.0-2', '0.1.0-2', 0),
            ('0.2.0', '0.1.9', 1),
            ('1.0.0-10', '1.0.0-9', 1),
        ]
        for left, right, expected in cases:
            with self.subTest(left=left, right=right):
                self.assertEqual(self.update.vercmp(left, right), expected)

    def test_matches_pacman_when_it_is_available(self):
        # The pure-python fallback is only ever used where vercmp is missing, so
        # it has to agree with pacman wherever pacman can be asked.
        if not self.update.shutil.which('vercmp'):
            self.skipTest('vercmp is not installed')
        cases = [
            ('0.1.0-1', '0.1.0-2'), ('1.0', '1.0'), ('1.0', '1.0.0'),
            ('1.0', '1.0a'), ('1.0a', '1.0b'), ('1.0b', '1.1'),
            ('2.0', '10.0'), ('1.0.0', '1.0.0-1'), ('20261019', '20261020'),
        ]
        for left, right in cases:
            with self.subTest(left=left, right=right):
                real = self.update.subprocess.run(['vercmp', left, right],
                                                  capture_output=True, text=True)
                expected = self.update.vercmp(left, right)
                self.assertEqual(expected, (int(real.stdout) > 0) - (int(real.stdout) < 0))


class RepositoryUrl(UpdateCase):
    def test_explicit_url_wins(self):
        self.assertEqual(self.update.repo_url('https://example.test/pkgs/'),
                         'https://example.test/pkgs')

    def test_environment_overrides_the_default(self):
        with mock.patch.dict(os.environ, {'TESSARCHY_UPDATE_REPO': 'http://mirror.local/x/'}):
            self.assertEqual(self.update.repo_url(), 'http://mirror.local/x')

    def test_pacman_conf_supplies_the_url_and_expands_arch(self):
        conf = self.root / 'tessarchy.conf'
        conf.write_text('[tessarchy]\nServer = https://example.test/pkgs/$arch\n')
        with mock.patch.object(self.update, 'REPO_CONF', conf):
            self.assertEqual(self.update.repo_url(),
                             f'https://example.test/pkgs/{self.update.arch()}')

    def test_default_points_at_the_project_site(self):
        with mock.patch.object(self.update, 'REPO_CONF', self.root / 'missing.conf'):
            with mock.patch.dict(os.environ, {}, clear=False):
                os.environ.pop('TESSARCHY_UPDATE_REPO', None)
                self.assertTrue(self.update.repo_url().startswith('https://'))
                self.assertIn(self.update.arch(), self.update.repo_url())


class Check(UpdateCase):
    def test_reports_what_is_newer_and_exits_ten(self):
        url = self.repo_server()
        self.publish({'tessera-shell': '0.2.0-1', 'tessarchy-session': '0.1.0-2'})
        self.installed({'tessera-shell': '0.1.0-2', 'tessarchy-session': '0.1.0-2'})

        status = self.run_cli('--check', '--repo', url, '--pacman', self.pacman,
                              expect=self.update.EXIT_UPDATE_AVAILABLE)
        self.assertEqual(status, 10)
        self.assertEqual(self.state_json()['pending'], ['tessera-shell'])
        self.assertEqual(self.state_json()['repo_version'], '9.9.9')

    def test_says_up_to_date_without_state_noise(self):
        url = self.repo_server()
        self.publish(self.all_packages('0.1.0-2'))
        self.installed(self.all_packages('0.1.0-2'))

        self.run_cli('--check', '--repo', url, '--pacman', self.pacman,
                     expect=self.update.EXIT_UP_TO_DATE)
        self.assertEqual(self.state_json()['pending'], [])

    def test_a_package_that_is_not_installed_yet_counts_as_an_update(self):
        url = self.repo_server()
        self.publish(self.all_packages('0.1.0-2'))
        self.installed({'tessera-shell': '0.1.0-2'})

        self.run_cli('--check', '--repo', url, '--pacman', self.pacman,
                     expect=self.update.EXIT_UPDATE_AVAILABLE)
        self.assertIn('tessarchy-update', self.state_json()['pending'])

    def test_a_live_medium_is_not_behind_anything(self):
        # Nothing is installed there yet, so the repository's packages are
        # installs, not updates: a timer must not report a medium as "behind"
        # once a day, every day.
        url = self.repo_server()
        self.publish(self.all_packages('0.1.0-2'))
        import io
        captured = io.StringIO()
        with contextlib.redirect_stdout(captured):
            status = self.run_cli('--check', '--repo', url, '--pacman', self.pacman)
        self.assertEqual(status, self.update.EXIT_UP_TO_DATE)
        self.assertEqual(self.state_json()['pending'], [])
        self.assertIn('the repository offers', captured.getvalue())
        self.assertIn('live medium', captured.getvalue())

    def test_a_missing_repository_is_reported_not_crashed(self):
        missing = f'http://127.0.0.1:1/pkgs'
        self.run_cli('--check', '--repo', missing, '--pacman', self.pacman, expect=1)
        self.assertFalse(self.state_json()['ok'])
        self.assertIn('error', self.state_json())

    def test_a_page_that_is_not_a_repo_info_is_rejected(self):
        (self.repo / 'repo-info.json').write_text('<html>hello</html>')
        url = self.repo_server()
        self.run_cli('--check', '--repo', url, '--pacman', self.pacman, expect=1)

    def test_quiet_check_says_nothing(self):
        url = self.repo_server()
        self.publish(self.all_packages('0.1.0-2'))
        self.installed(self.all_packages('0.1.0-2'))
        import io
        captured = io.StringIO()
        with contextlib.redirect_stdout(captured), contextlib.redirect_stderr(captured):
            self.run_cli('--check', '--quiet', '--repo', url, '--pacman', self.pacman)
        self.assertEqual(captured.getvalue(), '')


class Apply(UpdateCase):
    def setUp(self):
        super().setUp()
        self.flag = self.root / 'restart-required'
        patcher = mock.patch.object(self.update, 'RESTART_FLAG', self.flag)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_default_apply_upgrades_the_whole_system(self):
        # Tessarchy packages depend on the base system, so updating only them
        # would be a partial upgrade; the default has to be a full one.
        url = self.repo_server()
        self.publish(self.all_packages('0.2.0-1'))
        self.installed(self.all_packages('0.1.0-2'))
        self.environment['PACMAN_UPGRADE_TO'] = '0.2.0-1'

        with mock.patch('os.geteuid', return_value=0):
            self.run_cli('--apply', '--repo', url, '--pacman', self.pacman, expect=0)
        self.assertEqual(self.invocations('-Syu'), ['-Syu --needed --noconfirm'])
        self.assertTrue(self.flag.is_file())
        self.assertEqual(self.state_json()['pending'], [])

    def test_packages_only_passes_the_pending_names(self):
        url = self.repo_server()
        self.publish({'tessera-shell': '0.2.0-1', 'tessarchy-session': '0.1.0-2'})
        self.installed({'tessera-shell': '0.1.0-2', 'tessarchy-session': '0.1.0-2'})

        with mock.patch('os.geteuid', return_value=0):
            self.run_cli('--apply', '--packages-only', '--repo', url,
                         '--pacman', self.pacman)
        self.assertEqual(self.invocations('-Sy'),
                         ['-Sy --needed --noconfirm tessera-shell'])

    def test_refuses_to_install_without_root(self):
        with mock.patch('os.geteuid', return_value=1000):
            self.run_cli('--apply', '--pacman', self.pacman, expect=1)
        self.assertEqual(self.invocations('-Syu', '-Sy', '-U'), [])

    def test_dry_run_does_not_invoke_pacman(self):
        url = self.repo_server()
        self.publish(self.all_packages('0.2.0-1'))
        self.installed(self.all_packages('0.1.0-2'))

        with mock.patch('os.geteuid', return_value=0):
            self.run_cli('--apply', '--dry-run', '--repo', url, '--pacman', self.pacman)
        self.assertEqual(self.invocations('-Syu', '-Sy', '-U'), [])
        self.assertFalse(self.flag.exists())

    def test_refuses_to_install_at_another_source(self):
        # pacman installs from this machine's configuration, so an --apply that
        # names a different repository would quietly do something else.
        url = self.repo_server()
        self.publish(self.all_packages('0.2.0-1'))
        self.installed(self.all_packages('0.1.0-2'))
        import io
        errors = io.StringIO()
        with mock.patch('os.geteuid', return_value=0), \
                contextlib.redirect_stderr(errors):
            status = self.run_cli('--apply', '--repo', 'https://elsewhere.test/pkgs',
                                  '--pacman', self.pacman)
        self.assertEqual(status, 1)
        self.assertIn('--enable-repo', errors.getvalue())
        self.assertEqual(self.invocations('-Syu', '-Sy', '-U'), [])

    def test_a_failing_pacman_is_reported(self):
        url = self.repo_server()
        self.publish(self.all_packages('0.2.0-1'))
        self.installed(self.all_packages('0.1.0-2'))
        failing = self.root / 'bin/pacman'
        failing.write_text('#!/usr/bin/env bash\nexit 3\n')
        failing.chmod(0o755)

        with mock.patch('os.geteuid', return_value=0):
            status = self.run_cli('--apply', '--repo', url, '--pacman', str(failing))
        self.assertEqual(status, 3)
        self.assertFalse(self.state_json()['ok'])


class Notifier(UpdateCase):
    """The desktop notice: it has to be readable, and quiet when told nothing."""

    def notifier(self, check_output: str, check_status: int, notify_exit: int = 0):
        """Run the real notifier against stubbed tessarchy-update and notify-send."""
        bindir = self.root / 'bin'
        (bindir / 'tessarchy-update').write_text(
            '#!/usr/bin/env bash\ncat <<\'OUT\'\n' + check_output + 'OUT\n'
            f'exit {check_status}\n')
        (bindir / 'tessarchy-update').chmod(0o755)
        notify = bindir / 'notify-send'
        # One line per invocation, so a multi-line body does not look like two
        # notifications.
        notify.write_text('#!/usr/bin/env bash\n'
                          'printf \'%s\\n\' "$*" | tr \'\\n\' \'|\' >> "$NOTIFY_LOG"\n'
                          'printf \'\\n\' >> "$NOTIFY_LOG"\n'
                          f'exit {notify_exit}\n')
        notify.chmod(0o755)
        log = self.root / 'notify.log'
        environment = dict(os.environ, PATH=f'{bindir}:{os.environ["PATH"]}',
                           NOTIFY_LOG=str(log))
        result = subprocess.run([str(ROOT / 'session/tessera-update-notify')],
                                env=environment, capture_output=True, text=True)
        return result, (log.read_text().splitlines() if log.exists() else [])

    def test_the_summary_is_readable(self):
        result, calls = self.notifier(
            'checking somewhere\nupdates available:\n'
            '  tessera-shell        0.1.0-2 -> 0.1.0-3\n'
            '  tessarchy-session    0.1.0-2 -> 0.1.0-3\n', 10)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)
        self.assertIn('--app-name=Tessarchy', calls[0])
        self.assertIn('Tessarchy update available', calls[0])
        self.assertIn('tessera-shell 0.1.0-2 -> 0.1.0-3, '
                      'tessarchy-session 0.1.0-2 -> 0.1.0-3', calls[0])

    def test_nothing_new_means_no_notification(self):
        result, calls = self.notifier('checking somewhere\nTessarchy is up to date.\n', 0)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_a_failed_check_says_nothing(self):
        result, calls = self.notifier('tessarchy-update: no route to host\n', 1)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_a_session_without_a_notification_service_is_not_silent(self):
        # notify-send is installed but no service owns the bus name: say what
        # the update was in the journal instead of telling nobody at all.
        result, _ = self.notifier(
            'checking somewhere\nupdates available:\n  tessera-shell 1 -> 2\n',
            10, notify_exit=1)
        self.assertEqual(result.returncode, 0)
        self.assertIn('tessera-shell 1 -> 2', result.stderr)


class Offline(UpdateCase):
    def test_installs_packages_from_a_folder(self):
        folder = self.root / 'usb'
        folder.mkdir()
        package = folder / 'tessera-shell-0.2.0-1-any.pkg.tar.zst'
        package.write_bytes(b'not really a package')
        (folder / 'other-thing-1.0-1-any.pkg.tar.zst').write_bytes(b'x')

        with mock.patch('os.geteuid', return_value=0):
            self.run_cli('--offline', str(folder), '--pacman', self.pacman, expect=0)
        # Nothing is package-managed here yet, so the files on disk must be
        # allowed to give way to the packages that own them.
        self.assertEqual(self.invocations('-U'),
                         [f'-U --needed --noconfirm --overwrite * {package}'])

    def test_a_machine_that_already_owns_them_gets_no_overwrite(self):
        folder = self.root / 'usb'
        folder.mkdir()
        package = folder / 'tessera-shell-0.2.0-1-any.pkg.tar.zst'
        package.write_bytes(b'not really a package')
        self.installed({'tessera-shell': '0.1.0-2'})

        with mock.patch('os.geteuid', return_value=0):
            self.run_cli('--offline', str(folder), '--pacman', self.pacman, expect=0)
        self.assertEqual(self.invocations('-U'),
                         [f'-U --needed --noconfirm {package}'])

    def test_packages_only_on_a_machine_that_owns_them_gets_no_overwrite(self):
        url = self.repo_server()
        self.publish({'tessera-shell': '0.2.0-1', 'tessarchy-session': '0.1.0-2'})
        self.installed({'tessera-shell': '0.1.0-2', 'tessarchy-session': '0.1.0-2'})
        self.environment['PACMAN_UPGRADE_TO'] = '0.2.0-1'
        with mock.patch('os.geteuid', return_value=0):
            self.run_cli('--apply', '--packages-only', '--repo', url,
                         '--pacman', self.pacman, expect=0)
        self.assertEqual(self.invocations('-Sy'),
                         ['-Sy --needed --noconfirm tessera-shell'])

    def test_adopting_on_a_machine_that_owns_nothing_overwrites(self):
        url = self.repo_server()
        self.publish(self.all_packages('0.1.0-2'))
        self.environment['PACMAN_UPGRADE_TO'] = '0.1.0-2'
        with mock.patch('os.geteuid', return_value=0):
            self.run_cli('--apply', '--packages-only', '--repo', url, '--force',
                         '--pacman', self.pacman, expect=0)
        self.assertIn('--overwrite *', self.invocations('-Sy')[0])

    def test_a_folder_with_no_packages_is_an_error(self):
        folder = self.root / 'empty'
        folder.mkdir()
        with mock.patch('os.geteuid', return_value=0):
            self.run_cli('--offline', str(folder), '--pacman', self.pacman, expect=1)


class EnableRepo(UpdateCase):
    def test_writes_the_stanza_and_the_include_once(self):
        conf = self.root / 'etc/tessarchy.conf'
        pacman_conf = self.root / 'etc/pacman.conf'
        pacman_conf.parent.mkdir(parents=True)
        pacman_conf.write_text('[options]\nArchitecture = auto\n')
        with mock.patch.object(self.update, 'REPO_CONF', conf), \
                mock.patch.object(self.update, 'PACMAN_CONF', pacman_conf), \
                mock.patch('os.geteuid', return_value=0):
            self.run_cli('--enable-repo', '--repo', 'https://example.test/pkgs')
            self.run_cli('--enable-repo', '--repo', 'https://example.test/pkgs')

        body = pacman_conf.read_text()
        self.assertEqual(body.count('Include = ' + str(conf)), 1)
        self.assertIn('[tessarchy]', conf.read_text())
        self.assertIn('Server = https://example.test/pkgs/$arch', conf.read_text())

    def test_dry_run_writes_nothing(self):
        conf = self.root / 'etc/tessarchy.conf'
        with mock.patch.object(self.update, 'REPO_CONF', conf), \
                mock.patch('os.geteuid', return_value=0):
            self.run_cli('--enable-repo', '--dry-run')
        self.assertFalse(conf.exists())

    def test_the_default_repository_architecture_is_not_written_twice(self):
        # The fetch URL already ends in the architecture; the pacman Server line
        # must not end up with .../x86_64/$arch.
        conf = self.root / 'etc/tessarchy.conf'
        pacman_conf = self.root / 'etc/pacman.conf'
        pacman_conf.parent.mkdir(parents=True)
        pacman_conf.write_text('[options]\n')
        with mock.patch.object(self.update, 'REPO_CONF', conf), \
                mock.patch.object(self.update, 'PACMAN_CONF', pacman_conf), \
                mock.patch.dict(os.environ, {}, clear=False), \
                mock.patch('os.geteuid', return_value=0):
            os.environ.pop('TESSARCHY_UPDATE_REPO', None)
            self.run_cli('--enable-repo')
        server_line = [line for line in conf.read_text().splitlines()
                       if line.startswith('Server')][0]
        self.assertEqual(server_line,
                         f'Server = {self.update.DEFAULT_REPO}/$arch')
        # $arch is what pacman expands; the literal architecture must not appear,
        # or the Server line ends up naming x86_64 twice.
        self.assertEqual(server_line.count('$arch'), 1)
        self.assertNotIn(self.update.arch(), server_line)


class Status(UpdateCase):
    def test_json_output_carries_what_a_shell_needs(self):
        self.installed(self.all_packages('0.1.0-2'))
        import io
        captured = io.StringIO()
        with contextlib.redirect_stdout(captured):
            self.run_cli('--status', '--json', '--pacman', self.pacman)
        payload = json.loads(captured.getvalue())
        self.assertEqual(payload['installed']['tessera-shell'], '0.1.0-2')
        self.assertIn('repo', payload)
        self.assertIn('restart_required', payload)

    def test_pending_from_the_last_check_drives_the_exit_code(self):
        self.state.parent.mkdir(parents=True)
        self.state.write_text(json.dumps({'pending': ['tessera-shell'], 'ok': True}))
        self.installed(self.all_packages('0.1.0-2'))
        self.run_cli('--status', '--pacman', self.pacman,
                     expect=self.update.EXIT_UPDATE_AVAILABLE)


class MediumIntegration(unittest.TestCase):
    """The medium and the repository have to describe the same product."""

    def test_repo_conf_in_the_medium_matches_the_updater_default(self):
        update = load_update()
        conf = (ROOT / 'iso/airootfs/etc/pacman.d/tessarchy.conf').read_text()
        servers = [line.split('=', 1)[1].strip() for line in conf.splitlines()
                   if line.strip().startswith('Server')]
        self.assertEqual(len(servers), 1)
        self.assertTrue(update.DEFAULT_REPO.startswith('https://'))
        self.assertEqual(servers[0], update.DEFAULT_REPO + '/$arch')

    def test_the_timer_and_the_notifier_exist_on_the_medium(self):
        system = ROOT / 'iso/airootfs/etc/systemd/system'
        skel = ROOT / 'iso/airootfs/etc/skel/.config/systemd/user'
        self.assertIn('tessarchy-update --check',
                      (system / 'tessarchy-update-check.service').read_text())
        self.assertIn('OnCalendar=daily', (system / 'tessarchy-update-check.timer').read_text())
        self.assertIn('tessera-update-notify',
                      (skel / 'tessarchy-update-notify.service').read_text())
        self.assertIn('WantedBy=timers.target',
                      (skel / 'tessarchy-update-notify.timer').read_text())

    def test_the_medium_lets_its_own_user_install_tessarchy_packages(self):
        # A machine installed from this medium is a single-user device and its
        # user has no password to type, so without exactly this grant an
        # installed machine could never apply an update at all.
        sudoers = (ROOT / 'iso/airootfs/etc/sudoers.d/tessarchy-update').read_text()
        grants = [line.strip() for line in sudoers.splitlines()
                  if line.strip() and not line.strip().startswith('#')]
        self.assertEqual(
            grants,
            ['tess ALL=(root) NOPASSWD: /usr/bin/tessarchy-update --apply --packages-only'])
        # Changing where updates come from is a separate, password-protected
        # step, and a full system upgrade still asks for a password.
        self.assertNotIn('--enable-repo', grants[0])
        self.assertNotIn('NOPASSWD: /usr/bin/tessarchy-update --apply$',
                         '\n'.join(grants))

    def test_the_medium_carries_what_its_packages_depend_on(self):
        # A medium whose own packages cannot be installed is useless: pacman
        # refuses the whole transaction when one dependency is missing, and that
        # is exactly what the first install of this feature did
        # (tessarchy-greeter depended on greetd, which the medium deliberately
        # does not ship because the session starts from tty1 instead).
        shipped = set((ROOT / 'iso/packages.x86_64').read_text().split())
        ours = {path.parent.name for path in (ROOT / 'packaging').glob('*/PKGBUILD')}
        for pkgbuild in sorted((ROOT / 'packaging').glob('*/PKGBUILD')):
            declared = re.search(r"^depends=\((.*?)\)", pkgbuild.read_text(), re.S | re.M)
            if not declared:
                continue
            for entry in re.findall(r"'([^']+)'", declared.group(1)):
                base = re.split(r'[<>=]', entry)[0]
                if base in ours:
                    continue
                with self.subTest(package=pkgbuild.parent.name, dependency=entry):
                    self.assertIn(base, shipped,
                                  f'{pkgbuild.parent.name} needs {entry}, which the '
                                  f'medium does not install')

    def test_package_list_matches_what_is_shipped(self):
        update = load_update()
        for package in update.PACKAGES:
            with self.subTest(package=package):
                self.assertTrue((ROOT / f'packaging/{package}/PKGBUILD').is_file())


if __name__ == '__main__':
    unittest.main()
