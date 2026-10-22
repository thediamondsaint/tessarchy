import QtQuick
import QtQuick.Layouts

RowLayout {
    id: control
    property color accentColor: Theme.accent
    property bool compact: false
    property int notificationCount: 0
    property int cellularStrength: -1
    property int wifiStrength: -1
    property bool airplaneOn: false
    property bool batteryPresent: false
    property real batteryPercent: 0
    property bool audioAvailable: false
    property bool audioMuted: false
    property bool notificationsSelected: false
    property bool settingsSelected: false
    property bool showBatteryText: true
    property bool showVolume: true
    property bool showSettings: true
    property bool touchMode: false
    property int touchSlot: 56
    property bool reducedMotion: false
    signal notificationsRequested
    signal settingsRequested
    signal muteToggled
    /// Tapping a bare status glyph opens the quick-controls sheet.
    signal panelRequested
    readonly property int glyphSize: compact ? 18 : 21
    spacing: compact ? 2 : 8

    TrayButton {
        id: bellButton
        slotWidth: control.touchMode ? control.touchSlot : control.compact ? 28 : 48
        icon.source: "../icons/bell.svg"
        icon.width: control.glyphSize
        icon.height: control.glyphSize
        accentColor: control.accentColor
        reducedMotion: control.reducedMotion
        selected: control.notificationsSelected
        Rectangle {
            visible: control.notificationCount > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: control.compact ? 1 : 6
            anchors.topMargin: control.compact ? 1 : 8
            width: 14
            height: 14
            radius: Theme.radius("tile", 7, height)
            color: Theme.danger
            Text {
                anchors.centerIn: parent
                text: control.notificationCount
                color: Theme.darkerBackground
                font.pixelSize: 9
                font.bold: true
            }
        }
        Accessible.name: control.notificationCount > 0 ? "Notifications, " + control.notificationCount + " unread" : "Notifications"
        onClicked: control.notificationsRequested()
    }
    Item {
        visible: control.airplaneOn
        Layout.preferredWidth: control.touchMode ? control.touchSlot : control.compact ? 28 : 48
        Layout.preferredHeight: 48
        Rectangle {
            anchors.centerIn: parent
            width: 44
            height: 44
            radius: Theme.radius("button", 20, height)
            color: Qt.alpha(Theme.text, 0.08)
            border.width: Theme.borderWidth(1)
            border.color: Qt.alpha(control.accentColor, 0.18)
            Icon { anchors.centerIn: parent; symbol: "airplane"; size: 20; color: control.accentColor }
        }
        Accessible.name: "Airplane mode on"
    }
    StatusIcon {
        symbol: "cellular"
        label: "Cellular"
        strength: control.cellularStrength
        uniform: control.compact
        showFallback: control.compact
        touchMode: control.touchMode
        touchSlot: control.touchSlot
        onClicked: control.panelRequested()
    }
    StatusIcon {
        symbol: "wifi"
        label: "Wi-Fi"
        strength: control.wifiStrength
        uniform: control.compact
        showFallback: control.compact
        touchMode: control.touchMode
        touchSlot: control.touchSlot
        onClicked: control.panelRequested()
    }
    Item {
        Layout.preferredWidth: control.touchMode ? control.touchSlot : control.compact ? 28 : batteryRow.implicitWidth
        Layout.preferredHeight: 48
        Rectangle {
            visible: control.touchMode
            anchors.centerIn: parent
            width: 44
            height: 44
            radius: Theme.radius("button", 20, height)
            color: Qt.alpha(Theme.text, 0.08)
            border.width: Theme.borderWidth(1)
            border.color: Qt.alpha(control.accentColor, 0.16)
        }
        RowLayout {
            id: batteryRow
            anchors.centerIn: parent
            spacing: 4
            Icon {
                symbol: "battery"
                size: control.compact ? 18 : 22
                color: control.batteryPresent ? control.accentColor : Theme.textMuted
                opacity: control.compact || control.batteryPresent ? 1 : 0.55
            }
            Text {
                visible: control.showBatteryText
                text: control.batteryPresent ? Math.round(control.batteryPercent * 100) + "%" : "—"
                color: control.compact ? Theme.textSecondary : Theme.accent
                font.pixelSize: control.compact ? 10 : 11
                Accessible.name: control.batteryPresent ? "Battery " + text : "Battery status unavailable"
            }
        }
        Accessible.role: Accessible.Button
        Accessible.name: control.batteryPresent ? "Battery " + Math.round(control.batteryPercent * 100) + " percent" : "Battery status unavailable"
        MouseArea {
            anchors.fill: parent
            onClicked: control.panelRequested()
        }
    }
    TrayButton {
        visible: control.showVolume
        slotWidth: control.touchMode ? control.touchSlot : control.compact ? 28 : 48
        enabled: control.audioAvailable
        icon.source: "../icons/" + (control.audioMuted ? "volume-muted" : "volume") + ".svg"
        icon.width: control.glyphSize
        icon.height: control.glyphSize
        accentColor: control.accentColor
        reducedMotion: control.reducedMotion
        Accessible.name: control.audioMuted ? "Unmute audio" : "Mute audio"
        onClicked: control.muteToggled()
    }
    TrayButton {
        visible: control.showSettings
        slotWidth: control.touchMode ? control.touchSlot : control.compact ? 28 : 48
        icon.source: "../icons/settings.svg"
        icon.width: control.glyphSize
        icon.height: control.glyphSize
        accentColor: control.accentColor
        reducedMotion: control.reducedMotion
        selected: control.settingsSelected
        Accessible.name: "Settings"
        onClicked: control.settingsRequested()
    }
}
