import QtQuick
import QtQuick.Layouts

TouchButton {
    id: control
    property string iconSource: ""
    property bool iconFailed: false
    onIconSourceChanged: iconFailed = false
    required property string symbol
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: 84
    focusPolicy: Qt.StrongFocus
    function activateFromKeyboard(event) {
        if (enabled && !event.isAutoRepeat) clicked();
        event.accepted = true;
    }
    Keys.onReturnPressed: event => control.activateFromKeyboard(event)
    Keys.onEnterPressed: event => control.activateFromKeyboard(event)
    background: Rectangle {
        radius: Theme.radius("tile", 12, height)
        color: "transparent"
        border.width: control.visualFocus ? 1 : 0
        border.color: control.accentColor
    }
    contentItem: ColumnLayout {
        spacing: 8
        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            source: control.iconSource && !control.iconFailed ? control.iconSource : "../icons/" + control.symbol + ".svg"
            sourceSize.width: 30
            sourceSize.height: 30
            fillMode: Image.PreserveAspectFit
            onStatusChanged: if (status === Image.Error) control.iconFailed = true
            opacity: control.down ? 0.65 : 1
        }
        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: control.text
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            color: Theme.tileText
            font.pixelSize: 12
        }
    }
}
