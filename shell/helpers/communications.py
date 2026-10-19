#!/usr/bin/env python3
"""Private local contacts, sound preferences and ModemManager operations."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.parse import unquote, urlparse
import uuid

MM = 'org.freedesktop.ModemManager1'
ROOT = '/org/freedesktop/ModemManager1'
SOUNDS = Path(__file__).resolve().parents[1] / 'audio/ringtones'


def number(value):
    value = re.sub(r'[ ()\-.]', '', str(value))
    if not re.fullmatch(r'\+?[0-9]{1,20}', value):
        raise ValueError('Enter a valid phone number')
    return value


def local_file(value):
    parsed = urlparse(str(value))
    if parsed.scheme and (parsed.scheme != 'file' or parsed.netloc not in ('', 'localhost')):
        raise ValueError('Choose a local file')
    path = Path(unquote(parsed.path) if parsed.scheme else value).expanduser()
    if not path.is_absolute() or not path.is_file() or path.stat().st_size > 15_000_000:
        raise ValueError('Choose a local file smaller than 15 MB')
    return path


class Store:
    def __init__(self, directory=None):
        self.directory = directory or Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'tessera/communications'
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.lock = (self.directory / '.lock').open('a')
        os.chmod(self.lock.name, 0o600)
        fcntl.flock(self.lock, fcntl.LOCK_EX)
        self.path = self.directory / 'data.json'
        self.data = json.loads(self.path.read_text()) if self.path.exists() else {}
        for key, default in [('contacts', []), ('messages', []), ('history', []), ('sounds', {})]:
            self.data.setdefault(key, default)

    def save(self):
        with tempfile.NamedTemporaryFile(mode='w', dir=self.directory, delete=False) as out:
            temporary = Path(out.name)
            json.dump(self.data, out, ensure_ascii=False)
        os.replace(temporary, self.path)

    def contact(self, request):
        name = str(request.get('name', '')).strip()[:120]
        if not name:
            raise ValueError('Enter a contact name')
        phone = number(request.get('number', ''))
        identifier = request.get('id') or str(uuid.uuid4())
        old = next((c for c in self.data['contacts'] if c['id'] == identifier), None)
        if request.get('id') and not old:
            raise ValueError('Contact no longer exists')
        photo = old.get('photo', '') if old else ''
        if request.get('photo') and request['photo'] != photo:
            source = local_file(request['photo'])
            if source.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp'):
                raise ValueError('Choose a PNG, JPEG or WebP photo')
            directory = self.directory / 'avatars'
            directory.mkdir(exist_ok=True, mode=0o700)
            target = directory / (str(uuid.uuid4()) + '.png')
            subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-protocol_whitelist', 'file,pipe',
                            '-f', 'image2', '-pattern_type', 'none', '-i', str(source), '-frames:v', '1',
                            '-vf', 'scale=256:256:force_original_aspect_ratio=decrease', '-update', '1', str(target)],
                           capture_output=True, timeout=10, check=True)
            target.chmod(0o600)
            photo = target.as_uri()
        contact = {'id': identifier, 'name': name, 'number': phone, 'photo': photo}
        self.data['contacts'] = sorted([c for c in self.data['contacts'] if c['id'] != identifier] + [contact], key=lambda c: c['name'].casefold())
        self.save()

    def tones(self):
        paths = list(SOUNDS.glob('*.mp3')) + list((self.directory / 'ringtones').glob('*.mp3'))
        return [{'id': p.stem, 'name': p.stem.replace('-', ' '), 'path': str(p)} for p in sorted(paths)]


class Modems:
    def __init__(self, connection=None):
        from gi.repository import Gio, GLib
        self.Gio, self.GLib = Gio, GLib
        self.bus = connection or Gio.bus_get_sync(Gio.BusType.SYSTEM, None)

    def call(self, path, interface, method, signature=None, values=()):
        parameters = self.GLib.Variant(signature, values) if signature else None
        result = self.bus.call_sync(MM, path, interface, method, parameters, None,
                                    self.Gio.DBusCallFlags.NONE, 8000, None)
        return result.unpack()

    def props(self, path, interface):
        return self.call(path, 'org.freedesktop.DBus.Properties', 'GetAll', '(s)', (interface,))[0]

    def snapshot(self, selected=''):
        objects = self.call(ROOT, 'org.freedesktop.DBus.ObjectManager', 'GetManagedObjects')[0]
        def properties(path, interface):
            cached = objects.get(path, {}).get(interface)
            return cached if cached is not None else self.props(path, interface)
        modems = []
        for path, interfaces in objects.items():
            if MM + '.Modem' in interfaces:
                p = interfaces[MM + '.Modem']
                modems.append({'id': path, 'name': p.get('Model') or 'Cellular modem'})
        if not modems:
            return {'available': False, 'label': 'No cellular modem detected', 'modems': [], 'calls': [], 'messages': [], 'sims': []}
        path = selected if any(m['id'] == selected for m in modems) else modems[0]['id']
        interfaces = objects[path]
        modem = interfaces[MM + '.Modem']
        network = interfaces.get(MM + '.Modem.Modem3gpp', {})
        sims = []
        slots = modem.get('SimSlots') or [modem.get('Sim', '/')]
        for index, sim in enumerate(slots):
            p = properties(sim, MM + '.Sim') if sim != '/' else {}
            sims.append({'id': sim, 'slot': index + 1, 'present': sim != '/', 'active': sim == modem.get('Sim'),
                         'name': p.get('OperatorName') or ('SIM ' + str(index + 1)),
                         'type': 'eSIM' if p.get('SimType') == 2 or p.get('Eid') else 'Physical SIM' if p.get('SimType') == 1 else 'SIM',
                         'suffix': str(p.get('SimIdentifier', ''))[-4:], 'eid': p.get('Eid', ''),
                         'profileStatus': p.get('EsimStatus', 0)})
        voice, messaging = MM + '.Modem.Voice', MM + '.Modem.Messaging'
        calls = []
        for call in interfaces.get(voice, {}).get('Calls', [])[:8]:
            p = properties(call, MM + '.Call')
            calls.append({'id': call, 'number': p.get('Number', ''), 'state': p.get('State', 0), 'direction': p.get('Direction', 0)})
        messages = []
        for sms in interfaces.get(messaging, {}).get('Messages', [])[-100:]:
            p = properties(sms, MM + '.Sms')
            if p.get('State') not in (3, 5):
                continue
            content = {'number': p.get('Number', ''), 'text': p.get('Text', ''), 'timestamp': p.get('Timestamp', ''),
                       'incoming': p.get('State') == 3, 'status': 'Received' if p.get('State') == 3 else 'Sent to network'}
            content['id'] = hashlib.sha256(json.dumps([path, sms, content], sort_keys=True).encode()).hexdigest()
            messages.append(content)
        state = modem.get('State', 0)
        return {'available': True, 'id': path, 'modems': modems, 'label': network.get('OperatorName') or
                ('SIM locked' if state == 2 else 'Cellular ready' if state >= 8 else 'Searching for service'),
                'registered': state >= 8, 'voice': voice in interfaces, 'sms': messaging in interfaces,
                'locked': modem.get('UnlockRequired', 0), 'retries': {str(k): v for k, v in modem.get('UnlockRetries', {}).items()},
                'enabled': state >= 6, 'sims': sims, 'calls': calls, 'messages': messages,
                'signal': modem.get('SignalQuality', (0, False))[0] if modem.get('SignalQuality', (0, False))[1] else -1}

    def act(self, request, state):
        if not state.get('available') or request.get('modem') != state['id']:
            raise ValueError('Select an available modem first')
        action, path = request['action'], state['id']
        if action == 'dial':
            if not state['registered'] or not state['voice']:
                raise ValueError('Voice service is not ready')
            phone = number(request.get('number', ''))
            call = self.call(path, MM + '.Modem.Voice', 'CreateCall', '(a{sv})', ({'number': self.GLib.Variant('s', phone)},))[0]
            self.call(call, MM + '.Call', 'Start')
        elif action in ('answer', 'hangup', 'dtmf'):
            call = next((c for c in state['calls'] if c['id'] == request.get('call')), None)
            if not call or call['state'] == 7:
                raise ValueError('Call is no longer available')
            if action == 'dtmf':
                tone = str(request.get('tone', ''))
                if not re.fullmatch(r'[0-9A-D*#]', tone):
                    raise ValueError('Invalid keypad tone')
                self.call(call['id'], MM + '.Call', 'SendDtmf', '(s)', (tone,))
            else:
                self.call(call['id'], MM + '.Call', 'Accept' if action == 'answer' else 'Hangup')
        elif action == 'send-sms':
            if not state['registered'] or not state['sms']:
                raise ValueError('Messaging service is not ready')
            text = str(request.get('text', '')).strip()
            if not text or len(text) > 1600:
                raise ValueError('Enter a message of 1–1600 characters')
            props = {'number': self.GLib.Variant('s', number(request.get('number', ''))), 'text': self.GLib.Variant('s', text)}
            sms = self.call(path, MM + '.Modem.Messaging', 'Create', '(a{sv})', (props,))[0]
            self.call(sms, MM + '.Sms', 'Send')
        elif action == 'unlock-sim':
            sim = next((s for s in state['sims'] if s['active']), None)
            pin = str(request.get('pin', ''))
            if not sim or not re.fullmatch(r'[0-9]{4,8}', pin) or state['locked'] != 2:
                raise ValueError('SIM PIN unlock is not available')
            self.call(sim['id'], MM + '.Sim', 'SendPin', '(s)', (pin,))
        elif action == 'select-slot':
            slot = int(request.get('slot', 0))
            if not any(s['slot'] == slot and s['present'] for s in state['sims']):
                raise ValueError('SIM slot is not available')
            self.call(path, MM + '.Modem', 'SetPrimarySimSlot', '(u)', (slot,))
        elif action == 'modem-power':
            self.call(path, MM + '.Modem', 'Enable', '(b)', (bool(request.get('enabled')),))
        else:
            raise ValueError('Unknown cellular action')


def esim_profiles(run=subprocess.run):
    if not shutil.which('lpac'):
        return {'available': False, 'label': 'Install lpac for eSIM profile management', 'profiles': []}
    result = run(['lpac', 'profile', 'list'], capture_output=True, text=True, timeout=20, check=True)
    replies = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
    payload = next((r['payload'] for r in reversed(replies) if r.get('type') == 'lpa'), {})
    if payload.get('code') != 0 or not isinstance(payload.get('data'), list):
        raise ValueError('No accessible eUICC reader. Check the lpac reader configuration')
    return {'available': True, 'label': 'eSIM profiles', 'profiles': [
        {'id': p['iccid'], 'name': p.get('profileNickname') or p.get('profileName') or p.get('serviceProviderName') or 'eSIM',
         'enabled': p.get('profileState') == 'enabled'} for p in payload['data']]}


def handle(request, store, backend_factory=Modems):
    action = request.get('action', 'status')
    if action == 'browse':
        home = Path.home()
        folder = Path(request.get('folder') or str(home / ('Pictures' if request.get('kind') == 'photo' else 'Music'))).expanduser()
        if not folder.exists() and not request.get('folder'):
            folder = home
        if not folder.is_absolute() or not folder.is_dir():
            return {'error': 'Choose an accessible local folder'}
        folder = folder.resolve()
        extensions = ('.png', '.jpg', '.jpeg', '.webp') if request.get('kind') == 'photo' else ('.mp3',)
        try:
            entries = [{'name': p.name, 'path': str(p), 'directory': p.is_dir()} for p in folder.iterdir()
                       if not p.name.startswith('.') and (p.is_dir() or p.suffix.lower() in extensions)]
            entries.sort(key=lambda entry: (not entry['directory'], entry['name'].casefold()))
            return {'picker': {'folder': str(folder), 'parent': str(folder.parent), 'title': 'Home' if folder == home else folder.name or 'Files', 'entries': entries[:500]}, 'error': ''}
        except OSError:
            return {'error': 'This folder cannot be opened'}
    error, notice = '', ''
    cellular = {'available': False, 'label': 'Cellular service unavailable', 'calls': [], 'messages': [], 'sims': [], 'modems': []}
    try:
        if action == 'save-contact':
            store.contact(request)
        elif action == 'delete-contact':
            store.data['contacts'] = [c for c in store.data['contacts'] if c['id'] != request.get('id')]
            store.save()
        elif action == 'set-sound':
            if request.get('kind') not in ('ringtone', 'message', 'alarm') or request.get('tone') not in [t['id'] for t in store.tones()] + ['silent']:
                raise ValueError('Choose a listed tone')
            store.data['sounds'][request['kind']] = request['tone']
            store.save()
        elif action == 'import-tone':
            source = local_file(request.get('file', ''))
            if source.suffix.lower() != '.mp3' or source.stat().st_size == 0:
                raise ValueError('Choose an MP3 ringtone')
            probe = subprocess.run(['ffprobe', '-v', 'error', '-protocol_whitelist', 'file,pipe',
                                    '-show_entries', 'format=format_name', '-of', 'json', str(source)],
                                   capture_output=True, text=True, timeout=8, check=True)
            if json.loads(probe.stdout).get('format', {}).get('format_name') != 'mp3':
                raise ValueError('Choose a valid MP3 audio file')
            directory = store.directory / 'ringtones'
            directory.mkdir(exist_ok=True, mode=0o700)
            target = directory / ('Custom-' + hashlib.sha256(source.read_bytes()).hexdigest()[:12] + '.mp3')
            if not target.exists():
                with target.open('xb') as out:
                    target.chmod(0o600)
                    out.write(source.read_bytes())
        elif action not in ('status', 'esim-list', 'esim-enable', 'esim-disable', 'dial', 'answer', 'hangup', 'dtmf', 'send-sms', 'unlock-sim', 'select-slot', 'modem-power'):
            raise ValueError('Unknown action')
        if action.startswith('esim-'):
            profiles = esim_profiles()
            if action != 'esim-list':
                identifier = str(request.get('profile', ''))
                if not request.get('confirmed') or not re.fullmatch(r'[0-9]{10,24}', identifier) or not any(p['id'] == identifier for p in profiles['profiles']):
                    raise ValueError('Confirm a currently listed eSIM profile')
                result = subprocess.run(['lpac', 'profile', 'enable' if action == 'esim-enable' else 'disable', identifier], capture_output=True, text=True, timeout=30, check=True)
                replies = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
                if not any(r.get('type') == 'lpa' and r.get('payload', {}).get('code') == 0 for r in replies):
                    raise ValueError('The eSIM operation was not confirmed by the reader')
                profiles = esim_profiles()
            return {'esim': profiles, 'error': '', 'notice': ''}
    except (ValueError, OSError, ImportError, subprocess.SubprocessError):
        error = 'Could not complete this action. Check the input, device and permissions.'
    try:
        modem = backend_factory()
        cellular = modem.snapshot(request.get('modem', ''))
        if action in ('dial', 'answer', 'hangup', 'dtmf', 'send-sms', 'unlock-sim', 'select-slot', 'modem-power') and not error:
            if action in ('select-slot', 'modem-power') and not request.get('confirmed'):
                raise ValueError('Confirm this SIM change first')
            modem.act(request, cellular)
            notice = 'Sent to network' if action == 'send-sms' else 'Request accepted'
            cellular = modem.snapshot(request.get('modem', ''))
        previous = json.dumps(store.data, sort_keys=True)
        known = {m['id'] for m in store.data['messages']}
        for message in cellular.get('messages', []):
            if message['id'] not in known:
                store.data['messages'].append(message)
                known.add(message['id'])
        for call in cellular.get('calls', []):
            key = cellular.get('id', '') + call['id']
            old = next((c for c in store.data['history'] if c.get('source') == key), None)
            if old and not (old['state'] == 7 and call['state'] != 7):
                old.update(state=call['state'])
            else:
                store.data['history'].insert(0, dict(call, id=str(uuid.uuid4()), source=key, timestamp=time.strftime('%Y-%m-%d %H:%M')))
        if json.dumps(store.data, sort_keys=True) != previous:
            store.save()
    except Exception:
        if action in ('dial', 'answer', 'hangup', 'dtmf', 'send-sms', 'unlock-sim', 'select-slot', 'modem-power'):
            error = 'Cellular action failed. Check SIM service, support and authorization before retrying.'
    return dict(store.data, cellular=cellular, tones=store.tones(), playerAvailable=bool(shutil.which('ffplay')),
                error=error, notice=notice, esimManagerAvailable=bool(shutil.which('lpa-gtk')))


def main():
    os.umask(0o077)
    try:
        line = sys.stdin.readline(65537)
        if len(line) > 65536:
            raise ValueError('Request too large')
        request = json.loads(line)
        if not isinstance(request, dict):
            raise ValueError('Invalid request')
        result = handle(request, Store())
    except Exception:
        result = {'error': 'Communications data is unavailable. Check local storage permissions.'}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
