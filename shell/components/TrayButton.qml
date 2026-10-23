import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control
    property color accentColor: Theme.accent
    property bool selected: false
    property bool reducedMotion: false
    property int slotWidth: 48
    Layout.minimumWidth: slotWidth
    Layout.minimumHeight: 48
    Layout.preferredWidth: slotWidth
    implicitWidth: slotWidth
    implicitHeight: 48
    padding: 0
    focusPolicy: Qt.NoFocus
    transformOrigin: Item.Center
    scale: down ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: control.reducedMotion ? 0 : 90; easing.type: Easing.OutCubic } }
    display: AbstractButton.IconOnly
    icon.width: 20
    icon.height: 20
    icon.color: control.enabled ? (control.selected ? control.accentColor : Theme.textSecondary) : Theme.muted
    background: Rectangle {
        radius: Theme.radius("button", 20, height)
        border.width: Theme.borderWidth(1)
        border.color: control.down ? control.accentColor : control.selected ? Qt.alpha(control.accentColor, 0.78) : Theme.glassBorder
        gradient: Gradient {
            GradientStop { position: 0; color: control.down ? Qt.alpha(control.accentColor, 0.32) : control.selected ? Qt.alpha(control.accentColor, 0.22) : Qt.alpha(Theme.text, 0.12) }
            GradientStop { position: 0.48; color: control.down ? Qt.alpha(Theme.glassStrong, 0.88) : Theme.glass }
            GradientStop { position: 1; color: Qt.alpha(Theme.darkerBackground, control.down ? 0.34 : 0.16) }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Math.max(0, parent.radius - 2)
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.text, control.down ? 0.24 : 0.10)
        }
    }
}
