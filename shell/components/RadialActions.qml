pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: radial
    signal triggered(string action)
    signal dismissed()
    readonly property var actions: [
        {label: "Apps", action: "apps"},
        {label: "Settings", action: "settings"},
        {label: "Recents", action: "windows"},
        {label: "Controls", action: "controls"},
        {label: "Keyboard", action: "keyboard"},
        {label: "Exit tape", action: "leave"}
    ]
    Repeater {
        model: radial.actions
        delegate: TouchButton {
            id: actionButton
            required property var modelData
            required property int index
            readonly property real angle: -Math.PI / 2 + index * Math.PI / 3
            width: 76; height: 56
            x: radial.width / 2 + Math.cos(angle) * 94 - width / 2
            y: radial.height / 2 + Math.sin(angle) * 94 - height / 2
            text: modelData.label
            padding: 3
            contentItem: Text {
                text: actionButton.text
                textFormat: Text.PlainText
                font.pixelSize: 14
                color: Theme.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Accessible.name: modelData.label
            onClicked: radial.triggered(modelData.action)
        }
    }
    TouchButton {
        anchors.centerIn: parent
        width: 56; height: 56
        text: "×"
        Accessible.name: "Close radial actions"
        onClicked: radial.dismissed()
    }
}
