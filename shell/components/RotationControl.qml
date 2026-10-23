pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

ColumnLayout {
    id: control
    property color accentColor: Theme.accent

    readonly property var monitor: Hyprland.focusedMonitor
    // `Item.transform` is FINAL in Qt Quick; this property must not be named transform.
    readonly property int currentTransform: {
        if (!control.monitor || !control.monitor.lastIpcObject)
            return 0;
        const value = control.monitor.lastIpcObject.transform;
        return Number.isInteger(value) && value >= 0 && value < 4 ? value : 0;
    }
    readonly property string orientation: ["0°", "90°", "180°", "270°"][control.currentTransform]

    spacing: 6

    function send(action) {
        if (!control.monitor)
            return;
        // Fixed argv: the monitor name comes from the compositor, the action is a literal.
        Quickshell.execDetached(["tessera-rotate", action, control.monitor.name]);
        refreshTimer.restart();
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: Hyprland.refreshMonitors()
    }

    Text {
        text: "Screen orientation · " + (control.monitor ? control.orientation : "no monitor")
        color: Theme.textSecondary
        font.pixelSize: 14
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        TouchButton {
            text: "Rotate"
            enabled: control.monitor !== null
            accentColor: control.accentColor
            Layout.fillWidth: true
            Accessible.name: control.monitor ? "Rotate screen, now " + control.orientation : "Rotate screen unavailable"
            onClicked: control.send("cycle")
        }
        TouchButton {
            text: "Reset"
            enabled: control.monitor !== null && control.currentTransform !== 0
            accentColor: control.accentColor
            Layout.fillWidth: true
            Accessible.name: "Reset screen rotation"
            onClicked: control.send("reset")
        }
    }
}
