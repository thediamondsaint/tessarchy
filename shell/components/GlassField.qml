import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

TextField {
    id: field
    implicitHeight: 52
    Layout.minimumHeight: 52
    Layout.fillWidth: true
    color: Theme.inputText
    placeholderTextColor: Theme.inputPlaceholder
    selectionColor: Theme.inputSelection
    font.pixelSize: 16
    padding: 14
    selectByMouse: true
    background: Rectangle {
        radius: Theme.radius("field", 16, height)
        color: Theme.glass
        border.color: field.activeFocus ? Theme.accent : Theme.inputBorder
        border.width: Theme.borderWidth(1)
    }
    Accessible.name: placeholderText
}
