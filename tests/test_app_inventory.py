"""Native desktop-entry discovery and live updates in an isolated Quickshell."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstalledApplications(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell runtime unavailable')
    def test_native_install_metadata_hide_and_remove_updates(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            apps = home / 'data/applications'
            apps.mkdir(parents=True)
            runtime = home / 'runtime'
            runtime.mkdir(mode=0o700)
            log = home / 'output.log'
            harness = home / 'harness'
            harness.mkdir()
            shutil.copy2(ROOT / 'shell/AppPolicy.js', harness / 'AppPolicy.js')
            (harness / 'shell.qml').write_text(
                (ROOT / 'tests/quickshell/installed-apps.qml').read_text()
                .replace('../../shell/AppPolicy.js', 'AppPolicy.js'))

            def write_entry(app_id, name, category='Utility', icon='test-icon', hidden=False):
                temporary = apps / (app_id + '.tmp')
                temporary.write_text('[Desktop Entry]\nType=Application\n'
                                     f'Name={name}\nExec=/usr/bin/true\n'
                                     f'Categories={category};\nIcon={icon}\n'
                                     f'NoDisplay={str(hidden).lower()}\n')
                temporary.replace(apps / (app_id + '.desktop'))

            write_entry('base', 'Base')
            environment = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / 'config'),
                               XDG_STATE_HOME=str(home / 'state'), XDG_DATA_HOME=str(home / 'data'),
                               XDG_DATA_DIRS=str(home / 'empty-system'), XDG_RUNTIME_DIR=str(runtime),
                               QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='')
            with log.open('w') as output:
                process = subprocess.Popen(
                    [shutil.which('qs'), '--no-color', '-p', str(harness / 'shell.qml')],
                    env=environment, stdout=output, stderr=subprocess.STDOUT)
                offset = 0

                def wait_inventory(expected):
                    nonlocal offset
                    deadline = time.monotonic() + 12
                    while time.monotonic() < deadline:
                        text = log.read_text()
                        for line in text[offset:].splitlines(keepends=True):
                            if not line.endswith('\n'):
                                break
                            offset += len(line)
                            if 'APP_INVENTORY:' not in line:
                                continue
                            payload = line.split('APP_INVENTORY:', 1)[1].strip()
                            inventory = json.loads(payload)
                            if inventory == expected:
                                return
                        if process.poll() is not None:
                            self.fail('Quickshell exited before update:\n' + text)
                        time.sleep(0.05)
                    self.fail('Native inventory did not update:\n' + log.read_text())

                def item(app_id, name, category='Utilities', icon='test-icon'):
                    return dict(id=app_id, name=name, icon=icon, category=category)

                try:
                    wait_inventory([item('base', 'Base')])
                    write_entry('outside-role-list', 'New app', 'Network')
                    wait_inventory([item('base', 'Base'), item('outside-role-list', 'New app', 'Internet')])
                    write_entry('outside-role-list', 'A renamed app', 'Office', 'new-icon')
                    wait_inventory([item('outside-role-list', 'A renamed app', 'Office', 'new-icon'), item('base', 'Base')])
                    write_entry('outside-role-list', 'A renamed app', hidden=True)
                    wait_inventory([item('base', 'Base')])
                    (apps / 'base.desktop').unlink()
                    wait_inventory([])
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
