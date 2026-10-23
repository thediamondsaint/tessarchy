import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control
    Layout.minimumWidth: 48
    Layout.minimumHeight: 56
    implicitWidth: 120
    implicitHeight: 56
    padding: 10
    // Touch remains the primary input, but every shared button can also be
    // reached with Tab/Enter on desktop keyboards.
    focusPolicy: Qt.TabFocus
    property color accentColor: Theme.accent
    property bool destructive: false
    property bool selected: false
    property bool reducedMotion: false
    transformOrigin: Item.Center
    scale: down ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: control.reducedMotion ? 0 : 90; easing.type: Easing.OutCubic } }
    contentItem: Text {
        textFormat: Text.PlainText
        text: control.text
        color: control.enabled ? Theme.text : Theme.muted
        font.pixelSize: 16
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Theme.radius("button", 12, height)
        color: control.down ? Theme.pressed(control.accentColor) : control.destructive ? Theme.dangerSurface : control.selected ? Theme.selected(control.accentColor) : control.hovered ? Qt.alpha(control.accentColor, 0.10) : Theme.glass
        border.color: control.destructive ? Theme.danger : control.down ? control.accentColor : control.visualFocus ? control.accentColor : control.selected ? control.accentColor : control.hovered ? Qt.alpha(control.accentColor, 0.42) : Theme.glassBorder
        border.width: Theme.borderWidth(1)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Math.max(0, parent.radius - 2)
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.text, control.down ? 0.22 : control.visualFocus ? 0.24 : control.hovered ? 0.16 : 0.09)
        }
    }
    Accessible.name: text
    Accessible.role: Accessible.Button
}
