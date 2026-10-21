"""Observable install safety and profile assembly; no GUI or privileged tests."""
import os
import re
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Workflows(unittest.TestCase):
    def test_shell_shape_literals_live_in_theme_tokens(self):
        # Tiny decorative marks and circular avatars retain fixed geometry.
        legacy = {'StatusIcon.qml': 1, 'ContactAvatar.qml': 1, 'shell.qml': 2}
        pattern = re.compile(r'\bradius:\s*(?:\d+|width\s*/\s*2)\b')
        paths = list((ROOT / 'shell').glob('*.qml')) + list((ROOT / 'shell/components').glob('*.qml'))
        for path in paths:
            if path.name == 'Theme.qml':
                continue
            offenders = [n for n, line in enumerate(path.read_text().splitlines(), 1)
                         if pattern.search(line)]
            self.assertLessEqual(len(offenders), legacy.get(path.name, 0),
                                 f'{path.name}: raw radius at {offenders}')
        self.assertEqual(sum(legacy.values()), 4)

    def test_shell_shape_overrides_clamp_and_reset(self):
        import shutil
        quickshell = shutil.which('qs')
        if not quickshell:
            self.skipTest('Quickshell runtime unavailable')
        runtime = self.home / 'runtime'
        runtime.mkdir(mode=0o700)
        shell = self.home / 'shell'
        shutil.copytree(ROOT / 'shell', shell)
        harness = shell / 'shape-harness.qml'
        harness.write_text((ROOT / 'tests/quickshell/shape.qml').read_text()
                           .replace('../../shell/components', 'components'))
        result = subprocess.run([quickshell, '--no-color', '-p', str(harness)],
                                env=dict(self.env, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='',
                                         XDG_RUNTIME_DIR=str(runtime)),
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('SHAPE_TEST_PASS', result.stdout + result.stderr)
        self.assertNotIn('SHAPE_TEST_FAIL', result.stdout + result.stderr)

    def test_shell_colors_live_in_theme_tokens(self):
        pattern = re.compile(r'#[0-9a-fA-F]{6,8}\b|Qt\.rgba\s*\(')
        paths = list((ROOT / 'shell').glob('*.qml')) + list((ROOT / 'shell/components').glob('*.qml'))
        for path in paths:
            if path.name == 'Theme.qml':
                continue  # Only the theme engine may hold colour literals.
            offenders = [number for number, line in enumerate(path.read_text().splitlines(), 1)
                         if pattern.search(line)]
            self.assertEqual(offenders, [], f'{path.name}: colour literals')
        # Every semantic token is loadable from shell.toml and pinned by Tessera.
        theme = (ROOT / 'shell/components/Theme.qml').read_text()
        tokens = re.findall(r'property color \w+: token\("([a-z_]+)"', theme)
        self.assertGreater(len(tokens), 50)
        allowed = re.search(r'const allowed = \[(.*?)\];', theme, re.S).group(1)
        tessera = (ROOT / 'themes/tessera/shell.toml').read_text()
        for name in tokens:
            self.assertIn(f'"{name}"', allowed)
            self.assertRegex(tessera, rf'(?m)^{name} = "#[0-9a-f]{{6,8}}"$')
        for name in ('greeter.qml', 'login-preview.qml'):
            self.assertIn('ThemeLoader {', (ROOT / 'shell' / name).read_text())

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

    def test_bar_geometry_comes_from_one_set_of_constants(self):
        import re
        shell = (ROOT / 'shell/shell.qml').read_text()
        policy = (ROOT / 'shell/LayoutPolicy.js').read_text()
        self.assertIn('function barGeometry(mode, rows)', policy)
        self.assertRegex(shell, r'property var bar: Policy\.barGeometry\(mode, dock\.rows\)')
        self.assertRegex(shell, r'property int navHeight: bar\.height\n')
        panel = shell[shell.index('id: panel\n'):shell.index('id: statusBar\n')]
        # The frame and its content margins: no literal except the open-page flush 0.
        margins = re.findall(r'^ {20}anchors\.\w*[mM]argins?:.*$', panel, re.M)
        self.assertGreaterEqual(len(margins), 5, margins)
        for line in margins:
            self.assertNotRegex(line.replace('panel.expanded ? 0 :', ''), r'\d', line)
        dock = panel[panel.index('columns: surface.dock.columns') - 200:]
        dock = dock[:dock.index('NavButton {')]
        for key in ('Layout.preferredHeight', 'columnSpacing', 'rowSpacing'):
            line = re.search(key + r':.*', dock).group(0)
            self.assertNotRegex(line, r'\d', line)
        taskbar = panel[panel.index('visible: surface.mode === "desktop"\n'):]
        self.assertIn('Layout.preferredHeight: surface.bar.row\n', taskbar[:200])

    def test_navigation_gestures_reuse_dock_actions_and_keep_a_button_fallback(self):
        shell = (ROOT / 'shell/shell.qml').read_text()
        settings = (ROOT / 'shell/components/SettingsPage.qml').read_text()
        self.assertIn('property string navigation: "gestures"', shell)
        self.assertIn('property bool showGestureHandle: true', shell)
        self.assertIn('Policy.gestureNavigation(mode, shellPreferences.navigation)', shell)
        self.assertIn('Policy.dockLayout(mode, modelData.width, root.oskAvailable, gestures)', shell)
        # Buttons and gestures call the same panel action; no copied logic.
        for action in ('back', 'home', 'recents'):
            self.assertIn(f'onClicked: panel.navigate("{action}")', shell)
        self.assertIn('if (surface.gestures) panel.navigate(action);', shell)
        self.assertEqual(shell.count('onGesture: action => panel.navigate(action)'), 1)
        self.assertEqual(shell.count('visible: !surface.gestures'), 3)
        self.assertIn('shown: surface.gestures && shellPreferences.showGestureHandle', shell)
        self.assertIn('visible: surface.gestures', shell)
        self.assertIn('value: "buttons"', settings)
        self.assertIn('page.preferences.navigation = modelData.value', settings)

    def test_hidden_touch_dock_has_independent_reveal_layer(self):
        shell = (ROOT / 'shell/shell.qml').read_text()
        policy = (ROOT / 'shell/LayoutPolicy.js').read_text()
        self.assertIn('Policy.dockState(mode, hasApp, panel.expanded, dockRevealed, navHeight)', shell)
        self.assertIn('visible: surface.dockState.visible', shell)
        self.assertIn('exclusiveZone: surface.dockState.exclusiveZone', shell)
        self.assertIn('visible: surface.gestures || surface.dockState.reveal', shell)
        self.assertIn('onTapped: if (surface.dockState.reveal) surface.revealDock()', shell)
        self.assertIn('shown: surface.gestures && shellPreferences.showGestureHandle', shell)
        self.assertIn('function dockState(mode, hasApp, expanded, revealed, barHeight)', policy)

    def test_components_qmldir_lists_every_component(self):
        # An explicit qmldir hides any component it omits ("X is not a type").
        components = ROOT / 'shell/components'
        listed = {line.split()[-1] for line in (components / 'qmldir').read_text().splitlines() if line.strip()}
        self.assertEqual(listed, {path.name for path in components.glob('*.qml')})

    def test_display_controls_restore_failed_brightness_and_apply_night_preference(self):
        stubs = self.home / 'display-bin'
        stubs.mkdir()
        brightness = stubs / 'tessera-brightness'
        brightness.write_text('#!/bin/sh\nif [ "$1" = get ]; then echo 42; else exit 1; fi\n')
        night = stubs / 'tessera-nightlight'
        night.write_text('#!/bin/sh\ncase "$1" in\nstatus) if [ -f "$HOME/night-active" ]; then echo on; else echo off; exit 1; fi ;;\non) touch "$HOME/night-active" ;;\noff) rm -f "$HOME/night-active" ;;\nesac\n')
        brightness.chmod(0o755)
        night.chmod(0o755)
        self.env['PATH'] = str(stubs) + ':' + os.environ['PATH']
        self.run_quickshell_harness('display', 'DISPLAY')

    def test_bluetooth_component_lifecycle_and_action_guards(self):
        self.run_quickshell_harness('bluetooth', 'BLUETOOTH')

    def test_audio_panel_without_pipewire_service(self):
        self.run_quickshell_harness('audio', 'AUDIO')

    def test_communications_components_and_private_contact_save(self):
        self.env['DBUS_SYSTEM_BUS_ADDRESS'] = 'unix:path=/nonexistent/tessarchy-test-bus'
        self.run_quickshell_harness('communications', 'COMMUNICATIONS')

    def test_power_panel_without_daemon_never_writes(self):
        self.env['DBUS_SYSTEM_BUS_ADDRESS'] = 'unix:path=/nonexistent/tessarchy-test-bus'
        self.run_quickshell_harness('power', 'POWER')

    def test_site_builder_refuses_existing_output_and_bundles_originals(self):
        import sys
        import zipfile
        destination = self.home / 'site'
        command = [sys.executable, str(ROOT / 'scripts/build-site.py'),
                   '--output', str(destination)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        with zipfile.ZipFile(destination / 'assets/screenshots.zip') as archive:
            count = sum(name.endswith('.png') for name in archive.namelist())
            page = (destination / 'index.html').read_text()
            self.assertIn(f'includes {count} published captures', page)
            self.assertNotIn('{{SCREENSHOT_COUNT}}', page)
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
        for variable in ('DISPLAY', 'WAYLAND_DISPLAY', 'TESSARCHY_DATA_DIR', 'DBUS_SESSION_BUS_ADDRESS'):
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
        for helper in ('tessera-brightness', 'tessera-nightlight'):
            self.assertTrue((self.home / '.local/bin' / helper).stat().st_mode & 0o111)
        self.assertTrue((data / 'shell/components/NotificationCard.qml').is_file())
        self.assertTrue((data / 'shell/icons/bell.svg').is_file())
        self.run_script('install-dev.sh', expected=1)
        self.run_script('uninstall-dev.sh')
        self.assertFalse(data.exists())
        self.assertEqual(sentinel.read_text(), 'existing config')
        self.assertEqual(preferences.read_text(), '-- mine')
        self.assertEqual(shell_settings.read_text(), '[Shell]\nlayoutMode=tablet\n')
        self.assertFalse((self.home / '.local/bin/tessarchy-osk').exists())
        self.assertFalse((self.home / '.local/bin/tessera-screenshot').exists())
        self.assertFalse((self.home / '.local/bin/tessera-brightness').exists())
        self.assertFalse((self.home / '.local/bin/tessera-nightlight').exists())

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

    def test_osk_enforces_minimum_portrait_key_height(self):
        log = self.home / 'gsettings.log'
        fake_osk = ('squeekboard', 'exit 0\n')
        # width, height, monitor scale, expected portrait panel multiplier.
        cases = (('400', '800', '1', '1.80'), ('800', '1600', '2', '1.80'),
                 ('300', '600', '1', '2.00'),
                 ('600', '1200', '1.5', '1.80'), ('600', '1200', '1.50', '1.80'),
                 ('500', '1000', '1.25', '1.80'))
        for width, height, scale, expected in cases:
            hypr = ('hyprctl', f'echo \'[{{"width":{width},"height":{height},"scale":{scale}}}]\'\n')
            gsettings = ('gsettings', f'echo "$*" >> {log}\n')
            env = dict(self.env, WAYLAND_DISPLAY='wayland-test')
            log.unlink(missing_ok=True)
            result = self.osk('start', path_tools=[fake_osk, hypr, gsettings], env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(f'scale-in-vertical-screen-orientation {expected}', log.read_text())

    def test_osk_arms_and_disarms_the_a11y_keyboard(self):
        log = self.home / 'a11y.log'
        gsettings = ('gsettings', f'echo "$*" >> {log}\n')
        for action, expected in (('disable', 'false'), ('enable', 'true')):
            log.unlink(missing_ok=True)
            result = self.osk(action, path_tools=[gsettings])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(f'screen-keyboard-enabled {expected}', log.read_text())
        self.assertEqual(self.osk('whatever').returncode, 2)

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
        # A real login user bus must be reused instead of starting a private bus.
        import socket
        runtime = self.home / 'user-bus'
        runtime.mkdir()
        with socket.socket(socket.AF_UNIX) as server:
            server.bind(str(runtime / 'bus'))
            (tools / 'dbus-run-session').write_text('#!/bin/bash\nexit 99\n')
            result = subprocess.run([str(ROOT / 'session/start-tessarchy')],
                                    env=dict(env, XDG_RUNTIME_DIR=str(runtime)),
                                    capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
    def theme(self, *args, env=None):
        run_env = dict(env or self.env, TESSARCHY_DATA_DIR=str(ROOT),
                       XDG_STATE_HOME=str(self.home / 'state'))
        return subprocess.run([str(ROOT / 'session/tessarchy-theme'), *args], env=run_env,
                              capture_output=True, text=True)

    def test_theme_renders_shell_keyboard_and_terminal_from_one_palette(self):
        state = self.home / 'state/tessarchy'
        self.assertEqual(self.theme('current').stdout.strip(), 'tessera')
        self.assertEqual(self.theme('apply').returncode, 0)
        self.assertEqual((state / 'theme/name').read_text().strip(), 'tessera')
        self.assertIn('accent = "#a9e8d5"', (state / 'theme/colors.toml').read_text())
        self.assertIn('glass = "#501c2c43"', (state / 'theme/colors.toml').read_text())
        result = self.theme('set', 'tessera-light')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((state / 'theme/mode').read_text().strip(), 'light')
        self.assertNotIn('[tessera]', (state / 'theme/colors.toml').read_text())
        css = (state / 'osk/gtk-3.0/gtk.css').read_text()
        self.assertIn('#Return { background: #1f8a72', css)
        self.assertIn('sq_view { background-color: #cfd9e4', css)
        self.assertIn('background=eef3f8', (state / 'theme/foot.ini').read_text())
        for bad in ('../tessera', 'missing', '.hidden'):
            self.assertEqual(self.theme('set', bad).returncode, 1, bad)
        self.assertEqual(self.theme('current').stdout.strip(), 'tessera-light')
        self.assertEqual(self.theme().returncode, 2)
        # An Omarchy theme directory works as-is: palette, luminance-derived
        # mode, wallpaper, and the user's own foot config kept underneath.
        mine = self.home / 'config/tessarchy/themes/paper'
        (mine / 'backgrounds').mkdir(parents=True)
        (mine / 'colors.toml').write_text('background = "#FAFAFA"\nforeground = "#202020"\nblue = "#3366cc"\n')
        (mine / 'backgrounds/1.png').write_bytes(b'png')
        user_foot = self.home / 'config/foot/foot.ini'
        user_foot.parent.mkdir(parents=True)
        user_foot.write_text('font=monospace:size=14\n')
        self.assertIn('paper\tlight\t#fafafa\t#202020\t#3366cc', self.theme('list').stdout)
        self.assertEqual(self.theme('set', 'paper').returncode, 0)
        self.assertNotIn('[tessera]', (state / 'theme/colors.toml').read_text())
        self.assertEqual((state / 'theme/mode').read_text().strip(), 'light')
        self.assertEqual((state / 'theme/wallpaper').read_text().strip(), str(mine / 'backgrounds/1.png'))
        foot = (state / 'theme/foot.ini').read_text()
        self.assertTrue(foot.startswith(f'include={user_foot}\n'), foot)
        self.assertEqual(user_foot.read_text(), 'font=monospace:size=14\n')
        self.theme('set', 'tessera')
        self.assertEqual((state / 'theme/wallpaper').read_text().strip(), '')

    def test_theme_surface_defaults_overrides_and_invalid_values(self):
        state = self.home / 'state/tessarchy/theme'
        borders = 'window_border = 0, window_border_active = "rgb(a9e8d5)", window_border_inactive = "rgb(34465e)"'
        defaults = f'return {{ window_rounding = 18, blur_enabled = true, blur_size = 4, blur_passes = 2, {borders} }}\n'
        self.assertEqual(self.theme('set', 'tessera').returncode, 0)
        self.assertEqual((state / 'surface.lua').read_text(), defaults)
        custom = self.home / 'config/tessarchy/themes/shape'
        custom.mkdir(parents=True)
        (custom / 'colors.toml').write_text((ROOT / 'themes/tessera/colors.toml').read_text())
        (custom / 'shell.toml').write_text('[surface]\nradius_card = 4\nradius_button = 4\n'
                                           'border_width = 3\nwindow_rounding = 4\nblur_enabled = false\n'
                                           'blur_size = 8\nblur_passes = 3\n')
        result = self.theme('set', 'shape')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((state / 'surface.lua').read_text(),
                         f'return {{ window_rounding = 4, blur_enabled = false, blur_size = 8, blur_passes = 3, {borders} }}\n')
        self.assertIn('radius_card = 4', (state / 'colors.toml').read_text())
        (custom / 'shell.toml').write_text('[surface]\nwindow_rounding = 4; os.execute("false")\n'
                                           'blur_enabled = "false"\nblur_size = -1\nblur_passes = 999\n'
                                           'radius_card = "garbage"\nborder_width = 9\n')
        result = self.theme('set', 'shape')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((state / 'surface.lua').read_text(), defaults)
        self.assertEqual(self.theme('set', 'tessera-light').returncode, 0)
        self.assertIn('blur_passes = 2, window_border = 0, window_border_active = "rgb(1f8a72)"',
                      (state / 'surface.lua').read_text())

    def hyprland_config(self):
        # Evaluate session/hyprland.lua with a stub hl and print what it configures.
        script = r'''local seen = {}
local noop = function() end
hl = setmetatable({ config = function(t) seen = t end, dsp = setmetatable({}, { __index = function()
    return setmetatable({}, { __index = function() return noop end, __call = noop }) end }) },
    { __index = function() return noop end })
dofile(arg[1])
local g, col = seen.general, seen.general.col or {}
local group = seen.group and seen.group.col or {}
print(g.border_size, col.active_border, col.inactive_border, group.border_active, group.border_inactive)
'''
        env = dict(self.env, XDG_STATE_HOME=str(self.home / 'state'))
        result = subprocess.run(['lua', '-', str(ROOT / 'session/hyprland.lua')],
                                input=script, text=True, capture_output=True, env=env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout.split()

    def test_theme_window_borders_default_off_clamp_and_fall_back(self):
        import shutil
        if not shutil.which('lua'):
            self.skipTest('Lua interpreter unavailable')
        state = self.home / 'state/tessarchy/theme'
        # No staged theme: the session config keeps border_size 0 and Hyprland's colours.
        self.assertEqual(self.hyprland_config(), ['0', 'nil', 'nil', 'nil', 'nil'])
        self.assertEqual(self.theme('set', 'tessera').returncode, 0)
        self.assertEqual(self.hyprland_config(), ['0', 'rgb(a9e8d5)', 'rgb(34465e)', 'rgb(a9e8d5)', 'rgb(34465e)'])
        custom = self.home / 'config/tessarchy/themes/framed'
        custom.mkdir(parents=True)
        (custom / 'colors.toml').write_text((ROOT / 'themes/tessera/colors.toml').read_text())
        shell = lambda body: (custom / 'shell.toml').write_text('[surface]\n' + body)
        shell('window_border = 2\nwindow_border_active = "#FF8800"  # orange\n'
              'window_border_inactive = "#202020"\n')
        self.assertEqual(self.theme('set', 'framed').returncode, 0)
        self.assertIn('window_border = 2, window_border_active = "rgb(ff8800)", window_border_inactive = "rgb(202020)"',
                      (state / 'surface.lua').read_text())
        self.assertEqual(self.hyprland_config(), ['2', 'rgb(ff8800)', 'rgb(202020)', 'rgb(ff8800)', 'rgb(202020)'])
        shell('window_border = 9\n')
        self.theme('set', 'framed')
        self.assertEqual(self.hyprland_config()[0], '4')
        # Invalid widths and colours fall back to no border and palette colours.
        for bad in ('window_border = -1\nwindow_border_active = "red"\nwindow_border_inactive = #123456\n',
                    'window_border = 2.5\nwindow_border_active = "#12345"\n',
                    'window_border = "2"\nwindow_border_active = "#123456"; os.execute("false")\n',
                    'window_border = 2; os.exit(1)\nwindow_border_inactive = "#zzzzzz"\n'):
            shell(bad)
            self.assertEqual(self.theme('set', 'framed').returncode, 0, bad)
            self.assertEqual(self.hyprland_config(), ['0', 'rgb(a9e8d5)', 'rgb(34465e)', 'rgb(a9e8d5)', 'rgb(34465e)'], bad)
        # A hand-edited out-of-range staged file is still refused by the session.
        (state / 'surface.lua').write_text('return { window_border = 12, window_border_active = "red; x" }\n')
        self.assertEqual(self.hyprland_config(), ['0', 'nil', 'nil', 'nil', 'nil'])
        self.assertEqual(self.theme('set', 'tessera').returncode, 0)
        self.assertEqual(self.hyprland_config()[0], '0')

    def test_theme_never_sources_theme_hyprland_or_chromium_files(self):
        import shutil
        if not shutil.which('lua'):
            self.skipTest('Lua interpreter unavailable')
        marker = self.home / 'theme-code-ran'
        custom = self.home / 'config/tessarchy/themes/coded'
        custom.mkdir(parents=True)
        (custom / 'colors.toml').write_text((ROOT / 'themes/tessera/colors.toml').read_text())
        (custom / 'hyprland.lua').write_text(f'os.execute("touch {marker}")\nerror("theme code ran")\n')
        (custom / 'chromium.theme').write_text('255,0,0\n')
        result = self.theme('set', 'coded')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.hyprland_config()[0], '0')
        self.assertFalse(marker.exists())
        staged = self.home / 'state/tessarchy/theme'
        self.assertEqual(sorted(p.name for p in staged.iterdir()),
                         ['colors.toml', 'foot.ini', 'mode', 'name', 'surface.lua', 'wallpaper'])
        for path in staged.iterdir():
            self.assertNotIn('theme code ran', path.read_text())

    def test_theme_icon_theme_is_validated_and_applied_only_when_installed(self):
        stubs = self.home / 'bin'
        stubs.mkdir()
        log = self.home / 'gsettings.log'
        (stubs / 'gsettings').write_text(f'#!/bin/bash\necho \"$*\" >> {log}\n')
        (stubs / 'gsettings').chmod(0o755)
        (self.home / 'data/icons/Good-Icons').mkdir(parents=True)
        (self.home / 'data/icons/Good-Icons/index.theme').write_text('[Icon Theme]\nName=Good\n')
        (self.home / 'data/icons/No-Index').mkdir(parents=True)
        env = dict(self.env, PATH=f'{stubs}:{os.environ["PATH"]}', XDG_DATA_DIRS=str(self.home / 'none'),
                   DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
        custom = self.home / 'config/tessarchy/themes/iconic'
        custom.mkdir(parents=True)
        (custom / 'colors.toml').write_text((ROOT / 'themes/tessera/colors.toml').read_text())
        staged = self.home / 'state/tessarchy/theme/icons'
        calls = lambda: log.read_text().splitlines() if log.exists() else []
        # Omarchy's icons.theme has no trailing newline.
        (custom / 'icons.theme').write_text('Good-Icons')
        self.assertEqual(self.theme('set', 'iconic', env=env).returncode, 0)
        self.assertEqual(calls(), ['set org.gnome.desktop.interface icon-theme Good-Icons'])
        self.assertEqual(staged.read_text(), 'Good-Icons\n')
        for bad in ('Missing-Icons', 'No-Index', '../data/icons/Good-Icons', 'Good Icons', '$(touch x)',
                    '-Good-Icons', '', 'A' * 65, 'Good-Icons/../Good-Icons'):
            (custom / 'icons.theme').write_text(bad + '\n')
            self.assertEqual(self.theme('set', 'iconic', env=env).returncode, 0, bad)
            self.assertEqual(len(calls()), 1, bad)
            self.assertFalse(staged.exists(), bad)
        # Surrounding whitespace is tolerated; no session bus means no GSettings write.
        (custom / 'icons.theme').write_text('  Good-Icons \n')
        self.assertEqual(self.theme('set', 'iconic', env=dict(env, DBUS_SESSION_BUS_ADDRESS='')).returncode, 0)
        self.assertEqual(len(calls()), 1)
        self.assertEqual(staged.read_text(), 'Good-Icons\n')
        # A theme without icons.theme leaves the current icon theme alone.
        self.assertEqual(self.theme('set', 'tessera', env=env).returncode, 0)
        self.assertEqual(len(calls()), 1)
        self.assertFalse(staged.exists())

    def test_theme_list_reports_preview_images(self):
        custom = self.home / 'config/tessarchy/themes/pictured'
        custom.mkdir(parents=True)
        (custom / 'colors.toml').write_text('background = "#101010"\nforeground = "#f0f0f0"\naccent = "#ff8800"\n')
        (custom / 'preview.png').write_bytes(b'png')
        rows = {line.split('\t')[0]: line.split('\t') for line in self.theme('list').stdout.splitlines()}
        self.assertEqual(rows['pictured'], ['pictured', 'dark', '#101010', '#f0f0f0', '#ff8800', str(custom / 'preview.png')])
        self.assertEqual(rows['tessera'][5], '')
        settings = (ROOT / 'shell/components/SettingsPage.qml').read_text()
        self.assertIn('fillMode: Image.PreserveAspectCrop', settings)
        # Every picker card has one size; palette themes draw a mock thumbnail.
        self.assertIn('Layout.preferredHeight: Math.min(Math.round(width * 9 / 16), 120) + labelHeight', settings)
        self.assertNotIn('hasPreview ? Math.min', settings)
        self.assertIn('visible: !themeButton.hasPreview', settings)
        shell = (ROOT / 'shell/shell.qml').read_text()
        self.assertIn('preview: field[5] || ""', shell)
        # Page glass covers the column margins; scroll edges are marked.
        self.assertIn('expandedContent.width + pageColumn.anchors.leftMargin + pageColumn.anchors.rightMargin', shell)
        self.assertIn('opacity: pageScroll.ScrollBar.vertical.position > 0 ? 1 : 0', shell)

    def test_run_launches_apps_in_theme_mode(self):
        stubs = self.home / 'bin'
        stubs.mkdir()
        for name in ('foot', 'firefox'):
            (stubs / name).write_text('#!/bin/bash\necho "$GTK_THEME|$*"\n')
            (stubs / name).chmod(0o755)
        env = dict(self.env, PATH=f'{stubs}:{os.environ["PATH"]}', XDG_STATE_HOME=str(self.home / 'state'))
        run = lambda *a: subprocess.run([str(ROOT / 'session/tessarchy-run'), *a], env=env,
                                        capture_output=True, text=True).stdout.strip()
        self.assertEqual(run('firefox', 'about:blank'), 'Adwaita:dark|about:blank')
        self.theme('set', 'tessera-light')
        config = self.home / 'state/tessarchy/theme/foot.ini'
        self.assertEqual(run('foot', '-e', 'ls'), f'Adwaita|--config={config} -e ls')
        self.assertEqual(run('firefox'), 'Adwaita|')

    def test_portal_asks_shell_and_falls_back_to_gtk_in_desktop(self):
        import shutil
        need = ('cc', 'make', 'pkg-config', 'gdbus', 'dbus-run-session')
        if not all(shutil.which(tool) for tool in need):
            self.skipTest('portal build/D-Bus tools unavailable')
        out = self.home / 'portal-build'
        build = subprocess.run(['make', '-s', '-C', str(ROOT / 'portal'), f'O={out}'],
                               capture_output=True, text=True)
        self.assertEqual(build.returncode, 0, build.stderr)
        stubs = self.home / 'bin'
        stubs.mkdir()
        log = self.home / 'asked'
        # Stand-in shell: logs the request, answers per $SHELL_ANSWER.
        (stubs / 'tessera-shell').write_text(f'''#!/bin/bash
printf '%s\\n' "$*" >> {log}
[[ $3 == picker && $4 == pick ]] || exit 0
case $SHELL_ANSWER in
  pick) printf '%s\\n' "$8/$9" "" > "$5"; echo ok ;;
  cancel) echo > "$5"; echo ok ;;
  *) echo desktop ;;
esac
''')
        (stubs / 'tessera-shell').chmod(0o755)
        env = dict(self.env, PATH=f'{stubs}:{os.environ["PATH"]}', XDG_RUNTIME_DIR=str(self.home))

        def call(answer, method, options):
            # One private bus per case: the stub reads SHELL_ANSWER from the portal's environment.
            script = (f'{out}/tessarchy-portal & sleep 0.5; gdbus call --session '
                      '--dest org.freedesktop.impl.portal.desktop.tessarchy '
                      '--object-path /org/freedesktop/portal/desktop '
                      f'--method org.freedesktop.impl.portal.FileChooser.{method} '
                      '/org/freedesktop/portal/desktop/request/1_1/t1 app "" Title "$0"')
            result = subprocess.run(['dbus-run-session', '--', 'bash', '-c', script, options],
                                    env=dict(env, SHELL_ANSWER=answer), capture_output=True, text=True, timeout=30)
            return result.stdout.strip()

        # NUL-terminated, as xdg-desktop-portal sends it (gdbus's b'' text form is not).
        folder = '<@ay [' + ', '.join(f'0x{c:02x}' for c in b'/srv/x\0') + ']>'
        self.assertEqual(call('pick', 'SaveFile', "{'current_name': <'a b.txt'>, 'current_folder': " + folder + "}"),
                         "(uint32 0, {'uris': <['file:///srv/x/a%20b.txt']>})")
        self.assertEqual(call('cancel', 'OpenFile', "{'filters': <[('Images', [(uint32 0, '*.png'), (uint32 0, '*.jpg')])]>}"),
                         '(uint32 1, @a{sv} {})')
        # Desktop mode: forwarded to xdg-desktop-portal-gtk, absent on this bus.
        self.assertEqual(call('desktop', 'OpenFile', "{'directory': <true>}"), '(uint32 2, @a{sv} {})')
        asked = log.read_text()
        self.assertIn('ipc call picker pick ', asked)
        self.assertIn(' save 0 /srv/x a b.txt Title \n', asked)
        self.assertIn(' open 0 ' + str(self.home), asked)
        self.assertIn(' *.png;*.jpg\n', asked)
        self.assertIn(' folder 0 ', asked)
        self.assertEqual(list((self.home / 'tessarchy-portal').iterdir()), [])  # FIFOs removed

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
local share = os.getenv("TESSARCHY_DATA_DIR")
assert(commands[1] == "tessarchy-session-services" and commands[2] == "tessera-shell" and commands[3] == "tessarchy-osk start",
       table.concat(commands, ","))
assert(commands[4] == "hypridle -c '" .. share .. "/session/hypridle.conf'",
       tostring(commands[4]))
assert(#commands == 4, "unexpected extra autostart commands")
'''
        env = dict(self.env, TESSARCHY_DATA_DIR=str(self.home / 'data'))
        result = subprocess.run(['lua', '-', str(ROOT / 'session/hyprland.lua')],
                                input=script, text=True, capture_output=True, env=env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_idle_config_blanks_without_locking(self):
        config = (ROOT / 'session/hypridle.conf').read_text()
        self.assertIn('timeout = 300', config)
        self.assertIn("on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'", config)
        self.assertIn("on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'", config)
        for absent in ('lock_cmd', 'swaylock', 'hyprlock'):
            self.assertNotIn(absent, config)

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

    def test_uninstall_after_source_update_uses_installed_launcher_versions(self):
        import shutil
        self.run_script('install-dev.sh')
        updated = self.home / 'updated-source'
        (updated / 'scripts').mkdir(parents=True)
        (updated / 'session').mkdir()
        shutil.copy2(ROOT / 'scripts/uninstall-dev.sh', updated / 'scripts')
        (updated / 'session/start-tessarchy').write_text('#!/bin/bash\necho newer version\n')
        result = subprocess.run([str(updated / 'scripts/uninstall-dev.sh')], env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / '.local/bin/start-tessarchy').exists())
        self.assertFalse((self.home / 'data/tessarchy').exists())

    def test_uninstall_missing_launcher_snapshot_preserves_installation(self):
        self.run_script('install-dev.sh')
        data = self.home / 'data/tessarchy'
        (data / '.tessarchy-dev-launchers/start-tessarchy').unlink()
        self.run_script('uninstall-dev.sh', expected=1)
        self.assertTrue((self.home / '.local/bin/start-tessarchy').exists())
        self.assertTrue((data / 'shell/shell.qml').exists())

    def test_uninstall_legacy_v2_install_still_works(self):
        self.run_script('install-dev.sh')
        data = self.home / 'data/tessarchy'
        (data / '.tessarchy-dev-install').write_text('tessarchy-dev-v2\n')
        self.run_script('uninstall-dev.sh')
        self.assertFalse(data.exists())

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
        self.assertIn('session/hypridle.conf', listed)
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

    def test_aarch64_vm_plan_profile_and_refusals(self):
        import shlex
        repo = self.home / 'source'
        self.copy_repo(repo, ('scripts',))
        command = [str(repo / 'scripts/vm-aarch64.sh'), 'plan']
        result = subprocess.run(command, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('build-aarch64-disk.sh', result.stderr)
        vm = repo / 'vm/aarch64'
        vm.mkdir(parents=True)
        for name in ('rootfs.img', 'Image', 'initramfs-linux.img'):
            (vm / name).write_text(name)
        env = dict(self.env, VM_ACCEL='tcg', VM_QMP='/tmp/test-qmp.sock', VM_DISPLAY='vnc=127.0.0.1:0')
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        args = shlex.split(result.stdout.removeprefix('VM command:'))
        self.assertEqual(args[0], 'qemu-system-aarch64')
        for option in ['virt', 'max', str(vm / 'Image'), 'virtio-gpu-pci', 'vnc=127.0.0.1:0',
                       f'file={vm / "rootfs.img"},format=raw,if=virtio',
                       'virtio-multitouch-pci', 'unix:/tmp/test-qmp.sock,server=on,wait=off']:
            self.assertIn(option, args)
        self.assertEqual((vm / 'Image').read_text(), 'Image')
        for name, value in [('VM_ACCEL', 'bad'), ('VM_RAM', '4G'), ('VM_CPUS', '0'),
                            ('VM_DISPLAY', 'gtk,gl=on'), ('VM_SSH_PORT', '80'),
                            ('VM_QMP', '/tmp/a,server=off')]:
            result = subprocess.run(command, env=dict(env, **{name: value}),
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn(name, result.stderr)
        result = subprocess.run([str(repo / 'scripts/vm-aarch64.sh'), 'wat'], env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)

    def test_aarch64_disk_build_refuses_missing_input_and_existing_output(self):
        repo = self.home / 'source'
        self.copy_repo(repo, ('scripts',))
        command = [str(repo / 'scripts/build-aarch64-disk.sh')]
        result = subprocess.run(command, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        if 'fetch-alarm' not in result.stderr:
            self.skipTest('fakeroot, bsdtar or mke2fs unavailable')
        vm = repo / 'vm/aarch64'
        vm.mkdir(parents=True)
        (vm / 'ArchLinuxARM-aarch64-latest.tar.gz').write_text('archive')
        result = subprocess.run(command, env=dict(self.env, VM_DISK_SIZE='16'),
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('VM_DISK_SIZE', result.stderr)
        (vm / 'rootfs.img').write_text('mine')
        result = subprocess.run(command, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('Keeping existing', result.stderr)
        self.assertEqual((vm / 'rootfs.img').read_text(), 'mine')
        self.assertFalse(list(vm.glob('.build.*')))

    def test_alarm_fetch_refuses_existing_archive_and_plain_keyserver(self):
        repo = self.home / 'source'
        self.copy_repo(repo, ('scripts',))
        command = [str(repo / 'scripts/fetch-alarm.sh')]
        vm = repo / 'vm/aarch64'
        vm.mkdir(parents=True)
        result = subprocess.run(command, env=dict(self.env, ALARM_KEYSERVER='http://keys.example'),
                                capture_output=True, text=True)
        if 'Missing' in result.stderr:
            self.skipTest('curl, gpg, gpgv or md5sum unavailable')
        self.assertEqual(result.returncode, 1)
        self.assertIn('ALARM_KEYSERVER', result.stderr)
        (vm / 'ArchLinuxARM-aarch64-latest.tar.gz').write_text('existing')
        result = subprocess.run(command, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('already exists', result.stderr)
        self.assertEqual((vm / 'ArchLinuxARM-aarch64-latest.tar.gz').read_text(), 'existing')

    def test_vm_hardware_profile_and_invalid_options(self):
        import shlex
        repo = self.home / 'source'
        self.copy_repo(repo, ('scripts',))
        disk = repo / 'vm/tessarchy.qcow2'
        disk.parent.mkdir(parents=True)
        disk.touch()
        env = dict(self.env, VM_AUDIO='pipewire', VM_GL='1', VM_TOUCH='1',
                   VM_AUDIO_USB='1', VM_QMP='/tmp/test-qmp.sock')
        command = [str(repo / 'scripts/vm.sh'), 'plan']
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        args = shlex.split(result.stdout.removeprefix('VM command:'))
        for option in ['virtio-vga-gl', 'gtk,gl=on', 'virtio-multitouch-pci',
                       'pipewire,id=sound', 'hda-output,audiodev=sound',
                       'usb-audio,id=usb-sound,audiodev=sound', 'virtio-rng-pci',
                       'unix:/tmp/test-qmp.sock,server=on,wait=off']:
            self.assertIn(option, args)
        for name, value in [('VM_GL', 'bad'), ('VM_AUDIO', 'bad'),
                            ('VM_AUDIO_CODEC', 'hda-output,extra=bad'),
                            ('VM_QMP', '/tmp/a,server=off')]:
            result = subprocess.run(command, env=dict(env, **{name: value}),
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(name, result.stderr)

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
                              'docs', 'tests', 'assets', 'website', 'themes', 'portal'))
        share = repo / 'build/vm-share/tessarchy'
        def run():
            return subprocess.run([str(repo / 'scripts/export-vm-source.sh')], env=self.env,
                                  capture_output=True, text=True)
        self.assertEqual(run().returncode, 0)
        self.assertEqual((share / 'scripts/install-dev.sh').read_bytes(),
                         (ROOT / 'scripts/install-dev.sh').read_bytes())
        self.assertTrue((share / 'website/index.html').is_file())
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
                            'test -f "$VM_SOURCE_SHARE/tessarchy/scripts/setup-guest.sh"\n'
                            'test -f "$VM_SOURCE_SHARE/tessarchy/website/index.html"\n')
        fakeqemu.chmod(0o755)
        import shutil
        source = self.home / 'source'
        for directory in ('scripts', 'shell', 'session', 'packaging', 'iso', 'docs', 'tests', 'assets', 'website', 'themes', 'portal'):
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
                       tag = function(action) return action end,
                       float = function(action) return action end,
                       center = function(action) return action end,
                       close = function() return {} end,
                       cycle_next = function() return {} end,
                       move = function(target) return target end,
                       drag = function() return {} end,
                       resize = function(action) return action end } }
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
check("auto", 400, 800, 1, 0, false, 0, 4)
check("auto", 800, 1280, 1, 0, false, 0, 1)
check("auto", 1280, 800, 1, 0, false, 0, 3)
check("auto", 1280, 800, 2, 0, false, 0, 4)
check("auto", 1280, 800, 1, 1, false, 0, 1)
check("desktop", 400, 800, 1, 0, false, 0, 3)
check("phone", 1280, 800, 1, 0, false, 0, 4)
check("invalid", 400, 800, 1, 0, false, 0, 4)
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
                       center = action("center"), move = action("move"),
                       float = action("float"), tag = action("tag"),
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
local phone = { floating = false, fullscreen = 0, monitor = monitor(400, 800), tags = {} }
a = fire("window.active", phone)
assert(#a == 4 and a[1].kind == "tag" and a[2].kind == "float", "independent phone surface")
assert(a[3].kind == "resize" and a[3].x == 400 and a[3].y == 672, "phone app bounds")
assert(a[4].kind == "move" and a[4].x == 0 and a[4].y == 48, "below status bar")
phone.floating = true; phone.tags = { "tessarchy-phone" }
phone.monitor.reserved.bottom = 400
a = fire("window.active", phone)
assert(#a == 2 and a[1].y == 352, "keyboard shrinks tracked apps")
phone.monitor.reserved.bottom = 80
a = fire("window.active", phone)
assert(a[1].y == 672, "keyboard dismissal restores full preview size")
phone.monitor.transform = 1
a = fire("window.active", phone)
assert(a[1].x == 800 and a[1].y == 272, "rotation uses logical phone bounds")
phone.monitor.scale = 2; phone.monitor.transform = 0
phone.monitor.x = -200; phone.monitor.y = 100
phone.monitor.reserved = {left = 8, right = 12, top = 24, bottom = 40}
a = fire("window.active", phone)
assert(a[1].x == 180 and a[1].y == 336, "scaled reserved area")
assert(a[2].x == -192 and a[2].y == 124, "monitor offset")
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

    def test_windowed_desktop_floats_new_windows_and_honors_settings_toggle(self):
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
                       center = action("center"), float = action("float"), tag = action("tag"),
                       move = action("move"), drag = action("drag"),
                       close = action("close"), cycle_next = action("cycle") } }
}
dofile(arg[1])
local function prefer(mode, windows)
    local f = assert(io.open(os.getenv("XDG_CONFIG_HOME") .. "/tessarchy/shell.ini", "w"))
    if windows then f:write("[Shell]\nlayoutMode=" .. mode .. "\ndesktopWindows=" .. windows .. "\n")
    else f:write("[Shell]\nlayoutMode=" .. mode .. "\n") end
    f:close()
end
local function monitor(w, h)
    return { width = w, height = h, scale = 1, transform = 0, reserved = {} }
end
local function fire(event, window) actions = {}; callbacks[event](window); return actions end
-- Windowed is the default: an ordinary desktop window floats, shrinks to the
-- conventional size, and centers. Width/height are capped and floored.
prefer("desktop")
local app = { floating = false, fullscreen = 0, monitor = monitor(1920, 1080) }
local a = fire("window.open", app)
assert(#a == 3, "expected float, resize and center")
assert(a[1].kind == "float" and a[1].action == "set" and a[1].window == app)
assert(a[2].kind == "resize" and a[2].window == app and a[2].x == 960 and a[2].y == 640,
    a[2].x .. "x" .. a[2].y)
assert(a[3].kind == "center" and a[3].window == app)
-- A small output floors the size instead of collapsing it.
local small = { floating = false, fullscreen = 0, monitor = monitor(640, 400) }
a = fire("window.open", small)
assert(a[2].x == 544 and a[2].y == 280, a[2].x .. "x" .. a[2].y)
-- Tiled restores the old behaviour: nothing is floated, nothing is maximized.
prefer("desktop", "tiled")
local tiled = { floating = false, fullscreen = 0, monitor = monitor(1920, 1080) }
assert(#fire("window.open", tiled) == 0, "tiled desktop must not touch new windows")
-- Already-floating windows and dialogs are never re-floated.
prefer("desktop")
assert(#fire("window.open", { floating = true, fullscreen = 0, monitor = monitor(1920, 1080) }) == 0)
-- Phone surfaces retain full size independently of Desktop window settings.
prefer("phone", "windowed")
local phone = { floating = false, fullscreen = 0, monitor = monitor(720, 1440) }
a = fire("window.open", phone)
assert(#a == 4 and a[1].kind == "tag" and a[2].kind == "float")
assert(a[3].kind == "resize" and a[3].x == 720 and a[3].y == 1440)
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

    def rotation_tools(self, keep_reload=False):
        tools = self.home / 'bin'
        tools.mkdir(exist_ok=True)
        state = self.home / 'transform-state'
        state.write_text('0')
        stub = tools / 'hyprctl'
        stub.write_text('''#!/bin/bash
state=$STUB_STATE
case "$1" in
monitors)
    printf 'Monitor eDP-1 (ID 0):\\n\\t1920x1080@60.000 at 0x0\\n\\tscale: 1.00\\n\\ttransform: %s\\n' "$(cat "$state")"
    ;;
reload)
    [ -n "${STUB_KEEP_RELOAD:-}" ] && exit 0
    config=${XDG_CONFIG_HOME:-$HOME/.config}/tessarchy/display.lua
    if [ -f "$config" ]; then
        sed -n 's/.*transform = \\([0-9]*\\).*/\\1/p' "$config" > "$state"
    else
        echo 0 > "$state"
    fi
    ;;
*)
    exit 1
    ;;
esac
''')
        stub.chmod(0o755)
        env = dict(self.env, PATH=str(tools) + ':' + os.environ['PATH'], STUB_STATE=str(state))
        if keep_reload:
            env['STUB_KEEP_RELOAD'] = '1'
        return env, state

    def test_rotation_helper_cycles_and_preserves_display_settings(self):
        env, state = self.rotation_tools()
        preferences = self.home / 'config/tessarchy/preferences.lua'
        preferences.parent.mkdir(parents=True)
        preferences.write_text('-- mine\n')
        command = [str(ROOT / 'session/tessera-rotate')]
        result = subprocess.run(command + ['cycle', 'eDP-1'], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('90 degrees', result.stdout)
        display = self.home / 'config/tessarchy/display.lua'
        first = display.read_text()
        self.assertIn('output = "eDP-1"', first)
        self.assertIn('mode = "1920x1080@60.000"', first)
        self.assertIn('position = "0x0"', first)
        self.assertIn('scale = 1.00', first)
        self.assertIn('transform = 1', first)
        self.assertEqual(state.read_text(), '1\n')
        result = subprocess.run(command + ['cycle', 'eDP-1'], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        second = display.read_text()
        self.assertIn('transform = 2', second)
        self.assertNotIn('transform = 1', second)
        self.assertEqual(second.count('hl.monitor('), 1)
        self.assertEqual(preferences.read_text(), '-- mine\n')

    def test_rotation_helper_restores_state_when_reload_does_not_apply(self):
        env, _ = self.rotation_tools(keep_reload=True)
        display = self.home / 'config/tessarchy/display.lua'
        display.parent.mkdir(parents=True)
        previous = '-- previous\nhl.monitor({ output = "eDP-1", transform = 3 })\n'
        display.write_text(previous)
        result = subprocess.run([str(ROOT / 'session/tessera-rotate'), 'cycle', 'eDP-1'],
                                env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('restoring', result.stderr)
        self.assertEqual(display.read_text(), previous)

    def test_rotation_helper_reset_removes_generated_rule(self):
        env, state = self.rotation_tools()
        display = self.home / 'config/tessarchy/display.lua'
        display.parent.mkdir(parents=True)
        display.write_text('hl.monitor({ output = "eDP-1", transform = 2 })\n')
        state.write_text('2')
        command = [str(ROOT / 'session/tessera-rotate')]
        result = subprocess.run(command + ['reset', 'eDP-1'], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(display.exists())
        self.assertEqual(state.read_text(), '0\n')
        again = subprocess.run(command + ['reset', 'eDP-1'], env=env, capture_output=True, text=True)
        self.assertEqual(again.returncode, 0)

    def test_rotation_helper_rejects_arguments_and_unknown_output(self):
        env, _ = self.rotation_tools()
        command = [str(ROOT / 'session/tessera-rotate')]
        for arguments in ([], ['cycle'], ['wobble', 'eDP-1'], ['cycle', 'eDP-1;true'],
                          ['cycle', 'eDP-1/../x'], ['cycle', ''], ['cycle', 'HDMI-A-1']):
            result = subprocess.run(command + arguments, env=env, capture_output=True, text=True)
            self.assertIn(result.returncode, (1, 64), arguments)
        self.assertFalse((self.home / 'config/tessarchy/display.lua').exists())

    def test_rotation_wiring_uses_generated_lua_not_keywords(self):
        settings = (ROOT / 'shell/components/SettingsPage.qml').read_text()
        self.assertIn('RotationControl {', settings)
        control = (ROOT / 'shell/components/RotationControl.qml').read_text()
        self.assertIn('Quickshell.execDetached(["tessera-rotate", action, control.monitor.name])', control)
        self.assertIn('control.send("cycle")', control)
        self.assertIn('control.send("reset")', control)
        self.assertNotIn('keyword', control)
        lua = (ROOT / 'session/hyprland.lua').read_text()
        self.assertIn('tessarchy/display.lua', lua)
        for name in ('scripts/install-dev.sh', 'scripts/uninstall-dev.sh', 'scripts/stage-iso.sh',
                     'scripts/check.sh', 'packaging/tessarchy-session/PKGBUILD'):
            self.assertIn('tessera-rotate', (ROOT / name).read_text(), name)

    def test_iso_staging_preserves_boot_assets_and_account_databases(self):
        # Minimal fixture exercises our assembly, not upstream archiso validity.
        repo = self.home / 'source'
        (repo / 'scripts').mkdir(parents=True)
        import shutil
        for directory in ('shell', 'session', 'iso', 'docs', 'themes', 'portal'):
            shutil.copytree(ROOT / directory, repo / directory)
        shutil.copy2(ROOT / 'scripts/stage-iso.sh', repo / 'scripts')
        shutil.copy2(ROOT / 'scripts/export-boot-assets.py', repo / 'scripts')
        # Staging refuses to build a medium that cannot update itself, so the
        # fixture needs the packages a repository build would have produced.
        packages = repo / 'dist/repo/x86_64'
        packages.mkdir(parents=True)
        (packages / 'tessera-shell-0.1.0-2-any.pkg.tar.zst').write_bytes(b'fake package')
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
        (base / 'airootfs/etc/systemd/system/sysinit.target.wants').mkdir(parents=True)
        wait_sync = base / 'airootfs/etc/systemd/system/sysinit.target.wants/systemd-time-wait-sync.service'
        wait_sync.symlink_to('/usr/lib/systemd/system/systemd-time-wait-sync.service')
        env = dict(self.env, ARCHISO_RELENG=str(base))
        command = [str(repo / 'scripts/stage-iso.sh')]
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        profile = repo / 'build/iso-profile'
        # Staging deliberately replaces releng's boot menus with Tessarchy's.
        self.assertFalse((profile / 'efiboot/loader/entries/arch.conf').exists())
        self.assertIn('Tessarchy',
                      (profile / 'efiboot/loader/entries/01-tessarchy-linux.conf').read_text())
        self.assertIn('Tessarchy', (profile / 'syslinux/archiso_head.cfg').read_text())
        self.assertTrue((profile / 'syslinux/splash.png').is_file())
        self.assertIn('tessarchy', (profile / 'grub/loopback.cfg').read_text())
        self.assertEqual((profile / 'airootfs/etc/passwd').read_text(),
                         'root:x:0:0:root:/root:/usr/bin/bash\n')
        self.assertIn('/usr/bin/zsh', (base / 'airootfs/etc/passwd').read_text())
        self.assertFalse((profile / 'airootfs/etc/group').exists())
        self.assertFalse((profile / 'airootfs/etc/systemd/system/multi-user.target.wants/sshd.service').is_symlink())
        self.assertTrue(ssh_link.is_symlink())
        self.assertFalse((profile / 'airootfs/etc/systemd/system/sysinit.target.wants/systemd-time-wait-sync.service').is_symlink())
        self.assertTrue(wait_sync.is_symlink())
        self.assertIn('quickshell', (profile / 'packages.x86_64').read_text())
        # A medium that cannot update itself is not worth shipping: the packages
        # travel with it, pacman is pointed at the repository, and the machine
        # learns which medium it came from.
        self.assertTrue((profile / 'airootfs/usr/share/tessarchy/pkgs/'
                         'tessera-shell-0.1.0-2-any.pkg.tar.zst').is_file())
        self.assertTrue((profile / 'airootfs/etc/pacman.d/tessarchy.conf').is_file())
        self.assertEqual(
            (profile / 'airootfs/etc/pacman.d/tessarchy.conf').read_text(),
            (ROOT / 'iso/airootfs/etc/pacman.d/tessarchy.conf').read_text())
        version = (profile / 'airootfs/etc/tessarchy/version').read_text().strip()
        self.assertRegex(version, r'^0\.1\.0-\d{8}$')
        self.assertIn(f'iso_version="{version}"', (profile / 'profiledef.sh').read_text())
        timer = profile / 'airootfs/etc/systemd/system/timers.target.wants'
        self.assertTrue((timer / 'tessarchy-update-check.timer').is_symlink())
        user_timer = profile / 'airootfs/home/tess/.config/systemd/user/timers.target.wants'
        self.assertTrue((user_timer / 'tessarchy-update-notify.timer').is_symlink())
        self.assertTrue((profile / 'airootfs/usr/bin/tessarchy-update').is_file())
        if (ROOT / 'etc/pacman.conf').is_file():
            staged_pacman = (profile / 'airootfs/etc/pacman.conf').read_text()
            self.assertIn('Include = /etc/pacman.d/tessarchy.conf', staged_pacman)
            self.assertIn('[core]', staged_pacman)
            self.assertEqual(staged_pacman.count('Include = /etc/pacman.d/tessarchy.conf'), 1)
        # A mirror build points the medium (and the machines installed from it)
        # at another repository without editing a tracked file.
        shutil.rmtree(repo / 'build', ignore_errors=True)
        mirror = subprocess.run(command, env=dict(env, TESSARCHY_REPO_URL='http://mirror.test/pkgs/'),
                                capture_output=True, text=True)
        self.assertEqual(mirror.returncode, 0, mirror.stdout + mirror.stderr)
        staged_conf = (profile / 'airootfs/etc/pacman.d/tessarchy.conf').read_text()
        self.assertIn('Server = http://mirror.test/pkgs/$arch', staged_conf)
        self.assertNotIn('thediamondsaint', staged_conf)
        self.assertNotIn('http://mirror.test/pkgs/$arch/$arch', staged_conf)

        self.assertNotIn('unused-rescue-tool', (profile / 'packages.x86_64').read_text())
        self.assertIn('linux-firmware', (profile / 'packages.x86_64').read_text().splitlines())
        self.assertFalse((profile / 'airootfs/etc/systemd/system/multi-user.target.wants/systemd-networkd.service').is_symlink())
        self.assertTrue((profile / 'airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service').is_symlink())
        self.assertEqual((profile / 'airootfs/etc/resolv.conf').readlink().as_posix(), '/run/NetworkManager/resolv.conf')
        self.assertTrue((profile / 'airootfs/etc/systemd/system/multi-user.target.wants/systemd-timesyncd.service').is_symlink())
        self.assertEqual((profile / 'airootfs/etc/hostname').read_text().strip(), 'tessarchy')
        self.assertIn('en_US.UTF-8', (profile / 'airootfs/etc/locale.conf').read_text())
        self.assertIn('en_US.UTF-8', (profile / 'airootfs/etc/locale.gen').read_text())
        self.assertIn('/usr/share/tessarchy/docs', (profile / 'airootfs/etc/motd').read_text())
        self.assertIn('Storage=volatile',
                      (profile / 'airootfs/etc/systemd/journald.conf.d/volatile.conf').read_text())
        self.assertTrue((profile / 'airootfs/usr/share/tessarchy/docs/iso.md').is_file())
        self.assertTrue((profile / 'airootfs/usr/bin/start-tessarchy').stat().st_mode & 0o111)
        self.assertTrue((profile / 'airootfs/usr/share/plymouth/themes/tessarchy/logo-159.png').is_file())
        self.assertTrue((profile / 'airootfs/usr/bin/tessarchy-session-services').is_file())
        self.assertTrue((profile / 'airootfs/usr/bin/tessera-screenshot').stat().st_mode & 0o111)
        for helper in ('tessera-brightness', 'tessera-nightlight'):
            self.assertTrue((profile / 'airootfs/usr/bin' / helper).stat().st_mode & 0o111)
        for package in ('brightnessctl', 'hyprsunset'):
            self.assertIn(package, (profile / 'packages.x86_64').read_text().splitlines())
        self.assertTrue((profile / 'airootfs/usr/share/tessarchy/session/hypridle.conf').is_file())
        self.assertIn('hypridle', (profile / 'packages.x86_64').read_text().splitlines())
        self.assertIn('grim', (profile / 'packages.x86_64').read_text().splitlines())
        self.assertIn('libnotify', (profile / 'packages.x86_64').read_text().splitlines())
        self.assertIn('u tess 1000 "Tessarchy live user" /home/tess /usr/bin/fish',
                      (profile / 'airootfs/etc/sysusers.d/tessarchy.conf').read_text())
        self.assertIn('fish', (profile / 'packages.x86_64').read_text().splitlines())
        self.assertTrue((profile / 'airootfs/home/tess/.config/fish/config.fish').is_file())
        self.assertIn('/home/tess/.config/fish/config.fish', (profile / 'profiledef.sh').read_text())
        self.assertTrue((profile / 'airootfs/usr/bin/tessarchy-theme').stat().st_mode & 0o111)
        self.assertTrue((profile / 'airootfs/usr/share/tessarchy/themes/tessera/colors.toml').is_file())
        self.assertIn('u tess 1000', (profile / 'airootfs/etc/sysusers.d/tessarchy.conf').read_text())
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)


    def test_every_installed_binary_is_given_an_executable_mode(self):
        # mkarchiso resets the airootfs to a default mode and then applies
        # profiledef.sh's file_permissions, so a file installed with -m755 but
        # missing from that list ships as 0644. /usr/bin/tessarchy-update and
        # tessera-update-notify did, and the medium carried an updater nobody
        # could run ("exists but is not an executable file").
        staging = (ROOT / 'scripts/stage-iso.sh').read_text()
        installed = set()
        for line in staging.splitlines():
            if 'install -m755' not in line or '$airoot/usr/bin/' not in line:
                continue
            for name in re.findall(r'"\$root/(?:session|scripts)/([A-Za-z0-9._-]+)"', line):
                installed.add(name)
        self.assertTrue(installed, 'no install -m755 lines were parsed')
        for name in sorted(installed):
            with self.subTest(binary=name):
                self.assertIn(f'["/usr/bin/{name}"]="0:0:755"', staging)

    def test_staging_refuses_to_build_a_medium_without_packages(self):
        repo = self.home / 'source'
        (repo / 'scripts').mkdir(parents=True)
        import shutil
        for directory in ('shell', 'session', 'iso', 'docs', 'themes', 'portal'):
            shutil.copytree(ROOT / directory, repo / directory)
        shutil.copy2(ROOT / 'scripts/stage-iso.sh', repo / 'scripts')
        shutil.copy2(ROOT / 'scripts/export-boot-assets.py', repo / 'scripts')
        base = self.home / 'releng'
        (base / 'airootfs/etc/systemd/system/multi-user.target.wants').mkdir(parents=True)
        (base / 'profiledef.sh').write_text('file_permissions=()\n')
        (base / 'packages.x86_64').write_text('base\n')
        (base / 'airootfs/etc/passwd').write_text('root:x:0:0:root:/root:/usr/bin/bash\n')
        # Staging replaces releng's boot entries, so the fixture needs them.
        entries = base / 'efiboot/loader/entries'
        entries.mkdir(parents=True)
        (entries / 'arch.conf').write_text('retained boot asset\n')
        env = dict(self.env, ARCHISO_RELENG=str(base))
        result = subprocess.run([str(repo / 'scripts/stage-iso.sh')], env=env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('build-packages.sh', result.stderr)

if __name__ == '__main__':
    unittest.main()
