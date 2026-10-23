import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Windows-XP-style task button: wide, horizontally laid out, with a bevelled
// edge. XP presses the button that owns the focused window; here the bevel and
// a translucent accent fill carry that state over the glass bar.
Button {
    id: control
    property color accentColor: Theme.accent
    property bool selected: false
    property string iconSource: ""
    Layout.minimumHeight: 48
    Layout.minimumWidth: 150
    Layout.maximumWidth: 240
    Layout.preferredWidth: 210
    implicitHeight: 48
    padding: 10
    focusPolicy: Qt.TabFocus
    contentItem: Item {
        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width)
            spacing: 8
            Image {
                visible: control.iconSource !== ""
                source: control.iconSource
                sourceSize.width: 18
                sourceSize.height: 18
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                textFormat: Text.PlainText
                text: control.text
                color: control.enabled ? Theme.text : Theme.muted
                font.pixelSize: 13
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
    background: Rectangle {
        radius: Theme.radius("button", 8, height)
        color: control.selected ? Theme.taskSelected(control.accentColor)
                                : control.down ? Theme.taskDown(control.accentColor)
                                               : control.hovered ? Qt.alpha(control.accentColor, 0.12)
                                                                 : Theme.taskIdle
        border.width: Theme.borderWidth(1)
        border.color: control.selected ? Theme.taskSelectedBorder(control.accentColor) : control.visualFocus ? control.accentColor : control.hovered ? Qt.alpha(control.accentColor, 0.42) : Theme.taskBorder
        // Inner bevel: light on top for a raised look, dark when the window has
        // focus so the button reads as pressed.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radius("button", 7, height)
            color: "transparent"
            border.width: Theme.borderWidth(1)
            border.color: control.selected ? Theme.taskPressedBevel : control.visualFocus ? Qt.alpha(control.accentColor, 0.32) : Theme.taskBevel
        }
    }
    Accessible.name: text
    Accessible.role: Accessible.Button
    Accessible.description: control.selected ? "Active window" : "Switch to window"
}
