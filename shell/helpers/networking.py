#!/usr/bin/env python3
"""NetworkManager connections and independent ModemManager signal reporting."""
import pwd
import json
import os
import re
import shutil
import subprocess
import sys
import time
import uuid

NM = 'org.freedesktop.NetworkManager'
ROOT = '/org/freedesktop/NetworkManager'
MM = 'org.freedesktop.ModemManager1'
MM_ROOT = '/org/freedesktop/ModemManager1'
DEVICE = NM + '.Device'
WIRELESS = DEVICE + '.Wireless'
AP = NM + '.AccessPoint'
ACTIVE = NM + '.Connection.Active'
PROFILE = NM + '.Settings.Connection'
CONNECTIVITY = {0: 'Unknown', 1: 'No internet', 2: 'Sign-in required', 3: 'Limited connectivity', 4: 'Internet available'}
REASONS = {7: 'Wi-Fi credentials are required', 8: 'Wi-Fi disconnected',
           9: 'Wi-Fi authentication configuration failed', 10: 'Wi-Fi authentication failed',
           11: 'Wi-Fi authentication timed out', 17: 'DHCP failed', 29: 'APN connection failed',
           31: 'Carrier registration denied', 32: 'Carrier registration timed out',
           43: 'Modem is not available', 45: 'SIM is missing', 46: 'SIM PIN is required',
           47: 'SIM PUK is required', 48: 'SIM is not accepted', 53: 'Network was not found'}


