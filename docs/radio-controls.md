# Pull-down radio controls

Pull down from the 48px status bar, or tap its clock/volume button, to open the
glass quick-controls sheet. Swipe up on the bar or bottom handle, or tap the
handle/clock, to collapse it. Opening controls dismisses the bottom sheet and
preserves the application's keyboard focus.

The status clock uses compact semibold digits without a leading hour zero or
AM/PM suffix. It follows the saved 12/24-hour choice; its accessible name and
the expanded clock retain AM/PM when appropriate.

The layout selector is in this sheet rather than on the home screen or status
bar. Choose Auto, Phone, Tablet, or Desktop; the active layout is shown above
the buttons. Manual choices persist, and Auto resumes size-based detection.
The same preferences remain available in Settings.

## What the switches control

Wi-Fi and cellular quick controls now use NetworkManager and ModemManager.
Tap a status icon to open the relevant connections. The Wi-Fi list supports
scanning, saved/personal/hidden networks and hotspots; SIM & cellular includes
mobile-data profiles and APN/roaming controls. Signal icons display reported
percentages and separate connection, disabled, blocked and unavailable states.
See [networking.md](networking.md) for the implementation and acceptance limits.

Bluetooth's existing power switch still uses the rfkill helper; device discovery
and paired connections use BlueZ. Airplane mode coordinates NetworkManager,
detected modems and kernel switches, reads back actual state, and reports errors
when it cannot verify or control a radio. It does not restore previous individual
radio selections when turned off.

Controls do not change network-manager ownership, install dependencies or run
sudo. NetworkManager/ModemManager operations use the session's standard PolicyKit
and credentials agents. A physical switch remains effective. New connections
are not labelled successful until their backend reports the connected state.

Automated tests use private D-Bus services and synthetic devices. No VM was
opened for the networking implementation; real adapter, modem and carrier
acceptance remains to be recorded in docs/testing.md.
