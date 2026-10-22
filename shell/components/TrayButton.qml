import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control
    property color accentColor: Theme.accent
    property bool selected: false
    property int slotWidth: 48
    Layout.minimumWidth: slotWidth
    Layout.minimumHeight: 48
    Layout.preferredWidth: slotWidth
    implicitWidth: slotWidth
    implicitHeight: 48
    padding: 0
    focusPolicy: Qt.NoFocus
    display: AbstractButton.IconOnly
    icon.width: 20
    icon.height: 20
    icon.color: control.enabled ? (control.selected ? control.accentColor : Theme.textSecondary) : Theme.muted
    background: Rectangle {
        radius: Theme.radius("button", 20, height)
        border.width: Theme.borderWidth(1)
        border.color: Qt.alpha(control.down || control.selected ? control.accentColor : Theme.text, control.down ? 0.78 : control.selected ? 0.62 : 0.16)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(control.down || control.selected ? control.accentColor : Theme.text, control.down ? 0.28 : control.selected ? 0.20 : 0.09) }
            GradientStop { position: 1; color: Qt.alpha(Theme.surface, control.down || control.selected ? 0.36 : 0.20) }
        }
    }
}
