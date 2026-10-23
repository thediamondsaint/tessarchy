pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: control
    property color accentColor: Theme.accent
    property bool nightLight: false
    property bool available: false
    property bool active: false
    property bool initialized: false
    property string error: ""
    signal toggleRequested
    spacing: 6

    function applyPreference() {
        if (available && !applier.running) {
            applier.command = ["tessera-nightlight", nightLight ? "on" : "off"];
            applier.running = true;
        }
    }
    onNightLightChanged: { if (initialized) applyPreference(); }
    Process {
        id: probe
        command: ["tessera-nightlight", "status"]
        running: true
        onExited: (code, status) => {
            control.available = status === 0 && (code === 0 || code === 1);
            control.active = control.available && code === 0;
            if (!control.initialized) {
                control.initialized = true;
                control.applyPreference();
            }
        }
    }
    Process {
        id: applier
        onExited: (code, status) => {
            control.error = code === 0 && status === 0 ? "" : "Could not change night light";
            probe.running = true;
        }
    }
    TouchButton {
        visible: control.available
        Layout.fillWidth: true
        enabled: !applier.running && !probe.running
        text: control.active ? "Night light on" : "Night light"
        selected: control.active
        accentColor: control.accentColor
        Accessible.name: control.nightLight ? "Turn night light off" : "Turn night light on"
        onClicked: control.toggleRequested()
    }
    Text {
        visible: control.available && !!control.error
        Layout.fillWidth: true
        text: control.error; color: Theme.errorText; wrapMode: Text.WordWrap
    }
}
