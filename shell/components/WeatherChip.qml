import QtQuick
import QtQuick.Layouts

Item {
    id: chip
    property var conditions: ({})
    property int glyphSize: 20
    property bool iconOnly: false
    signal clicked
    property bool pressed: false
    property bool hovered: false
    Layout.minimumWidth: 56
    Layout.minimumHeight: 48
    implicitWidth: iconOnly ? 56 : weatherRow.implicitWidth + 20
    implicitHeight: 48
    Accessible.role: Accessible.Button
    Accessible.name: (chip.conditions.description || "Weather") + ", " + Math.round(chip.conditions.temperature || 0) + (chip.conditions.unit || "")
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius("button", 20, height)
        color: chip.pressed ? Qt.alpha(Theme.accent, 0.24) : chip.hovered ? Qt.alpha(Theme.accent, 0.12) : Theme.glass
        border.width: Theme.borderWidth(1)
        border.color: chip.pressed ? Theme.accent : chip.hovered ? Qt.alpha(Theme.accent, 0.46) : Theme.glassBorder
        scale: chip.pressed ? 0.96 : chip.hovered ? 1.03 : 1
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Math.max(0, parent.radius - 2)
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.text, chip.pressed ? 0.24 : 0.10)
        }
    }
    RowLayout {
        id: weatherRow
        anchors.fill: parent
        anchors.leftMargin: chip.iconOnly ? 0 : 10
        anchors.rightMargin: chip.iconOnly ? 0 : 10
        Layout.alignment: Qt.AlignCenter
        spacing: 6
        Icon {
            Layout.alignment: Qt.AlignVCenter
            symbol: chip.conditions.icon || "weather-cloud"
            size: chip.glyphSize
            color: Theme.accent
        }
        Text {
            visible: !chip.iconOnly
            Layout.alignment: Qt.AlignVCenter
            text: Math.round(chip.conditions.temperature || 0) + (chip.conditions.unit || "")
            color: Theme.textSecondary
            font.pixelSize: 12
            Accessible.name: (chip.conditions.description || "Weather") + ", " + text
                + (chip.conditions.stale ? ", last observation" : "")
        }
    }
    TapHandler {
        onPressedChanged: chip.pressed = pressed
        onTapped: chip.clicked()
    }
    HoverHandler { onHoveredChanged: chip.hovered = hovered }
    focus: true
    activeFocusOnTab: true
    Keys.onReturnPressed: chip.clicked()
    Keys.onSpacePressed: chip.clicked()
    Accessible.description: chip.conditions.stale ? "Weather data is stale; tap to refresh" : "Tap to refresh weather"
}
