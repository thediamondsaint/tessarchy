pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One notification from the server's tracked model. Tapping the body emits
// opened (pop-ups hide); the close button emits closed (removes it from the
// tracked list everywhere).
Button {
    id: card
    required property var notification
    property color accentColor: Theme.accent
    signal opened
    signal closed
    implicitWidth: 360
    implicitHeight: Math.max(72, content.implicitHeight + padding * 2)
    padding: 12
    focusPolicy: Qt.NoFocus
    onClicked: card.opened()
    contentItem: RowLayout {
        id: content
        spacing: 8
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: card.notification.appName || "Notification"
                    color: card.accentColor
                    font {
                        pixelSize: 11
                        bold: true
                        letterSpacing: 1
                    }
                    elide: Text.ElideRight
                }
                Text {
                    textFormat: Text.PlainText
                    visible: card.notification.urgency === 2
                    text: "IMPORTANT"
                    color: Theme.urgentText
                    font {
                        pixelSize: 10
                        bold: true
                    }
                }
            }
            Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: card.notification.summary || ""
                color: Theme.text
                font {
                    pixelSize: 15
                    bold: true
                }
                elide: Text.ElideRight
            }
            Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.notification.body || ""
                color: Theme.detailText
                font.pixelSize: 13
                maximumLineCount: 3
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
            }
        }
        TouchButton {
            text: "✕"
            implicitWidth: 48
            implicitHeight: 48
            Layout.minimumWidth: 48
            Layout.minimumHeight: 48
            Layout.preferredWidth: 48
            Layout.alignment: Qt.AlignTop
            padding: 0
            accentColor: card.accentColor
            Accessible.name: "Dismiss notification"
            onClicked: card.closed()
        }
    }
    background: Rectangle {
        radius: Theme.radius("card", 14, height)
        color: card.down ? Theme.notificationCardPressed : Theme.notificationCard
        border.width: Theme.borderWidth(1)
        border.color: card.notification.urgency === 2 ? Theme.urgentBorder : Qt.alpha(card.accentColor, 0.35)
    }
    Accessible.name: (card.notification.appName || "Notification") + ": " + card.notification.summary
    Accessible.role: Accessible.Button
}
