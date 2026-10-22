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
    // Desktop widgets sit directly on the wallpaper. Keep the data legible
    // while letting the background show through; touch layouts use the fuller
    // glass treatment for separation and thumb-friendly grouping.
    property bool subtle: false
    signal clicked
    default property alias content: body.data

    implicitWidth: 224
    implicitHeight: 164
    radius: Theme.radius("card", subtle ? 20 : 24, height)
    color: subtle ? Qt.alpha(Theme.surface, Theme.mode === "light" ? 0.18 : 0.10) : Theme.glass
    border.width: Theme.borderWidth(1)
    border.color: Qt.alpha(card.accentColor, subtle ? 0.22 : 0.38)

    // Keep the glass treatment palette-driven: a soft theme surface wash,
    // an edge highlight, and a restrained accent rim instead of a fixed
    // white overlay.
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.alpha(Theme.text, card.subtle ? 0.04 : Theme.mode === "light" ? 0.16 : 0.08) }
        GradientStop { position: 0.34; color: card.subtle ? Qt.alpha(Theme.surface, 0.10) : Qt.alpha(Theme.glass, 0.96) }
        GradientStop { position: 1; color: Qt.alpha(Theme.darkerBackground, card.subtle ? 0.08 : Theme.mode === "light" ? 0.12 : 0.32) }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, card.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.text, card.subtle ? 0.05 : Theme.mode === "light" ? 0.18 : 0.08)
    }

    Behavior on border.color { ColorAnimation { duration: 140 } }

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
                color: Qt.alpha(card.accentColor, card.subtle ? 0.10 : 0.18)
                border.width: Theme.borderWidth(1)
                border.color: Qt.alpha(card.accentColor, card.subtle ? 0.18 : 0.28)
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
