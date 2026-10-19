import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: indicator
    required property string symbol
    required property string label
    property int strength: -1
    property string status: "unavailable"
    property string detail: ""
    property string badge: ""
    property bool uniform: false
    readonly property int level: strength < 0 ? 0 : Math.min(4, Math.ceil(Math.max(0, strength) / 25))
    readonly property bool unavailable: ["unavailable", "off", "blocked", "disconnected", "locked", "failed", "unmanaged"].indexOf(status) >= 0
    implicitWidth: 48
    implicitHeight: 48
    Layout.preferredWidth: 48
    Layout.preferredHeight: 48
    focusPolicy: Qt.NoFocus
    padding: 0
    background: Item {}
    Accessible.name: label + ", " + status + (detail ? ", " + detail : "") + (strength >= 0 ? ", " + strength + " percent signal" : ", signal unavailable")
    contentItem: Item {
        Image {
            objectName: "networkSignalGlyph"
            anchors.centerIn: parent
            width: 18; height: 18
            source: "../icons/" + indicator.symbol + "-level-" + indicator.level + ".svg"
            sourceSize.width: 18; sourceSize.height: 18
            opacity: indicator.uniform || !indicator.unavailable ? 1 : 0.5
        }
        Rectangle {
            visible: indicator.unavailable
            anchors.centerIn: parent
            width: 22; height: 1.5; radius: 1; rotation: -45
            color: indicator.uniform ? "#d0f3e9" : "#879caa"
        }
        Text {
            anchors.right: parent.right; anchors.top: parent.top
            text: indicator.status === "connecting" || indicator.status === "searching" ? "…" : indicator.badge
            textFormat: Text.PlainText; color: "#d0f3e9"; font { pixelSize: 10; bold: true }
        }
    }
}
