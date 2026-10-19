"""Private storage and cellular action tests with an isolated modem service."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('communications', ROOT / 'shell/helpers/communications.py')
comm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(comm)


class FakeModem:
    events = []
    messages = []

    def snapshot(self, selected=''):
        return {'available': True, 'id': '/modem/0', 'label': 'Test network', 'registered': True,
                'voice': True, 'sms': True, 'calls': [], 'messages': self.messages, 'sims': [], 'modems': []}

    def act(self, request, state):
        self.events.append(request)
        if request['action'] == 'send-sms':
            raise PermissionError('Synthetic authorization failure')


class Communications(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.store = comm.Store(Path(self.temporary.name) / 'private')
        FakeModem.events, FakeModem.messages = [], []

    def tearDown(self):
        self.store.lock.close()
        self.temporary.cleanup()

    def request(self, **values):
        return comm.handle(values, self.store, FakeModem)

    def test_contacts_save_edit_delete_and_reopen(self):
        result = self.request(action='save-contact', name='Example Contact', number='+1 (202) 555-0123')
        contact = result['contacts'][0]
        self.assertEqual(contact['number'], '+12025550123')
        self.request(action='save-contact', id=contact['id'], name='Updated Name', number='+12025550123')
        self.assertEqual(json.loads(self.store.path.read_text())['contacts'][0]['name'], 'Updated Name')
        self.assertEqual(self.store.path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.store.directory.stat().st_mode & 0o777, 0o700)
        self.assertFalse(self.request(action='delete-contact', id=contact['id'])['contacts'])

    def test_malformed_numbers_and_remote_photos_are_rejected(self):
        for phone in ('', '--help', '+1; command', '123\n456', '*123#'):
            with self.assertRaises(ValueError):
                comm.number(phone)
        for uri in ('https://example.invalid/photo.png', 'file://remote/private/photo.png'):
            with self.assertRaises(ValueError):
                comm.local_file(uri)
        self.assertTrue(self.request(action='save-contact', name='Example', number='bad')['error'])
        self.assertEqual(self.store.data['contacts'], [])

    def test_unknown_actions_and_unconfirmed_sim_switch_do_not_reach_modem(self):
        self.assertTrue(self.request(action='execute-shell')['error'])
        self.assertTrue(self.request(action='select-slot', modem='/modem/0', slot=2)['error'])
        self.assertEqual(FakeModem.events, [])

    def test_failed_sms_never_creates_successful_local_message(self):
        result = self.request(action='send-sms', modem='/modem/0', number='+12025550123', text='Synthetic test')
        self.assertTrue(result['error'])
        self.assertEqual(result['messages'], [])
        self.assertEqual(result['notice'], '')

    def test_repeated_received_sms_is_stored_once(self):
        FakeModem.messages = [{'id': 'sms-test', 'number': '+12025550123', 'text': '<b>Plain text</b>', 'incoming': True}]
        self.request(action='status')
        result = self.request(action='status')
        self.assertEqual(len(result['messages']), 1)
        self.assertEqual(result['messages'][0]['text'], '<b>Plain text</b>')

    def test_sounds_persist_and_unknown_tone_is_rejected(self):
        tone = self.store.tones()[0]['id']
        self.request(action='set-sound', kind='ringtone', tone=tone)
        self.assertEqual(json.loads(self.store.path.read_text())['sounds']['ringtone'], tone)
        self.assertTrue(self.request(action='set-sound', kind='ringtone', tone='../../other')['error'])
        self.assertEqual(self.request(action='set-sound', kind='message', tone='silent')['sounds']['message'], 'silent')

    def test_missing_modem_service_keeps_contacts_and_sounds_available(self):
        with patch.object(comm, 'Modems', side_effect=ImportError):
            result = comm.handle({'action': 'status'}, self.store, comm.Modems)
        self.assertFalse(result['cellular']['available'])
        self.assertEqual(len(result['tones']), 5)
        self.assertFalse(result['error'])

    def test_file_browser_filters_types_and_never_mutates_contacts(self):
        directory = Path(self.temporary.name) / 'photos'
        directory.mkdir()
        for name in ('photo.png', 'track.mp3', '.private.png', 'script.sh'):
            (directory / name).write_bytes(b'test')
        (directory / 'Album').mkdir()
        result = self.request(action='browse', folder=str(directory), kind='photo')
        self.assertEqual([p['name'] for p in result['picker']['entries']], ['Album', 'photo.png'])
        result = self.request(action='browse', folder=str(directory), kind='tone')
        self.assertEqual([p['name'] for p in result['picker']['entries']], ['Album', 'track.mp3'])
        self.assertEqual(self.store.data['contacts'], [])
        self.assertTrue(self.request(action='browse', folder='/nonexistent/tessarchy-test')['error'])

    def test_photo_is_copied_to_private_storage(self):
        if not shutil.which('ffmpeg'):
            self.skipTest('Image decoder is not installed')
        result = self.request(action='save-contact', name='Photo example', number='+12025550123',
                              photo=str(ROOT / 'assets/boot/phone-startup.png'))
        self.assertFalse(result['error'])
        photo = comm.local_file(result['contacts'][0]['photo'])
        self.assertEqual(photo.parent, self.store.directory / 'avatars')
        self.assertEqual(photo.stat().st_mode & 0o777, 0o600)
        self.assertTrue(photo.read_bytes().startswith(b'\x89PNG'))

    def test_modem_inventory_detects_esim_and_empty_slots_without_signal_fabrication(self):
        modem = comm.Modems.__new__(comm.Modems)
        path, sim = comm.ROOT + '/Modem/0', comm.ROOT + '/SIM/1'
        objects = {path: {
            comm.MM + '.Modem': {'Model': 'Fixture modem', 'State': 8, 'Sim': sim,
                                  'SimSlots': ['/', sim], 'SignalQuality': (0, False), 'UnlockRequired': 1},
            comm.MM + '.Modem.Voice': {'Calls': []}, comm.MM + '.Modem.Messaging': {'Messages': []}}}
        modem.call = lambda *args: (objects,)
        modem.props = lambda *args: {'SimType': 2, 'OperatorName': 'Fixture operator', 'SimIdentifier': '890000001234', 'Eid': '1234'}
        result = modem.snapshot()
        self.assertFalse(result['sims'][0]['present'])
        self.assertEqual(result['sims'][1]['type'], 'eSIM')
        self.assertTrue(result['sims'][1]['active'])
        self.assertEqual(result['signal'], -1)
        self.assertTrue(result['voice'])
        with self.assertRaises(ValueError):
            modem.act({'action': 'dial', 'modem': '/other/modem', 'number': '123'}, result)

    def test_managed_sms_inventory_does_not_block_calls_with_per_message_queries(self):
        modem = comm.Modems.__new__(comm.Modems)
        path = comm.ROOT + '/Modem/0'
        messages = ['/sms/' + str(i) for i in range(100)]
        objects = {path: {comm.MM + '.Modem': {'State': 8, 'Sim': '/'},
                          comm.MM + '.Modem.Messaging': {'Messages': messages}}}
        for message in messages:
            objects[message] = {comm.MM + '.Sms': {'State': 3, 'Number': '+12025550123', 'Text': 'Synthetic'}}
        requests = []
        modem.call = lambda *args: requests.append(args) or (objects,)
        def unexpected(*args):
            self.fail('Redundant per-message D-Bus query')
        modem.props = unexpected
        result = modem.snapshot()
        self.assertEqual(len(result['messages']), 100)
        self.assertEqual(len(requests), 1)

    def test_sim_pin_and_sms_use_typed_dbus_calls_without_subprocess(self):
        try:
            from gi.repository import GLib
        except ImportError:
            self.skipTest('GObject metadata not installed')
        modem = comm.Modems.__new__(comm.Modems)
        modem.GLib = GLib
        calls = []
        modem.call = lambda *args: calls.append(args) or ('/sms/0',)
        state = {'available': True, 'id': '/modem/0', 'registered': True, 'sms': True,
                 'locked': 2, 'sims': [{'active': True, 'id': '/sim/0'}]}
        modem.act({'action': 'unlock-sim', 'modem': '/modem/0', 'pin': '5678'}, state)
        self.assertEqual(calls[-1], ('/sim/0', comm.MM + '.Sim', 'SendPin', '(s)', ('5678',)))
        modem.act({'action': 'send-sms', 'modem': '/modem/0', 'number': '+12025550123', 'text': "Quotes ' and , stay intact"}, state)
        self.assertEqual(calls[-2][2], 'Create')
        self.assertEqual(calls[-2][-1][0]['text'].unpack(), "Quotes ' and , stay intact")
        self.assertEqual(calls[-1][2], 'Send')


if __name__ == '__main__':
    unittest.main()
