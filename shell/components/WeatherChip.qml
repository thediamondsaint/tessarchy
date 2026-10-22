import QtQuick
import QtQuick.Layouts

RowLayout {
    id: chip
    property var conditions: ({})
    property int glyphSize: 20
    signal clicked
    Layout.minimumWidth: 56
    Layout.minimumHeight: 48
    Accessible.role: Accessible.Button
    Accessible.name: (chip.conditions.description || "Weather") + ", " + Math.round(chip.conditions.temperature || 0) + (chip.conditions.unit || "")
    spacing: 6
    Icon {
        Layout.alignment: Qt.AlignVCenter
        symbol: chip.conditions.icon || "weather-cloud"
        size: chip.glyphSize
        color: Theme.accent
    }
    Text {
        Layout.alignment: Qt.AlignVCenter
        text: Math.round(chip.conditions.temperature || 0) + (chip.conditions.unit || "")
        color: Theme.textSecondary
        font.pixelSize: 12
        Accessible.name: (chip.conditions.description || "Weather") + ", " + text
            + (chip.conditions.stale ? ", last observation" : "")
    }
    TapHandler { onTapped: chip.clicked() }
}
