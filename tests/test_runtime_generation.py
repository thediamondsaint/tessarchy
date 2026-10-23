import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import textwrap
import tempfile
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_LOADER = importlib.machinery.SourceFileLoader(
    "runtime_source_manifest", str(ROOT / "scripts/runtime-source-manifest.py"))
MANIFEST_SPEC = importlib.util.spec_from_loader(MANIFEST_LOADER.name, MANIFEST_LOADER)
MANIFEST = importlib.util.module_from_spec(MANIFEST_SPEC)
MANIFEST_LOADER.exec_module(MANIFEST)
create_manifest = MANIFEST.create_manifest

LOADER = importlib.machinery.SourceFileLoader(
    "tessarchy_runtime", str(ROOT / "session/tessarchy-runtime"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
RUNTIME = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(RUNTIME)

REQUIRED = (
    "shell/shell.qml",
    "shell/components/ThemeLoader.qml",
    "shell/audio/ringtones/manifest.json",
    "shell/helpers/radios.py",
    "session/hyprland.lua",
    "session/window-controls.lua",
    "session/window-tape.lua",
    "session/hypridle.conf",
    "session/osk/squeekboard/keyboards/us.yaml",
    "session/tessera-chatgpt-status",
    "session/runtime-shell.qml",
    "session/runtime-hyprland.lua",
    "themes/tessera/colors.toml",
)


class RuntimeGeneration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "installed"
        for relative in REQUIRED:
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("source: " + relative + "\n", encoding="utf-8")
        (self.source / "session/runtime-shell.qml").write_text(
            "import QtQuick\nimport Quickshell\nShellRoot {}\n", encoding="utf-8")
        (self.source / "session/runtime-hyprland.lua").write_text(
            "local generation = 'test'\n", encoding="utf-8")
        (self.source / "session/tessera-chatgpt-status").chmod(0o755)
        self.runtime = self.root / "home/tessarchy/runtime"
        self.commit = "a" * 40
        self.write_manifests()

    def write_manifests(self, commit=None):
        manifest = create_manifest(self.source, commit or self.commit)
        package_manifests = self.source / "package-manifests"
        package_manifests.mkdir(exist_ok=True)
        encoded = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
        (package_manifests / "tessera-shell.json").write_text(encoded, encoding="utf-8")
        (package_manifests / "tessarchy-session.json").write_text(encoded, encoding="utf-8")

    def test_prepare_stages_complete_read_only_generation_and_stable_bootstrap(self):
        with mock.patch.dict(os.environ, {"WAYLAND_DISPLAY": "", "HYPRLAND_INSTANCE_SIGNATURE": ""}):
            generation = RUNTIME.prepare(self.source, self.runtime)
        payload = self.runtime / "generations" / generation
        self.assertEqual(RUNTIME.active_generation(self.runtime), generation)
        self.assertTrue((payload / "session/window-controls.lua").is_file())
        self.assertTrue((payload / "shell/audio/ringtones/manifest.json").is_file())
        self.assertFalse((payload / "session/window-controls.lua").stat().st_mode & 0o222)
        self.assertTrue((self.runtime / "bootstrap/shell.qml").is_file())
        self.assertTrue((self.runtime / "bootstrap/session/hyprland.lua").is_file())

    def test_mismatched_package_manifests_fail_closed(self):
        (self.source / "package-manifests/tessarchy-session.json").write_text("{}\n")
        with self.assertRaisesRegex(RUNTIME.RuntimeErrorMessage, "different runtime manifests"):
            RUNTIME.stage(self.source, self.runtime)

    def test_unmanifested_or_modified_installed_source_is_rejected(self):
        (self.source / "shell/unexpected.qml").write_text("mixed generation\n")
        with self.assertRaisesRegex(RUNTIME.RuntimeErrorMessage, "file set differs"):
            RUNTIME.stage(self.source, self.runtime)

    def test_local_edit_to_retained_generation_is_never_overwritten(self):
        with mock.patch.dict(os.environ, {"WAYLAND_DISPLAY": "", "HYPRLAND_INSTANCE_SIGNATURE": ""}):
            generation = RUNTIME.prepare(self.source, self.runtime)
        file = self.runtime / "generations" / generation / "shell/shell.qml"
        file.chmod(0o644)
        file.write_text("local edit\n")
        with self.assertRaisesRegex(RUNTIME.RuntimeErrorMessage, "payload was modified"):
            RUNTIME.verify_generation(self.runtime, generation)

    def test_failed_live_reload_restores_previous_generation(self):
        with mock.patch.dict(os.environ, {"WAYLAND_DISPLAY": "", "HYPRLAND_INSTANCE_SIGNATURE": ""}):
            previous = RUNTIME.prepare(self.source, self.runtime)
        changed = self.source / "shell/shell.qml"
        changed.write_text("updated shell\n")
        self.commit = "b" * 40
        self.write_manifests()
        env = {
            "WAYLAND_DISPLAY": "wayland-1",
            "HYPRLAND_INSTANCE_SIGNATURE": "test-instance",
            "TESSARCHY_RUNTIME_HOME": str(self.runtime),
        }
        with mock.patch.dict(os.environ, env, clear=False), \
             mock.patch.object(RUNTIME, "reload_compositor"), \
             mock.patch.object(RUNTIME, "request_shell_reload",
                               side_effect=[RuntimeError("reload rejected"), None]), \
             mock.patch.object(RUNTIME, "wait_for_shell_ack"):
            with self.assertRaisesRegex(RUNTIME.RuntimeErrorMessage, "previous generation was restored"):
                RUNTIME.activate(self.source, self.runtime)
        self.assertEqual(RUNTIME.active_generation(self.runtime), previous)

    @unittest.skipUnless(shutil.which("qs"), "Quickshell runtime is unavailable")
    def test_stable_bootstrap_loads_a_generation_in_software_quickshell(self):
        runtime = self.root / "quickshell-runtime"
        runtime.mkdir()
        generation = "c" * 64
        bootstrap = runtime / "bootstrap"
        shell = runtime / "generations" / generation / "shell"
        bootstrap.mkdir(parents=True)
        shell.mkdir(parents=True)
        components = shell / "components"
        components.mkdir()
        (components / "RuntimeMarker.qml").write_text(
            'import QtQuick\nQtObject { property string value: "relative-import-ready" }\n',
            encoding="utf-8")
        source = (ROOT / "session/runtime-shell.qml").read_text(encoding="utf-8")
        source = source.rsplit("\n}", 1)[0] + "\n    Timer { interval: 1200; running: true; onTriggered: Qt.quit() }\n}\n"
        (bootstrap / "shell.qml").write_text(source, encoding="utf-8")
        (runtime / "active-generation").write_text(generation + "\n", encoding="utf-8")
        (shell / "shell.qml").write_text(textwrap.dedent("""\
            import QtQuick
            import Quickshell
            import "components"
            ShellRoot {
                property string generationId: "software-probe"
                RuntimeMarker { id: marker }
                readonly property string relativeImport: marker.value
            }
        """), encoding="utf-8")
        probe = self.root / "bin/tessarchy-runtime"
        probe.parent.mkdir()
        acknowledgments = self.root / "acknowledgments.txt"
        probe.write_text("#!/usr/bin/env python3\n"
                         "import os, sys\n"
                         "open(os.environ['TESSARCHY_RUNTIME_PROBE_LOG'], 'a').write(' '.join(sys.argv[1:]) + '\\n')\n",
                         encoding="utf-8")
        probe.chmod(0o755)
        env = dict(os.environ)
        env.update({
            "PATH": str(probe.parent) + os.pathsep + env.get("PATH", ""),
            "TESSARCHY_RUNTIME_PROBE_LOG": str(acknowledgments),
            "TESSARCHY_RUNTIME_HOME": str(runtime),
            "QT_QPA_PLATFORM": "offscreen",
            "QS_NO_RELOAD_POPUP": "1",
            "WAYLAND_DISPLAY": "",
        })
        for name in ("config", "data", "cache", "state", "run"):
            path = self.root / "xdg" / name
            path.mkdir(parents=True, exist_ok=True)
            if name == "run":
                path.chmod(0o700)
            env[{"config": "XDG_CONFIG_HOME", "data": "XDG_DATA_HOME",
                 "cache": "XDG_CACHE_HOME", "state": "XDG_STATE_HOME",
                 "run": "XDG_RUNTIME_DIR"}[name]] = str(path)
        process = subprocess.Popen(
            ["qs", "--no-duplicate", "--path", str(bootstrap / "shell.qml")],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            time.sleep(0.3)
            ipc = subprocess.run(
                ["qs", "ipc", "--path", str(bootstrap / "shell.qml"),
                 "call", "runtime", "reload"], env=env, capture_output=True,
                text=True, timeout=5, check=False)
            self.assertEqual(ipc.returncode, 0, ipc.stdout + ipc.stderr)
            output, errors = process.communicate(timeout=5)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
        self.assertEqual(process.returncode, 0, output + errors)
        self.assertIn("Configuration Loaded", output + errors)
        self.assertIn("ack success " + generation, acknowledgments.read_text(), output + errors)


if __name__ == "__main__":
    unittest.main()
