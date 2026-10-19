pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Touch handle between the two apps of a Tablet split (see tessarchy.split in
// session/hyprland.lua). Hyprland does the tiling; this only sends it commands.
// Drag to resize, double-tap for 50/50, Swap trades sides, Unsplit leaves.
PanelWindow {
    id: divider
    property color accentColor: "#a9e8d5"
    property bool allowed: true
    readonly property int thickness: 48
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var monitorInfo: monitor ? monitor.lastIpcObject : null
    readonly property int originX: monitorInfo && monitorInfo.x !== undefined ? monitorInfo.x : 0
    readonly property int originY: monitorInfo && monitorInfo.y !== undefined ? monitorInfo.y : 0
    readonly property int workspaceId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    // The two split windows on this monitor's workspace, first = left/top.
    readonly property var pair: {
        const found = [];
        for (const toplevel of Hyprland.toplevels.values) {
            const o = toplevel.lastIpcObject;
            if (!o || !o.at || !o.size || !o.workspace || o.workspace.id !== workspaceId || o.floating)
                continue;
            if ((o.tags || []).indexOf("split") >= 0)
                found.push(o);
        }
        found.sort((a, b) => a.at[0] !== b.at[0] ? a.at[0] - b.at[0] : a.at[1] - b.at[1]);
        return found.length === 2 ? found : [];
    }
    readonly property bool active: allowed && pair.length === 2
    readonly property bool sideBySide: active && pair[0].at[0] !== pair[1].at[0]
    // Pair rectangle and boundary, in this screen's logical coordinates.
    readonly property int pairX: active ? pair[0].at[0] - originX : 0
    readonly property int pairY: active ? pair[0].at[1] - originY : 0
    readonly property int pairW: active ? (sideBySide ? pair[1].at[0] + pair[1].size[0] - pair[0].at[0] : pair[0].size[0]) : 1
    readonly property int pairH: active ? (sideBySide ? pair[0].size[1] : pair[1].at[1] + pair[1].size[1] - pair[0].at[1]) : 1
    // Midpoint of the gap between the two apps.
    readonly property int boundary: active ? Math.round(sideBySide ? (pair[0].size[0] + pair[1].at[0] - pair[0].at[0]) / 2 : (pair[0].size[1] + pair[1].at[1] - pair[0].at[1]) / 2) : 0
    property bool dragging: false
    property real dragRatio: 0.5
    // Touch keeps reporting positions relative to where the bar was pressed,
    // so the surface holds still during a drag; the apps resize underneath.
    property int heldLeft: 0
    property int heldTop: 0

    function hypr(code) {
        Quickshell.execDetached(["hyprctl", "eval", code]);
        refresh.restart();
    }

    visible: active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "tessera-split"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        top: true
        left: true
    }
    margins.left: dragging ? heldLeft : sideBySide ? pairX + boundary - thickness / 2 : pairX
    margins.top: dragging ? heldTop : sideBySide ? pairY : pairY + boundary - thickness / 2
    implicitWidth: sideBySide ? thickness : pairW
    implicitHeight: sideBySide ? pairH : thickness

    Timer {
        id: refresh
        interval: 120
        onTriggered: Hyprland.refreshToplevels()
    }
    // Window geometry and tags come from Hyprland's client list, which is
    // only fetched on request; resizes emit no event, so refresh after ours.
    Component.onCompleted: Hyprland.refreshToplevels()
    Connections {
        target: Hyprland
        function onRawEvent() {
            refresh.restart();
        }
    }
    Timer {
        id: liveResize
        interval: 120
        repeat: true
        running: divider.dragging
        onTriggered: divider.hypr("tessarchy.ratio(" + divider.dragRatio.toFixed(3) + ")")
    }

    Rectangle {
        anchors.fill: parent
        // Opaque so the home screen's clock never shows through the gap
        // (upstream status bar tint).
        color: "#101b30"
        Rectangle {
            anchors.centerIn: parent
            width: divider.sideBySide ? 6 : parent.width
            height: divider.sideBySide ? parent.height : 6
            color: Qt.alpha(divider.accentColor, divider.dragging ? 0.9 : 0.55)
        }
    }

    MouseArea {
        anchors.fill: parent
        property bool moved: false
        property real pressAt: 0
        property real startOffset: 0 // bar's start, from the pair's start
        property real total: 1
        onPressed: mouse => {
            moved = false;
            pressAt = divider.sideBySide ? mouse.x : mouse.y;
            startOffset = divider.boundary - divider.thickness / 2;
            total = divider.sideBySide ? divider.pairW : divider.pairH;
            divider.dragRatio = divider.boundary / total;
        }
        onPositionChanged: mouse => {
            const along = divider.sideBySide ? mouse.x : mouse.y;
            if (!divider.dragging) {
                if (Math.abs(along - pressAt) < 12)
                    return;
                moved = true;
                divider.heldLeft = divider.sideBySide ? divider.pairX + divider.boundary - divider.thickness / 2 : divider.pairX;
                divider.heldTop = divider.sideBySide ? divider.pairY : divider.pairY + divider.boundary - divider.thickness / 2;
                divider.dragging = true;
            }
            divider.dragRatio = Math.max(0.2, Math.min(0.8, (startOffset + along) / total));
        }
        onReleased: {
            if (divider.dragging)
                divider.hypr("tessarchy.ratio(" + divider.dragRatio.toFixed(3) + ")");
            divider.dragging = false;
        }
        onCanceled: divider.dragging = false
        onDoubleClicked: {
            if (!moved)
                divider.hypr("tessarchy.ratio(0.5)");
        }
    }

    // Swap / Unsplit, centred on the bar.
    GridLayout {
        visible: !divider.dragging
        anchors.centerIn: parent
        flow: divider.sideBySide ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 16
        columnSpacing: 16
        Repeater {
            model: [
                { symbol: "swap", name: "Swap apps", code: "tessarchy.swap()" },
                { symbol: "close", name: "Leave split", code: "tessarchy.unsplit()" }
            ]
            delegate: Rectangle {
                id: action
                required property var modelData
                implicitWidth: divider.thickness
                implicitHeight: divider.thickness
                radius: divider.thickness / 2
                color: tap.pressed ? Qt.lighter("#351c2c43", 1.4) : "#351c2c43"
                border.width: 2
                border.color: Qt.alpha(divider.accentColor, 0.7)
                Accessible.role: Accessible.Button
                Accessible.name: modelData.name
                Image {
                    anchors.centerIn: parent
                    source: "../icons/" + action.modelData.symbol + ".svg"
                    sourceSize.width: 24
                    sourceSize.height: 24
                }
                MouseArea {
                    id: tap
                    anchors.fill: parent
                    onClicked: divider.hypr(action.modelData.code)
                }
            }
        }
    }
}
