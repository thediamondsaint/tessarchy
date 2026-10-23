import QtQuick
import QtQuick.Layouts
import "../StatusPolicy.js" as StatusPolicy

Item {
    id: indicator
    required property string symbol
    required property string label
    // Strength is normalized; negative or invalid data is unavailable.
    property real strength: -1
    property bool uniform: false
    // Top bars use a full touch target even when the glyph itself stays small.
    property bool touchMode: false
    property bool pressed: false
    property bool hovered: false
    property int touchSlot: 48
    signal clicked
    readonly property int level: StatusPolicy.signalLevel(strength)
    readonly property bool reported: level >= 0
    Layout.preferredWidth: touchMode ? touchSlot : uniform ? 28 : 18
    Layout.preferredHeight: 48
    Accessible.name: label + (reported ? " signal " + Math.round(strength * 100) + "%" : " unavailable")
    Accessible.role: Accessible.Button
    Rectangle {
        anchors.centerIn: parent
        width: 44
        height: 44
        radius: Theme.radius("button", 20, height)
        color: indicator.pressed ? Qt.alpha(Theme.accent, 0.24) : indicator.hovered ? Qt.alpha(Theme.accent, 0.12) : indicator.uniform ? Qt.alpha(Theme.text, 0.11) : Theme.glass
        border.width: Theme.borderWidth(1)
        border.color: indicator.pressed ? Theme.accent : indicator.hovered ? Qt.alpha(Theme.accent, 0.46) : Qt.alpha(indicator.uniform ? Theme.text : Theme.accent, indicator.uniform ? 0.18 : 0.16)
        scale: indicator.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Math.max(0, parent.radius - 2)
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.text, indicator.pressed ? 0.24 : 0.10)
        }
        Image {
            objectName: "signalLevelImage"
            anchors.centerIn: parent
            width: indicator.uniform ? 20 : 18
            height: width
            source: "../icons/" + indicator.symbol + "-level-" + Math.max(0, indicator.level) + ".svg"
            sourceSize.width: width
            sourceSize.height: height
            opacity: indicator.reported ? 1 : 0.55
        }
        Rectangle {
            objectName: "unavailableSlash"
            visible: !indicator.reported
            anchors.centerIn: parent
            width: 22
            height: 1.5
            radius: Theme.radius("progress", 1, height)
            rotation: -45
            color: indicator.uniform ? Theme.textSecondary : Theme.muted
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: indicator.hovered = true
        onExited: indicator.hovered = false
        onPressed: indicator.pressed = true
        onReleased: indicator.pressed = false
        onCanceled: indicator.pressed = false
        onClicked: indicator.clicked()
    }
    focus: false
    activeFocusOnTab: true
    Keys.onReturnPressed: indicator.clicked()
    Keys.onSpacePressed: indicator.clicked()
}
