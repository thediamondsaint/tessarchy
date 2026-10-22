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
    focusPolicy: Qt.NoFocus
    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight
        RowLayout {
            id: contentRow
            width: parent.width
            height: Math.max(implicitHeight, parent.height)
            anchors.verticalCenter: parent.verticalCenter
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
                textFormat: Text.PlainText
                text: control.text
                color: control.enabled ? Theme.text : Theme.muted
                font.pixelSize: 13
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
    background: Rectangle {
        radius: Theme.radius("button", 8, height)
        color: control.selected ? Theme.taskSelected(control.accentColor)
                                : control.down ? Theme.taskDown(control.accentColor)
                                               : Theme.taskIdle
        border.width: Theme.borderWidth(1)
        border.color: control.selected ? Theme.taskSelectedBorder(control.accentColor) : Theme.taskBorder
        // Inner bevel: light on top for a raised look, dark when the window has
        // focus so the button reads as pressed.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radius("button", 7, height)
            color: "transparent"
            border.width: Theme.borderWidth(1)
            border.color: control.selected ? Theme.taskPressedBevel : Theme.taskBevel
        }
    }
    Accessible.name: text
}
