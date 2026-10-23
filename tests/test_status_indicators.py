"""Status wiring and asset checks; no services or compositor are launched."""
from pathlib import Path

import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class StatusWiring(unittest.TestCase):
    def test_both_shell_locations_pass_ready_battery_and_state(self):
        shell = (ROOT / 'shell/shell.qml').read_text()
        self.assertEqual(shell.count('batteryPresent: UPower.displayDevice.ready && UPower.displayDevice.isPresent'), 2)
        # Two status strips bind the indicator component; a separate media card
        # also reads the battery percentage without using that component.
        self.assertGreaterEqual(shell.count('batteryPercent: UPower.displayDevice.percentage'), 2)
        self.assertEqual(shell.count('batteryState: root.batteryState'), 2)
        for enum, state in [('Charging', 'charging'), ('Discharging', 'discharging'),
                            ('Empty', 'empty'), ('FullyCharged', 'full'),
                            ('PendingCharge', 'pending-charge'), ('PendingDischarge', 'pending-discharge')]:
            self.assertIn(f'case UPowerDeviceState.{enum}: return "{state}";', shell)
        self.assertIn('if (!UPower.displayDevice.ready) return "unknown";', shell)

    def test_cellular_uses_existing_backend_and_policy(self):
        shell = (ROOT / 'shell/shell.qml').read_text()
        self.assertIn('StatusPolicy.cellularStrength(communications.state.cellular)', shell)
        strip = (ROOT / 'shell/components/StatusIndicators.qml').read_text()
        for symbol in ('cellular', 'wifi'):
            self.assertIn(f'property real {symbol}Strength: -1', strip)
        self.assertNotIn('showFallback:', strip)

    def test_signal_assets_are_valid_and_distinct(self):
        for kind in ('cellular', 'wifi'):
            assets = [(ROOT / f'shell/icons/{kind}-level-{i}.svg').read_text() for i in range(5)]
            self.assertEqual(len(set(assets)), 5)
            for svg in assets:
                self.assertEqual(ET.fromstring(svg).attrib['viewBox'], '0 0 24 24')

    def test_new_assets_are_in_legacy_cleanup(self):
        cleanup = (ROOT / 'scripts/uninstall-dev.sh').read_text()
        self.assertIn('"$data/shell/components/BatteryIndicator.qml"', cleanup)
        self.assertIn('"$data/shell/StatusPolicy.js"', cleanup)
        self.assertIn('for kind in cellular wifi;', cleanup)
        self.assertIn('for level in 0 1 2 3 4;', cleanup)
        self.assertIn('"$data/shell/icons/$kind-level-$level.svg"', cleanup)
