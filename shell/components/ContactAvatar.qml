import QtQuick

Rectangle {
    id: avatar
    property string name: ""
    property string photo: ""
    property color accentColor: Theme.accent
    implicitWidth: 48
    implicitHeight: 48
    radius: width / 2
    color: Qt.alpha(accentColor, 0.14)
    border.color: Qt.alpha(accentColor, 0.35)
    border.width: Theme.borderWidth(1)
    clip: true
    Image {
        id: picture
        anchors.fill: parent
        source: avatar.photo
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
    }
    Text {
        anchors.centerIn: parent
        visible: picture.status !== Image.Ready
        text: avatar.name.trim().slice(0, 1).toUpperCase() || "•"
        color: avatar.accentColor
        font { pixelSize: 22; weight: Font.DemiBold }
    }
}
