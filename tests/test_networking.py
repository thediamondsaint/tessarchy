"""Network operations use synthetic devices; no host network action is executed."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('tessarchy_networking', ROOT / 'shell/helpers/networking.py')
networking = importlib.util.module_from_spec(spec)
spec.loader.exec_module(networking)
try:
    from gi.repository import Gio, GLib
except ImportError:
    Gio = GLib = None

WIFI = networking.ROOT + '/Devices/1'
MODEM = networking.ROOT + '/Devices/2'
ACCESS = networking.ROOT + '/AccessPoint/1'
SAVED = networking.ROOT + '/Settings/1'
DATA = networking.ROOT + '/Settings/2'
ACTIVE = networking.ROOT + '/ActiveConnection/1'
MMODEM = networking.MM_ROOT + '/Modem/0'


class FakeNetwork(networking.Network):
    def __init__(self):
        self.GLib, self.Gio = GLib, Gio
        self.cache, self.events, self.saved = {}, [], []
        self.tables = {
            (networking.ROOT, networking.NM): {'Devices': [WIFI, MODEM], 'WirelessEnabled': True,
                'WirelessHardwareEnabled': True, 'WwanEnabled': True, 'WwanHardwareEnabled': True, 'Connectivity': 4},
            (WIFI, networking.DEVICE): {'DeviceType': 2, 'State': 100, 'Interface': 'wlan0', 'Managed': True,
                'ActiveConnection': ACTIVE, 'AvailableConnections': [SAVED], 'StateReason': (100, 0)},
            (WIFI, networking.WIRELESS): {'AccessPoints': [ACCESS], 'ActiveAccessPoint': ACCESS,
                'WirelessCapabilities': 0x40, 'LastScan': 123},
            (ACCESS, networking.AP): {'Ssid': list(b'Fixture Wi-Fi'), 'Strength': 37, 'Flags': 1, 'RsnFlags': 0x100},
            (MODEM, networking.DEVICE): {'DeviceType': 8, 'State': 100, 'Interface': 'cdc-wdm0', 'Udi': MMODEM,
                'Managed': True, 'ActiveConnection': networking.ROOT + '/ActiveConnection/2', 'AvailableConnections': [DATA]},
            (ACTIVE, networking.ACTIVE): {'Connection': SAVED}
        }
        self.profiles_data = {
            SAVED: {'connection': {'id': 'Fixture Wi-Fi', 'type': '802-11-wireless', 'autoconnect': True},
                    '802-11-wireless': {'ssid': list(b'Fixture Wi-Fi')}, '802-11-wireless-security': {'key-mgmt': 'wpa-psk'}},
            DATA: {'connection': {'id': 'Fixture carrier', 'type': 'gsm'}, 'gsm': {'apn': 'example.invalid', 'home-only': True}}
        }
        self.objects = {MMODEM: {networking.MM + '.Modem': {'State': 11, 'Model': 'Fixture modem',
            'SignalQuality': (63, True), 'AccessTechnologies': 1 << 14, 'UnlockRequired': 1,
            'PrimaryPort': 'cdc-wdm0', 'Ports': [('cdc-wdm0', 2)]},
            networking.MM + '.Modem.Modem3gpp': {'OperatorName': 'Fixture carrier', 'RegistrationState': 1}}}
        self.fail_nm = self.fail_mm = False
        self.fail_action = False

    def call(self, path, interface, method, signature=None, values=(), service=networking.NM):
        self.events.append((path, interface, method, signature, values, service))
        if service == networking.MM:
            if self.fail_mm:
                raise GLib.Error('Synthetic missing modem service')
            if method == 'Enable':
                self.objects[path][networking.MM + '.Modem']['State'] = 6 if values[0] else 3
                return ()
            return (self.objects,)
        if self.fail_nm:
            raise GLib.Error('Synthetic missing network service')
        if method == 'GetAll':
            if (path, values[0]) not in self.tables:
                raise GLib.Error('Synthetic vanished object')
            return (self.tables[path, values[0]],)
        if method == 'ListConnections':
            return (list(self.profiles_data),)
        if method == 'GetSettings':
            return (copy.deepcopy(self.profiles_data[path]),)
        if self.fail_action:
            raise GLib.Error('Synthetic denied action: private fixture secret')
        if method == 'Set':
            self.tables[networking.ROOT, networking.NM][values[1]] = values[2].unpack()
        return ('/new/profile', '/new/active')

    def request(self, action='status', **values):
        request = dict(action=action, details=True, **values)
        state = self.snapshot(request)
        if action != 'status':
            self.act(request, state)
        return state

    def set_kernel_radios(self, blocked):
        self.events.append(('/kernel', 'rfkill', 'Rfkill', None, (blocked,), None))

    def mutations(self):
        return [e for e in self.events if e[2] in ('Set', 'Enable', 'Delete', 'ActivateConnection', 'AddAndActivateConnection2', 'Disconnect', 'RequestScan')]


try:
    import gi
    gi.require_version('NM', '1.0')
    from gi.repository import NM as LibNM
except (ImportError, ValueError):
    LibNM = None


@unittest.skipUnless(LibNM, 'libnm introspection is required for settings schema validation')
class SettingsSchemas(unittest.TestCase):
    def test_wifi_security_and_hotspot_settings_pass_native_networkmanager_validation(self):
        network = FakeNetwork()
        for kind, password in (('open', ''), ('owe', ''), ('wpa-psk', 'fixture-password'),
                               ('sae', 'fixture-password'), ('wep', 'abcde')):
            with self.subTest(security=kind):
                settings = network.wifi_settings({'ssid': 'Fixture', 'security': kind, 'password': password})
                connection = LibNM.SimpleConnection.new_from_dbus(GLib.Variant('a{sa{sv}}', settings))
                self.assertTrue(connection.verify())
        settings = network.wifi_settings({'ssid': 'Fixture AP', 'security': 'wpa-psk', 'password': 'fixture-password', 'hotspot': True})
        self.assertFalse(settings['connection']['autoconnect'].unpack())
        self.assertTrue(LibNM.SimpleConnection.new_from_dbus(GLib.Variant('a{sa{sv}}', settings)).verify())

    def test_mobile_data_settings_pass_native_networkmanager_validation(self):
        network = FakeNetwork()
        with patch.object(networking, 'kernel_radios', return_value=[]):
            network.request('cellular-connect', device=MODEM, modem=MMODEM, name='Fixture mobile', apn='example.invalid')
        settings = network.mutations()[-1][4][0]
        self.assertFalse(settings['connection']['autoconnect'].unpack())
        self.assertTrue(LibNM.SimpleConnection.new_from_dbus(GLib.Variant('a{sa{sv}}', settings)).verify())


class ProtocolValidation(unittest.TestCase):
    def test_percent_does_not_invent_signal(self):
        for invalid in (None, True, -1, 101, float('nan'), '80'):
            self.assertEqual(networking.percent(invalid), -1)
        self.assertEqual(networking.percent(0), 0)
        self.assertEqual(networking.percent(37), 37)

    def test_security_uses_networkmanager_key_management_bits(self):
        for bits, expected in ((0x100, 'wpa-psk'), (0x200, 'enterprise'), (0x400, 'sae'),
                               (0x800, 'owe'), (0x1000, 'owe'), (0x2000, 'enterprise'), (0x500, 'sae')):
            self.assertEqual(networking.security({'Flags': 1, 'RsnFlags': bits}), expected)
        self.assertEqual(networking.security({'Flags': 1}), 'wep')
        self.assertEqual(networking.security({}), 'open')
        self.assertEqual(networking.security({'WpaFlags': 0x100}), 'wpa-psk')

    def test_access_technology_uses_modemmanager_flags(self):
        for flags, label in ((0, ''), (1 << 14, '4G'), (1 << 15, '5G'), (1 << 17, '4G'),
                              (1 << 5, '3G'), (1 << 4, 'EDGE'), (0xFFFFFFFF, '')):
            self.assertEqual(networking.technology(flags), label)

    def test_cli_rejects_large_or_invalid_requests_before_opening_bus(self):
        script = ROOT / 'shell/helpers/networking.py'
        for data in ('[]\n', 'x' * 65537, 'not json\n'):
            result = subprocess.run([sys.executable, str(script)], input=data, capture_output=True, text=True)
            state = json.loads(result.stdout)
            self.assertTrue(state['error'])
            self.assertFalse(state['available'])
            self.assertEqual(result.stderr, '')

    def test_unknown_action_never_constructs_backend(self):
        def forbidden():
            self.fail('Backend constructed for an invalid action')
        self.assertTrue(networking.handle({'action': 'execute'}, forbidden)['error'])


@unittest.skipUnless(GLib, 'Python GObject is required for typed D-Bus fixtures')
class NetworkWorkflows(unittest.TestCase):
    def setUp(self):
        self.radios = patch.object(networking, 'kernel_radios', return_value=[])
        self.radios.start()
        self.addCleanup(self.radios.stop)
        self.network = FakeNetwork()

    def test_live_wifi_and_cell_signal_are_distinct_percentages(self):
        state = self.network.request()
        self.assertEqual(state['wifi']['strength'], 37)
        self.assertEqual(state['wifi']['label'], 'Fixture Wi-Fi')
        self.assertEqual(state['cellular']['strength'], 63)
        self.assertEqual(state['cellular']['status'], 'connected')
        self.assertEqual(state['cellular']['technology'], '4G')
        self.assertEqual(state['cellular']['device'], MODEM)
        self.assertEqual(state['connectivity'], 'Internet available')
        self.assertEqual(self.network.mutations(), [])

    def test_wifi_off_blocked_unmanaged_and_failed_have_no_signal(self):
        for status in ('off', 'blocked', 'unmanaged', 'failed', 'disconnected', 'connecting'):
            n = FakeNetwork()
            if status == 'off': n.tables[networking.ROOT, networking.NM]['WirelessEnabled'] = False
            elif status == 'blocked': n.tables[networking.ROOT, networking.NM]['WirelessHardwareEnabled'] = False
            elif status == 'unmanaged': n.tables[WIFI, networking.DEVICE]['Managed'] = False
            else: n.tables[WIFI, networking.DEVICE]['State'] = {'failed': 120, 'disconnected': 30, 'connecting': 60}[status]
            result = n.request()['wifi']
            self.assertEqual(result['status'], status)
            self.assertEqual(result['strength'], -1)

    def test_stale_modem_signal_is_not_shown_and_zero_remains_zero(self):
        modem = self.network.objects[MMODEM][networking.MM + '.Modem']
        modem['SignalQuality'] = (80, False)
        self.assertEqual(self.network.request()['cellular']['strength'], -1)
        modem['SignalQuality'] = (0, True)
        self.assertEqual(self.network.request()['cellular']['strength'], 0)

    def test_registration_is_not_reported_as_mobile_data(self):
        self.network.tables[MODEM, networking.DEVICE]['State'] = 30
        modem = self.network.objects[MMODEM][networking.MM + '.Modem']
        modem['State'] = 8
        cell = self.network.request()['cellular']
        self.assertEqual(cell['status'], 'registered')
        self.assertEqual(cell['dataStatus'], 'disconnected')
        self.network.objects[MMODEM][networking.MM + '.Modem.Modem3gpp']['RegistrationState'] = 5
        self.assertTrue(self.network.request()['cellular']['roaming'])

    def test_missing_services_do_not_invent_hardware(self):
        self.network.fail_mm = True
        state = self.network.request()
        self.assertFalse(state['cellular']['available'])
        self.assertEqual(state['wifi']['strength'], 37)
        self.network.fail_mm = False
        self.network.fail_nm = True
        state = self.network.request()
        self.assertFalse(state['available'])
        self.assertTrue(state['cellular']['available'])
        self.assertEqual(state['cellular']['strength'], 63)

    def test_empty_device_inventory_is_usable(self):
        self.network.tables[networking.ROOT, networking.NM]['Devices'] = []
        self.network.objects = {}
        state = self.network.request()
        self.assertFalse(state['wifi']['available'])
        self.assertFalse(state['cellular']['available'])
        self.assertFalse(state['airplane']['available'])

    def test_scan_and_saved_connection_use_current_device_and_profile(self):
        self.network.request('wifi-scan', device=WIFI)
        self.network.request('wifi-connect', device=WIFI, profile=SAVED, accessPoint=ACCESS)
        events = self.network.mutations()
        self.assertEqual(events[0][2:5], ('RequestScan', '(a{sv})', ({},)))
        self.assertEqual(events[1][2:5], ('ActivateConnection', '(ooo)', (SAVED, WIFI, ACCESS)))

    def test_wrong_password_profile_and_device_fail_without_mutation(self):
        cases = [dict(device='/wrong'), dict(device=WIFI, profile='/missing'),
                 dict(device=WIFI, accessPoint='/missing'), dict(device=WIFI, accessPoint=ACCESS, password='short')]
        for values in cases:
            self.network.events.clear()
            with self.assertRaises(ValueError): self.network.request('wifi-connect', **values)
            self.assertFalse(self.network.mutations())

    def test_personal_wifi_secret_is_a_typed_value_and_not_in_snapshot(self):
        password = "Quotes ' and ; stay data"
        self.network.request('wifi-connect', device=WIFI, accessPoint=ACCESS, password=password)
        event = self.network.mutations()[-1]
        self.assertEqual(event[2], 'AddAndActivateConnection2')
        self.assertEqual(event[3], '(a{sa{sv}}ooa{sv})')
        GLib.Variant(event[3], event[4])
        settings, device, ap, options = event[4]
        self.assertEqual(settings['802-11-wireless-security']['psk'].unpack(), password)
        self.assertEqual(settings['802-11-wireless']['ssid'].unpack(), list(b'Fixture Wi-Fi'))
        self.assertNotIn(password, json.dumps(self.network.request()))

    def test_hidden_and_hotspot_profiles_have_expected_ip_modes(self):
        for hotspot in (False, True):
            self.network.request('wifi-connect', device=WIFI, hidden=not hotspot, hotspot=hotspot,
                                 ssid='Hidden fixture', password='fixture-password', security='wpa-psk', remember=False)
            settings, device, ap, options = self.network.mutations()[-1][4]
            self.assertEqual(ap, '/')
            self.assertEqual(options['persist'].unpack(), 'volatile')
            self.assertEqual(settings['ipv4']['method'].unpack(), 'shared' if hotspot else 'auto')
            self.assertEqual(settings['802-11-wireless']['mode'].unpack(), 'ap' if hotspot else 'infrastructure')

    def test_utf8_ssid_limit_and_unknown_security_are_rejected(self):
        for name, kind in (('é' * 17, 'open'), ('', 'open'), ('fixture', 'enterprise')):
            with self.assertRaises(ValueError): self.network.wifi_settings({'ssid': name, 'security': kind})

    def test_forget_requires_confirmation_and_rejects_active_profile(self):
        for confirmed in (False, True):
            with self.assertRaises(ValueError):
                self.network.request('wifi-forget', device=WIFI, profile=SAVED, confirmed=confirmed)
        self.network.tables[WIFI, networking.DEVICE]['ActiveConnection'] = '/'
        self.network.cache.clear()
        self.network.request('wifi-forget', device=WIFI, profile=SAVED, confirmed=True)
        self.assertEqual(self.network.mutations()[-1][2], 'Delete')

    def test_mobile_profile_contains_apn_auth_roaming_and_metering(self):
        self.network.request('cellular-connect', device=MODEM, modem=MMODEM, name='Fixture data',
            apn='example.invalid', username='fixture', password='synthetic-password', allowRoaming=False)
        event = self.network.mutations()[-1]
        GLib.Variant(event[3], event[4])
        settings = event[4][0]
        self.assertEqual(settings['gsm']['apn'].unpack(), 'example.invalid')
        self.assertEqual(settings['gsm']['password'].unpack(), 'synthetic-password')
        self.assertTrue(settings['gsm']['home-only'].unpack())
        self.assertEqual(settings['connection']['metered'].unpack(), 1)
        self.assertNotIn('synthetic-password', json.dumps(self.network.request()))

    def test_saved_cellular_and_disconnect_are_typed(self):
        self.network.request('cellular-connect', device=MODEM, modem=MMODEM, profile=DATA)
        self.assertEqual(self.network.mutations()[-1][4], (DATA, MODEM, '/'))
        self.network.request('cellular-disconnect', device=MODEM, modem=MMODEM)
        self.assertEqual(self.network.mutations()[-1][2], 'Disconnect')

    def test_radio_toggle_checks_real_hardware_and_boolean_input(self):
        for enabled in ('true', 1, None):
            with self.assertRaises(ValueError): self.network.request('wifi-power', enabled=enabled)
        self.network.request('wifi-power', enabled=False)
        self.assertEqual(self.network.mutations()[-1][4][2].unpack(), False)
        self.network.tables[networking.ROOT, networking.NM]['WirelessHardwareEnabled'] = False
        self.network.cache.clear()
        with self.assertRaises(ValueError): self.network.request('wifi-power', enabled=True)

    def test_action_errors_do_not_expose_dbus_details_or_secrets(self):
        self.network.fail_action = True
        state = networking.handle({'action': 'wifi-connect', 'device': WIFI, 'accessPoint': ACCESS,
            'password': 'private-fixture-secret'}, lambda: self.network)
        self.assertTrue(state['error'])
        self.assertNotIn('private', json.dumps(state))

    def test_airplane_mode_requires_kernel_visibility_and_permission(self):
        for devices in (None, [{'soft': 'unblocked'}]):
            with patch.object(networking, 'kernel_radios', return_value=devices), patch.object(networking.os, 'access', return_value=False):
                with self.assertRaises(ValueError): self.network.request('airplane', enabled=True)
                self.assertFalse(self.network.mutations())
        self.network.request('airplane', enabled=True)
        state = self.network.request()
        self.assertTrue(state['airplane']['enabled'])
        self.assertEqual(state['wifi']['strength'], -1)
        self.assertEqual(state['cellular']['strength'], -1)
        self.assertFalse(state['cellular']['enabled'])

    def test_cellular_hardware_block_and_missing_fresh_signal_clear_the_icon(self):
        self.network.tables[networking.ROOT, networking.NM]['WwanHardwareEnabled'] = False
        cell = self.network.request()['cellular']
        self.assertEqual(cell['status'], 'blocked')
        self.assertEqual(cell['strength'], -1)
        self.assertFalse(cell['enabled'])

    def test_selected_modem_does_not_reuse_another_modems_signal(self):
        other = networking.MM_ROOT + '/Modem/7'
        self.network.objects[other] = {networking.MM + '.Modem': {'State': 7, 'SignalQuality': (99, True), 'Model': 'Searching fixture'}}
        cell = self.network.request(modem=other)['cellular']
        self.assertEqual(cell['id'], other)
        self.assertEqual(cell['strength'], -1)
        self.assertEqual(cell['status'], 'searching')
        self.assertEqual(cell['device'], '')

    def test_device_disappearing_during_action_cannot_receive_a_write(self):
        state = self.network.snapshot({'action': 'wifi-connect', 'device': WIFI, 'details': True})
        del self.network.devices[WIFI]
        with self.assertRaises(ValueError): self.network.act({'action': 'wifi-connect', 'device': WIFI, 'accessPoint': ACCESS}, state)
        self.assertFalse(self.network.mutations())

    def test_hotspot_status_does_not_invent_client_signal_strength(self):
        self.network.tables[WIFI, networking.WIRELESS]['Mode'] = 3
        wifi = self.network.request()['wifi']
        self.assertEqual(wifi['status'], 'hotspot')
        self.assertEqual(wifi['strength'], -1)
        with self.assertRaises(ValueError): self.network.request('wifi-scan', device=WIFI)

    def test_wifi_ip_details_are_reported_without_assuming_internet(self):
        self.network.tables[WIFI, networking.DEVICE].update(Ip4Config='/ip/4', Ip4Connectivity=2)
        self.network.tables['/ip/4', networking.NM + '.IP4Config'] = {
            'AddressData': [{'address': '192.0.2.10', 'prefix': 24}], 'Gateway': '192.0.2.1',
            'NameserverData': [{'address': '192.0.2.53'}]}
        wifi = self.network.request()['wifi']
        self.assertEqual(wifi['addresses'], ['192.0.2.10/24'])
        self.assertEqual(wifi['connectivity'], 'Sign-in required')

    def test_untyped_roaming_and_remember_flags_cannot_enable_options(self):
        for option in ('allowRoaming', 'remember', 'autoconnect', 'hidden'):
            with self.subTest(option=option), self.assertRaises(ValueError):
                self.network.request('cellular-connect', device=MODEM, modem=MMODEM, name='Fixture', **{option: 'false'})
        self.assertFalse(self.network.mutations())

    def test_airplane_is_not_claimed_until_the_modem_is_disabled(self):
        self.network.tables[networking.ROOT, networking.NM].update(WirelessEnabled=False, WwanEnabled=False)
        self.assertFalse(self.network.request()['airplane']['enabled'])
        self.network.objects[MMODEM][networking.MM + '.Modem']['State'] = 3
        self.assertTrue(self.network.request()['airplane']['enabled'])

    def test_scanner_is_only_requested_explicitly(self):
        self.network.request()
        self.network.request()
        self.assertFalse(self.network.mutations())


if __name__ == '__main__':
    unittest.main()
