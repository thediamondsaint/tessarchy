import QtQuick
import QtQuick.Controls
import "../StatusPolicy.js" as StatusPolicy

Item {
    id: indicator
    property bool present: false
    property real percentage: -1
    property string powerState: "unknown"
    readonly property bool reported: present && StatusPolicy.validFraction(percentage)
    readonly property bool charging: reported && powerState === "charging"
    readonly property string description: {
        if (!reported) return "Battery status unavailable";
        const percent = Math.round(percentage * 100) + "%";
        switch (powerState) {
        case "charging": return "Battery charging · " + percent;
        case "discharging": return "Battery discharging · " + percent;
        case "empty": return "Battery empty · " + percent;
        case "full": return "Battery fully charged · " + percent;
        case "pending-charge": return "Battery plugged in, not charging · " + percent;
        case "pending-discharge": return "Battery pending discharge · " + percent;
        default: return "Battery state unknown · " + percent;
        }
    }
    implicitWidth: 22
    implicitHeight: 22
    Accessible.name: description
    Accessible.role: Accessible.Indicator
    ToolTip.visible: hover.hovered
    ToolTip.text: description
    HoverHandler { id: hover }

    Item {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: indicator.width / 24
        Rectangle {
            x: 2; y: 6; width: 18; height: 12; radius: height / 4
            color: "transparent"
            border.width: 1.8
            border.color: Theme.text
            opacity: indicator.reported ? 1 : 0.35
        }
        Rectangle {
            x: 22; y: 10; width: 1.8; height: 4; radius: Math.min(width, height) / 2
            color: Theme.text
            opacity: indicator.reported ? 1 : 0.35
        }
        Rectangle {
            objectName: "batteryFill"
            x: 5; y: 9; width: indicator.reported ? 12 * indicator.percentage : 0; height: 6; radius: height / 6
            color: Theme.text
        }
        Canvas {
            objectName: "chargingBolt"
            anchors.fill: parent
            visible: indicator.charging
            property color foreground: Theme.text
            property color outline: Theme.background
            onForegroundChanged: requestPaint()
            onOutlineChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.beginPath();
                ctx.moveTo(14, 3); ctx.lineTo(8, 13); ctx.lineTo(12, 13);
                ctx.lineTo(10, 21); ctx.lineTo(17, 10); ctx.lineTo(13, 10);
                ctx.closePath();
                ctx.strokeStyle = outline; ctx.lineWidth = 2.5; ctx.stroke();
                ctx.fillStyle = foreground; ctx.fill();
            }
        }
        Text {
            anchors.centerIn: parent
            visible: !indicator.reported
            text: "?"
            color: Theme.textSecondary
            font.pixelSize: 12
            font.bold: true
        }
    }
}
