import QtQuick
import QtQuick.Layouts
import "../AppPolicy.js" as Apps

GridLayout {
    id: grid
    property var applications: []
    property var iconPath: function(name) { return ""; }
    property color accentColor: "#a9e8d5"
    property string focusedAppId: ""
    property bool ready: false
    signal launchRequested(string appId)
    signal tileFocused(var tile)
    columns: 4
    columnSpacing: 8
    rowSpacing: 8
    function refresh() {
        let hadFocus = false;
        for (let i = 0; i < tiles.count; ++i) {
            const cell = tiles.itemAt(i);
            if (cell && cell.item && cell.item.activeFocus) hadFocus = true;
        }
        const previous = focusedAppId;
        const changed = Apps.syncRows(rows, Apps.menuRows(applications));
        if (changed && hadFocus) Qt.callLater(() => grid.focusApp(previous));
    }
    function focusApp(appId) {
        let first = null;
        for (let i = 0; i < tiles.count; ++i) {
            const tile = tiles.itemAt(i);
            if (!tile || tile.heading || !tile.item) continue;
            if (!first) first = tile.item;
            if (tile.appId === appId) {
                tile.item.forceActiveFocus();
                grid.tileFocused(tile.item);
                return;
            }
        }
        if (first) {
            first.forceActiveFocus();
            grid.tileFocused(first);
        } else grid.forceActiveFocus();
    }
    onApplicationsChanged: if (ready) refresh()
    Component.onCompleted: { ready = true; refresh(); }
    ListModel { id: rows }
    Repeater {
        id: tiles
        model: rows
        delegate: Loader {
            id: cell
            required property bool heading
            required property string appId
            required property string name
            required property string icon
            Layout.fillWidth: true
            Layout.columnSpan: heading ? grid.columns : 1
            Layout.preferredWidth: 1
            Layout.minimumWidth: heading ? 0 : 48
            Layout.preferredHeight: heading ? 28 : 84
            sourceComponent: heading ? categoryHeading : applicationTile
            Component {
                id: categoryHeading
                Text {
                    text: cell.name
                    textFormat: Text.PlainText
                    color: grid.accentColor
                    font.pixelSize: 12
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
            Component {
                id: applicationTile
                StartMenuTile {
                    id: tileButton
                    text: cell.name
                    symbol: "browser"
                    iconSource: grid.iconPath(cell.icon)
                    accentColor: grid.accentColor
                    onActiveFocusChanged: if (activeFocus) {
                        grid.focusedAppId = cell.appId;
                        grid.tileFocused(tileButton);
                    }
                    onClicked: grid.launchRequested(cell.appId)
                }
            }
        }
    }
    Text {
        visible: rows.count === 0
        Layout.columnSpan: grid.columns
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? 56 : 0
        text: "No applications installed"
        color: grid.accentColor
        horizontalAlignment: Text.AlignHCenter
    }
}
