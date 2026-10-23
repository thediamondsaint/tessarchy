import QtQuick
import "../LayoutPolicy.js" as Policy

// Recognises one navigation gesture that starts on a screen-edge strip.
// Wayland keeps delivering a touch to the surface it began on, so the swipe
// is tracked after the finger leaves the thin strip.
MouseArea {
    id: area
    // "bottom", "left" or "right".
    required property string edge
    signal gesture(string action)
    property real startX: 0
    property real startY: 0
    property real dx: 0
    property real dy: 0
    property real stillX: 0
    property real stillY: 0
    property double stillSince: 0
    // Recents may fire while the finger is still down; release then does nothing.
    property bool fired: false
    // Upward travel as a 0-1 fraction of the Home distance, for handle feedback.
    readonly property real progress: pressed && edge === "bottom" ? Math.max(0, Math.min(1, -dy / Policy.GESTURE_DISTANCE)) : 0
    preventStealing: true
    Accessible.ignored: true

    function heldMs() {
        return Date.now() - stillSince;
    }
    onPressed: mouse => {
        startX = mouse.x;
        startY = mouse.y;
        dx = 0;
        dy = 0;
        stillX = mouse.x;
        stillY = mouse.y;
        stillSince = Date.now();
        fired = false;
        holdTimer.restart();
    }
    onPositionChanged: mouse => {
        dx = mouse.x - startX;
        dy = mouse.y - startY;
        if (Math.abs(mouse.x - stillX) > Policy.GESTURE_STILL || Math.abs(mouse.y - stillY) > Policy.GESTURE_STILL) {
            stillX = mouse.x;
            stillY = mouse.y;
            stillSince = Date.now();
            holdTimer.restart();
        }
    }
    onReleased: mouse => {
        holdTimer.stop();
        if (!fired) {
            const action = Policy.classifyGesture(edge, mouse.x - startX, mouse.y - startY, heldMs());
            if (action !== "none") gesture(action);
        }
        dx = 0;
        dy = 0;
    }
    onCanceled: {
        holdTimer.stop();
        dx = 0;
        dy = 0;
    }
    Timer {
        id: holdTimer
        interval: Policy.GESTURE_HOLD
        onTriggered: {
            if (!area.pressed || area.fired) return;
            if (Policy.classifyGesture(area.edge, area.dx, area.dy, area.heldMs()) === "recents") {
                area.fired = true;
                area.gesture("recents");
            }
        }
    }
}
