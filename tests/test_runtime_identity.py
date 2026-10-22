import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('runtime_identity', ROOT / 'scripts/runtime-identity.py')
assert spec and spec.loader
identity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(identity)


class RuntimeIdentityTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.base = Path(tmp.name)
        self.source = self.base / 'private-username/checkout'
        (self.source / 'shell/components').mkdir(parents=True)
        (self.source / 'session').mkdir()
        (self.source / 'shell/shell.qml').write_text('import QtQuick\nItem {}\n')
        (self.source / 'shell/components/qmldir').write_text('Example 1.0 Example.qml\n')
        (self.source / 'session/hyprland.lua').write_text('-- fixture\n')
        self.proc = self.base / 'proc'
        self.process = self.proc / '42'
        self.process.mkdir(parents=True)
        (self.process / 'comm').write_text('qs\n')
        (self.process / 'stat').write_text('42 (qs) ' + ' '.join(['S'] + ['0'] * 18 + ['12345']))
        self.argv('--path', str(self.source / 'shell/shell.qml'))
        self.calls = []
        self.service = 'MainPID=42\nActiveState=active\nSubState=running\nNRestarts=0\n'
        self.monitors = [{'id': 0, 'width': 1920, 'height': 1080, 'x': 0, 'y': 0,
                          'scale': 1.5, 'transform': 1, 'serial': 'private-serial',
                          'description': 'private-monitor', 'name': 'private-output'}]

    def argv(self, *args):
        (self.process / 'cmdline').write_bytes(b'qs\0' + b'\0'.join(a.encode() for a in args) + b'\0')

    def fake_run(self, args):
        self.calls.append(args)
        if args[0] == 'systemctl':
            return {'status': 'ok', 'stdout': self.service}
        if args == ['qs', '--version']:
            return {'status': 'ok', 'stdout': 'quickshell 0.3.2, revision fixture'}
        if args == ['hyprctl', '-j', 'version']:
            return {'status': 'ok', 'stdout': json.dumps({'tag': 'v0.56.0', 'commit': 'abcdef',
                                                         'commit_message': 'private message'})}
        if args == ['hyprctl', '-j', 'monitors']:
            return {'status': 'ok', 'stdout': json.dumps(self.monitors)}
        return {'status': 'unavailable'}

    def report(self, pid: int | None = 42, run=None):
        return identity.collect_report(pid, proc_root=self.proc, run=run or self.fake_run)

    def test_explicit_process_identifies_actual_source_and_hashes(self):
        report = self.report()
        self.assertEqual(report['selection']['status'], 'identified')
        self.assertEqual(report['source']['files_sha256']['shell/shell.qml'],
                         hashlib.sha256((self.source / 'shell/shell.qml').read_bytes()).hexdigest())
        self.assertFalse(report['source']['loaded_bytes_verified'])
        self.assertEqual(report['process']['start_ticks'], 12345)
        self.assertTrue(report['process']['identity_stable'])

    def test_service_pid_selection(self):
        report = self.report(None)
        self.assertEqual(report['selection']['pid'], 42)
        self.assertEqual(report['selection']['method'], 'service')
        self.assertTrue(report['service']['selected_pid_matches'])

    def test_missing_service_does_not_guess_another_process(self):
        self.service = 'MainPID=0\nActiveState=inactive\n'
        report = self.report(None)
        self.assertEqual(report['selection']['status'], 'unavailable')
        self.assertNotIn('source', report)

    def test_missing_process_does_not_fall_back_to_checkout(self):
        report = self.report(99)
        self.assertEqual(report['selection']['status'], 'unavailable')
        self.assertNotIn('source', report)

    def test_ambiguous_path_arguments_are_unavailable(self):
        self.argv('-p', str(self.source / 'shell'), '--path', str(self.source / 'shell'))
        self.assertEqual(self.report()['selection']['status'], 'unavailable')

    def test_relative_path_uses_selected_process_cwd(self):
        (self.process / 'cwd').symlink_to(self.source, target_is_directory=True)
        self.argv('-p', 'shell')
        self.assertEqual(self.report()['selection']['status'], 'identified')

    def test_equals_path_argument(self):
        self.argv('--path=' + str(self.source / 'shell'))
        self.assertEqual(self.report()['selection']['status'], 'identified')

    def test_named_config_is_not_guessed_from_callers_environment(self):
        self.argv('--config', 'tessera')
        self.assertEqual(self.report()['selection']['status'], 'unavailable')

    def test_other_process_is_not_labeled_quickshell(self):
        (self.process / 'comm').write_text('unrelated\n')
        self.assertEqual(self.report()['selection']['status'], 'unavailable')

    def test_private_fields_and_absolute_paths_are_filtered(self):
        report = self.report()
        serialized = json.dumps(report)
        for secret in (str(self.base), 'private-username', 'private-serial', 'private-monitor',
                       'private-output', 'private message'):
            self.assertNotIn(secret, serialized)
        self.assertEqual(report['monitors']['items'][0]['scale'], 1.5)
        self.assertEqual(report['versions']['quickshell']['version'], '0.3.2')

    def test_unknown_and_invalid_geometry_are_not_echoed(self):
        self.monitors = [{'width': 'PRIVATE', 'height': float('nan'), 'scale': False,
                          'x': 0, 'extra': 'SECRET'}]
        text = json.dumps(self.report(), allow_nan=False)
        self.assertNotIn('PRIVATE', text)
        self.assertNotIn('SECRET', text)
        self.assertNotIn('NaN', text)

    def test_command_errors_are_structured_not_raw_output(self):
        def broken(args):
            return {'status': 'failed', 'stdout': 'private-error /home/PRIVATE password=SECRET'}
        report = self.report(run=broken)
        text = json.dumps(report)
        self.assertNotIn('PRIVATE', text)
        self.assertNotIn('SECRET', text)
        self.assertEqual(report['monitors']['status'], 'failed')
        self.assertEqual(report['versions']['quickshell']['status'], 'failed')

    def test_outside_root_symlink_is_not_hashed(self):
        secret = self.base / 'private-file'
        secret.write_text('secret not source')
        (self.source / 'shell/private.qml').symlink_to(secret)
        report = self.report()
        self.assertNotIn('shell/private.qml', report['source']['files_sha256'])
        self.assertGreater(report['source']['excluded_files'], 0)

    def test_commands_are_only_fixed_reads(self):
        self.report()
        self.assertFalse(any(part in ['eval', 'repl', 'dispatch', 'reload', 'restart', 'kill']
                             for args in self.calls for part in args))
        self.assertTrue(all(isinstance(args, list) for args in self.calls))

    def test_unknown_source_files_are_not_read(self):
        (self.source / 'shell/credentials.secret').write_text('not runtime')
        (self.source / 'session/credentials.secret').write_text('not runtime')
        files = self.report()['source']['files_sha256']
        self.assertNotIn('shell/credentials.secret', files)
        self.assertNotIn('session/credentials.secret', files)

    def test_json_parse_errors_do_not_leak_raw_reply(self):
        def invalid(args):
            return {'status': 'ok', 'stdout': 'PRIVATE malformed reply'}
        report = self.report(run=invalid)
        self.assertEqual(report['monitors']['status'], 'invalid')
        self.assertNotIn('PRIVATE', json.dumps(report))

    def test_pid_reuse_is_not_reported_as_stable(self):
        from unittest.mock import patch
        with patch.object(identity, 'process_start', side_effect=[1, 2]):
            report = self.report()
        self.assertEqual(report['selection']['status'], 'changed')
        self.assertFalse(report['process']['identity_stable'])

    def test_invalid_pid_does_not_create_source_identity(self):
        for pid in (-1, 0):
            with self.subTest(pid=pid):
                self.assertEqual(self.report(pid)['selection']['status'], 'unavailable')

    def test_non_tessera_config_is_not_mislabeled(self):
        (self.source / 'session/hyprland.lua').unlink()
        self.assertEqual(self.report()['selection']['status'], 'unavailable')

    def test_query_context_limitations_are_explicit(self):
        report = self.report()
        self.assertIn('invoking session', report['versions']['query_context'])
        self.assertIn('invoking session', report['monitors']['query_context'])
        self.assertFalse(report['source']['loaded_bytes_verified'])

    def git_fixture(self, root):
        import os
        env = dict(PATH=os.environ['PATH'], HOME=str(self.base), GIT_CONFIG_NOSYSTEM='1',
                   GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull,
                   GIT_AUTHOR_NAME='Fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
                   GIT_COMMITTER_NAME='Fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid')
        subprocess.run(['git', '-C', str(root), 'init', '-q'], env=env, check=True,
                       capture_output=True)
        subprocess.run(['git', '-C', str(root), 'commit', '--allow-empty', '-qm', 'fixture'],
                       env=env, check=True, capture_output=True)
        def run(args):
            if args[0] != 'git':
                return self.fake_run(args)
            result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=3)
            return {'status': 'ok' if result.returncode == 0 else 'failed', 'stdout': result.stdout}
        return run

    def test_nested_source_does_not_inherit_parent_repository_identity(self):
        report = self.report(run=self.git_fixture(self.base))
        self.assertNotIn('git_head', report['source'])
        self.assertNotIn('git_tracked_changes', report['source'])

    def test_source_root_repository_metadata_is_reported(self):
        report = self.report(run=self.git_fixture(self.source))
        self.assertRegex(report['source']['git_head'], r'^[0-9a-f]{40}$')
        self.assertIs(report['source']['git_tracked_changes'], False)

    def test_real_command_wrapper_bounds_and_sanitizes_failure(self):
        result = identity.run_command([sys.executable, '-c', 'raise SystemExit(7)'])
        self.assertEqual(result['status'], 'failed')
        self.assertNotIn('stderr', result)
        result = identity.run_command([sys.executable, '-c', 'import time; time.sleep(1)'], timeout=0.01)
        self.assertEqual(result['status'], 'timeout')

    def test_cli_help_does_not_need_a_running_shell(self):
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/runtime-identity.py'), '--help'],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--pid', result.stdout)


if __name__ == '__main__':
    unittest.main()
