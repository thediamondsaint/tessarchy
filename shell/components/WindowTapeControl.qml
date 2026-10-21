pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: control
    property bool expanded: false
    property bool canPan: true
    property int hideDelay: 8000
    property bool reducedMotion: false
    property bool radialOpen: false
    property Component recentsComponent
    readonly property var recentView: recents.item
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
    implicitWidth: Math.min(maxControlWidth, radialOpen ? 280 : expanded ? (tessaCube ? 560 : 336) : (tessaCube ? 56 : 128))
    implicitHeight: radialOpen ? 280 : expanded && tessaCube ? 300 : 56

    function cancel() {
        radialOpen = false;
        expanded = false;
        idle.stop();
        canceled();
    }
    onVisibleChanged: if (!visible) cancel()
    onCanPanChanged: if (!canPan) cancel()
    onExpandedChanged: if (expanded) { if (recentView) recentView.selectActive(); idle.restart(); }
    Timer {
        id: idle
        interval: control.hideDelay
        onTriggered: {
            if (previous.down || next.down || leave.down || (control.recentView && control.recentView.interacting) || control.activeFocus) restart();
            else { control.expanded = false; control.radialOpen = false; }
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius("card", control.radialOpen ? height / 2 : 20, height)
        color: Qt.alpha(Theme.background, 0.96)
        border.color: Qt.alpha(Theme.wheelGlow, 0.65)
        border.width: Theme.borderWidth(1)
    }
    TouchButton {
        id: cubeButton
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
        background: Rectangle {
            radius: Theme.radius("card", 20, height)
            color: cubeButton.down ? Theme.pressed(Theme.wheelGlow) : Theme.glassStrong
            border.color: Theme.wheelGlow
            border.width: Theme.borderWidth(1)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: Theme.radius("card", 17, height)
                color: "transparent"
                border.color: Qt.alpha(Theme.wheelGlow, 0.20)
                border.width: Theme.borderWidth(1)
            }
        }
        Accessible.name: control.tessaCube ? "Open recent apps and Tessa controls" : "Window tape"
        onClicked: control.expanded = true
    }
    RowLayout {
        visible: control.tessaCube && control.expanded && !control.radialOpen
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 4 }
        height: 48
        BrandMark {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            playOnStart: false
            reducedMotion: control.reducedMotion
            enabled: false
        }
        Text {
            text: "Recent apps"
            color: Theme.text
            font.pixelSize: 18
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
        TouchButton {
            objectName: "collapseCube"
            text: "⌄"
            Accessible.name: "Collapse recent apps"
            Layout.preferredWidth: 48
            Layout.fillHeight: true
            onClicked: control.cancel()
        }
    }
    Loader {
        id: recents
        objectName: "cubeRecents"
        active: control.tessaCube
        visible: control.expanded && !control.radialOpen
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 48; leftMargin: 12; rightMargin: 12 }
        height: Math.max(188, control.height - 112)
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: control.reducedMotion ? 0 : 160 } }
        Behavior on scale { NumberAnimation { duration: control.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        sourceComponent: control.recentsComponent
    }
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
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
