import QtQuick

// Navigation handle pill above the bottom gesture strip. `shown` is the only
// switch; shell.qml binds it to the showGestureHandle preference.
Rectangle {
    id: handle
    property bool shown: true
    property color accentColor: Theme.accent
    property bool reducedMotion: false
    // 0-1 swipe progress; the pill rises with the finger, then settles.
    property real progress: 0
    property real travel: 8
    visible: shown
    implicitWidth: 108
    implicitHeight: 4
    radius: height / 2
    color: Qt.alpha(accentColor, 0.75)
    Accessible.ignored: true
    transform: Translate {
        y: -handle.progress * handle.travel
        Behavior on y {
            enabled: !handle.reducedMotion
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }
}
