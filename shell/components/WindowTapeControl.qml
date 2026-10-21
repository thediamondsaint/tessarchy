pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: control
    property bool expanded: false
    property bool canPan: true
    property int hideDelay: 5000
    property bool reducedMotion: false
    property bool radialOpen: false
    signal actionRequested(string action)
    // Tessa's compact cube mode uses the existing native tape gestures.
    property bool tessaCube: true
    property int maxControlWidth: 10000
    signal launcherRequested()
    signal started()
    signal canceled()
    signal moved(int delta)
    signal stepped(string direction)
    signal settled()
    signal leaveRequested()
    implicitWidth: Math.min(maxControlWidth, radialOpen ? 280 : expanded ? (tessaCube ? 384 : 336) : (tessaCube ? 56 : 128))
    implicitHeight: radialOpen ? 280 : 56

    function cancel() {
        radialOpen = false;
        expanded = false;
        idle.stop();
        canceled();
    }
    onVisibleChanged: if (!visible) cancel()
    onCanPanChanged: if (!canPan) cancel()
    onExpandedChanged: if (expanded) idle.restart()
    Timer {
        id: idle
        interval: control.hideDelay
        onTriggered: {
            if (previous.down || next.down || leave.down || control.activeFocus) restart();
            else { control.expanded = false; control.radialOpen = false; }
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius("card", control.radialOpen ? height / 2 : 20, height)
        color: Theme.glassStrong
        border.color: Qt.alpha(Theme.accent, 0.65)
        border.width: Theme.borderWidth(1)
    }
    TouchButton {
        anchors.fill: parent
        visible: !control.expanded
        text: control.tessaCube ? "" : "Window tape"
        BrandMark {
            anchors.centerIn: parent
            width: 44; height: 44
            enabled: false
            playOnStart: false
            reducedMotion: control.reducedMotion
        }
        Accessible.name: control.tessaCube ? "Open Tessa window controls" : "Window tape"
        onClicked: control.expanded = true
    }
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 56
        spacing: 0
        visible: control.expanded && !control.radialOpen
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: control.reducedMotion ? 0 : 160 } }
        TouchButton {
            visible: control.tessaCube
            Layout.minimumWidth: 48
            text: "Apps"
            padding: 4
            Accessible.name: "Open Tessa launcher"
            Layout.preferredWidth: 56
            Layout.fillHeight: true
            onClicked: { control.launcherRequested(); control.expanded = false; }
        }
        TouchButton {
            id: previous
            text: "‹"
            Accessible.name: "Previous window"
            Layout.preferredWidth: 48
            Layout.fillHeight: true
            enabled: control.canPan
            onClicked: { control.stepped("previous"); idle.restart(); }
        }
        TouchButton {
            Layout.preferredWidth: 64
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: "Menu"
            Accessible.name: "Open radial actions"
            onClicked: { control.radialOpen = true; idle.restart(); }
        }
        TouchButton {
            id: next
            text: "›"
            Accessible.name: "Next window"
            Layout.preferredWidth: 48
            Layout.fillHeight: true
            enabled: control.canPan
            onClicked: { control.stepped("next"); idle.restart(); }
        }
        TouchButton {
            id: leave
            text: "×"
            Accessible.name: "Leave window tape"
            Layout.preferredWidth: 48
            Layout.fillHeight: true
            onClicked: control.leaveRequested()
        }
    }
    RadialActions {
        anchors.centerIn: parent
        visible: control.radialOpen
        width: Math.min(parent.width, 280)
        height: 280
        onTriggered: action => {
            control.radialOpen = false;
            control.expanded = false;
            control.actionRequested(action);
        }
        onDismissed: { control.radialOpen = false; idle.restart(); }
    }
}
