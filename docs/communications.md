# Phone, messages and sound

Phone and Messages live on the bottom dock and in the launcher. They use the
same Quiet Edge glass controls as the rest of Tessera. Desktop keeps a centered
760-pixel panel; Messages adds a conversation column when space permits. Narrow
screens wrap the dock when its controls would otherwise lose their touch size.

## Phone and contacts

The keypad places calls through ModemManager's Voice interface. Incoming calls
open Phone and play the selected ringtone. Answer, hang up and in-call keypad
signals operate on the currently reported call object. Recents records observed
calls. The call button is enabled only when voice service is ready.

Contacts supports search, creation, editing, confirmed deletion, phone numbers
and local photos. Choose a photo through Tessera's glass file browser. PNG,
JPEG and WebP images are decoded into private PNG copies up to 256 pixels.
Contact shortcuts open the keypad or an SMS conversation.

## Messages

Messages reads received SMS and sends through ModemManager. It groups messages
by number and displays contact names where available. Message content is plain
text. A failed send retains the composer; successful sending is labelled
“Sent to network”, rather than claiming delivery to the recipient. MMS/RCS and
network delivery reports are separate future work.

## Sounds

Open **Settings → Sounds & ringtones**. Choose an incoming-call tone, message
alert and alarm sound, preview it, stop preview playback or import another MP3.
The five supplied VoidRing tracks are bundled as optimized 96 kbps copies;
the original supplied files remain unchanged. Silent is available for each type.
Message alerts play a short excerpt; incoming calls loop until answered or ended.
The alarm selection is stored for alarm apps; this change does not add a scheduler.

The file browser stays inside the glass panel, avoiding native dialogs hidden
behind the layer-shell window. Selection rows are at least 48 pixels high.

## Mobile data

SIM & cellular now includes NetworkManager data profiles, APN/authentication,
operator selection, roaming controls and saved-profile connect/disconnect/forget.
The selected modem is shared with SIM/call/message controls. Modem registration
and data connectivity have separate reported states; indicators use recent modem
signal independently of the message/contact worker. See [networking.md](networking.md)
for controls, dependencies and remaining device acceptance.

## SIM and eSIM

Open **Settings → SIM & cellular**, or choose **SIM & cellular** in the pull-down.
ModemManager supplies the modem list, SIM slots, active SIM, operator, SIM type,
masked ICCID suffix, signal quality and lock state. Options include confirmed
modem power changes, confirmed active-slot changes and SIM PIN entry. PINs travel
on standard input and D-Bus; they are not saved or passed in command arguments.

**Detect eSIM profiles** uses `lpac` with the device's configured eUICC reader.
Listed profiles can be enabled or disabled after confirmation. **Add or manage
eSIM profiles** opens `lpa-gtk` when installed, including carrier enrollment.
Profile deletion is not exposed by Tessera.

## Runtime and storage

- Required application tools: Python, Python GObject/Gio and FFmpeg.
- Cellular service: ModemManager, a supported modem and the device's normal D-Bus/PolicyKit authorization.
- eSIM management: `lpac`, a configured reader/backend, and optionally `lpa-gtk` for enrollment.
- User data: `$XDG_DATA_HOME/tessera/communications`, defaulting to `~/.local/share/tessera/communications`.

Contacts, observed messages/calls, photos and sound preferences are local user
data, separate from the development installation. The directory is private;
data and avatar files use mode 0600. Updates use an exclusive lock and atomic
replacement. External tools receive argument arrays; message text and SIM PINs
use typed D-Bus values. Ringtone playback opens only local file/pipe protocols.
The helper never escalates privileges.

## Validation

The VM exercises contacts/photos, input, file selection, sound persistence,
preview start/stop, adaptive rendering and unavailable cellular controls.
Fixtures exercise ModemManager inventory, eSIM identification, typed actions,
failed sending and SMS deduplication. Hardware calls, audio routing, SMS delivery,
SIM hotplug/unlock and eUICC profile changes remain device acceptance tests.
See [testing.md](testing.md) for actual results.

## API references

- [ModemManager Voice](https://www.freedesktop.org/software/ModemManager/doc/latest/ModemManager/gdbus-org.freedesktop.ModemManager1.Modem.Voice.html)
- [ModemManager Call](https://www.freedesktop.org/software/ModemManager/doc/latest/ModemManager/gdbus-org.freedesktop.ModemManager1.Call.html)
- [ModemManager Messaging](https://www.freedesktop.org/software/ModemManager/doc/latest/ModemManager/gdbus-org.freedesktop.ModemManager1.Modem.Messaging.html)
- [ModemManager SIM interface](https://github.com/linux-mobile-broadband/ModemManager/blob/main/introspection/org.freedesktop.ModemManager1.Sim.xml)
- [lpac usage](https://github.com/estkme-group/lpac/blob/main/docs/USAGE.md)
