pragma ComponentBehavior: Bound
import QtQuick

TouchButton {
    id: button
    required property string symbol
    property bool reducedMotion: false
    implicitWidth: 56
    implicitHeight: 56
    padding: 0
    scale: down ? 0.92 : hovered ? 1.04 : 1
    Behavior on scale { NumberAnimation { duration: button.reducedMotion ? 0 : 120 } }
    contentItem: Item {
        Icon { anchors.centerIn: parent; symbol: button.symbol; size: 24; color: button.enabled ? Theme.text : Theme.muted }
    }
    background: Rectangle {
        radius: Theme.radius("button", 20, height)
        border.width: Theme.borderWidth(1)
        border.color: Qt.alpha(button.down ? Theme.wheelGlow : Theme.text, button.down ? 0.7 : 0.20)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.text, button.down ? 0.22 : 0.12) }
            GradientStop { position: 1; color: Qt.alpha(Theme.surface, 0.24) }
        }
    }
}
