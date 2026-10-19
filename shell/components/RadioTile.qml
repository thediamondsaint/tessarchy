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
                width: 40; height: 40; radius: 20
                color: tile.selected ? Qt.alpha(tile.accentColor, 0.23) : "#2991b3c5"
                Image { anchors.centerIn: parent; width: 22; height: 22; sourceSize.width: 22; sourceSize.height: 22; source: "../icons/" + tile.symbol + ".svg"; opacity: tile.enabled ? 1 : 0.4 }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, tile.availableWidth - 52)
                spacing: 4
                Text { width: parent.width; text: tile.text; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#edf5fa"; wrapMode: Text.WordWrap }
                Text { width: parent.width; textFormat: Text.PlainText; text: tile.detail; font.pixelSize: 10; color: tile.selected ? tile.accentColor : "#99afbe"; elide: Text.ElideRight }
            }
        }
    }
}
