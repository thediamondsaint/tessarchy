pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: control
    property bool expanded: false
    property bool canPan: true
    property int hideDelay: 1500
    // Tessa's compact cube mode uses the existing native tape gestures.
    property bool tessaCube: true
    // Existing tape drag remains the transport; compact wheel is only another input surface.
    property bool edgeWheel: true
    signal launcherRequested()
    property real pending: 0
    readonly property bool dragging: dragArea.pressed
    signal started()
    signal canceled()
    signal moved(int delta)
    signal stepped(string direction)
    signal settled()
    signal leaveRequested()
    implicitWidth: expanded ? (tessaCube ? 384 : 336) : (tessaCube ? 56 : 128)
    implicitHeight: 48

    function cancel() {
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
            else control.expanded = false;
        }
    }
    Timer {
        id: frame
        interval: 16
        repeat: true
        onTriggered: control.flush()
    }
    TouchButton {
        anchors.fill: parent
        visible: !control.expanded
        text: control.tessaCube ? "◈" : "Window tape"
        Accessible.name: control.tessaCube ? "Open Tessa window controls" : "Window tape"
        onClicked: control.expanded = true
    }
    RowLayout {
        anchors.fill: parent
        spacing: 0
        visible: control.expanded
        TouchButton {
            visible: control.tessaCube
            text: "Apps"
            Accessible.name: "Open Tessa launcher"
            Layout.preferredWidth: 64
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
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radius("button", 12, height)
            color: Theme.glassStrong
            GestureHandle { anchors.centerIn: parent; implicitWidth: 72 }
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
}
