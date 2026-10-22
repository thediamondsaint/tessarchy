import QtQuick
import QtQuick.Layouts

Item {
    id: chip
    property var conditions: ({})
    property int glyphSize: 20
    signal clicked
    Layout.minimumWidth: 56
    Layout.minimumHeight: 48
    implicitWidth: weatherRow.implicitWidth + 20
    implicitHeight: 48
    Accessible.role: Accessible.Button
    Accessible.name: (chip.conditions.description || "Weather") + ", " + Math.round(chip.conditions.temperature || 0) + (chip.conditions.unit || "")
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius("button", 20, height)
        color: Qt.alpha(Theme.text, 0.08)
        border.width: Theme.borderWidth(1)
        border.color: Qt.alpha(Theme.accent, 0.16)
    }
    RowLayout {
        id: weatherRow
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
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
    }
    TapHandler { onTapped: chip.clicked() }
}
