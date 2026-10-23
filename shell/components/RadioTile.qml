import QtQuick
import QtQuick.Layouts

TouchButton {
    id: tile
    required property string symbol
    property string detail: "Unavailable"
    implicitHeight: 100
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Accessible.name: text + ", " + detail
    contentItem: Item {
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Rectangle {
                width: 40; height: 40; radius: Theme.radius("tile", 20, height)
                color: tile.selected ? Theme.selected(tile.accentColor) : Theme.glass
                Icon { anchors.centerIn: parent; symbol: tile.symbol; size: 22; color: Theme.text; opacity: tile.enabled ? 1 : 0.4 }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, tile.availableWidth - 52)
                spacing: 4
                Text { width: parent.width; text: tile.text; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text; wrapMode: Text.WordWrap }
                Text { width: parent.width; text: tile.detail; font.pixelSize: 10; color: tile.selected ? tile.accentColor : Theme.textMuted; elide: Text.ElideRight }
            }
        }
    }
}
