import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../OskDismissPolicy.js" as Osk

Scope {
    id: watcher
    property bool enabled: false
    property var rectangles: []
    function refresh() {
        if (!enabled) rectangles = [];
        else if (query && !query.running) query.running = true;
    }
    onEnabledChanged: refresh()
    Component.onCompleted: refresh()
    Timer {
        interval: 500
        running: watcher.enabled
        repeat: true
        onTriggered: watcher.refresh()
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openlayer", "closelayer", "monitoradded", "monitorremoved", "configreloaded"].indexOf(event.name) >= 0)
                watcher.refresh();
        }
    }
    Process {
        id: query
        command: ["hyprctl", "repl", Osk.query()]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    watcher.rectangles = watcher.enabled && Array.isArray(result) ? result : [];
                } catch (error) {
                    watcher.rectangles = [];
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) watcher.rectangles = [];
        }
    }
}
