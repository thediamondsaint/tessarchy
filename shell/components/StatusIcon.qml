import QtQuick
import QtQuick.Layouts

Item {
    id: indicator
    required property string symbol
    required property string label
    // Negative means no reading; `available` distinguishes a present-but-idle
    // backend from a missing one.
    property real strength: -1
    property bool available: strength >= 0
    Layout.preferredWidth: 18
    Layout.preferredHeight: 20
    Accessible.name: label + (strength < 0 ? (available ? " disconnected" : " unavailable") : " connected")
    Image {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: "../icons/" + indicator.symbol + ".svg"
        sourceSize.width: 18
        sourceSize.height: 18
        opacity: indicator.available ? 1 : 0.35
    }
    Rectangle {
        visible: !indicator.available
        anchors.centerIn: parent
        width: 22
        height: 1.5
        radius: 1
        rotation: -45
        color: "#879caa"
    }
}
