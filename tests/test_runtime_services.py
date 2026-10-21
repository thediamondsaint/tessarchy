"""Runtime supervision with fake executables and a disposable compositor socket."""
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RuntimeServices(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.log = self.home / 'calls'
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + ':' + os.environ['PATH'],
                        STUB_LOG=str(self.log), XDG_RUNTIME_DIR=str(self.home / 'runtime'),
                        HYPRLAND_INSTANCE_SIGNATURE='test', WAYLAND_DISPLAY='wayland-1',
                        TESSARCHY_AUTOROTATE_LOGGED='1', TESSARCHY_ROTATE_OUTPUT='eDP-1')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/usr/bin/env bash\n' + body + '\n')
        path.chmod(0o755)

    def test_sensor_retries_ended_stream_then_exits_with_session(self):
        directory = self.home / 'runtime/hypr/test'
        directory.mkdir(parents=True)
        sock = socket.socket(socket.AF_UNIX)
        sock.bind(str(directory / '.socket.sock'))
        self.addCleanup(sock.close)
        self.stub('monitor-sensor', '''echo sensor >> "$STUB_LOG"
if [ "$(wc -l < "$STUB_LOG")" -eq 1 ]; then
    printf 'Has accelerometer (orientation: normal)\\nAccelerometer orientation changed: left-up\\nAccelerometer orientation changed: undefined\\n'
else
    printf 'Accelerometer orientation changed: bottom-up\\nAccelerometer orientation changed: right-up\\n'
fi''')
        self.stub('tessera-rotate', 'printf "rotate %s %s\\n" "$1" "$2" >> "$STUB_LOG"')
        self.stub('sleep', '''printf 'sleep %s\\n' "$1" >> "$STUB_LOG"
if [ "$(grep -c '^sleep ' "$STUB_LOG")" -ge 2 ]; then rm -f "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock"; fi''')
        result = subprocess.run([str(ROOT / 'session/tessarchy-autorotate')], env=self.env,
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.log.read_text().splitlines()
        self.assertEqual([c for c in calls if c.startswith('sleep ')], ['sleep 2', 'sleep 4'])
        self.assertEqual([c for c in calls if c.startswith('rotate ')],
                         ['rotate 0 eDP-1', 'rotate 1 eDP-1', 'rotate 2 eDP-1', 'rotate 3 eDP-1'])
        self.assertIn('monitor-sensor ended; retrying in 2s', result.stderr)
        self.assertIn('monitor-sensor ended; retrying in 4s', result.stderr)

    def test_sensor_does_not_start_without_live_compositor(self):
        self.stub('monitor-sensor', 'echo unexpected >> "$STUB_LOG"')
        result = subprocess.run([str(ROOT / 'session/tessarchy-autorotate')], env=self.env,
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.log.exists())

    def test_shell_service_and_direct_fallback(self):
        self.stub('dbus-update-activation-environment', 'printf "import %s\\n" "$*" >> "$STUB_LOG"')
        self.stub('systemctl', '''printf 'systemctl %s\\n' "$*" >> "$STUB_LOG"
case "$*" in
    '--user cat tessera-shell.service'|'--user restart tessera-shell.service'|'--user is-active --quiet tessera-shell.service')
        [ "${STUB_UNIT_AVAILABLE:-0}" = 1 ] && {
            [ "$*" != '--user restart tessera-shell.service' ] || [ "${STUB_RESTART_FAIL:-0}" = 0 ]; }
        ;;
    *) exit 1 ;;
esac''')
        self.stub('tessera-shell', 'echo direct >> "$STUB_LOG"')
        for available, restart_fail in (('1', '0'), ('0', '0'), ('1', '1')):
            self.log.unlink(missing_ok=True)
            env = dict(self.env, STUB_UNIT_AVAILABLE=available, STUB_RESTART_FAIL=restart_fail)
            result = subprocess.run([str(ROOT / 'session/tessarchy-session-services')], env=env,
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = self.log.read_text().splitlines()
            self.assertIn('import --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE TESSARCHY_DATA_DIR', calls)
            self.assertEqual('direct' in calls, available == '0' or restart_fail == '1')
            self.assertEqual('systemctl --user restart tessera-shell.service' in calls, available == '1')
        unit = (ROOT / 'session/tessera-shell.service').read_text()
        self.assertIn('Restart=on-failure', unit)
        self.assertIn('ExecCondition=', unit)

    def test_package_and_iso_wiring(self):
        package = (ROOT / 'packaging/tessarchy-session/PKGBUILD').read_text()
        stage = (ROOT / 'scripts/stage-iso.sh').read_text()
        for name in ('tessarchy-autorotate', 'tessera-shell.service'):
            self.assertIn(name, package)
            self.assertIn(name, stage)
