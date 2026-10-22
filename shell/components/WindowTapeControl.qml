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
    signal phoneRequested()
    signal messagesRequested()
    signal keyboardRequested()
    signal started()
    signal canceled()
    signal moved(int delta)
    signal stepped(string direction)
    signal settled()
    signal leaveRequested()
    implicitWidth: Math.min(maxControlWidth, radialOpen ? 280 : expanded ? (tessaCube ? 408 : 336) : (tessaCube ? 56 : 128))
    implicitHeight: radialOpen ? 280 : expanded && tessaCube ? 256 : 56

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
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.surface, Theme.mode === "light" ? 0.84 : 0.68) }
            GradientStop { position: 1; color: Qt.alpha(Theme.background, Theme.mode === "light" ? 0.76 : 0.52) }
        }
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
        Item { Layout.fillWidth: true }
        GlassIconButton {
            objectName: "collapseCube"
            symbol: "close"
            reducedMotion: control.reducedMotion
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
        height: Math.max(104, control.height - 104)
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: control.reducedMotion ? 0 : 160 } }
        Behavior on scale { NumberAnimation { duration: control.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        sourceComponent: control.recentsComponent
    }
    GridLayout {
        id: cubeActions
        objectName: "cubeActions"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Math.min(parent.width - 24, 344)
        height: control.tessaCube ? 104 : 56
        columns: control.tessaCube ? 4 : 5
        columnSpacing: 8
        rowSpacing: 8
        visible: control.expanded && !control.radialOpen
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: control.reducedMotion ? 0 : 160 } }
        GlassIconButton {
            symbol: "dialpad"
            reducedMotion: control.reducedMotion
            visible: control.tessaCube
            Layout.minimumWidth: 48
            text: "Apps"
            padding: 4
            Accessible.name: "Open Tessa launcher"
            Layout.preferredWidth: 48
            Layout.fillWidth: true
            Layout.fillHeight: true
            onClicked: { control.launcherRequested(); control.expanded = false; }
        }
        GlassIconButton {
            symbol: "back"
            reducedMotion: control.reducedMotion
            id: previous
            text: "‹"
            Accessible.name: "Previous window"
            Layout.preferredWidth: 48
            Layout.fillWidth: true
            Layout.fillHeight: true
            enabled: control.canPan
            onClicked: { control.stepped("previous"); idle.restart(); }
        }
        GlassIconButton {
            symbol: "controls"
            reducedMotion: control.reducedMotion
            Layout.preferredWidth: 64
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: "Menu"
            Accessible.name: "Open radial actions"
            onClicked: { control.radialOpen = true; idle.restart(); }
        }
        GlassIconButton {
            symbol: "return"
            reducedMotion: control.reducedMotion
            id: next
            text: "›"
            Accessible.name: "Next window"
            Layout.preferredWidth: 48
            Layout.fillWidth: true
            Layout.fillHeight: true
            enabled: control.canPan
            onClicked: { control.stepped("next"); idle.restart(); }
        }
        GlassIconButton {
            objectName: "cubePhone"
            symbol: "call"
            reducedMotion: control.reducedMotion
            visible: control.tessaCube
            text: "Phone"
            Accessible.name: "Open Phone"
            Layout.preferredWidth: 48
            Layout.fillWidth: true
            Layout.fillHeight: true
            onClicked: { control.phoneRequested(); control.expanded = false; }
        }
        GlassIconButton {
            objectName: "cubeMessages"
            symbol: "messages"
            reducedMotion: control.reducedMotion
            visible: control.tessaCube
            text: "Messages"
            Accessible.name: "Open Messages"
            Layout.preferredWidth: 48
            Layout.fillWidth: true
            Layout.fillHeight: true
            onClicked: { control.messagesRequested(); control.expanded = false; }
        }
        GlassIconButton {
            objectName: "cubeKeyboard"
            symbol: "keyboard"
            reducedMotion: control.reducedMotion
            visible: control.tessaCube
            text: "Keyboard"
            Accessible.name: "Toggle on-screen keyboard"
            Layout.preferredWidth: 48
            Layout.fillWidth: true
            Layout.fillHeight: true
            onClicked: { control.keyboardRequested(); control.expanded = false; }
        }
        GlassIconButton {
            symbol: "desktop"
            reducedMotion: control.reducedMotion
            id: leave
            text: "×"
            Accessible.name: "Leave window tape"
            Layout.preferredWidth: 48
            Layout.fillWidth: true
            Layout.fillHeight: true
            onClicked: control.leaveRequested()
        }
    }
    RadialActions {
        anchors.centerIn: parent
        visible: control.radialOpen
        width: Math.min(parent.width, 280)
        height: 280
        reducedMotion: control.reducedMotion
        onTriggered: action => {
            control.radialOpen = false;
            control.expanded = false;
            control.actionRequested(action);
        }
        onDismissed: { control.radialOpen = false; idle.restart(); }
    }
}
