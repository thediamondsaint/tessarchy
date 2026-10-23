// Adapted from DMS / Dux LauncherRow.qml; Copyright (c) 2025 Avenge Media LLC.
// SPDX-License-Identifier: MIT; see ../third-party/dms/LICENSE and NOTICE.md.
pragma ComponentBehavior: Bound
import QtQuick

TouchButton {
    id: root
    property var item: null
    property string iconSource: ""
    property bool iconFailed: false
    readonly property real iconSize: 34
    readonly property string subtitle: item ? String(item.genericName || item.comment || "") : ""
    signal pointed()
    text: item ? String(item.name) : ""
    onIconSourceChanged: iconFailed = false
    implicitWidth: 520
    implicitHeight: 64
    padding: 0
    Accessible.name: text
    Accessible.description: subtitle
    background: Rectangle {
        radius: Theme.radius("button", 12, height)
        color: root.down ? Theme.tilePressed : root.selected ? Theme.selected(root.accentColor) : root.hovered ? Theme.glass : "transparent"
        border.width: root.selected ? Theme.borderWidth(1) : 0
        border.color: Theme.tileBorder
    }
    contentItem: Item {
        Image {
            id: iconRenderer
            width: root.iconSize
            height: root.iconSize
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            source: root.iconSource && !root.iconFailed ? root.iconSource : "../icons/browser.svg"
            sourceSize.width: root.iconSize * 2
            sourceSize.height: root.iconSize * 2
            fillMode: Image.PreserveAspectFit
            onStatusChanged: if (status === Image.Error) root.iconFailed = true
        }
        Item {
            id: textColumn
            anchors.left: iconRenderer.right
            anchors.leftMargin: 14
            anchors.right: rightContent.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: nameText.implicitHeight + (subText.visible ? subText.height + 3 : 0)
            Text {
                id: nameText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                text: root.text
                textFormat: Text.PlainText
                font.pixelSize: 17
                font.weight: Font.Medium
                color: Theme.text
                maximumLineCount: 1
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }
            Text {
                id: subText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: nameText.bottom
                anchors.topMargin: 3
                text: root.subtitle
                textFormat: Text.PlainText
                font.pixelSize: 12
                color: Theme.textSecondary
                maximumLineCount: 1
                elide: Text.ElideRight
                visible: root.subtitle.length > 0
                horizontalAlignment: Text.AlignLeft
            }
        }
        Text {
            id: rightContent
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            text: root.selected ? "↵" : ""
            color: Theme.textMuted
            font.pixelSize: 18
        }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onPositionChanged: root.pointed()
    }
}
