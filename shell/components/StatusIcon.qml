import QtQuick
import QtQuick.Layouts

Item {
    id: indicator
    required property string symbol
    required property string label
    // Negative means no backend/device; bind a real signal value here later.
    property real strength: -1
    property bool uniform: false
    // Top bars use a full touch target even when the glyph itself stays small.
    property bool touchMode: false
    // Mobile strip shows a steady medium signal when no radio backend reports
    // a real value, instead of a crossed-out glyph.
    property bool showFallback: false
    property int fallbackLevel: 2
    signal clicked
    readonly property bool reported: strength >= 0
    readonly property bool fallback: !reported && showFallback
    Layout.preferredWidth: touchMode ? 48 : uniform ? 28 : 18
    Layout.preferredHeight: 48
    Accessible.name: label + (reported || fallback ? " connected" : " unavailable")
    Accessible.role: Accessible.Button
    Rectangle {
        anchors.centerIn: parent
        width: 44
        height: 44
        radius: Theme.radius("button", 20, height)
        color: Qt.alpha(indicator.uniform ? Theme.text : Theme.surface, indicator.uniform ? 0.09 : 0.06)
        border.width: Theme.borderWidth(1)
        border.color: Qt.alpha(indicator.uniform ? Theme.text : Theme.accent, indicator.uniform ? 0.14 : 0.10)
        Icon {
            anchors.centerIn: parent
            symbol: indicator.fallback ? indicator.symbol + "-" + indicator.fallbackLevel : indicator.symbol
            size: indicator.uniform ? 20 : 18
            color: indicator.reported || indicator.fallback ? Theme.textSecondary : Theme.muted
            opacity: indicator.uniform || indicator.reported || indicator.fallback ? 1 : 0.55
        }
        Rectangle {
            visible: !indicator.reported && !indicator.fallback
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
        onClicked: indicator.clicked()
    }
}