def percent(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not 0 <= value <= 100:
        return -1
    return round(value)


def security(props):
    flags = int(props.get('RsnFlags', 0)) | int(props.get('WpaFlags', 0))
    if flags & 0x400:
        return 'sae'
    if flags & (0x800 | 0x1000):
        return 'owe'
    if flags & (0x200 | 0x2000):
        return 'enterprise'
    if flags & 0x100:
        return 'wpa-psk'
    if flags:
        return 'unsupported'
    return 'wep' if int(props.get('Flags', 0)) & 1 else 'open'


def technology(flags):
    if flags == 0xFFFFFFFF:
        return ''
    for mask, name in ((1 << 15, '5G'), (1 << 14 | 1 << 16 | 1 << 17, '4G'), (1 << 11 | 1 << 12 | 1 << 13, '3G'),
                       (1 << 9, 'H+'), (1 << 8 | 1 << 6 | 1 << 7, 'H'), (1 << 5, '3G'),
                       (1 << 10, '1x'),
                       (1 << 4, 'EDGE'), (1 << 1 | 1 << 2 | 1 << 3, '2G')):
        if flags & mask:
            return name
    return ''


def kernel_radios():
    if not shutil.which('rfkill'):
        return None
    try:
        result = subprocess.run(['rfkill', '--json', '--output', 'ID,TYPE,DEVICE,SOFT,HARD'],
                                capture_output=True, text=True, timeout=2, check=True)
        devices = json.loads(result.stdout)['rfkilldevices']
        if not isinstance(devices, list) or any(not isinstance(d, dict) or d.get('soft') not in ('blocked', 'unblocked') for d in devices):
            return None
        return devices
    except (ValueError, KeyError, OSError, subprocess.SubprocessError):
        return None


def empty_state():
    return {'available': False, 'connectivity': 'Unknown', 'error': '', 'notice': '', 'editorAvailable': bool(shutil.which('nm-connection-editor')),
            'wifi': {'available': False, 'enabled': False, 'hardwareEnabled': False, 'status': 'unavailable',
                     'label': 'Wi-Fi unavailable', 'strength': -1, 'devices': [], 'networks': [], 'profiles': []},
            'cellular': {'available': False, 'enabled': False, 'hardwareEnabled': False, 'status': 'unavailable',
                         'label': 'Cellular unavailable', 'strength': -1, 'modems': [], 'profiles': []},
            'airplane': {'available': False, 'enabled': False, 'label': 'Unavailable'}}


class Network:
    def __init__(self, connection=None, timeout=10):
        from gi.repository import Gio, GLib
        self.Gio, self.GLib = Gio, GLib
        self.bus = connection or Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.deadline = time.monotonic() + timeout
        self.cache = {}

    def call(self, path, interface, method, signature=None, values=(), service=NM):
        remaining = int((self.deadline - time.monotonic()) * 1000)
        if remaining <= 0:
            raise TimeoutError('Network service timed out')
        result = self.bus.call_sync(service, path, interface, method,
            self.GLib.Variant(signature, values) if signature else None, None,
            self.Gio.DBusCallFlags.ALLOW_INTERACTIVE_AUTHORIZATION if method in ('Set', 'Enable', 'RequestScan', 'Disconnect', 'Delete', 'ActivateConnection', 'AddAndActivateConnection2') else self.Gio.DBusCallFlags.NONE, min(remaining, 3000), None)
        return result.unpack() if result else ()

    def props(self, path, interface, service=NM):
        key = service, path, interface
        if key not in self.cache:
            self.cache[key] = self.call(path, 'org.freedesktop.DBus.Properties', 'GetAll', '(s)', (interface,), service)[0]
        return self.cache[key]

    def set_kernel_radios(self, blocked):
        subprocess.run(['rfkill', 'block' if blocked else 'unblock', 'all'],
                       capture_output=True, timeout=3, check=True)

    def set(self, name, enabled):
        if type(enabled) is not bool:
            raise ValueError('Choose on or off')
        self.call(ROOT, 'org.freedesktop.DBus.Properties', 'Set', '(ssv)',
                  (NM, name, self.GLib.Variant('b', enabled)))

    def profiles(self):
        result = []
        for path in self.call(ROOT + '/Settings', NM + '.Settings', 'ListConnections')[0]:
            try:
                data = self.call(path, PROFILE, 'GetSettings')[0]
                kind = data.get('connection', {}).get('type')
                if kind in ('802-11-wireless', 'gsm', 'cdma'):
                    connection = data['connection']
                    result.append({'id': path, 'name': connection.get('id', 'Connection'), 'type': kind,
                        'ssidHex': bytes(data.get('802-11-wireless', {}).get('ssid', [])).hex(),
                        'security': data.get('802-11-wireless-security', {}).get('key-mgmt', 'open'),
                        'autoconnect': connection.get('autoconnect', False), 'mode': data.get('802-11-wireless', {}).get('mode', 'infrastructure'),
                        'apn': data.get('gsm', {}).get('apn', ''), 'homeOnly': data.get('gsm', {}).get('home-only', False)})
            except self.GLib.Error:
                continue
        return result

    def snapshot(self, request):
        self.cache.clear()
        state = empty_state()
        try:
            manager = self.props(ROOT, NM)
            state.update(available=True, connectivity=CONNECTIVITY.get(manager.get('Connectivity'), 'Unknown'))
        except self.GLib.Error:
            manager = {}
            state['error'] = 'NetworkManager is unavailable'
        self.devices = {}
        for path in manager.get('Devices', []):
            try:
                self.devices[path] = self.props(path, DEVICE)
            except self.GLib.Error:
                continue
        self.saved = []
        if state['available'] and (request.get('details') or request.get('action', 'status') != 'status'):
            try:
                self.saved = self.profiles()
            except self.GLib.Error:
                state['error'] = 'Saved network connections could not be read'
        wifi_devices = [(p, d) for p, d in self.devices.items() if d.get('DeviceType') == 2]
        modem_devices = [(p, d) for p, d in self.devices.items() if d.get('DeviceType') == 8]
        self.wifi(state, manager, wifi_devices, request)
        self.cellular(state, manager, modem_devices, request)
        radios = kernel_radios()
        present = bool(wifi_devices or modem_devices or state['cellular']['available'] or radios)
        enabled = present and not manager.get('WirelessEnabled', False) and not manager.get('WwanEnabled', False)
        enabled = enabled and radios is not None and all(d['soft'] == 'blocked' for d in radios)
        enabled = enabled and (not modem_devices or state['cellular']['available'])
        enabled = enabled and all(not modem['enabled'] for modem in state['cellular']['modems'])
        state['airplane'] = {'available': state['available'] and present, 'enabled': enabled,
                             'label': 'On' if enabled else 'Off'}
        return state

    def connection_details(self, device):
        result = {'addresses': [], 'gateway': '', 'dns': []}
        for name, interface in (('Ip4Config', '.IP4Config'), ('Ip6Config', '.IP6Config')):
            path = device.get(name, '/')
            if path == '/':
                continue
            try:
                config = self.props(path, NM + interface)
                result['addresses'].extend(str(a['address']) + '/' + str(a['prefix']) for a in config.get('AddressData', []) if 'address' in a and 'prefix' in a)
                result['gateway'] = result['gateway'] or config.get('Gateway', '')
                result['dns'].extend(n['address'] for n in config.get('NameserverData', []) if 'address' in n)
            except self.GLib.Error:
                continue
        return result

    def wifi(self, state, manager, devices, request):
        wifi = state['wifi']
        wifi.update(available=bool(devices), enabled=bool(manager.get('WirelessEnabled')),
                    hardwareEnabled=bool(manager.get('WirelessHardwareEnabled')))
        for path, props in devices:
            wifi['devices'].append({'id': path, 'name': props.get('Interface', 'Wi-Fi'),
                                   'managed': bool(props.get('Managed')), 'state': props.get('State', 0)})
        requested = request.get('wifiDevice', request.get('device', ''))
        selected = next(((p, d) for p, d in devices if p == requested), None)
        selected = selected or next(((p, d) for p, d in devices if d.get('State') == 100), None)
        selected = selected or (devices[0] if devices else None)
        if not selected:
            return
        path, props = selected
        radio = self.props(path, WIRELESS)
        wifi.update(device=path, canHotspot=bool(radio.get('WirelessCapabilities', 0) & 0x40),
                    managed=bool(props.get('Managed')), stateReason=(props.get('StateReason') or (0, 0))[1],
                    active=props.get('ActiveConnection', '/'), lastScan=radio.get('LastScan', -1))
        code = props.get('State', 0)
        status = 'blocked' if not wifi['hardwareEnabled'] else 'off' if not wifi['enabled'] else 'unmanaged' if not wifi['managed'] else (
            'hotspot' if code == 100 and radio.get('Mode') == 3 else 'connected' if code == 100 else 'connecting' if 40 <= code < 100 else 'failed' if code == 120 else 'disconnected')
        wifi.update(status=status, label={'blocked': 'Wi-Fi hardware blocked', 'off': 'Wi-Fi off',
            'unmanaged': 'Wi-Fi managed elsewhere', 'hotspot': 'Hotspot active', 'connected': 'Wi-Fi connected', 'connecting': 'Wi-Fi connecting',
            'failed': REASONS.get(wifi['stateReason'], 'Wi-Fi connection failed'), 'disconnected': 'Wi-Fi disconnected'}[status])
        active_ap = radio.get('ActiveAccessPoint', '/')
        if active_ap != '/' and status == 'connected':
            ap = self.props(active_ap, AP)
            wifi.update(strength=percent(ap.get('Strength')), label=bytes(ap.get('Ssid', [])).decode('utf-8', 'replace') or 'Wi-Fi connected')
        self.aps = {}
        if request.get('details') or request.get('action', 'status') not in ('status', 'wifi-power', 'cellular-power', 'airplane'):
            for ap_path in radio.get('AccessPoints', [])[:256]:
                try:
                    ap = self.props(ap_path, AP)
                    raw = bytes(ap.get('Ssid', []))
                    if not raw:
                        continue
                    row = {'id': ap_path, 'name': raw.decode('utf-8', 'replace'), 'ssidHex': raw.hex(),
                           'security': security(ap), 'strength': percent(ap.get('Strength')),
                           'connected': ap_path == active_ap and status == 'connected'}
                    self.aps[ap_path] = row
                    wifi['networks'].append(row)
                except self.GLib.Error:
                    continue
        if request.get('details'):
            wifi.update(self.connection_details(props))
        ip4, ip6 = props.get('Ip4Connectivity', 0), props.get('Ip6Connectivity', 0)
        code_connectivity = 4 if 4 in (ip4, ip6) else 2 if 2 in (ip4, ip6) else 3 if 3 in (ip4, ip6) else 1 if 1 in (ip4, ip6) else 0
        wifi['connectivity'] = CONNECTIVITY[code_connectivity]
        available = set(props.get('AvailableConnections', []))
        wifi['profiles'] = [p for p in self.saved if p['type'] == '802-11-wireless' and p['id'] in available]
        grouped = {}
        for row in sorted(wifi['networks'], key=lambda row: (row['connected'], row['strength']), reverse=True):
            grouped.setdefault((row['ssidHex'], row['security']), row)
        wifi['networks'] = list(grouped.values())
        for row in wifi['networks']:
            row['profile'] = next((p['id'] for p in wifi['profiles'] if p['ssidHex'] == row['ssidHex']
                and p['security'] in ({'wep': ('none',), 'enterprise': ('wpa-eap', 'wpa-eap-suite-b-192', 'ieee8021x')}.get(row['security'], (row['security'],)))), '')

    def cellular(self, state, manager, devices, request):
        cellular = state['cellular']
        cellular.update(enabled=bool(manager.get('WwanEnabled', True)), hardwareEnabled=bool(manager.get('WwanHardwareEnabled', True)))
        try:
            objects = self.call(MM_ROOT, 'org.freedesktop.DBus.ObjectManager', 'GetManagedObjects', service=MM)[0]
            self.modem_objects = objects
        except self.GLib.Error:
            cellular['label'] = 'Cellular modem service unavailable'
            return
        for path, interfaces in objects.items():
            if MM + '.Modem' not in interfaces:
                continue
            props = interfaces[MM + '.Modem']
            network = interfaces.get(MM + '.Modem.Modem3gpp', {})
            ports = [p[0] for p in props.get('Ports', [])] + [props.get('PrimaryPort', '')]
            match = next(((p, d) for p, d in devices if d.get('Udi') == path), None)
            match = match or next(((p, d) for p, d in devices if d.get('Interface') in ports), None)
            nm_path, nm_props = match or ('', {})
            code = props.get('State', 0)
            signal = props.get('SignalQuality', (-1, False))
            registered = code >= 8
            enabled = code >= 6
            status = 'off' if not enabled or not cellular['enabled'] else 'locked' if code == 2 else (
                'connected' if nm_props.get('State') == 100 else 'registered' if registered else 'searching')
            if not cellular['hardwareEnabled']:
                status = 'blocked'
            elif code == 2:
                status = 'locked'
            elif code == -1:
                status = 'failed'
            roaming = network.get('RegistrationState') in (5, 7, 10)
            modem = {'id': path, 'name': props.get('Model') or 'Cellular modem', 'device': nm_path,
                'managed': bool(nm_props.get('Managed')), 'enabled': enabled, 'status': status,
                'registered': registered, 'operator': network.get('OperatorName', ''), 'roaming': roaming,
                'supportsApn': MM + '.Modem.Modem3gpp' in interfaces,
                'technology': technology(props.get('AccessTechnologies', 0)), 'dataStatus': 'connected' if nm_props.get('State') == 100 else 'connecting' if 40 <= nm_props.get('State', 0) < 100 else 'failed' if nm_props.get('State') == 120 else 'disconnected',
                'dataError': REASONS.get((nm_props.get('StateReason') or (0, 0))[1], 'Mobile data connection failed') if nm_props.get('State') == 120 else '',
                'strength': percent(signal[0]) if signal[1] and registered and enabled and cellular['enabled'] and cellular['hardwareEnabled'] else -1,
                'active': nm_props.get('ActiveConnection', '/'), 'locked': props.get('UnlockRequired', 0),
                'profiles': [p for p in self.saved if p['type'] in ('gsm', 'cdma')
                    and p['id'] in nm_props.get('AvailableConnections', [])]}
            modem['label'] = modem['operator'] or {'off': 'Cellular off', 'locked': 'SIM locked',
                'connected': 'Mobile data connected', 'registered': 'Registered · data disconnected',
                'searching': 'Searching for service', 'failed': 'Modem failure', 'blocked': 'Cellular hardware blocked'}[status]
            if status in ('off', 'locked', 'failed', 'blocked'):
                modem['label'] = {'off': 'Cellular off', 'locked': 'SIM locked', 'failed': 'Modem failure', 'blocked': 'Cellular hardware blocked'}[status]
            if request.get('details'):
                modem.update(self.connection_details(nm_props))
            cellular['modems'].append(modem)
        selected = next((m for m in cellular['modems'] if m['id'] == request.get('modem')), None)
        selected = selected or next((m for m in cellular['modems'] if m['status'] == 'connected'), None)
        selected = selected or next(iter(cellular['modems']), None)
        if selected:
            cellular.update(selected, available=True)
            cellular['enabled'] = bool(selected['enabled'] and cellular['hardwareEnabled'] and manager.get('WwanEnabled', True))

    def profile_settings(self, request, kind):
        variant = self.GLib.Variant
        name = str(request.get('name', '')).strip()
        if not name or len(name) > 120:
            raise ValueError('Enter a connection name')
        settings = {'connection': {'id': variant('s', name), 'uuid': variant('s', str(uuid.uuid4())),
            'type': variant('s', kind), 'autoconnect': variant('b', bool(request.get('autoconnect', True))),
            'permissions': variant('as', ['user:' + pwd.getpwuid(os.getuid()).pw_name + ':'])},
            'ipv4': {'method': variant('s', 'auto')}, 'ipv6': {'method': variant('s', 'auto')}}
        return settings

    def wifi_settings(self, request, network=None):
        variant = self.GLib.Variant
        raw = bytes.fromhex(network['ssidHex']) if network else str(request.get('ssid', '')).encode('utf-8')
        if not 1 <= len(raw) <= 32 or (network is None and b'\0' in raw):
            raise ValueError('The Wi-Fi name must contain 1–32 bytes')
        kind = network['security'] if network else request.get('security', 'wpa-psk')
        password = str(request.get('password', ''))
        profile_request = dict(request, name=raw.decode('utf-8', 'replace').strip() or 'Wi-Fi')
        if request.get('hotspot'):
            profile_request.setdefault('autoconnect', False)
        settings = self.profile_settings(profile_request, '802-11-wireless')
        settings['802-11-wireless'] = {'ssid': variant('ay', raw), 'mode': variant('s', 'ap' if request.get('hotspot') else 'infrastructure'),
                                      'hidden': variant('b', bool(request.get('hidden')))}
        if kind in ('wpa-psk', 'sae'):
            valid = 8 <= len(password.encode('utf-8')) <= 63 or bool(re.fullmatch(r'[0-9a-fA-F]{64}', password))
            if kind == 'sae':
                valid = 1 <= len(password.encode('utf-8')) <= 63
            if not valid:
                raise ValueError('Enter a valid Wi-Fi password')
            settings['802-11-wireless-security'] = {'key-mgmt': variant('s', kind), 'psk': variant('s', password)}
        elif kind == 'wep':
            if not (password.isascii() and len(password) in (5, 13)) and not re.fullmatch(r'(?:[0-9a-fA-F]{10}|[0-9a-fA-F]{26})', password):
                raise ValueError('Enter a valid WEP key')
            settings['802-11-wireless-security'] = {'key-mgmt': variant('s', 'none'), 'wep-key0': variant('s', password),
                'wep-key-type': variant('u', 1), 'wep-tx-keyidx': variant('u', 0)}
        elif kind == 'owe':
            settings['802-11-wireless-security'] = {'key-mgmt': variant('s', 'owe')}
        elif kind != 'open':
            raise ValueError('Configure this network in Connections, then select its saved profile')
        if request.get('hotspot'):
            if kind != 'wpa-psk':
                raise ValueError('Hotspots require WPA2 security')
            settings['ipv4']['method'] = variant('s', 'shared')
            settings['ipv6']['method'] = variant('s', 'disabled')
        return settings

    def act(self, request, state):
        action = request.get('action')
        for key in ('enabled', 'remember', 'autoconnect', 'hidden', 'hotspot', 'allowRoaming', 'confirmed'):
            if key in request and type(request[key]) is not bool:
                raise ValueError('Invalid connection option')
        if action in ('wifi-power', 'cellular-power'):
            section, prop = ('wifi', 'WirelessEnabled') if action == 'wifi-power' else ('cellular', 'WwanEnabled')
            if not state[section]['available'] or not state[section]['hardwareEnabled']:
                raise ValueError('Radio hardware is unavailable or blocked')
            self.set(prop, request.get('enabled'))
            if section == 'cellular' and state[section].get('id') and state[section].get('enabled') != request.get('enabled'):
                self.call(state[section]['id'], MM + '.Modem', 'Enable', '(b)', (request['enabled'],), service=MM)
            return
        if action == 'airplane':
            enabled = request.get('enabled')
            if type(enabled) is not bool:
                raise ValueError('Choose on or off')
            radios = kernel_radios()
            if radios is None:
                raise ValueError('Kernel radio state cannot be verified')
            if radios and not os.access('/dev/rfkill', os.W_OK):
                raise ValueError('Radio switch permission is required for airplane mode')
            self.set('WirelessEnabled', not enabled)
            self.set('WwanEnabled', not enabled)
            for modem in state['cellular']['modems']:
                if modem['enabled'] != (not enabled):
                    self.call(modem['id'], MM + '.Modem', 'Enable', '(b)', (not enabled,), service=MM)
            if radios:
                self.set_kernel_radios(enabled)
            return
        section = state['wifi'] if action.startswith('wifi-') else state['cellular']
        device = request.get('device', '')
        if not device or device != section.get('device') or device not in self.devices:
            raise ValueError('Choose an available network device')
        if not section.get('managed'):
            raise ValueError('This device is not managed by NetworkManager')
        if action == 'wifi-scan':
            if not section['enabled'] or not section['hardwareEnabled']:
                raise ValueError('Wi-Fi is off or hardware blocked')
            if section.get('status') == 'hotspot':
                raise ValueError('Stop the hotspot before scanning')
            self.call(device, WIRELESS, 'RequestScan', '(a{sv})', ({},))
        elif action.endswith('-disconnect'):
            self.call(device, DEVICE, 'Disconnect')
        elif action.endswith('-forget'):
            profile = next((p for p in section['profiles'] if p['id'] == request.get('profile')), None)
            if not profile or not request.get('confirmed'):
                raise ValueError('Confirm a saved connection first')
            if section.get('active', '/') != '/':
                active = self.props(section['active'], ACTIVE)
                if active.get('Connection') == profile['id']:
                    raise ValueError('Disconnect this connection before forgetting it')
            self.call(profile['id'], PROFILE, 'Delete')
        elif action in ('wifi-connect', 'cellular-connect'):
            if section.get('dataStatus') == 'connecting':
                raise ValueError('A data connection is already starting')
            if section.get('status') in ('connecting', 'locked', 'blocked', 'off', 'unmanaged', 'failed'):
                if section.get('status') != 'failed':
                    raise ValueError('The device is not ready to connect')
            profile = next((p for p in section['profiles'] if p['id'] == request.get('profile')), None)
            if request.get('profile'):
                if not profile:
                    raise ValueError('Saved connection is no longer available')
                ap = request.get('accessPoint', '/') if action == 'wifi-connect' else '/'
                if ap != '/' and ap not in self.aps:
                    raise ValueError('The network is no longer available')
                if ap != '/' and self.aps[ap]['ssidHex'] != profile['ssidHex']:
                    raise ValueError('Saved connection does not match this network')
                self.call(ROOT, NM, 'ActivateConnection', '(ooo)', (profile['id'], device, ap))
                return
            if action == 'wifi-connect':
                network = self.aps.get(request.get('accessPoint'))
                if not network and not request.get('hidden') and not request.get('hotspot'):
                    raise ValueError('The network is no longer available')
                if request.get('hotspot') and not section.get('canHotspot'):
                    raise ValueError('This adapter does not support a hotspot')
                settings = self.wifi_settings(request, network)
                ap = network['id'] if network else '/'
            else:
                if not section.get('supportsApn'):
                    raise ValueError('Configure this modem in Connections, then select its saved profile')
                apn = str(request.get('apn', '')).strip()
                if apn and not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]{0,99}', apn):
                    raise ValueError('Enter a valid APN')
                operator = str(request.get('operator', '')).strip()
                if operator and not re.fullmatch(r'[0-9]{5,6}', operator):
                    raise ValueError('Enter a five- or six-digit operator code')
                settings = self.profile_settings(dict(request, autoconnect=request.get('autoconnect', False)), 'gsm')
                settings['gsm'] = {'auto-config': self.GLib.Variant('b', not bool(apn)),
                                   'home-only': self.GLib.Variant('b', not bool(request.get('allowRoaming', False)))}
                for key, value in (('apn', apn), ('username', request.get('username', '')),
                                   ('password', request.get('password', '')), ('network-id', operator)):
                    if value:
                        if not isinstance(value, str) or len(value) > 256:
                            raise ValueError('Invalid mobile data settings')
                        settings['gsm'][key] = self.GLib.Variant('s', value)
                identifier = self.modem_objects.get(section['id'], {}).get(MM + '.Modem', {}).get('DeviceIdentifier', '')
                if identifier:
                    settings['gsm']['device-id'] = self.GLib.Variant('s', identifier)
                settings['connection']['metered'] = self.GLib.Variant('u', 1)
                ap = '/'
            options = {'persist': self.GLib.Variant('s', 'disk' if request.get('remember', True) else 'volatile')}
            self.call(ROOT, NM, 'AddAndActivateConnection2', '(a{sa{sv}}ooa{sv})', (settings, device, ap, options))
        else:
            raise ValueError('Unknown networking action')


