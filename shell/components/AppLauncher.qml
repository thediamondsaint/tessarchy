pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../AppPolicy.js" as Apps

Item {
    id: launcher
    property var applications: []
    property var iconPath: function(name) { return ""; }
    readonly property var matches: Apps.search(applications, search.text)
    signal launched(string appId)
    signal dismissed()
    implicitWidth: 560
    implicitHeight: 120 + Math.max(1, Math.min(matches.length, 7)) * 64
    function resetSearchAndFocus() {
        search.text = "";
        results.currentIndex = results.count ? 0 : -1;
        results.forceActiveFocus();
    }
    onVisibleChanged: if (visible) { resetSearchAndFocus(); Qt.callLater(() => results.forceActiveFocus()); }
    function activateCurrent() {
        if (results.currentIndex >= 0 && results.currentIndex < matches.length)
            launched(matches[results.currentIndex].id);
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius("card", 22, height)
        color: Qt.alpha(Theme.background, 0.96)
        border.width: Theme.borderWidth(1)
        border.color: Theme.tileBorder
    }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        TextField {
            id: search
            objectName: "launcherSearch"
            Layout.fillWidth: true
            Layout.minimumHeight: 56
            placeholderText: "Search apps…"
            placeholderTextColor: Theme.inputPlaceholder
            color: Theme.inputText
            selectionColor: Theme.inputSelection
            font.pixelSize: 18
            leftPadding: 16
            rightPadding: 16
            onTextChanged: results.currentIndex = results.count ? 0 : -1
            Keys.onDownPressed: { results.forceActiveFocus(); results.currentIndex = Math.max(0, results.currentIndex); }
            Keys.onUpPressed: { results.forceActiveFocus(); results.currentIndex = Math.max(0, results.count - 1); }
            Keys.onReturnPressed: launcher.activateCurrent()
            Keys.onEnterPressed: launcher.activateCurrent()
            Keys.onEscapePressed: launcher.dismissed()
            background: Rectangle { color: Theme.glass; radius: Theme.radius("field", 14, height); border.color: Theme.inputBorder }
        }
        ListView {
            id: results
            objectName: "launcherResults"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 64
            clip: true
            model: launcher.matches
            keyNavigationEnabled: true
            currentIndex: count ? 0 : -1
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            Keys.onPressed: event => {
                if (event.text.length === 1 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    search.forceActiveFocus(); search.text += event.text; event.accepted = true;
                }
            }
            Keys.onEscapePressed: launcher.dismissed()
            Keys.onReturnPressed: launcher.activateCurrent()
            Keys.onEnterPressed: launcher.activateCurrent()
            ScrollBar.vertical: ScrollBar {}
            delegate: LauncherRow {
                required property var modelData
                required property int index
                width: results.width
                item: modelData
                selected: ListView.isCurrentItem
                iconSource: launcher.iconPath(modelData.icon)
                onPointed: results.currentIndex = index
                onClicked: launcher.launched(modelData.id)
            }
            Text {
                anchors.centerIn: parent
                visible: launcher.matches.length === 0
                text: "No applications found"
                color: Theme.textSecondary
            }
        }
        Text {
            text: launcher.matches.length + (launcher.matches.length === 1 ? " application" : " applications")
            color: Theme.textMuted
            font.pixelSize: 12
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.preferredHeight: 20
        }
    }
}
