import QtQuick

// Ephemeral views only; the server model remains notification history truth.
QtObject {
    id: queue
    required property var trackedModel
    property var items: []

    function prune() {
        const live = queue.trackedModel ? queue.trackedModel.values : [];
        const next = queue.items.filter(n => n && live.indexOf(n) !== -1);
        // Unrelated history changes must not rebuild popup delegates/timers.
        if (next.length !== queue.items.length)
            queue.items = next;
    }
    function add(notification) {
        // onNotification runs before the server inserts the tracked object.
        // tracked=true requests retention; model membership is not ready yet.
        if (!notification || !notification.tracked)
            return;
        // Defensively deduplicate callers; native replacements update in place.
        const next = queue.items.filter(n => n && n !== notification);
        next.unshift(notification);
        queue.items = next.slice(0, 3);
    }
    function remove(notification) {
        queue.items = queue.items.filter(n => n !== notification);
    }
    onTrackedModelChanged: queue.prune()
    property Connections modelConnection: Connections {
        target: queue.trackedModel
        function onValuesChanged() { queue.prune(); }
    }
}
