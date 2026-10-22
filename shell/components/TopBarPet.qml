pragma ComponentBehavior: Bound
import QtQuick

// A tiny, icon-only Tessa companion for the empty span in touch bars. It is
// deliberately local artwork: no service, network request, or extra runtime
// dependency is needed for the idle animation or reactions.
Item {
    id: pet
    property bool reducedMotion: false
    property bool engaged: false
    property int attention: 0
    property color accentColor: Theme.accent
    signal clicked
    implicitWidth: 56
    implicitHeight: 56
    Accessible.role: Accessible.Button
    Accessible.name: engaged ? "Tessa companion is active" : "Tessa companion"

    onAttentionChanged: if (!reducedMotion) reaction.restart()
    onEngagedChanged: if (!reducedMotion) reaction.restart()
    onReducedMotionChanged: {
        if (reducedMotion) {
            idle.stop();
            reaction.stop();
            petGlyph.y = 0;
            petGlyph.rotation = 0;
            petGlyph.scale = 1;
        } else {
            idle.start();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius("button", 20, height)
        color: pet.engaged ? Qt.alpha(pet.accentColor, 0.24) : Theme.glass
        border.width: Theme.borderWidth(1)
        border.color: pet.engaged ? Qt.alpha(pet.accentColor, 0.72) : Theme.glassBorder
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.text, pet.engaged ? 0.18 : 0.12) }
            GradientStop { position: 0.52; color: Theme.glass }
            GradientStop { position: 1; color: Qt.alpha(Theme.darkerBackground, 0.22) }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Math.max(0, parent.radius - 2)
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(pet.accentColor, pet.engaged ? 0.34 : 0.12)
        }
    }

    Item {
        id: petGlyph
        anchors.centerIn: parent
        width: 30
        height: 30
        Image {
            anchors.fill: parent
            source: "../artwork/tessarchy-mark.svg"
            sourceSize: Qt.size(64, 64)
            smooth: true
        }
        Rectangle {
            width: 5
            height: 5
            radius: Math.min(width, height) / 2
            color: pet.accentColor
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -2
            anchors.topMargin: -2
            visible: pet.engaged
        }
    }

    SequentialAnimation {
        id: idle
        running: !pet.reducedMotion
        loops: Animation.Infinite
        NumberAnimation { target: petGlyph; property: "y"; to: -2; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { target: petGlyph; property: "y"; to: 2; duration: 1200; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        id: reaction
        NumberAnimation { target: petGlyph; property: "scale"; to: 1.16; duration: 100; easing.type: Easing.OutCubic }
        NumberAnimation { target: petGlyph; property: "rotation"; to: -8; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: petGlyph; property: "rotation"; to: 8; duration: 140; easing.type: Easing.InOutCubic }
        NumberAnimation { target: petGlyph; property: "rotation"; to: 0; duration: 100; easing.type: Easing.OutCubic }
        NumberAnimation { target: petGlyph; property: "scale"; to: 1; duration: 140; easing.type: Easing.OutCubic }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: pet.clicked()
    }
}
