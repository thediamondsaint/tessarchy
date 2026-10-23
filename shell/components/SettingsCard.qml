pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card
    property string title: ""
    property string subtitle: ""
    property color accentColor: Theme.accent
    default property alias contentData: body.data
    implicitWidth: 280
    implicitHeight: body.implicitHeight + 28
    radius: Theme.radius("card", 20, height)
    color: Theme.glass
    border.width: Theme.borderWidth(1)
    border.color: Qt.alpha(card.accentColor, 0.28)

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: card.title
                color: card.accentColor
                font { pixelSize: 11; bold: true; letterSpacing: 1.8 }
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Icon {
                visible: card.subtitle.length > 0
                symbol: "controls"
                size: 16
                color: Qt.alpha(card.accentColor, 0.72)
            }
        }
        Text {
            visible: card.subtitle.length > 0
            text: card.subtitle
            color: Theme.textMuted
            font.pixelSize: 12
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
