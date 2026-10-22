#!/usr/bin/env python3
"""Actual notification protocol + production queue, never the user's session bus."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent


def command(args, **kwargs):
    result = subprocess.run(args, capture_output=True, text=True, timeout=10, **kwargs)
    if result.returncode:
        raise RuntimeError(f'Command failed ({result.returncode}): {args[0]}: {result.stderr}')
    return result.stdout.strip()


def run_private():
    # This function is invoked only in the fresh dbus-run-session child below.
    with tempfile.TemporaryDirectory(prefix='tessarchy-notifications-', dir='/tmp') as scratch:
        env = dict(os.environ, HOME=scratch, XDG_CONFIG_HOME=scratch + '/config',
                   XDG_DATA_HOME=scratch + '/data', XDG_CACHE_HOME=scratch + '/cache',
                   XDG_RUNTIME_DIR=scratch, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='')
        for key in ('WAYLAND_DISPLAY', 'DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE', 'QS_CONFIG_PATH', 'QS_CONFIG_NAME'):
            env.pop(key, None)
        # No fixture code imports a system-bus module; still prevent accidental access.
        env['DBUS_SYSTEM_BUS_ADDRESS'] = 'unix:path=' + scratch + '/no-system-bus'
        # Quickshell remaps config files under qs:@/qs: parent-directory imports
        # cannot escape that root. Stage only this fixture and exact production
        # queue bytes beneath one isolated config root (no installed sources).
        staged = Path(scratch)
        (staged / 'components').mkdir()
        shutil.copyfile(HERE / 'notification-lifecycle.qml', staged / 'shell.qml')
        shutil.copyfile(HERE.parents[1] / 'shell/components/NotificationPopupQueue.qml',
                        staged / 'components/NotificationPopupQueue.qml')
        steps = []
        with tempfile.TemporaryFile(mode='w+') as log:
            process = subprocess.Popen(['qs', '-p', str(staged / 'shell.qml')],
                                       env=env, stdout=log, stderr=subprocess.STDOUT)
            try:
                command(['gdbus', 'wait', '--session', '--timeout=5', 'org.freedesktop.Notifications'], env=env)

                def ipc(function, *args):
                    return command(['qs', 'ipc', '--pid', str(process.pid), 'call', 'notificationTest', function, *args], env=env)

                def send(summary, replaces=0, urgent=False):
                    hints = "{'urgency': <byte 2>}" if urgent else '{}'
                    text = command(['gdbus', 'call', '--session', '--dest', 'org.freedesktop.Notifications',
                                    '--object-path', '/org/freedesktop/Notifications', '--method',
                                    'org.freedesktop.Notifications.Notify', 'Tessarchy isolated test',
                                    str(replaces), '', summary, '', '[]', hints, '0'], env=env)
                    match = re.fullmatch(r'\(uint32 (\d+),\)', text)
                    if not match:
                        raise AssertionError('Unexpected real Notify response: ' + text)
                    return int(match.group(1))

                def close(identifier):
                    command(['gdbus', 'call', '--session', '--dest', 'org.freedesktop.Notifications',
                             '--object-path', '/org/freedesktop/Notifications', '--method',
                             'org.freedesktop.Notifications.CloseNotification', str(identifier)], env=env)

                def check(label, expected_popups, expected_history):
                    snapshot = json.loads(ipc('snapshot'))
                    if snapshot['popups'] != expected_popups or set(snapshot['history']) != set(expected_history):
                        raise AssertionError(f'{label}: {snapshot}')
                    if len(snapshot['history']) != len(expected_history):
                        raise AssertionError(f'Duplicated history: {snapshot}')
                    steps.append({'step': label, **snapshot})

                check('empty', [], [])
                a = send('one'); check('delivery', ['one'], ['one'])
                replaced = send('replaced', a)
                if replaced != a:
                    raise AssertionError('Notification replacement changed its protocol ID')
                check('replacement', ['replaced'], ['replaced'])
                if steps[-1]['deliveries'] != 1:
                    raise AssertionError('Native replacement unexpectedly re-emitted delivery')
                b = send('two'); c = send('three'); d = send('four')
                check('overflow', ['four', 'three', 'two'], ['replaced', 'two', 'three', 'four'])
                close(d)
                check('app-withdrawal-no-resurrection', ['three', 'two'], ['replaced', 'two', 'three'])
                ipc('hideFirst')
                check('body-hide-retains-history', ['two'], ['replaced', 'two', 'three'])
                ipc('dismissFirst')
                check('dismiss-removes-history', [], ['replaced', 'three'])
                ipc('setMuted', 'true'); muted = send('muted')
                check('muted-delivery-in-history', [], ['replaced', 'three', 'muted'])
                ipc('setMuted', 'false')
                check('unmute-does-not-replay', [], ['replaced', 'three', 'muted'])
                urgent = send('urgent', urgent=True)
                check('urgent-delivery', ['urgent'], ['replaced', 'three', 'muted', 'urgent'])
                close(urgent)
                check('urgent-withdrawal', [], ['replaced', 'three', 'muted'])
                for identifier in (a, c, muted):
                    close(identifier)
                check('bulk-cleanup', [], [])
                log.seek(0); output = log.read()
                if re.search(r'ERROR|TypeError|ReferenceError|Cannot read property', output):
                    raise AssertionError('Native fixture logged QML errors: ' + output)
                version = command(['qs', '--version'], env=env)
                match = re.search(r'\d+\.\d+\.\d+[^\s]*', version)
                print(json.dumps({'result': 'pass', 'quickshell': match.group(0) if match else 'unknown',
                                  'isolation': 'new private session bus, offscreen, scratch HOME/runtime',
                                  'steps': steps}, indent=2))
            except Exception:
                log.seek(0)
                print(log.read(), file=sys.stderr)
                raise
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait(timeout=5)


if __name__ == '__main__':
    # Do not offer a public CLI flag that skips private-bus creation.
    child = 'import runpy,sys; runpy.run_path(sys.argv[1])["run_private"]()'
    result = subprocess.run(['dbus-run-session', '--', sys.executable, '-c', child, str(Path(__file__).resolve())],
                            check=False, timeout=90)
    raise SystemExit(result.returncode)
