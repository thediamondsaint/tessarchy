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
    // Material 3's expandable FAB pattern keeps the collapsed affordance
    // compact, then grows into a deliberate glass island with a stable action
    // grid.  The recent shelf only consumes space when there are real windows.
    readonly property bool hasRecents: recentView && recentView.windows !== undefined
        ? recentView.windows.length > 0 : !!recentView
    readonly property int expandedWidth: Math.min(maxControlWidth, tessaCube ? 360 : 336)
    // The empty shelf still gets a dedicated glass slot above the action grid;
    // keeping that slot in the height budget prevents its icon from colliding
    // with the first row on narrow touch layouts.
    readonly property int expandedHeight: hasRecents ? 408 : 344
    implicitWidth: Math.min(maxControlWidth, radialOpen ? 320 : expanded ? expandedWidth : (tessaCube ? 68 : 128))
    implicitHeight: radialOpen ? 320 : expanded && tessaCube ? expandedHeight : 68

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
        radius: Theme.radius("card", control.expanded || control.radialOpen ? 30 : 28, height)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.surface, Theme.mode === "light" ? 0.92 : 0.82) }
            GradientStop { position: 0.42; color: Qt.alpha(Theme.background, Theme.mode === "light" ? 0.88 : 0.70) }
            GradientStop { position: 1; color: Qt.alpha(Theme.darkerBackground, Theme.mode === "light" ? 0.76 : 0.62) }
        }
        border.color: Qt.alpha(Theme.wheelGlow, control.expanded ? 0.72 : 0.88)
        border.width: Theme.borderWidth(control.expanded ? 1 : 2)
    }
    TouchButton {
        id: cubeButton
        anchors.fill: parent
        visible: !control.expanded
        text: control.tessaCube ? "" : "Window tape"
        BrandMark {
            anchors.centerIn: parent
            width: 48; height: 48
            enabled: false
            playOnStart: false
            reducedMotion: control.reducedMotion
        }
        background: Rectangle {
            radius: Theme.radius("card", 28, height)
            color: cubeButton.down ? Theme.pressed(Theme.wheelGlow) : Qt.alpha(Theme.glassStrong, 0.92)
            border.color: Qt.alpha(Theme.wheelGlow, 0.92)
            border.width: Theme.borderWidth(2)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.radius("card", 23, height)
                color: "transparent"
                border.color: Qt.alpha(Theme.text, 0.24)
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
        visible: control.expanded && !control.radialOpen && control.hasRecents
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 58; leftMargin: 16; rightMargin: 16 }
        height: 96
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: control.reducedMotion ? 0 : 160 } }
        Behavior on scale { NumberAnimation { duration: control.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        sourceComponent: control.recentsComponent
    }
    Item {
        objectName: "cubeRecentsEmpty"
        visible: control.expanded && !control.radialOpen && !control.hasRecents
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 58 }
        height: 48
        Rectangle {
            anchors.centerIn: parent
            width: 58
            height: 44
            radius: Theme.radius("button", 18, height)
            color: Theme.glass
            border.width: Theme.borderWidth(1)
            border.color: Qt.alpha(Theme.wheelGlow, 0.26)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.text, 0.12) }
                GradientStop { position: 1; color: Qt.alpha(Theme.darkerBackground, 0.20) }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: Math.max(0, parent.radius - 2)
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.10)
            }
        }
        Icon {
            anchors.centerIn: parent
            symbol: "recents"
            size: 28
            color: Theme.textSecondary
        }
    }
    GridLayout {
        id: cubeActions
        objectName: "cubeActions"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: Math.min(parent.width - 32, 328)
        height: control.tessaCube ? 208 : 64
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
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
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
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            Layout.fillWidth: true
            Layout.fillHeight: true
            enabled: control.canPan
            onClicked: { control.stepped("previous"); idle.restart(); }
        }
        GlassIconButton {
            symbol: "controls"
            reducedMotion: control.reducedMotion
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
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
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
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
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
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
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
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
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            Layout.fillWidth: true
            Layout.fillHeight: true
            onClicked: { control.keyboardRequested(); control.expanded = false; }
        }
        GlassIconButton {
            objectName: "cubeSettings"
            symbol: "settings"
            reducedMotion: control.reducedMotion
            visible: control.tessaCube
            text: "Settings"
            Accessible.name: "Open Tessa settings"
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            Layout.fillWidth: true
            Layout.fillHeight: true
            onClicked: { control.actionRequested("settings"); }
        }
        GlassIconButton {
            objectName: "cubeChatGPT"
            symbol: "chatgpt"
            reducedMotion: control.reducedMotion
            visible: control.tessaCube
            text: "ChatGPT"
            Accessible.name: "Open ChatGPT"
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            Layout.fillWidth: true
            Layout.fillHeight: true
            onClicked: { control.actionRequested("chatgpt"); }
        }
        GlassIconButton {
            symbol: "desktop"
            reducedMotion: control.reducedMotion
            id: leave
            text: "×"
            Accessible.name: "Leave window tape"
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
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
