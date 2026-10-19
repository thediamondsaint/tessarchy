# Wi-Fi and cellular networking

Open quick controls and choose Wi-Fi networks, or tap the Wi-Fi status icon.
SIM & cellular opens mobile-data setup alongside the existing SIM, call and
message controls. All connection operations use the normal active user's
NetworkManager/ModemManager authorization; the shell does not run sudo or change
network-manager ownership.

## Wi-Fi

Select an adapter when more than one is present. Scan requests a fresh scan on
that adapter; ordinary status polling does not start scans or own a persistent
scanner. Results show their actual reported signal, security and connected state.
Duplicate access points are grouped by raw SSID and security, preferring the
connected point and then the strongest point. Names are rendered literally.

Open and enhanced-open networks connect directly. WPA/WPA2 Personal, WPA3 Personal
and WEP networks accept a password/key in the shell. Hidden networks have their
own name and security selection. Remember connection saves the profile through
NetworkManager; otherwise it is volatile. Connect automatically is a separate
choice. Cancel/hide clears password fields without sending a request. The status
panel accepts keyboard focus only while its network input form is open.

Saved connections can be activated or forgotten after confirmation; disconnect
an active profile before forgetting it. Disconnect also cancels a pending
activation. Adapter disappearance and stale access-point/profile IDs are checked
again before every action. Failed activation is not reported as connected.

Enterprise networks reuse saved NetworkManager profiles and its credentials
agent. Advanced Wi-Fi settings opens Connections for enterprise identity,
certificates, static IP/DNS and editing existing profiles. Native enterprise
certificate enrollment is not implemented in Tessera. A captive portal is marked
as requiring sign-in; open the browser to complete the network's login.

Hotspot creates a WPA2 shared-IPv4 profile on an AP-capable adapter; dnsmasq is
included in the tablet/ISO profile for connection sharing. Starting it replaces
that adapter's current Wi-Fi connection. Hotspot autoconnect defaults off. The
AP badge reports actual adapter mode; it does not invent a received signal level
for a device acting as an access point.

## Mobile data

Choose the modem, activate a saved data profile, or select Set up mobile data.
Leave APN blank for provider defaults, or enter the APN, optional username and
password, and optional five/six-digit operator code. New profiles are metered,
roaming is disabled by default and autoconnect defaults off. When the modem
supplies a stable device identifier the new profile is bound to that device.
A pending data activation can be cancelled, and saved profiles can be forgotten
after confirmation and disconnection. CDMA and other advanced configurations use
Connections; existing compatible profiles can still be activated in Tessera.

Modem registration and mobile-data connectivity are distinct. Operator, roaming,
2G/EDGE/3G/H/H+/4G/5G labels and recent signal quality come from ModemManager;
NetworkManager supplies data connection/IP state. A registered modem can show
signal while its data connection is disconnected. Stale/unknown measurements
remain unavailable; a valid zero-percent reading remains zero. Switching the
selected modem synchronizes data and SIM/call/message controls.

The existing SIM PIN, SIM-slot, eSIM, voice and SMS operations remain in the
communications backend. SMS/call/SIM properties already returned by its managed
object inventory are reused rather than issuing a synchronous request per message.
The network indicators run independently of contacts and message history.

## Indicators, radio power and recovery

Wi-Fi signal comes from the connected access point's Strength property, not the
loudest nearby network. Cellular uses the selected modem's recent SignalQuality.
Values remain integer percentages throughout the shell; no placeholder or
fraction-to-integer rounding supplies a connection state. The five bar levels
are a presentation of those measured percentages. Off, hardware-blocked,
searching, connecting, registered, failed and unavailable states are separate.
The Wi-Fi badge marks portal/limited/no-internet reports from the adapter's IP
connectivity state; association alone is not an internet-success claim.

Airplane mode requests Wi-Fi/WWAN off, disables detected modems and blocks kernel
radios. It refuses an action when kernel radio state/permission cannot be checked.
Its on-state requires both NetworkManager radio flags off, detected modems
disabled and all reported kernel radios blocked. Turning it off requests all
radios on; previous per-radio choices are not restored. Bluetooth's existing
rfkill and paired-device controls remain separate.

The helper reads requests on standard input and uses typed Gio D-Bus calls.
Passwords are never command arguments, helper output or Tessera preferences.
NetworkManager owns saved secrets according to its profile/agent policy. The
helper validates current device/profile membership before mutations and has a
shared D-Bus deadline; the UI also bounds actions and discards stale status
responses after actions. Missing services produce unavailable states and are
retried. Polling is faster while connection controls are visible or connecting;
otherwise it backs off to ten seconds, or thirty when no devices exist.

## Dependencies and API evidence

The shell package declares NetworkManager, the applet/editor and dnsmasq as
optional capabilities. The tablet/ISO profile includes them, ModemManager and
mobile-broadband-provider-info. The session starts its available PolicyKit and
NetworkManager credentials agents. NetworkManager remains the single network
manager; do not replace an existing manager remotely during acceptance.

- [NetworkManager connection methods and radio properties](https://networkmanager.dev/docs/api/latest/gdbus-org.freedesktop.NetworkManager.html)
- [Wireless device and scan API](https://networkmanager.dev/docs/api/latest/gdbus-org.freedesktop.NetworkManager.Device.Wireless.html)
- [Access-point flags and device states](https://networkmanager.dev/docs/api/latest/nm-dbus-types.html)
- [Mobile-broadband profile settings](https://networkmanager.dev/docs/api/latest/settings-gsm.html)
- [ModemManager access technologies and states](https://www.freedesktop.org/software/ModemManager/doc/latest/ModemManager/ModemManager-Flags-and-Enumerations.html)

Implementation was checked against installed NetworkManager D-Bus XML, libnm
headers/GObject metadata and ModemManager enum headers. New connection settings
are validated in tests by libnm, including each supported personal security
mode, hotspot sharing and a GSM/APN profile. This work does not alter the tested
Quickshell or Hyprland API baseline.

## Acceptance still required

No VM was opened for this change. Automated fixtures and private D-Bus services
exercise the real helper and typed requests without changing host connections.
They do not establish RF association, routing or carrier/device compatibility.

On a prepared guest, check layout, focus, OSK, scroll, missing-service behavior,
service restarts and real NetworkManager networking. A default QEMU wired NIC
does not expose a Wi-Fi adapter or cellular modem. Real association and signal,
hotspot DHCP/NAT, modem data, calls/SMS, audio routing and carrier behavior need
compatible physical hardware or explicitly provided device passthrough. Record
source revision, package versions and the actual devices with each result.

See docs/testing.md for executed checks and the readiness checklist.
