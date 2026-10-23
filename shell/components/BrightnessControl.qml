pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: control
    property color accentColor: Theme.accent
    // Probe on startup and when quick controls open; no background polling.
    property bool probed: false
    property int probePercent: -1
    property real level: 0.5

    readonly property bool available: probed && probePercent >= 0

    property string error: ""
    property int pendingPercent: -1
    onVisibleChanged: { if (visible && !write.running) probe.running = true; }

    function setLevel(next) {
        level = Math.max(0.01, Math.min(1, next));
        slider.value = level;
        settle.restart();
    }

    spacing: 6

    Process {
        id: probe
        command: ["tessera-brightness", "get"]
        running: true
        stdout: StdioCollector { id: probeOutput }
        onExited: (code, status) => {
            control.probed = true;
            const value = Number(probeOutput.text.trim());
            if (code === 0 && status === 0 && probeOutput.text.trim() !== "" && Number.isInteger(value) && value >= 0 && value <= 100) {
                control.probePercent = value;
                control.level = value / 100;
                slider.value = control.level;
            }
        }
    }
    Process {
        id: write
        onExited: (code, status) => {
            control.error = code === 0 && status === 0 ? "" : "Could not change brightness";
            if (control.pendingPercent >= 0) settle.restart();
            else probe.running = true;
        }
    }
    // Rapid changes coalesce into one helper call per quiet period.
    Timer {
        id: settle
        interval: 150
        onTriggered: {
            const percent = Math.max(1, Math.min(100, Math.round(control.level * 100)));
            control.pendingPercent = percent;
            if (!write.running) {
                control.pendingPercent = -1;
                write.command = ["tessera-brightness", "set", String(percent)];
                write.running = true;
            }
        }
    }

    Text {
        visible: control.available && !!control.error
        Layout.fillWidth: true
        text: control.error; color: Theme.errorText; wrapMode: Text.WordWrap
    }
    Text {
        visible: control.available
        text: "Brightness · " + Math.round(control.level * 100) + "%"
        color: Theme.text
        Layout.fillWidth: true
        wrapMode: Text.WrapAnywhere
    }
    LevelSlider {
        id: slider
        visible: control.available
        Layout.fillWidth: true
        from: 0.01
        to: 1
        value: control.level
        accentColor: control.accentColor
        Accessible.name: "Screen brightness"
        onMoved: {
            control.level = value;
            settle.restart();
        }
        onPressedChanged: {
            if (!pressed)
                settle.restart();
        }
    }
    RowLayout {
        visible: control.available
        Layout.fillWidth: true
        TouchButton {
            text: "−"
            Accessible.name: "Decrease brightness"
            accentColor: control.accentColor
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            onClicked: control.setLevel(control.level - 0.1)
        }
        TouchButton {
            text: "Dim"
            Accessible.name: "Dim screen to 10 percent"
            accentColor: control.accentColor
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            onClicked: control.setLevel(0.1)
        }
        TouchButton {
            text: "Bright"
            Accessible.name: "Raise screen to full brightness"
            accentColor: control.accentColor
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            onClicked: control.setLevel(1)
        }
        TouchButton {
            text: "+"
            Accessible.name: "Increase brightness"
            accentColor: control.accentColor
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            onClicked: control.setLevel(control.level + 0.1)
        }
    }
}
