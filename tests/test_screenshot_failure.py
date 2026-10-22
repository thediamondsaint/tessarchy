"""Exercise the real screenshot helper with controlled commands, never a desktop."""
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ScreenshotFailureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.bash = shutil.which('bash')
        assert self.bash is not None
        for name in ('mkdir', 'mktemp', 'date', 'rm', 'basename'):
            command = shutil.which(name)
            assert command is not None, name
            (self.bin / name).symlink_to(command)
        self.env = {'HOME': str(self.home), 'PATH': str(self.bin),
                    'NOTIFY_LOG': str(self.home / 'notify.jsonl')}
        self.command('grim', '''import os, pathlib, sys
pathlib.Path(sys.argv[1]).write_bytes(b'controlled capture fixture')
status = int(os.environ.get('GRIM_STATUS', '0'))
if status: print('fixture: capture failed for private output', file=sys.stderr)
sys.exit(status)
''')
        self.command('notify-send', '''import json, os, sys
with open(os.environ['NOTIFY_LOG'], 'a') as out:
    out.write(json.dumps(sys.argv[1:]) + '\\n')
sys.exit(int(os.environ.get('NOTIFY_STATUS', '0')))
''')

    def command(self, name, body):
        target = self.bin / name
        if target.is_symlink():
            target.unlink()
        target.write_text('#!' + sys.executable + '\n' + body)
        target.chmod(0o755)

    def run_helper(self, *args):
        return subprocess.run([self.bash, str(ROOT / 'session/tessera-screenshot'), *args],
                              env=self.env, capture_output=True, text=True, timeout=5)

    def notifications(self):
        p = Path(self.env['NOTIFY_LOG'])
        return [json.loads(line) for line in p.read_text().splitlines()] if p.exists() else []

    def assert_failure(self, result, status, reason):
        self.assertEqual(result.returncode, status, result.stderr)
        self.assertEqual(result.stdout, '')
        self.assertEqual(list(self.home.glob('Pictures/Screenshots/tessarchy-*.png')), [])
        self.assertEqual(self.notifications(), [['-a', 'Tessera', 'Screenshot failed', reason]])

    def test_capture_failure_cleans_partial_and_preserves_status(self):
        self.env['GRIM_STATUS'] = '7'
        result = self.run_helper()
        self.assert_failure(result, 7, 'The screen capture could not be saved.')
        self.assertIn('fixture: capture failed', result.stderr)

    def test_other_capture_status_is_not_replaced(self):
        self.env['GRIM_STATUS'] = '111'
        self.assert_failure(self.run_helper(), 111, 'The screen capture could not be saved.')

    def test_missing_grim_is_reported_without_creating_destination(self):
        (self.bin / 'grim').unlink()
        result = self.run_helper()
        self.assert_failure(result, 1, 'The screenshot capture tool is unavailable.')
        self.assertIn('grim is required', result.stderr)
        self.assertFalse((self.home / 'Pictures').exists())

    def test_destination_creation_failure_preserves_status(self):
        self.command('mkdir', "import sys; print('fixture: mkdir denied', file=sys.stderr); sys.exit(31)\n")
        result = self.run_helper()
        self.assert_failure(result, 31, 'The screenshot destination could not be prepared.')
        self.assertIn('fixture: mkdir denied', result.stderr)

    def test_file_creation_failure_preserves_status(self):
        self.command('mktemp', "import sys; print('fixture: mktemp denied', file=sys.stderr); sys.exit(32)\n")
        result = self.run_helper()
        self.assert_failure(result, 32, 'A private screenshot file could not be created.')
        self.assertIn('fixture: mktemp denied', result.stderr)

    def test_failure_without_notification_tool(self):
        (self.bin / 'notify-send').unlink()
        self.env['GRIM_STATUS'] = '7'
        result = self.run_helper()
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, '')
        self.assertEqual(self.notifications(), [])
        self.assertEqual(list(self.home.glob('Pictures/Screenshots/*.png')), [])

    def test_broken_notification_does_not_replace_failure_status(self):
        self.env.update(GRIM_STATUS='7', NOTIFY_STATUS='42')
        self.assert_failure(self.run_helper(), 7, 'The screen capture could not be saved.')

    def test_success_keeps_private_file_and_existing_success_notification(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        path = Path(result.stdout.strip())
        self.assertEqual(path.parent, self.home / 'Pictures/Screenshots')
        self.assertEqual(path.read_bytes(), b'controlled capture fixture')
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(self.notifications(), [['-a', 'Tessera', 'Screenshot saved', path.name]])

    def test_success_without_notification_tool(self):
        (self.bin / 'notify-send').unlink()
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(Path(result.stdout.strip()).is_file())

    def test_broken_success_notification_keeps_capture(self):
        self.env['NOTIFY_STATUS'] = '42'
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(Path(result.stdout.strip()).is_file())
        self.assertEqual(len(self.notifications()), 1)
        self.assertEqual(self.notifications()[0][2], 'Screenshot saved')

    def test_unexpected_arguments_do_not_capture_or_notify(self):
        result = self.run_helper('--unexpected')
        self.assertEqual(result.returncode, 64)
        self.assertIn('usage:', result.stderr)
        self.assertEqual(result.stdout, '')
        self.assertEqual(self.notifications(), [])
        self.assertFalse((self.home / 'Pictures').exists())

    def test_failure_does_not_remove_existing_screenshot(self):
        parent = self.home / 'Pictures/Screenshots'
        parent.mkdir(parents=True)
        existing = parent / 'existing.png'
        existing.write_bytes(b'keep existing')
        self.env['GRIM_STATUS'] = '7'
        self.assert_failure(self.run_helper(), 7, 'The screen capture could not be saved.')
        self.assertEqual(existing.read_bytes(), b'keep existing')

    def test_private_paths_and_raw_stderr_are_not_notification_text(self):
        self.env['GRIM_STATUS'] = '7'
        self.run_helper()
        notices = json.dumps(self.notifications())
        self.assertIn('Screenshot failed', notices)
        self.assertNotIn(str(self.home), notices)
        self.assertNotIn('fixture:', notices)
        self.assertNotIn('private output', notices)

    def test_configured_destination_is_used_literally(self):
        parent = self.home / 'pictures with spaces;literal%'
        self.env['XDG_PICTURES_DIR'] = str(parent)
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(result.stdout.strip()).parent, parent / 'Screenshots')

    def test_repeated_success_uses_distinct_paths(self):
        first, second = self.run_helper(), self.run_helper()
        self.assertEqual((first.returncode, second.returncode), (0, 0))
        self.assertNotEqual(first.stdout, second.stdout)
        self.assertTrue(Path(first.stdout.strip()).exists())
        self.assertTrue(Path(second.stdout.strip()).exists())

    def test_stdout_failure_does_not_remove_completed_capture(self):
        with subprocess.Popen([self.bash, str(ROOT / 'session/tessera-screenshot')],
                              env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as child:
            assert child.stdout is not None
            child.stdout.close()
            child.wait(timeout=5)
            self.assertNotEqual(child.returncode, 0)
        self.assertEqual(len(list(self.home.glob('Pictures/Screenshots/*.png'))), 1)
        self.assertEqual(len(self.notifications()), 1)
        self.assertEqual(self.notifications()[0][2], 'Screenshot saved')


if __name__ == '__main__':
    unittest.main()
