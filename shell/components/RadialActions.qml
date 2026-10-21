pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: radial
    property bool reducedMotion: false
    signal triggered(string action)
    signal dismissed()
    readonly property var actions: [
        {label: "Apps", icon: "dialpad", action: "apps"},
        {label: "Settings", icon: "settings", action: "settings"},
        {label: "Recents", icon: "recents", action: "windows"},
        {label: "Controls", icon: "controls", action: "controls"},
        {label: "Keyboard", icon: "keyboard", action: "keyboard"},
        {label: "Exit tape", icon: "desktop", action: "leave"}
    ]
    Repeater {
        model: radial.actions
        delegate: GlassIconButton {
            symbol: modelData.icon
            reducedMotion: radial.reducedMotion
            id: actionButton
            required property var modelData
            required property int index
            readonly property real angle: -Math.PI / 2 + index * Math.PI / 3
            width: 56; height: 56
            x: radial.width / 2 + Math.cos(angle) * 94 - width / 2
            y: radial.height / 2 + Math.sin(angle) * 94 - height / 2
            text: modelData.label
            padding: 3
            Accessible.name: modelData.label
            onClicked: radial.triggered(modelData.action)
        }
    }
    GlassIconButton {
        symbol: "close"
        reducedMotion: radial.reducedMotion
        anchors.centerIn: parent
        width: 56; height: 56
        text: "×"
        Accessible.name: "Close radial actions"
        onClicked: radial.dismissed()
    }
}
