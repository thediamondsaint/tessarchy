pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card
    property string title: ""
    property string subtitle: ""
    property string symbol: "controls"
    property color accentColor: Theme.accent
    property bool interactive: false
    signal clicked
    default property alias content: body.data

    implicitWidth: 224
    implicitHeight: 164
    radius: Theme.radius("card", 24, height)
    color: Qt.alpha(Theme.glass, 0.94)
    border.width: Theme.borderWidth(1)
    border.color: Qt.alpha(card.accentColor, 0.24)

    Behavior on color { ColorAnimation { duration: 140 } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: Theme.radius("tile", 14, height)
                color: Qt.alpha(card.accentColor, 0.18)
                border.width: Theme.borderWidth(1)
                border.color: Qt.alpha(card.accentColor, 0.28)
                Icon { anchors.centerIn: parent; symbol: card.symbol; size: 20; color: card.accentColor }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: card.title
                    color: Theme.text
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: card.subtitle.length > 0
                    text: card.subtitle
                    color: Theme.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: card.interactive
        hoverEnabled: true
        onClicked: card.clicked()
        onPressed: card.opacity = 0.86
        onReleased: card.opacity = 1
        onCanceled: card.opacity = 1
    }
}
