import QtQuick
import Quickshell
import "../../shell/AppPolicy.js" as Apps

ShellRoot {
    id: root
    property int revision: 0
    readonly property var applications: {
        root.revision;
        return Apps.applications(DesktopEntries.applications.values);
    }
    function report() {
        console.log("APP_INVENTORY:" + JSON.stringify(applications.map(entry =>
            ({id: entry.id, name: entry.name, icon: entry.icon, category: Apps.category(entry)}))));
    }
    onApplicationsChanged: report()
    Component.onCompleted: report()
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.revision++; }
    }
}
