pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Notification history panel page. The server's tracked model is the single
// source of truth: a notification leaves this list exactly when the user
// dismisses it or the application withdraws it.
ColumnLayout {
    id: center
    required property var server
    required property var preferences
    property color accentColor: Theme.accent
    readonly property int count: center.server.trackedNotifications.values.length
    signal clearAllRequested
    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        TouchButton {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: center.preferences.doNotDisturb ? "Pop-ups muted · On" : "Pop-ups muted · Off"
            selected: center.preferences.doNotDisturb
            accentColor: center.accentColor
            Accessible.name: center.preferences.doNotDisturb ? "Pop-up notifications muted, button" : "Pop-up notifications allowed, button"
            onClicked: center.preferences.doNotDisturb = !center.preferences.doNotDisturb
        }
        Text {
            text: center.count === 1 ? "1 alert" : center.count + " alerts"
            color: Theme.subtitleText
            font.pixelSize: 13
        }
    }
    Text {
        Layout.fillWidth: true
        visible: center.count === 0
        wrapMode: Text.WordWrap
        color: Theme.detailText
        text: "No notifications. Alerts appear above the status bar and collect here until you dismiss them or the session ends."
    }
    Repeater {
        model: center.server.trackedNotifications
        delegate: RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            NotificationCard {
                Layout.fillWidth: true
                notification: row.modelData
                accentColor: center.accentColor
                onClosed: row.modelData.dismiss()
            }
        }
    }
    TouchButton {
        Layout.fillWidth: true
        visible: center.count > 0
        text: "Clear all"
        destructive: true
        Accessible.name: "Clear all notifications"
        onClicked: center.clearAllRequested()
    }
    Text {
        Layout.fillWidth: true
        text: "Tessarchy does not persist notifications across sessions."
        color: Theme.textMuted
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
}
