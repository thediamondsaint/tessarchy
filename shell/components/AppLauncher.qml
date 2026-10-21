pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../AppPolicy.js" as Apps

ColumnLayout {
    id: launcher
    property var applications: []
    property var iconPath: function(name) { return ""; }
    readonly property var matches: Apps.search(applications, search.text)
    signal launched(string appId)
    signal dismissed()
    onVisibleChanged: if (visible) { search.text = ""; grid.currentIndex = grid.count ? 0 : -1; Qt.callLater(() => grid.forceActiveFocus()); }
    spacing: 8
    TextField {
        id: search
        objectName: "launcherSearch"
        Layout.fillWidth: true
        Layout.minimumHeight: 48
        placeholderText: "Search Tessa applications"
        placeholderTextColor: Theme.inputPlaceholder
        color: Theme.inputText
        selectionColor: Theme.inputSelection
        onTextChanged: grid.currentIndex = grid.count ? 0 : -1
        Keys.onDownPressed: { grid.forceActiveFocus(); grid.currentIndex = Math.max(0, grid.currentIndex); }
        Keys.onReturnPressed: if (grid.currentIndex >= 0 && grid.currentIndex < launcher.matches.length) launcher.launched(launcher.matches[grid.currentIndex].id)
        Keys.onEscapePressed: launcher.dismissed()
        background: Rectangle { color: Theme.glass; radius: Theme.radius("field", 12, height); border.color: Theme.inputBorder }
    }
    GridView {
        id: grid
        objectName: "launcherGrid"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 96
        clip: true
        cellWidth: width / Math.max(2, Math.floor(width / 112))
        cellHeight: 108
        model: launcher.matches
        keyNavigationEnabled: true
        Keys.onPressed: event => {
            if (event.text.length === 1 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                search.forceActiveFocus();
                search.text += event.text;
                event.accepted = true;
            }
        }
        currentIndex: count ? 0 : -1
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)
        Keys.onEscapePressed: launcher.dismissed()
        Keys.onReturnPressed: if (currentIndex >= 0 && currentIndex < launcher.matches.length) launcher.launched(launcher.matches[currentIndex].id)
        Keys.onEnterPressed: if (currentIndex >= 0 && currentIndex < launcher.matches.length) launcher.launched(launcher.matches[currentIndex].id)
        ScrollBar.vertical: ScrollBar {}
        delegate: AppTile {
            required property var modelData
            required property int index
            width: grid.cellWidth - 8
            height: 100
            text: modelData.name
            symbol: "browser"
            selected: GridView.isCurrentItem && grid.activeFocus
            iconSource: launcher.iconPath(modelData.icon)
            onClicked: launcher.launched(modelData.id)
        }
    }
    Text {
        visible: launcher.matches.length === 0
        text: "No applications found"
        color: Theme.textSecondary
        Layout.fillWidth: true
    }
}
