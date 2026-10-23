import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Slider {
    id: control
    property color accentColor: Theme.accent
    implicitHeight: 56
    Layout.minimumHeight: 56
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1 : 0.35
    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 4
        radius: Theme.radius("field", 2, height)
        color: Theme.selection
        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: Theme.radius("field", 2, height)
            color: control.accentColor
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 24
        implicitHeight: 24
        radius: Theme.radius("button", 12, height)
        color: control.pressed ? Theme.text : control.accentColor
        border.width: Theme.borderWidth(3)
        border.color: Theme.darkBackground
    }
}