def handle(request, factory=Network):
    state = empty_state()
    action = request.get('action', 'status')
    allowed = ('status', 'wifi-power', 'cellular-power', 'airplane', 'wifi-scan', 'wifi-connect',
               'wifi-disconnect', 'wifi-forget', 'cellular-connect', 'cellular-disconnect', 'cellular-forget')
    if action not in allowed:
        state['error'] = 'Unknown networking action'
        return state
    network = None
    try:
        network = factory()
        state = network.snapshot(request)
        if action != 'status':
            network.act(request, state)
            network.cache.clear()
            state = network.snapshot(dict(request, action='status'))
            state['notice'] = 'Connection requested' if action.endswith('-connect') else 'Request accepted'
    except ValueError as exc:
        state['error'] = str(exc)
    except Exception:
        try:
            state = network.snapshot(dict(request, action='status')) if network else empty_state()
        except Exception:
            state = empty_state()
        state['error'] = 'Network request failed. Check the device, credentials and permissions.'
    return state


def main():
    os.umask(0o077)
    try:
        line = sys.stdin.readline(65537)
        if len(line) > 65536:
            raise ValueError('Request too large')
        request = json.loads(line)
        if not isinstance(request, dict):
            raise ValueError('Invalid request')
        result = handle(request)
    except Exception:
        result = empty_state()
        result['error'] = 'Invalid networking request'
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
