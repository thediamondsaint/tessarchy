import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control
    Layout.minimumWidth: 48
    Layout.minimumHeight: 56
    implicitWidth: 120
    implicitHeight: 56
    padding: 10
    focusPolicy: Qt.NoFocus
    property color accentColor: "#a9e8d5"
    property bool destructive: false
    property bool selected: false
    // Keep text as the accessible name while displaying a glyph.
    property string symbol: ""
    Layout.preferredWidth: symbol !== "" ? 56 : -1
    contentItem: Item {
        Image {
            anchors.centerIn: parent
            visible: control.symbol !== ""
            source: control.symbol !== "" ? "../icons/" + control.symbol + ".svg" : ""
            sourceSize.width: 24; sourceSize.height: 24
            opacity: control.enabled ? 1 : 0.35
        }
        Text {
            anchors.fill: parent
            visible: control.symbol === ""
            textFormat: Text.PlainText
            text: control.text
            color: control.enabled ? "#f0f5f5" : "#7a8589"
            font.pixelSize: 16
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
    background: Rectangle {
        radius: 12
        color: control.down ? Qt.alpha(control.accentColor, 0.28) : control.destructive ? "#88502b38" : control.selected ? Qt.alpha(control.accentColor, 0.18) : "#501c2c43"
        border.color: control.destructive ? "#bf7383" : control.selected ? control.accentColor : "#504d687d"
    }
    Accessible.name: text
}
