"""CPU-only checks for the shell-owned mapped-layer query and command wiring."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('node') and shutil.which('lua'), 'Node and Lua required')
class OskDismissQueryTests(unittest.TestCase):
    def query(self, records):
        source = (ROOT / 'shell/OskDismissPolicy.js').read_text()
        script = subprocess.run(
            ['node', '-e', 'const fs=require("fs"),vm=require("vm");'
             'const ctx={};vm.createContext(ctx);vm.runInContext('
             'fs.readFileSync(0,"utf8").replace(/^\\.pragma library\\s*/,""),ctx);'
             'process.stdout.write(ctx.query());'],
            input=source, text=True, capture_output=True, check=True).stdout
        fixture = 'hl = { get_layers = function(q) assert(q.namespace == "osk"); return ' + records + ' end }; '
        result = subprocess.run(['lua', '-e', fixture + script], text=True,
                                capture_output=True, check=True)
        return json.loads(result.stdout)

    def test_mapped_geometry_serializes_monitor_local_numbers(self):
        self.assertEqual(self.query('{ {mapped=true, monitor={id=7}, x=150, y=500, w=400, h=200} }'),
                         [{'monitor': 7, 'x': 150, 'y': 500, 'w': 400, 'h': 200}])

    def test_unmapped_zero_sized_and_orphan_layers_are_excluded(self):
        self.assertEqual(self.query('''{
            {mapped=false, monitor={id=0}, x=0, y=500, w=800, h=300},
            {mapped=true, monitor=nil, x=0, y=500, w=800, h=300},
            {mapped=true, monitor={id=0}, x=0, y=500, w=0, h=300}
        }'''), [])

    def test_empty_and_multiple_outputs(self):
        self.assertEqual(self.query('{}'), [])
        rows = self.query('''{
            {mapped=true, monitor={id=0}, x=0, y=500, w=800, h=300},
            {mapped=true, monitor={id=9}, x=20, y=700, w=400, h=200}
        }''')
        self.assertEqual([r['monitor'] for r in rows], [0, 9])

    def test_geometry_query_uses_repl_transport(self):
        source = (ROOT / 'shell/components/OskWatcher.qml').read_text()
        self.assertIn('command: ["hyprctl", "repl", Osk.query()]', source)
        self.assertNotIn('command: ["hyprctl", "eval",', source)

    def test_shell_wiring_does_not_request_focus_or_navigation(self):
        source = (ROOT / 'shell/shell.qml').read_text()
        block = source.split('id: oskDismissLayer', 1)[1].split('// Gesture navigation:', 1)[0]
        self.assertIn('WlrLayershell.keyboardFocus: WlrKeyboardFocus.None', block)
        self.assertIn('exclusionMode: ExclusionMode.Ignore', block)
        self.assertIn('["tessarchy-osk", "hide"]', block)
        self.assertNotIn('panel.navigate', block)
        self.assertNotIn('close()', block)
        self.assertIn('OskDismissButton 1.0 OskDismissButton.qml',
                      (ROOT / 'shell/components/qmldir').read_text())
