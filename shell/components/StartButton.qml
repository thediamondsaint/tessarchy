import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Compact mark with a shallow background and a full-size touch target.
Button {
    id: control
    property color accentColor: Theme.accent
    // True while the Start menu is open.
    property bool selected: false
    Layout.minimumHeight: 48
    Layout.minimumWidth: 48
    implicitHeight: 48
    implicitWidth: 48
    padding: 0
    focusPolicy: Qt.NoFocus
    contentItem: Item {
        Image {
            anchors.centerIn: parent
            source: "../artwork/tessarchy-mark.svg"
            sourceSize.width: 20
            sourceSize.height: 20
        }
    }
    background: Item {
        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: 32
            radius: Theme.radius("card", 8, height)
            color: Qt.alpha(control.accentColor, control.down ? 0.3 : control.selected ? 0.22 : 0.10)
            border.color: Qt.alpha(control.accentColor, control.selected ? 0.7 : 0.3)
        }
    }
    Accessible.name: "Start"
}
