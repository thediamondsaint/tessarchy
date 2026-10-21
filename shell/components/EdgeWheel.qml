pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: dial
    property string placement: "bottom"
    readonly property bool vertical: placement !== "bottom"
    property bool canPan: true
    property bool reducedMotion: false
    property real pending: 0
    property real travel: 0
    property bool recentlyUsed: false
    property bool gestureActive: false
    readonly property bool dragging: gestureActive && dragArea.pressed
    signal started()
    signal moved(int delta)
    signal settled()
    signal canceled()
    implicitWidth: vertical ? 64 : 280
    implicitHeight: vertical ? 440 : 64
    clip: true
    opacity: !canPan ? 0.35 : dragging || recentlyUsed ? 1 : 0.94
    Behavior on opacity { NumberAnimation { duration: dial.reducedMotion ? 0 : 180 } }
    Accessible.name: vertical ? "Vertical window wheel" : "Horizontal window slider"

    function flush() {
        const delta = Math.round(pending);
        pending -= delta;
        if (delta !== 0) moved(delta);
    }
    function cancel() {
        gestureActive = false;
        pending = 0;
        travel = 0;
        frame.stop();
        canceled();
    }
    onVisibleChanged: if (!visible) cancel()
    onCanPanChanged: if (!canPan) cancel()
    onPlacementChanged: cancel()
    Timer { id: frame; interval: 16; repeat: true; onTriggered: dial.flush() }
    Timer { id: idle; interval: 3000; onTriggered: dial.recentlyUsed = false }
    Canvas {
        id: glass
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.beginPath();
            if (dial.vertical) {
                const cx = dial.placement === "left" ? 0 : width;
                const rx = width - 9;
                const ry = height / 2 - 9;
                ctx.save();
                ctx.translate(cx, height / 2);
                ctx.scale(rx, ry);
                ctx.arc(0, 0, 1, 0, Math.PI * 2);
                ctx.restore();
            } else {
                const x = 8, y = 12, w = width - 16, h = height - 20, r = h / 2;
                ctx.moveTo(x + r, y);
                ctx.lineTo(x + w - r, y);
                ctx.quadraticCurveTo(x + w, y, x + w, y + r);
                ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
                ctx.lineTo(x + r, y + h);
                ctx.quadraticCurveTo(x, y + h, x, y + r);
                ctx.quadraticCurveTo(x, y, x + r, y);
            }
            ctx.closePath();
            ctx.fillStyle = Qt.darker(Theme.darkBackground, 1.6);
            ctx.shadowColor = Theme.wheelGlow;
            ctx.shadowBlur = dial.dragging ? 20 : 13;
            ctx.fill();
            ctx.lineWidth = 1.3;
            ctx.strokeStyle = Qt.alpha(Theme.wheelGlow, 0.85);
            ctx.stroke();
        }
        Connections {
            target: Theme
            function onWheelGlowChanged() { glass.requestPaint(); }
            function onDarkBackgroundChanged() { glass.requestPaint(); }
        }
        Connections { target: dial; function onDraggingChanged() { glass.requestPaint(); } }
    }
    Repeater {
        model: 25
        delegate: Rectangle {
            required property int index
            readonly property real pitch: dial.vertical ? (dial.height - 56) / 24 : 11
            readonly property real tick: index - 12 + (dial.travel % pitch) / pitch
            readonly property real fade: Math.max(0, 1 - Math.abs(tick) / (dial.vertical ? 12 : (dial.width - 48) / 22))
            readonly property bool major: index % 2 === 0
            width: dial.vertical ? (major ? 23 : 14) * (0.65 + fade * 0.35) : (major ? 3 : 2)
            height: dial.vertical ? (major ? 3 : 2) : (major ? 19 : 12) * (0.65 + fade * 0.35)
            x: dial.vertical ? (dial.placement === "left" ? 23 : dial.width - 23) - width / 2 : dial.width / 2 + tick * 11 - width / 2
            y: dial.vertical ? dial.height / 2 + tick * pitch - height / 2 : dial.height / 2 + 2 - height / 2
            radius: Theme.radius("button", 2, height)
            color: major ? Qt.lighter(Theme.wheelGlow, 1.3) : Qt.alpha(Theme.wheelGlow, 0.7)
            opacity: fade
        }
    }
    Item {
        x: dial.vertical ? (dial.placement === "left" ? 23 : dial.width - 23) - width / 2 : dial.width / 2 - width / 2
        y: dial.height / 2 + (dial.vertical ? 0 : 2) - height / 2
        width: dial.vertical ? 32 : 6
        height: dial.vertical ? 6 : 28
        Repeater {
            model: 3
            delegate: Rectangle {
                required property int index
                anchors.centerIn: parent
                width: parent.width + index * 7
                height: parent.height + index * 7
                radius: Theme.radius("button", 7, height)
                color: Qt.alpha(Theme.wheelGlow, index === 0 ? 1 : index === 1 ? 0.25 : 0.08)
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius("button", 3, height)
            color: Theme.text
        }
    }
    Rectangle {
        visible: !dial.vertical
        anchors.horizontalCenter: parent.horizontalCenter
        y: 2
        width: 38; height: 3
        radius: Theme.radius("button", 2, height)
        color: Theme.wheelGlow
    }
    MouseArea {
        id: dragArea
        objectName: "tapeDrag"
        anchors.fill: parent
        enabled: dial.canPan
        preventStealing: true
        property real lastPosition: 0
        Accessible.name: dial.vertical ? "Drag up or down to browse windows" : "Drag left or right to browse windows"
        onPressed: mouse => {
            dial.gestureActive = true;
            lastPosition = dial.vertical ? mouse.y : mouse.x;
            dial.pending = 0;
            dial.recentlyUsed = true;
            idle.stop();
            dial.started();
            frame.start();
        }
        onPositionChanged: mouse => {
            if (!pressed || !dial.gestureActive) return;
            const position = dial.vertical ? mouse.y : mouse.x;
            const delta = position - lastPosition;
            dial.pending += delta;
            dial.travel += delta;
            lastPosition = position;
        }
        onReleased: {
            if (!dial.gestureActive) return;
            dial.gestureActive = false;
            frame.stop();
            dial.flush();
            dial.pending = 0;
            dial.travel = 0;
            dial.settled();
            idle.restart();
        }
        onCanceled: dial.cancel()
    }
}
