"""Application launches must leave the shell's cgroup without shell parsing."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LAUNCHER = ROOT / 'session/tessarchy-launch'


class AppLifetimeTests(unittest.TestCase):
    def test_dev_install_owns_and_removes_app_target(self):
        with tempfile.TemporaryDirectory() as scratch:
            env = dict(os.environ, HOME=scratch, XDG_DATA_HOME=scratch + '/data',
                       XDG_CONFIG_HOME=scratch + '/config')
            install = ROOT / 'scripts/install-dev.sh'
            uninstall = ROOT / 'scripts/uninstall-dev.sh'
            unit = Path(scratch) / 'config/systemd/user/tessarchy-apps.target'
            result = subprocess.run([str(install)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(unit.read_bytes(), (ROOT / 'session/tessarchy-apps.target').read_bytes())
            self.assertTrue((Path(scratch) / '.local/bin/tessarchy-launch').exists())
            unit.write_text('changed')
            result = subprocess.run([str(uninstall)], env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(unit.read_text(), 'changed')
            unit.write_bytes((ROOT / 'session/tessarchy-apps.target').read_bytes())
            result = subprocess.run([str(uninstall)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(unit.exists())
            self.assertFalse((Path(scratch) / '.local/bin/tessarchy-launch').exists())

    def test_session_target_is_started_after_environment_import_and_stopped_on_logout(self):
        services = (ROOT / 'session/tessarchy-session-services').read_text()
        session = (ROOT / 'session/start-tessarchy').read_text()
        self.assertLess(services.index('dbus-update-activation-environment --systemd'),
                        services.index('systemctl --user start tessarchy-apps.target'))
        self.assertIn('systemctl --user stop tessarchy-apps.target', session)
        self.assertIn('PartOf=graphical-session.target',
                      (ROOT / 'session/tessarchy-apps.target').read_text())
        self.assertIn('systemd-cat --identifier=tessarchy-session start-hyprland', session)
        self.assertNotIn('exec systemd-cat --identifier=tessarchy-session start-hyprland', session)

    def test_arguments_environment_and_failures(self):
        with tempfile.TemporaryDirectory() as scratch:
            stub = Path(scratch) / 'systemd-run'
            output = Path(scratch) / 'result.json'
            stub.write_text('#!/usr/bin/env python3\nimport json, os, sys\n'
                            'open(os.environ["RESULT"], "w").write(json.dumps(sys.argv[1:]))\n'
                            'sys.exit(int(os.environ.get("STUB_STATUS", "0")))\n')
            stub.chmod(0o755)
            env = dict(os.environ, PATH=scratch + ':' + os.environ['PATH'],
                       RESULT=str(output), WAYLAND_DISPLAY='wayland-x',
                       HYPRLAND_INSTANCE_SIGNATURE='a=b with spaces',
                       APP_VALUE='a $HOME %n and spaces')
            args = ['/usr/bin/printf', 'one two', '', '$HOME', '100%', '--bad=thing']
            result = subprocess.run([str(LAUNCHER), '--working-directory', scratch, *args],
                                    env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            call = json.loads(output.read_text())
            self.assertEqual(call[call.index('--') + 1:], args)
            self.assertIn('--working-directory=' + scratch, call)
            self.assertIn('--setenv=APP_VALUE', call)
            self.assertIn('--setenv=WAYLAND_DISPLAY', call)
            self.assertIn('--setenv=HYPRLAND_INSTANCE_SIGNATURE', call)
            self.assertIn('--expand-environment=no', call)
            self.assertIn('--property=PartOf=tessarchy-apps.target', call)
            self.assertIn('--service-type=exec', call)
            self.assertNotIn('--pipe', call)
            self.assertNotIn('--scope', call)
            result = subprocess.run([str(LAUNCHER), 'true'], env=dict(env, STUB_STATUS='17'))
            self.assertEqual(result.returncode, 17)
            result = subprocess.run([str(LAUNCHER)], env=env, capture_output=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn(b'Usage:', result.stderr)

    def test_every_shell_app_path_uses_launcher(self):
        shell = (ROOT / 'shell/shell.qml').read_text()
        self.assertNotIn('entry.execute()', shell)
        self.assertIn('Quickshell.execDetached(["tessarchy-launch"].concat(options, entry.command))', shell)
        self.assertIn('Quickshell.execDetached(["tessarchy-launch"].concat(command))', shell)
        self.assertIn('tessarchy-launch", "lpa-gtk',
                      (ROOT / 'shell/components/CellularSettings.qml').read_text())
