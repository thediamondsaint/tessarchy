"""Run the real networking CLI against isolated NetworkManager/ModemManager services."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest

from test_networking import FakeNetwork, Gio, GLib, ROOT, WIFI, MODEM, ACCESS, MMODEM
import test_networking

net = test_networking.networking


@unittest.skipUnless(Gio and shutil.which('dbus-daemon'), 'Private D-Bus tests require Gio and dbus-daemon')
class PrivateNetworkBus(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='tessarchy-network-bus-')
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.daemon = subprocess.Popen(['dbus-daemon', '--session', '--nofork', '--nopidfile',
            '--address=unix:path=' + str(self.directory / 'bus'), '--print-address=1'],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        self.addCleanup(self.stop_daemon)
        self.address = self.daemon.stdout.readline().strip()
        self.assertTrue(self.address)
        self.connection = Gio.DBusConnection.new_for_address_sync(self.address,
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, None, None)
        self.addCleanup(lambda: self.connection.close_sync(None))
        for name in (net.NM, net.MM):
            self.connection.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                'org.freedesktop.DBus', 'RequestName', GLib.Variant('(su)', (name, 0)), None,
                Gio.DBusCallFlags.NONE, 3000, None)
        self.model = FakeNetwork()
        self.commands = []
        self.registrations = []
        self.schemas = {
            net.NM: {'Devices': 'ao', 'WirelessEnabled': 'b', 'WirelessHardwareEnabled': 'b',
                     'WwanEnabled': 'b', 'WwanHardwareEnabled': 'b', 'Connectivity': 'u'},
            net.DEVICE: {'DeviceType': 'u', 'State': 'u', 'Interface': 's', 'Managed': 'b',
                'Udi': 's', 'ActiveConnection': 'o', 'AvailableConnections': 'ao', 'StateReason': '(uu)'},
            net.WIRELESS: {'AccessPoints': 'ao', 'ActiveAccessPoint': 'o', 'WirelessCapabilities': 'u', 'LastScan': 'x'},
            net.AP: {'Ssid': 'ay', 'Strength': 'y', 'Flags': 'u', 'RsnFlags': 'u', 'WpaFlags': 'u'},
            net.ACTIVE: {'Connection': 'o'}
        }
        methods = {
            net.NM: '<method name="AddAndActivateConnection2"><arg type="a{sa{sv}}" direction="in"/><arg type="o" direction="in"/><arg type="o" direction="in"/><arg type="a{sv}" direction="in"/><arg type="o" direction="out"/><arg type="o" direction="out"/><arg type="a{sv}" direction="out"/></method><method name="ActivateConnection"><arg type="o" direction="in"/><arg type="o" direction="in"/><arg type="o" direction="in"/><arg type="o" direction="out"/></method>',
            net.WIRELESS: '<method name="RequestScan"><arg type="a{sv}" direction="in"/></method>',
            net.DEVICE: '<method name="Disconnect"/>',
            net.NM + '.Settings': '<method name="ListConnections"><arg type="ao" direction="out"/></method>',
            net.PROFILE: '<method name="GetSettings"><arg type="a{sa{sv}}" direction="out"/></method><method name="Delete"/>',
            'org.freedesktop.DBus.ObjectManager': '<method name="GetManagedObjects"><arg type="a{oa{sa{sv}}}" direction="out"/></method>',
            net.MM + '.Modem': '<method name="Enable"><arg type="b" direction="in"/></method>'
        }
        for path, interface in self.model.tables:
            self.export(path, interface, methods.get(interface, ''))
        self.export(net.ROOT + '/Settings', net.NM + '.Settings', methods[net.NM + '.Settings'])
        for path in self.model.profiles_data:
            self.export(path, net.PROFILE, methods[net.PROFILE])
        self.export(net.MM_ROOT, 'org.freedesktop.DBus.ObjectManager', methods['org.freedesktop.DBus.ObjectManager'])
        self.export(MMODEM, net.MM + '.Modem', methods[net.MM + '.Modem'])
        self.loop = GLib.MainLoop()
        self.thread = threading.Thread(target=self.loop.run, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop_loop)
        fake_rfkill = self.directory / 'rfkill'
        fake_rfkill.write_text('#!/bin/sh\nprintf \'{"rfkilldevices":[]}\\n\'\n')
        fake_rfkill.chmod(0o700)

    def stop_loop(self):
        self.loop.quit()
        self.thread.join(timeout=5)
        for registration in self.registrations:
            self.connection.unregister_object(registration)

    def stop_daemon(self):
        self.daemon.terminate()
        self.daemon.wait(timeout=5)
        self.daemon.stdout.close()

    def export(self, path, interface, methods):
        properties = ''.join('<property name="' + name + '" type="' + signature + '" access="' +
            ('readwrite' if interface == net.NM and name in ('WirelessEnabled', 'WwanEnabled') else 'read') + '"/>'
            for name, signature in self.schemas.get(interface, {}).items())
        info = Gio.DBusNodeInfo.new_for_xml('<node><interface name="' + interface + '">' + properties + methods + '</interface></node>')
        self.registrations.append(self.connection.register_object(path, info.interfaces[0], self.method, self.get_property, self.set_property))

    def get_property(self, connection, sender, path, interface, name):
        signature = self.schemas[interface][name]
        default = [] if signature in ('ao', 'ay') else (0, 0) if signature == '(uu)' else '/' if signature == 'o' else '' if signature == 's' else 0
        value = self.model.tables[path, interface].get(name, default)
        return GLib.Variant(signature, value)

    def set_property(self, connection, sender, path, interface, name, value):
        self.commands.append(('Set', name, value.unpack()))
        self.model.tables[path, interface][name] = value.unpack()
        return True

    def method(self, connection, sender, path, interface, method, parameters, invocation):
        values = parameters.unpack()
        if method == 'ListConnections':
            reply = GLib.Variant('(ao)', (list(self.model.profiles_data),))
        elif method == 'GetSettings':
            settings = {}
            for section, entries in self.model.profiles_data[path].items():
                settings[section] = {key: GLib.Variant('ay' if key == 'ssid' else 'b' if isinstance(value, bool) else 's', value)
                                     for key, value in entries.items()}
            reply = GLib.Variant('(a{sa{sv}})', (settings,))
        elif method == 'GetManagedObjects':
            types = {'State': 'i', 'Model': 's', 'SignalQuality': '(ub)', 'AccessTechnologies': 'u',
                     'UnlockRequired': 'u', 'PrimaryPort': 's', 'Ports': 'a(su)', 'OperatorName': 's', 'RegistrationState': 'u'}
            objects = {p: {i: {k: GLib.Variant(types[k], value) for k, value in props.items()}
                           for i, props in interfaces.items()} for p, interfaces in self.model.objects.items()}
            reply = GLib.Variant('(a{oa{sa{sv}}})', (objects,))
        elif method == 'AddAndActivateConnection2':
            self.commands.append((method, values))
            reply = GLib.Variant('(ooa{sv})', ('/new/profile', '/new/active', {}))
        elif method == 'ActivateConnection':
            self.commands.append((method, values))
            reply = GLib.Variant('(o)', ('/new/active',))
        else:
            self.commands.append((method, values))
            reply = GLib.Variant('()', ())
        invocation.return_value(reply)

    def request(self, **payload):
        env = dict(os.environ, DBUS_SYSTEM_BUS_ADDRESS=self.address, HOME=str(self.directory), PATH=str(self.directory))
        result = subprocess.run([sys.executable, str(ROOT / 'shell/helpers/networking.py')],
            input=json.dumps({'action': 'status', 'details': True, **payload}) + '\n',
            capture_output=True, text=True, timeout=15, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        state = json.loads(result.stdout)
        self.assertEqual(state['error'], '', state)
        return state

    def test_real_cli_reports_signals_and_sends_typed_wifi_and_apn_requests(self):
        state = self.request()
        self.assertEqual(state['wifi']['strength'], 37)
        self.assertEqual(state['cellular']['strength'], 63)
        self.request(action='wifi-connect', device=WIFI, accessPoint=ACCESS, password='private-fixture-secret')
        self.assertEqual(self.commands[-1][0], 'AddAndActivateConnection2')
        self.assertEqual(self.commands[-1][1][0]['802-11-wireless-security']['psk'], 'private-fixture-secret')
        self.request(action='cellular-connect', device=MODEM, modem=MMODEM,
                     name='Fixture mobile', apn='example.invalid', password='private-apn-secret')
        self.assertEqual(self.commands[-1][1][0]['gsm']['password'], 'private-apn-secret')
        state = self.request(action='wifi-power', enabled=False)
        self.assertFalse(state['wifi']['enabled'])
        self.assertEqual(state['wifi']['strength'], -1)
        self.assertNotIn('private-', json.dumps(state))


if __name__ == '__main__':
    unittest.main()
