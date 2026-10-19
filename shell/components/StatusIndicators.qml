import QtQuick
import QtQuick.Layouts

RowLayout {
    id: control
    property color accentColor: "#a9e8d5"
    property bool compact: false
    property bool dense: false
    property bool showAirplane: true
    property int notificationCount: 0
    property int cellularStrength: -1
    property int wifiStrength: -1
    property string wifiStatus: "unavailable"
    property string cellularStatus: "unavailable"
    property string wifiDetail: ""
    property string cellularDetail: ""
    property string wifiBadge: ""
    property string cellularBadge: ""
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
    signal notificationsRequested
    signal settingsRequested
    signal wifiRequested
    signal cellularRequested
    signal muteToggled
    readonly property int glyphSize: compact ? 18 : 21
    spacing: compact || dense ? 0 : 8

    TrayButton {
        id: bellButton
        slotWidth: control.compact ? 32 : 48
        icon.source: "../icons/bell.svg"
        icon.width: control.glyphSize
        icon.height: control.glyphSize
        accentColor: control.accentColor
        selected: control.notificationsSelected
        Rectangle {
            visible: control.notificationCount > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: control.compact ? 1 : 6
            anchors.topMargin: control.compact ? 1 : 8
            width: 14
            height: 14
            radius: 7
            color: "#e2796d"
            Text {
                anchors.centerIn: parent
                text: control.notificationCount
                color: "#21151a"
                font.pixelSize: 9
                font.bold: true
            }
        }
        Accessible.name: control.notificationCount > 0 ? "Notifications, " + control.notificationCount + " unread" : "Notifications"
        onClicked: control.notificationsRequested()
    }
    Item {
        visible: control.airplaneOn && control.showAirplane
        Layout.preferredWidth: control.compact ? 32 : 18
        Layout.preferredHeight: 48
        Image {
            anchors.centerIn: parent
            source: "../icons/airplane.svg"
            sourceSize.width: 18
            sourceSize.height: 18
        }
        Accessible.name: "Airplane mode on"
    }
    StatusIcon {
        symbol: "cellular"
        label: "Cellular"
        strength: control.cellularStrength
        status: control.cellularStatus
        detail: control.cellularDetail
        badge: control.cellularBadge
        uniform: control.compact
        Layout.preferredWidth: control.compact ? 32 : 48
        onClicked: control.cellularRequested()
    }
    StatusIcon {
        symbol: "wifi"
        label: "Wi-Fi"
        strength: control.wifiStrength
        status: control.wifiStatus
        detail: control.wifiDetail
        badge: control.wifiBadge
        uniform: control.compact
        Layout.preferredWidth: control.compact ? 32 : 48
        onClicked: control.wifiRequested()
    }
    Item {
        Layout.preferredWidth: control.compact ? 32 : batteryRow.implicitWidth
        Layout.preferredHeight: 48
        RowLayout {
            id: batteryRow
            anchors.centerIn: parent
            spacing: 4
            Image {
                source: "../icons/battery.svg"
                sourceSize.width: control.compact ? 18 : 22
                sourceSize.height: control.compact ? 18 : 22
                opacity: control.compact || control.batteryPresent ? 1 : 0.35
            }
            Text {
                visible: control.showBatteryText
                text: control.batteryPresent ? Math.round(control.batteryPercent * 100) + "%" : "—"
                color: control.compact ? "#d0f3e9" : "#a9e8d5"
                font.pixelSize: control.compact ? 10 : 11
                Accessible.name: control.batteryPresent ? "Battery " + text : "Battery status unavailable"
            }
        }
    }
    TrayButton {
        visible: control.showVolume
        slotWidth: control.compact ? 32 : 48
        enabled: control.audioAvailable
        icon.source: "../icons/" + (control.audioMuted ? "volume-muted" : "volume") + ".svg"
        icon.width: control.glyphSize
        icon.height: control.glyphSize
        accentColor: control.accentColor
        Accessible.name: control.audioMuted ? "Unmute audio" : "Mute audio"
        onClicked: control.muteToggled()
    }
    TrayButton {
        visible: control.showSettings
        slotWidth: control.compact ? 32 : 48
        icon.source: "../icons/settings.svg"
        icon.width: control.glyphSize
        icon.height: control.glyphSize
        accentColor: control.accentColor
        selected: control.settingsSelected
        Accessible.name: "Settings"
        onClicked: control.settingsRequested()
    }
}
