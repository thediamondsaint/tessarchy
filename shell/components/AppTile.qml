import QtQuick
import QtQuick.Layouts

TouchButton {
    id: control
    property string iconSource: ""
    required property string symbol
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: 96
    contentItem: Item {
        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 12
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 52
                height: 52
                radius: Theme.radius("card", 16, height)
                rotation: 0
                color: Qt.alpha(control.accentColor, control.selected ? 0.4 : 0.18)
                Image {
                    anchors.centerIn: parent
                    rotation: 0
                    source: control.iconSource || "../icons/" + control.symbol + ".svg"
                    sourceSize.width: 24
                    sourceSize.height: 24
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: control.text
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: Theme.text
                font.pixelSize: 13
            }
        }
    }
}
