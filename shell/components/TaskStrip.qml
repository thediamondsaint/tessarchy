pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: strip
    property var windows: []
    property var activeWindow: null
    property color accentColor: Theme.accent
    property var iconForWindow: window => ""
    property string emptyText: "No open windows"
    readonly property bool overflow: windows.length * 150 + Math.max(0, windows.length - 1) * 6 > width
    signal windowRequested(var window)
    spacing: 6
    implicitHeight: 48
    Layout.minimumWidth: 0

    function revealActive() {
        tasks.forceLayout();
        const index = windows.findIndex(window => window === activeWindow || window.activated);
        if (index >= 0) tasks.positionViewAtIndex(index, ListView.Contain);
    }
    function scrollTasks(direction) {
        tasks.contentX = Math.max(0, Math.min(Math.max(0, tasks.contentWidth - tasks.width),
            tasks.contentX + direction * tasks.width * 0.8));
    }
    onActiveWindowChanged: Qt.callLater(revealActive)
    onWindowsChanged: Qt.callLater(revealActive)
    onWidthChanged: Qt.callLater(revealActive)

    TouchButton {
        visible: strip.overflow
        Layout.preferredWidth: 48
        Layout.minimumHeight: 48
        implicitHeight: 48
        text: "‹"
        enabled: tasks.contentX > 0.5
        accentColor: strip.accentColor
        Accessible.name: "Earlier windows"
        onClicked: strip.scrollTasks(-1)
    }
    ListView {
        id: tasks
        objectName: "desktopTaskList"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0
        orientation: ListView.Horizontal
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onCountChanged: Qt.callLater(strip.revealActive)
        onWidthChanged: Qt.callLater(strip.revealActive)
        Component.onCompleted: Qt.callLater(strip.revealActive)
        model: strip.windows
        delegate: TaskButton {
            id: task
            required property var modelData
            required property int index
            width: strip.overflow ? 150 : Math.min(210, Math.max(150,
                (tasks.width - Math.max(0, tasks.count - 1) * tasks.spacing) / Math.max(1, tasks.count)))
            height: 48
            text: modelData.title || "Untitled window"
            selected: modelData.activated
            iconSource: strip.iconForWindow(modelData)
            accentColor: strip.accentColor
            enabled: !!modelData.wayland
            onSelectedChanged: { if (selected) Qt.callLater(strip.revealActive); }
            onClicked: strip.windowRequested(modelData)
        }
        WheelHandler {
            target: null
            onWheel: event => {
                const delta = event.pixelDelta.x || event.pixelDelta.y || event.angleDelta.x / 3 || event.angleDelta.y / 3;
                tasks.contentX = Math.max(0, Math.min(Math.max(0, tasks.contentWidth - tasks.width), tasks.contentX - delta));
                event.accepted = true;
            }
        }
    }
    Text {
        visible: tasks.count === 0
        text: strip.emptyText
        color: Theme.textMuted
        font.pixelSize: 12
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        Accessible.name: strip.emptyText
    }
    TouchButton {
        visible: strip.overflow
        Layout.preferredWidth: 48
        Layout.minimumHeight: 48
        implicitHeight: 48
        text: "›"
        enabled: tasks.contentX < tasks.contentWidth - tasks.width - 0.5
        accentColor: strip.accentColor
        Accessible.name: "Later windows"
        onClicked: strip.scrollTasks(1)
    }
}
