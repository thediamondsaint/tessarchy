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
    property real pending: 0
    readonly property bool dragging: dragArea.pressed
    signal started()
    signal canceled()
    signal moved(int delta)
    signal stepped(string direction)
    signal settled()
    signal leaveRequested()
    implicitWidth: Math.min(maxControlWidth, radialOpen ? 280 : expanded ? (tessaCube ? 384 : 336) : (tessaCube ? 56 : 128))
    implicitHeight: radialOpen ? 280 : expanded ? 112 : 56

    function cancel() {
        radialOpen = false;
        pending = 0;
        frame.stop();
        expanded = false;
        idle.stop();
        canceled();
    }
    function flush() {
        const delta = Math.round(pending);
        pending -= delta;
        if (delta !== 0) moved(delta);
    }
    onVisibleChanged: if (!visible) cancel()
    onCanPanChanged: if (!canPan) cancel()
    onExpandedChanged: if (expanded) idle.restart()
    Timer {
        id: idle
        interval: control.hideDelay
        onTriggered: {
            if (control.dragging || previous.down || next.down || leave.down || control.activeFocus) restart();
            else { control.expanded = false; control.radialOpen = false; }
        }
    }
    Timer {
        id: frame
        interval: 16
        repeat: true
        onTriggered: control.flush()
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
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            height: 48
            visible: control.expanded && !control.radialOpen
            radius: Theme.radius("button", 12, height)
            color: Theme.glassStrong
            Text { anchors.centerIn: parent; text: control.dragging ? "‹  Moving windows  ›" : "‹  Slide windows  ›"; color: Theme.accent; font.pixelSize: 14 }
            MouseArea {
                id: dragArea
                objectName: "tapeDrag"
                anchors.fill: parent
                preventStealing: true
                enabled: control.canPan
                property real lastX: 0
                Accessible.name: "Drag to move window tape"
                onPressed: mouse => {
                    lastX = mouse.x;
                    control.started();
                    control.pending = 0;
                    frame.start();
                }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    control.pending += mouse.x - lastX;
                    lastX = mouse.x;
                }
                onReleased: {
                    frame.stop();
                    control.flush();
                    control.pending = 0;
                    control.settled();
                    idle.restart();
                }
                onCanceled: control.cancel()
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
