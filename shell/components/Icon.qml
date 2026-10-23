pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// A monochrome (white) SVG from ../icons tinted to the theme.
Image {
    id: icon
    required property string symbol
    property color color: Theme.textSecondary
    property int size: 24
    source: "../icons/" + symbol + ".svg"
    sourceSize.width: size
    sourceSize.height: size
    width: size
    height: size
    layer.enabled: true
    layer.effect: MultiEffect {
        colorization: 1.0
        colorizationColor: icon.color
    }
}
