import QtQuick
import QtQuick.Effects

Item {
    Image {
        id: wallpaper
        anchors.fill: parent
        source: "../artwork/aurora-fold.png"
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: true
        blurMax: 64
        blur: 1
        autoPaddingEnabled: false
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.darkerBackground, 0.38)
    }
}
