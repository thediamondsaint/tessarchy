"""Observable install safety and profile assembly; no GUI or privileged tests."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Workflows(unittest.TestCase):
    def run_quickshell_harness(self, name, marker):
        import shutil
        quickshell = shutil.which('qs')
        if not quickshell:
            self.skipTest('Quickshell runtime unavailable')
        runtime = self.home / 'runtime'
        runtime.mkdir(mode=0o700)
        env = dict(self.env, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='',
                   XDG_RUNTIME_DIR=str(runtime))
        shutil.copytree(ROOT / 'shell', self.home / 'shell')
        harness = self.home / (name + '.qml')
        harness.write_text((ROOT / 'tests/quickshell' / (name + '.qml')).read_text()
                           .replace('../../shell/components', 'shell/components'))
        result = subprocess.run([quickshell, '--no-color', '-p', str(harness)],
                                env=env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(marker + '_TEST_PASS', result.stdout + result.stderr)
        self.assertNotIn(marker + '_TEST_FAIL', result.stdout + result.stderr)

    def test_bluetooth_component_lifecycle_and_action_guards(self):
        self.run_quickshell_harness('bluetooth', 'BLUETOOTH')

    def test_audio_panel_without_pipewire_service(self):
        self.run_quickshell_harness('audio', 'AUDIO')

    def test_site_builder_refuses_existing_output_and_bundles_originals(self):
        import sys
        import zipfile
        destination = self.home / 'site'
        command = [sys.executable, str(ROOT / 'scripts/build-site.py'),
                   '--output', str(destination)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        with zipfile.ZipFile(destination / 'assets/screenshots.zip') as archive:
            self.assertEqual(archive.read('phone-switcher.png'),
                             (ROOT / 'assets/screenshots/phone-switcher.png').read_bytes())
            self.assertEqual(archive.read('phone-login.png'),
                             (ROOT / 'assets/screenshots/phone-login.png').read_bytes())
        sentinel = destination / 'keep.txt'
        sentinel.write_text('unrelated content')
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sentinel.read_text(), 'unrelated content')

    def test_site_release_download_ignores_brand_only_releases(self):
        import json
        import sys
        metadata = self.home / 'releases.json'
        iso_release = {'tag_name': 'tester', 'assets': [{'name': 'tessarchy.iso'}]}
        metadata.write_text(json.dumps([
            {'tag_name': 'branding', 'assets': [{'name': 'logo.zip'}]},
            {'tag_name': 'draft', 'draft': True, 'assets': [{'name': 'draft.iso'}]},
            iso_release]))
        destination = self.home / 'release-site'
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/build-site.py'),
                                 '--output', str(destination), '--releases', str(metadata)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((destination / 'project.json').read_text())['release'],
                         iso_release)

    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix='tessarchy-test-')
        self.addCleanup(self.scratch.cleanup)
        self.home = Path(self.scratch.name)
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_DATA_HOME=str(self.home / 'data'),
                        XDG_CONFIG_HOME=str(self.home / 'config'))
        for variable in ('DISPLAY', 'WAYLAND_DISPLAY', 'TESSARCHY_DATA_DIR'):
            self.env.pop(variable, None)

    def run_script(self, name, expected=0, env=None):
        result = subprocess.run([str(ROOT / 'scripts' / name)], env=env or self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def test_install_uninstall_preserves_preferences_and_other_configs(self):
        sentinel = self.home / 'config/hypr/hyprland.conf'
        sentinel.parent.mkdir(parents=True)
        sentinel.write_text('existing config')
        preferences = self.home / 'config/tessarchy/preferences.lua'
        preferences.parent.mkdir(parents=True)
        preferences.write_text('-- mine')
        shell_settings = preferences.with_name('shell.ini')
        shell_settings.write_text('[Shell]\nlayoutMode=tablet\n')
        self.run_script('install-dev.sh')
        data = self.home / 'data/tessarchy'
        self.assertEqual((data / 'shell/shell.qml').read_bytes(),
                         (ROOT / 'shell/shell.qml').read_bytes())
        self.run_script('install-dev.sh', expected=1)
        self.run_script('uninstall-dev.sh')
        self.assertFalse(data.exists())
        self.assertEqual(sentinel.read_text(), 'existing config')
        self.assertEqual(preferences.read_text(), '-- mine')
        self.assertEqual(shell_settings.read_text(), '[Shell]\nlayoutMode=tablet\n')
        self.assertFalse((self.home / '.local/bin/tessarchy-osk').exists())
        self.assertFalse((self.home / '.local/bin/tessera-screenshot').exists())

    def osk(self, *args, path_tools=(), env=None):
        """Run tessarchy-osk with PATH limited to bash, mkdir and the given stubs."""
        import shutil
        stubs = self.home / 'stubs'
        stubs.mkdir(exist_ok=True)
        for real in ('bash', 'mkdir'):
            if not (stubs / real).exists():
                (stubs / real).symlink_to(shutil.which(real) or f'/usr/bin/{real}')
        for name, body in path_tools:
            tool = stubs / name
            tool.write_text('#!/bin/bash\n' + body)
            tool.chmod(0o755)
        run_env = dict(env or self.env, PATH=str(stubs),
                       XDG_STATE_HOME=str(self.home / 'state'))
        return subprocess.run([str(ROOT / 'session/tessarchy-osk'), *args], env=run_env,
                              capture_output=True, text=True)

    def test_osk_is_optional_and_keeps_gnome_settings_private(self):
        missing = self.osk('start')
        self.assertEqual(missing.returncode, 0, missing.stderr)
        self.assertIn('squeekboard not installed', missing.stderr)
        self.assertEqual(self.osk().returncode, 2)
        self.assertEqual(self.osk('bogus').returncode, 2)
        fake = ('squeekboard', 'printf "%s|%s\\n" "$GSETTINGS_BACKEND" "$XDG_CONFIG_HOME"\n')
        self.assertEqual(self.osk('start', path_tools=[fake]).returncode, 1)
        env = dict(self.env, WAYLAND_DISPLAY='wayland-test')
        result = self.osk('start', path_tools=[fake], env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.home / 'state/tessarchy/osk'
        self.assertEqual(result.stdout.strip(), f'keyfile|{state}')
        keyfile = state / 'glib-2.0/settings/keyfile'
        self.assertIn('screen-keyboard-enabled=true', keyfile.read_text())
        keyfile.write_text('[org/gnome/desktop/a11y/applications]\nscreen-keyboard-enabled=false\n')
        self.osk('start', path_tools=[fake], env=env)
        self.assertIn('=false', keyfile.read_text())
        self.assertFalse((self.home / 'config/glib-2.0').exists())

    def test_osk_toggle_flips_visibility(self):
        log = self.home / 'busctl.log'
        for current, expected in (('true', 'false'), ('false', 'true')):
            busctl = ('busctl', f'echo "$*" >> {log}\n'
                      f'[[ $2 == get-property ]] && echo "b {current}"\nexit 0\n')
            result = self.osk('toggle', path_tools=[busctl])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(log.read_text().splitlines()[-1].endswith(f'SetVisible b {expected}'))
        self.osk('show', path_tools=[busctl])
        self.assertTrue(log.read_text().splitlines()[-1].endswith('SetVisible b true'))

    def test_session_uses_watchdog_and_preserves_config_path_arguments(self):
        import shutil
        tools = self.home / 'launcher-tools'
        tools.mkdir()
        (tools / 'bash').symlink_to(shutil.which('bash'))
        for name, body in {
                'qs': 'exit 0',
                'systemd-cat': 'shift; exec "$@" > "$JOURNAL_TEST_LOG" 2>&1',
                'dbus-run-session': 'shift; exec "$@"',
                'start-hyprland': 'printf "%s\\0" "$@" > "$LAUNCH_TEST_LOG"; echo compositor-output; echo compositor-error >&2'}.items():
            path = tools / name
            path.write_text('#!/bin/bash\n' + body + '\n')
            path.chmod(0o755)
        share = self.home / 'source with spaces'
        (share / 'session').mkdir(parents=True)
        (share / 'session/hyprland.lua').write_text('-- test config\n')
        log = self.home / 'launcher-args'
        journal = self.home / 'session-journal'
        env = dict(self.env, PATH=str(tools), TESSARCHY_DATA_DIR=str(share),
                   LAUNCH_TEST_LOG=str(log), JOURNAL_TEST_LOG=str(journal))
        result = subprocess.run([str(ROOT / 'session/start-tessarchy')], env=env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.read_bytes().split(b'\0')[:-1],
                         [b'--', b'--config', str(share / 'session/hyprland.lua').encode()])
        self.assertEqual(result.stdout, '')
        self.assertEqual(result.stderr, '')
        self.assertIn('compositor-output', journal.read_text())
        self.assertIn('compositor-error', journal.read_text())

    def test_session_start_launches_shell_and_optional_keyboard(self):
        import shutil
        if not shutil.which('lua'):
            self.skipTest('Lua interpreter unavailable')
        script = r'''local callbacks, commands = {}, {}
hl = {
    layer_rule = function() end,
    monitor = function() end, config = function() end, bind = function() end,
    on = function(name, callback) callbacks[name] = callback end,
    exec_cmd = function(command) table.insert(commands, command) end,
    dsp = { exec_cmd = function() end, exit = function() end, focus = function() end,
            window = { fullscreen = function(action) return action end, resize = function() end,
                       move = function() end, close = function() end,
                       cycle_next = function() end, drag = function() end } }
}
dofile(arg[1])
callbacks["hyprland.start"]()
assert(commands[1] == "tessera-shell" and commands[2] == "tessarchy-osk start",
       table.concat(commands, ","))
'''
        result = subprocess.run(['lua', '-', str(ROOT / 'session/hyprland.lua')],
                                input=script, text=True, capture_output=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_existing_launcher_refused_before_installing_data(self):
        launcher = self.home / '.local/bin/start-tessarchy'
        launcher.parent.mkdir(parents=True)
        launcher.write_text('unrelated')
        self.run_script('install-dev.sh', expected=1)
        self.assertEqual(launcher.read_text(), 'unrelated')
        self.assertFalse((self.home / 'data/tessarchy').exists())

    def test_modified_launcher_blocks_uninstall(self):
        self.run_script('install-dev.sh')
        launcher = self.home / '.local/bin/start-tessarchy'
        launcher.write_text('modified')
        self.run_script('uninstall-dev.sh', expected=1)
        self.assertEqual(launcher.read_text(), 'modified')
        self.assertTrue((self.home / 'data/tessarchy/.tessarchy-dev-install').exists())

    def test_uninstall_requires_marker_and_preserves_extra_files(self):
        self.run_script('uninstall-dev.sh', expected=1)
        self.run_script('install-dev.sh')
        extra = self.home / 'data/tessarchy/keep.txt'
        extra.write_text('keep')
        self.run_script('uninstall-dev.sh')
        self.assertEqual(extra.read_text(), 'keep')

    def test_uninstall_uses_install_manifest_and_preserves_unknown_extras(self):
        self.run_script('install-dev.sh')
        data = self.home / 'data/tessarchy'
        manifest = data / '.tessarchy-dev-files'
        listed = manifest.read_text().splitlines()
        self.assertIn('shell/shell.qml', listed)
        self.assertIn('session/hyprland.lua', listed)
        self.assertIn('.tessarchy-dev-install', listed)
        for entry in (data / 'shell').rglob('*'):
            if entry.is_file():
                self.assertIn(entry.relative_to(data).as_posix(), listed)
        extra = data / 'shell/components/untracked-extra.qml'
        extra.write_text('keep')
        self.run_script('uninstall-dev.sh')
        self.assertEqual(extra.read_text(), 'keep')
        self.assertFalse((data / 'shell/shell.qml').exists())
        self.assertFalse((data / 'session/hyprland.lua').exists())
        self.assertFalse((data / '.tessarchy-dev-install').exists())
        self.assertFalse((data / '.tessarchy-dev-files').exists())

    def test_uninstall_rejects_unsafe_manifest_before_removing_files(self):
        self.run_script('install-dev.sh')
        data = self.home / 'data/tessarchy'
        manifest = data / '.tessarchy-dev-files'
        original = manifest.read_text()
        outside = self.home / 'outside'
        outside.mkdir()
        sentinel = outside / 'keep'
        sentinel.write_text('keep')
        (data / 'redirect').symlink_to(outside, target_is_directory=True)
        for entry in ('../../outside/keep', '/outside/keep', 'redirect/keep', ''):
            with self.subTest(entry=entry):
                manifest.write_text(original + entry + '\n')
                self.run_script('uninstall-dev.sh', expected=1)
                self.assertEqual(sentinel.read_text(), 'keep')
                self.assertTrue((self.home / '.local/bin/tessera-shell').exists())
                self.assertTrue((data / 'shell/shell.qml').exists())

    def test_uninstall_legacy_marker_uses_fixed_v1_set(self):
        data = self.home / 'data/tessarchy'
        for relative in ('shell/shell.qml', 'shell/components/TouchButton.qml',
                         'session/hyprland.lua'):
            target = data / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('installed')
        marker = data / '.tessarchy-dev-install'
        marker.write_text('tessarchy-dev-v1')
        kept = data / 'shell/components/kept-extra.txt'
        kept.write_text('keep')
        self.run_script('uninstall-dev.sh')
        self.assertFalse((data / 'shell/shell.qml').exists())
        self.assertFalse((data / 'shell/components/TouchButton.qml').exists())
        self.assertFalse((data / 'session/hyprland.lua').exists())
        self.assertFalse((data / '.tessarchy-dev-install').exists())
        self.assertEqual(kept.read_text(), 'keep')
        # The untracked extra survives; everything installed under v1 goes.
        self.assertTrue(kept.exists())
        self.assertFalse((data / 'shell/shell.qml').exists())

    def copy_repo(self, destination, directories):
        import shutil
        for directory in directories:
            shutil.copytree(ROOT / directory, destination / directory)
        for name in ('README.md', 'AGENTS.md', 'LICENSE'):
            shutil.copy2(ROOT / name, destination / name)

    def test_vm_plan_prints_command_refuses_missing_disk_and_bad_usage(self):
        # plan mode only prints the command; qemu is not required to test refusals.
        repo = self.home / 'source'
        self.copy_repo(repo, ('scripts',))
        command = [str(repo / 'scripts/vm.sh')]
        disk = self.home / 'source/vm/tessarchy.qcow2'
        result = subprocess.run(command + ['plan'], env=self.env,
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('init first', result.stderr)
        disk.parent.mkdir(parents=True, exist_ok=True)
        disk.write_text('disk')
        result = subprocess.run(command + ['plan'], env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(str(disk), result.stdout)
        self.assertIn('virtio-vga', result.stdout)
        result = subprocess.run(command + ['wat'], env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        env = dict(self.env, VM_SSH_PORT='80')
        result = subprocess.run(command + ['plan'], env=env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('VM_SSH_PORT', result.stderr)

    FAKE_CURL = ('#!/bin/bash\n'
                 'out=""\n'
                 'prev=""\n'
                 'for a in "$@"; do\n'
                 '    if [[ $prev == "-o" ]]; then out=$a; fi\n'
                 '    prev=$a\n'
                 'done\n'
                 'case "$*" in\n'
                 '    *sha256sums.txt*) cat "$TESSARCHY_FIXTURE_MANIFEST" > "$out";;\n'
                 '    *) exit %s;;\n'
                 'esac\n'
                 'exit 0\n')

    def stub_fetch_tools(self, fakebin, manifest, other_exit):
        import shutil
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_text('1234567890abcdef' * 4 + ' *archlinux-2026.10.01-x86_64.iso\n')
        (fakebin / 'test-keyring.gpg').write_bytes(b'fixture: verification is never reached')
        fakecurl = fakebin / 'curl'
        fakecurl.write_text(self.FAKE_CURL % other_exit)
        fakecurl.chmod(0o755)
        shutil.copy2('/usr/bin/gpgv', fakebin / 'gpgv')
        shutil.copy2('/usr/bin/sha256sum', fakebin / 'sha256sum')

    def test_fetch_iso_never_overwrites_existing_download(self):
        repo = self.home / 'source'
        self.copy_repo(repo, ('scripts',))
        (repo / 'vm').mkdir()
        existing = repo / 'vm/archlinux-2026.10.01-x86_64.iso'
        existing.write_bytes(b'existing download')
        fakebin = self.home / 'bin'
        fakebin.mkdir()
        self.stub_fetch_tools(fakebin, fakebin / 'manifest-fixtures/sha256sums.txt', 0)
        env = dict(self.env, PATH=str(fakebin) + ':' + os.environ['PATH'],
                   TESSARCHY_FIXTURE_MANIFEST=str(fakebin / 'manifest-fixtures/sha256sums.txt'),
                   ARCH_ISO_KEYRING=str(fakebin / 'test-keyring.gpg'))
        result = subprocess.run([str(repo / 'scripts/fetch-arch-iso.sh')], env=env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('already exists', result.stderr)
        self.assertEqual(existing.read_bytes(), b'existing download')
        self.assertFalse(list((repo / 'vm').glob('.download*')))

    def test_fetch_iso_download_failure_leaves_no_partial_iso(self):
        repo = self.home / 'source'
        self.copy_repo(repo, ('scripts',))
        (repo / 'vm').mkdir()
        fakebin = self.home / 'bin'
        fakebin.mkdir()
        self.stub_fetch_tools(fakebin, fakebin / 'manifest-fixtures/sha256sums.txt', 22)
        env = dict(self.env, PATH=str(fakebin) + ':' + os.environ['PATH'],
                   TESSARCHY_FIXTURE_MANIFEST=str(fakebin / 'manifest-fixtures/sha256sums.txt'),
                   ARCH_ISO_KEYRING=str(fakebin / 'test-keyring.gpg'))
        result = subprocess.run([str(repo / 'scripts/fetch-arch-iso.sh')], env=env,
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(list((repo / 'vm').glob('archlinux-*.iso')))
        self.assertFalse(list((repo / 'vm').glob('.download*')))

    def test_build_iso_requires_explicit_archiso_install(self):
        self.run_script('build-iso.sh', expected=1)

    def test_export_vm_source_keeps_existing_snapshot_idempotent(self):
        repo = self.home / 'source'
        self.copy_repo(repo, ('shell', 'session', 'scripts', 'packaging', 'iso',
                              'docs', 'tests', 'assets'))
        share = repo / 'build/vm-share/tessarchy'
        def run():
            return subprocess.run([str(repo / 'scripts/export-vm-source.sh')], env=self.env,
                                  capture_output=True, text=True)
        self.assertEqual(run().returncode, 0)
        self.assertEqual((share / 'scripts/install-dev.sh').read_bytes(),
                         (ROOT / 'scripts/install-dev.sh').read_bytes())
        marker = share / 'README.md'
        first = marker.read_bytes()
        self.assertEqual(run().returncode, 0)
        self.assertIn('Keeping existing snapshot', run().stdout)
        self.assertEqual(marker.read_bytes(), first)

    def test_basic_vm_launcher_refuses_missing_guest_disk(self):
        repo = self.home / 'source'
        self.copy_repo(repo, ('scripts', 'session'))
        result = subprocess.run([str(repo / 'scripts/run-basic-vm.sh')], env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('Missing basic Arch VM disk', result.stderr)

    def test_session_refuses_nested_graphical_launch(self):
        env = dict(self.env, WAYLAND_DISPLAY='wayland-test')
        result = subprocess.run([str(ROOT / 'session/start-tessarchy')], env=env,
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('local TTY', result.stderr)

    def test_login_startup_roundtrip_preserves_profile_and_is_idempotent(self):
        self.run_script('install-dev.sh')
        profile = self.home / '.bash_profile'
        original = b'# existing setup\nexport KEEP_ME=yes\n'
        profile.write_bytes(original)
        command = [str(ROOT / 'scripts/login-session.sh')]
        def change(operation):
            return subprocess.run(command + [operation], env=self.env,
                                  capture_output=True, text=True)
        self.assertEqual(change('enable').returncode, 0)
        enabled = profile.read_bytes()
        self.assertTrue(enabled.startswith(original))
        self.assertIn(b'/dev/tty1', enabled)
        self.assertEqual(change('enable').returncode, 0)
        self.assertEqual(profile.read_bytes(), enabled)
        self.assertEqual(change('disable').returncode, 0)
        self.assertEqual(profile.read_bytes(), original)
        self.assertEqual(change('disable').returncode, 0)
        self.assertTrue(list(self.home.glob('.bash_profile.tessarchy-backup-*')))

    def test_login_startup_preserves_symlinks_and_modified_blocks(self):
        self.run_script('install-dev.sh')
        profile = self.home / '.bash_profile'
        target = self.home / 'real-profile'
        target.write_text('keep')
        profile.symlink_to(target)
        command = [str(ROOT / 'scripts/login-session.sh'), 'enable']
        result = subprocess.run(command, env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.read_text(), 'keep')
        profile.unlink()
        original = '# BEGIN TESSARCHY LOGIN\nmodified\n# END TESSARCHY LOGIN\n'
        profile.write_text(original)
        result = subprocess.run(command, env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(profile.read_text(), original)

    def test_basic_vm_uses_downloaded_disk_and_readonly_fresh_share(self):
        # Stub QEMU rather than open a window or touch a running guest disk.
        fakebin = self.home / 'bin'
        fakebin.mkdir()
        fakeqemu = fakebin / 'qemu-system-x86_64'
        fakeqemu.write_text('#!/bin/bash\nprintf "%s\\n" "$@"\n'
                            'test -f "$VM_SOURCE_SHARE/tessarchy/scripts/setup-guest.sh"\n')
        fakeqemu.chmod(0o755)
        import shutil
        source = self.home / 'source'
        for directory in ('scripts', 'shell', 'session', 'packaging', 'iso', 'docs', 'tests', 'assets'):
            shutil.copytree(ROOT / directory, source / directory)
        for name in ('README.md', 'AGENTS.md', 'LICENSE'):
            shutil.copy2(ROOT / name, source / name)
        (source / 'vm').mkdir()
        disk = source / 'vm/Arch-Linux-x86_64-basic.qcow2'
        disk.write_bytes(b'keep running guest image')
        env = dict(self.env, PATH=str(fakebin) + ':' + os.environ['PATH'])
        result = subprocess.run([str(source / 'scripts/run-basic-vm.sh')], env=env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(str(disk), result.stdout)
        self.assertIn('readonly=on', result.stdout)
        self.assertEqual(disk.read_bytes(), b'keep running guest image')
        self.assertFalse(list((source / 'build').glob('source-share.*')))

    def test_new_windows_follow_saved_mode_without_touching_dialogs(self):
        import shutil
        if not shutil.which('lua'):
            self.skipTest('Lua interpreter unavailable')
        folder = self.home / 'config/tessarchy'
        folder.mkdir(parents=True)
        script = r'''local callbacks, actions, binds = {}, {}, {}
hl = {
    monitor = function() end, config = function() end,
    bind = function(keys, dispatcher, flags) binds[keys] = { dispatcher = dispatcher, flags = flags } end,
    layer_rule = function() end,
    on = function(name, callback) callbacks[name] = callback end,
    dispatch = function(action) table.insert(actions, action) end,
    dsp = { exec_cmd = function(command) return { exec = command } end, exit = function() end,
            focus = function(target) return target end,
            window = { fullscreen = function(action) return action end,
                       close = function() return {} end,
                       cycle_next = function() return {} end,
                       move = function(target) return target end,
                       drag = function() return {} end,
                       resize = function() return {} end } }
}
dofile(arg[1])
-- Desktop bindings stay present and are built from fixed keys and dispatchers.
for i = 1, 5 do
    assert(binds["SUPER + " .. i], "missing workspace bind " .. i)
    assert(binds["SUPER + " .. i].dispatcher.workspace == i, "workspace bind targets wrong workspace")
    assert(binds["SUPER + SHIFT + " .. i], "missing move-to-workspace bind " .. i)
    assert(binds["SUPER + SHIFT + " .. i].dispatcher.workspace == i, "move bind targets wrong workspace")
end
for _, name in ipairs({ "SUPER + Q", "SUPER + Tab", "SUPER + left", "SUPER + right",
    "SUPER + up", "SUPER + down", "SUPER + SHIFT + left", "SUPER + SHIFT + right",
    "SUPER + SHIFT + up", "SUPER + SHIFT + down" }) do
    assert(binds[name], "missing desktop bind: " .. name)
end
assert(binds["SUPER + mouse:272"].flags.mouse == true, "drag bind must be a mouse bind")
assert(binds["SUPER + mouse:273"].flags.mouse == true, "resize bind must be a mouse bind")
assert(binds["XF86AudioMute"].flags.locked == true and binds["XF86AudioMute"].flags.repeating == true,
    "volume keys must work on the lock screen and repeat")
assert(binds["SUPER + Q"].dispatcher.exec == "tessera-shell ipc call actions closeWindow")
assert(binds["SUPER + SHIFT + E"].dispatcher.exec == "tessera-shell ipc call actions endSession")
local function check(mode, width, height, scale, transform, floating, fullscreen, expected)
    local f = assert(io.open(os.getenv("XDG_CONFIG_HOME") .. "/tessarchy/shell.ini", "w"))
    f:write("[Other]\nlayoutMode=desktop\n[Shell]\nlayoutMode=" .. mode .. "\n")
    f:close()
    actions = {}
    local window = { floating = floating, fullscreen = fullscreen,
        monitor = {width=width, height=height, scale=scale, transform=transform} }
    callbacks["window.open"](window)
    assert(#actions == expected, mode .. ": unexpected app startup policy")
    if expected == 1 then
        assert(actions[1].window == window and actions[1].mode == "maximized")
    end
end
check("auto", 400, 800, 1, 0, false, 0, 1)
check("auto", 800, 1280, 1, 0, false, 0, 1)
check("auto", 1280, 800, 1, 0, false, 0, 0)
check("auto", 1280, 800, 2, 0, false, 0, 1)
check("auto", 1280, 800, 1, 1, false, 0, 1)
check("desktop", 400, 800, 1, 0, false, 0, 0)
check("phone", 1280, 800, 1, 0, false, 0, 1)
check("invalid", 400, 800, 1, 0, false, 0, 1)
check("phone", 400, 800, 1, 0, true, 0, 0)
check("phone", 400, 800, 1, 0, false, 2, 0)
'''
        result = subprocess.run(['lua', '-', str(ROOT / 'session/hyprland.lua')],
                                input=script, text=True, capture_output=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_mobile_policy_keeps_active_app_maximized_and_fits_dialogs(self):
        import shutil
        if not shutil.which('lua'):
            self.skipTest('Lua interpreter unavailable')
        (self.home / 'config/tessarchy').mkdir(parents=True)
        script = r'''local callbacks, actions = {}, {}
local function action(kind) return function(a) a = a or {}; a.kind = kind; return a end end
hl = {
    layer_rule = function() end,
    monitor = function() end, config = function() end, bind = function() end,
    on = function(name, callback) callbacks[name] = callback end,
    dispatch = function(a) table.insert(actions, a) end,
    dsp = { exec_cmd = function() end, exit = function() end, focus = function() end,
            window = { fullscreen = action("fullscreen"), resize = action("resize"),
                       center = action("center"), move = function() end,
                       close = function() end, cycle_next = function() end,
                       drag = function() end } }
}
dofile(arg[1])
local function mode(m)
    local f = assert(io.open(os.getenv("XDG_CONFIG_HOME") .. "/tessarchy/shell.ini", "w"))
    f:write("[Shell]\nlayoutMode=" .. m .. "\n"); f:close()
end
local function monitor(w, h, transform, bottom)
    return { width = w, height = h, scale = 1, transform = transform or 0,
             reserved = { left = 0, right = 0, top = 48, bottom = bottom or 80 } }
end
local function fire(event, window) actions = {}; callbacks[event](window); return actions end
mode("auto")
-- Switching to (or surfacing) an ordinary app maximizes it on phones.
local app = { floating = false, fullscreen = 0, monitor = monitor(720, 1440) }
local a = fire("window.active", app)
assert(#a == 1 and a[1].kind == "fullscreen" and a[1].mode == "maximized" and a[1].window == app)
app.fullscreen = 1
assert(#fire("window.active", app) == 0, "already maximized")
assert(#fire("window.active", nil) == 0, "no active window")
local desk = { floating = false, fullscreen = 0, monitor = monitor(1920, 1080) }
assert(#fire("window.active", desk) == 0, "desktop keeps tiling")
-- Oversized dialogs shrink to the area between bars and keyboard, then center.
local dialog = { floating = true, fullscreen = 0, size = { x = 1232, y = 949 },
                 monitor = monitor(720, 1440, 0, 305) }
a = fire("window.open", dialog)
assert(#a == 2 and a[1].kind == "resize" and a[1].window == dialog, "resize first")
assert(a[1].x == 720 and a[1].y == 949, a[1].x .. "x" .. a[1].y)
assert(a[2].kind == "center" and a[2].window == dialog)
dialog.size = { x = 600, y = 1200 }
a = fire("window.open", dialog)
assert(a[1].x == 600 and a[1].y == 1087, "height limited by keyboard")
-- Rotated phone: logical 800x400 minus bars.
dialog.monitor = monitor(400, 800, 1); dialog.size = { x = 1000, y = 300 }
a = fire("window.open", dialog)
assert(a[1].x == 800 and a[1].y == 272, a[1].x .. "x" .. a[1].y)
dialog.monitor = monitor(720, 1440); dialog.size = { x = 400, y = 300 }
assert(#fire("window.open", dialog) == 0, "dialogs that fit are left alone")
dialog.fullscreen = 2; dialog.size = { x = 1232, y = 949 }
assert(#fire("window.open", dialog) == 0, "fullscreen stays untouched")
dialog.fullscreen = 0
dialog.size = { x = 1232, y = 949 }; mode("desktop")
assert(#fire("window.open", dialog) == 0, "desktop dialogs are left alone")
'''
        result = subprocess.run(['lua', '-', str(ROOT / 'session/hyprland.lua')],
                                input=script, text=True, capture_output=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def screenshot_tools(self, grim_body=None):
        import shutil
        tools = self.home / 'capture-tools'
        tools.mkdir()
        for name in ('bash', 'mkdir', 'mktemp', 'rm', 'basename'):
            (tools / name).symlink_to(shutil.which(name))
        (tools / 'date').write_text('#!/bin/bash\nprintf 20261017-120000\n')
        (tools / 'date').chmod(0o755)
        if grim_body is not None:
            (tools / 'grim').write_text('#!/bin/bash\n' + grim_body)
            (tools / 'grim').chmod(0o755)
        return dict(self.env, PATH=str(tools), XDG_PICTURES_DIR=str(self.home / 'pictures'))

    def test_screenshots_are_unique_private_and_notification_is_optional(self):
        env = self.screenshot_tools('printf png > "$1"\n')
        tools = Path(env['PATH'])
        (tools / 'notify-send').write_text('#!/bin/bash\nexit 1\n')
        (tools / 'notify-send').chmod(0o755)
        directory = self.home / 'pictures/Screenshots'
        directory.mkdir(parents=True)
        sentinel = directory / 'tessarchy-20261017-120000.png'
        sentinel.write_text('unrelated existing screenshot')
        paths = []
        for _ in range(2):
            result = subprocess.run([str(ROOT / 'session/tessera-screenshot')], env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            path = Path(result.stdout.strip())
            self.assertEqual(path.read_text(), 'png')
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            paths.append(path)
        self.assertNotEqual(paths[0], paths[1])
        self.assertEqual(sentinel.read_text(), 'unrelated existing screenshot')

    def test_failed_screenshot_removes_partial_file_and_rejects_arguments(self):
        env = self.screenshot_tools('printf partial > "$1"; exit 7\n')
        command = [str(ROOT / 'session/tessera-screenshot')]
        failed = subprocess.run(command, env=env, capture_output=True, text=True)
        self.assertEqual(failed.returncode, 7)
        self.assertEqual(list((self.home / 'pictures/Screenshots').iterdir()), [])
        invalid = subprocess.run(command + ['unrelated.png'], env=env, capture_output=True)
        self.assertEqual(invalid.returncode, 64)
        (Path(env['PATH']) / 'grim').unlink()
        missing = subprocess.run(command, env=env, capture_output=True, text=True)
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn('grim is required', missing.stderr)

    def test_existing_screenshot_helper_refused(self):
        launcher = self.home / '.local/bin/tessera-screenshot'
        launcher.parent.mkdir(parents=True)
        launcher.write_text('unrelated helper')
        self.run_script('install-dev.sh', expected=1)
        self.assertEqual(launcher.read_text(), 'unrelated helper')
        self.assertFalse((self.home / 'data/tessarchy').exists())

    def test_wifi_panel_password_contract(self):
        source = (ROOT / 'shell/components/WifiPanel.qml').read_text()
        # A passphrase leaves the panel only through connectWithPsk, the field
        # is masked, and every close path clears it before the attempt.
        self.assertEqual(source.count('connectWithPsk'), 1)
        self.assertIn('TextInput.Password', source)
        self.assertIn('pskField.text = ""', source)
        self.assertGreaterEqual(source.count('closePrompt()'), 4)
        self.assertIn('psk.length < 8', source)
        # The scanner is owned by the panel: on only while visible and on.
        self.assertIn('panel.device.scannerEnabled = panel.visible && panel.wifiOn', source)
        self.assertIn('if (!panel.visible)', source)

    def test_wifi_quick_controls_wiring(self):
        sheet = (ROOT / 'shell/components/QuickSettings.qml').read_text()
        self.assertIn('WifiPanel {', sheet)
        self.assertIn('device: sheet.wifiDevice', sheet)
        self.assertIn('property var wifiDevice', sheet)
        shell = (ROOT / 'shell/shell.qml').read_text()
        self.assertIn('wifiDevice: root.wifiDevice', shell)
        self.assertIn('NetworkBackendType.None', shell)
        self.assertIn('available: root.networkBackend', shell)
        # Keyboard focus reaches the drawer only while the prompt is open.
        self.assertIn('quickSheet.wifiPromptOpen ? WlrKeyboardFocus.Exclusive', shell)

    def test_iso_staging_preserves_boot_assets_and_account_databases(self):
        # Minimal fixture exercises our assembly, not upstream archiso validity.
        repo = self.home / 'source'
        (repo / 'scripts').mkdir(parents=True)
        import shutil
        for directory in ('shell', 'session', 'iso', 'docs'):
            shutil.copytree(ROOT / directory, repo / directory)
        shutil.copy2(ROOT / 'scripts/stage-iso.sh', repo / 'scripts')
        base = self.home / 'releng'
        (base / 'airootfs/etc/systemd/system/multi-user.target.wants').mkdir(parents=True)
        (base / 'profiledef.sh').write_text('file_permissions=(["/etc/shadow"]="0:0:400")\n')
        (base / 'packages.x86_64').write_text('base\nlinux\nunused-rescue-tool\n')
        (base / 'airootfs/etc/passwd').write_text('root:x:0:0:root:/root:/usr/bin/zsh\n')
        boot = base / 'efiboot/loader/entries'
        boot.mkdir(parents=True)
        (boot / 'arch.conf').write_text('retained boot asset')
        ssh_link = base / 'airootfs/etc/systemd/system/multi-user.target.wants/sshd.service'
        ssh_link.symlink_to('/usr/lib/systemd/system/sshd.service')
        env = dict(self.env, ARCHISO_RELENG=str(base))
        command = [str(repo / 'scripts/stage-iso.sh')]
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        profile = repo / 'build/iso-profile'
        self.assertEqual((profile / 'efiboot/loader/entries/arch.conf').read_text(),
                         'retained boot asset')
        self.assertEqual((profile / 'airootfs/etc/passwd').read_text(),
                         'root:x:0:0:root:/root:/usr/bin/bash\n')
        self.assertIn('/usr/bin/zsh', (base / 'airootfs/etc/passwd').read_text())
        self.assertFalse((profile / 'airootfs/etc/group').exists())
        self.assertFalse((profile / 'airootfs/etc/systemd/system/multi-user.target.wants/sshd.service').is_symlink())
        self.assertTrue(ssh_link.is_symlink())
        self.assertIn('quickshell', (profile / 'packages.x86_64').read_text())
        self.assertIn('networkmanager', (profile / 'packages.x86_64').read_text())
        self.assertIn('wpa_supplicant', (profile / 'packages.x86_64').read_text())
        self.assertNotIn('unused-rescue-tool', (profile / 'packages.x86_64').read_text())
        self.assertNotIn('linux-firmware', (profile / 'packages.x86_64').read_text())
        self.assertTrue((profile / 'airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service').is_symlink())
        self.assertTrue((profile / 'airootfs/etc/systemd/system/multi-user.target.wants/systemd-timesyncd.service').is_symlink())
        self.assertEqual((profile / 'airootfs/etc/hostname').read_text().strip(), 'tessarchy')
        self.assertIn('en_US.UTF-8', (profile / 'airootfs/etc/locale.conf').read_text())
        self.assertIn('en_US.UTF-8', (profile / 'airootfs/etc/locale.gen').read_text())
        self.assertIn('/usr/share/tessarchy/docs', (profile / 'airootfs/etc/motd').read_text())
        self.assertIn('Storage=volatile',
                      (profile / 'airootfs/etc/systemd/journald.conf.d/volatile.conf').read_text())
        self.assertTrue((profile / 'airootfs/usr/share/tessarchy/docs/iso.md').is_file())
        self.assertTrue((profile / 'airootfs/usr/bin/start-tessarchy').stat().st_mode & 0o111)
        self.assertTrue((profile / 'airootfs/usr/bin/tessera-screenshot').stat().st_mode & 0o111)
        self.assertIn('grim', (profile / 'packages.x86_64').read_text().splitlines())
        self.assertIn('libnotify', (profile / 'packages.x86_64').read_text().splitlines())
        self.assertIn('u tess 1000 "Tessarchy live user" /home/tess /usr/bin/fish',
                      (profile / 'airootfs/etc/sysusers.d/tessarchy.conf').read_text())
        self.assertIn('fish', (profile / 'packages.x86_64').read_text().splitlines())
        self.assertTrue((profile / 'airootfs/home/tess/.config/fish/config.fish').is_file())
        self.assertIn('/home/tess/.config/fish/config.fish', (profile / 'profiledef.sh').read_text())
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
