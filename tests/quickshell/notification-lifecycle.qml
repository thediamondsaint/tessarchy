import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "components"

// Only started by notification-lifecycle.py on a disposable private bus.
ShellRoot {
    id: root
    property bool muted: false
    property int deliveries: 0
    NotificationPopupQueue {
        id: popups
        trackedModel: server.trackedNotifications
    }
    NotificationServer {
        id: server
        onNotification: notification => {
            root.deliveries++;
            notification.tracked = true;
            if (!root.muted) popups.add(notification);
        }
    }
    IpcHandler {
        target: "notificationTest"
        function snapshot(): string {
            return JSON.stringify({
                deliveries: root.deliveries,
                popups: popups.items.map(n => n ? n.summary : "<destroyed>"),
                history: server.trackedNotifications.values.map(n => n.summary)
            });
        }
        function hideFirst(): void { popups.remove(popups.items[0]); }
        function dismissFirst(): void { popups.items[0].dismiss(); }
        function setMuted(value: bool): void { root.muted = value; }
    }
}
