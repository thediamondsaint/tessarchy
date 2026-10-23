pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../LayoutPolicy.js" as Policy

ColumnLayout {
    id: panel
    property var sink: null
    property var devices: []
    property var streams: []
    property bool backendAvailable: false
    property color accentColor: Theme.accent
    signal outputRequested(var node)
    spacing: 6

    function usable(node) { return !!node && node.ready && !!node.audio; }
    function selectOutput(node) {
        if (backendAvailable && devices.indexOf(node) >= 0 && usable(node) && node !== sink) outputRequested(node);
    }
    function setStreamVolume(node, value) {
        if (backendAvailable && streams.indexOf(node) >= 0 && usable(node) && Number.isFinite(value)) node.audio.volume = Math.max(0, Math.min(1, value));
    }
    function toggleStreamMuted(node) {
        if (backendAvailable && streams.indexOf(node) >= 0 && usable(node)) node.audio.muted = !node.audio.muted;
    }
    Text {
        text: !panel.backendAvailable ? "Audio service unavailable" : panel.usable(panel.sink) ? "Output · " + Policy.nodeLabel(panel.sink.description, panel.sink.nickname, panel.sink.name) : "No audio output connected"
        textFormat: Text.PlainText
        color: Theme.text
        Layout.fillWidth: true
        wrapMode: Text.WrapAnywhere
    }
    Text {
        textFormat: Text.PlainText
        visible: panel.devices.length > 1
        text: "OUTPUT DEVICE"
        color: Theme.textMuted
        font {
            pixelSize: 11
            letterSpacing: 2
        }
    }
    Repeater {
        model: panel.devices
        delegate: TouchButton {
            required property var modelData
            visible: panel.devices.length > 1
            selected: modelData === panel.sink
            accentColor: panel.accentColor
            Layout.fillWidth: true
            text: Policy.nodeLabel(modelData.description, modelData.nickname, modelData.name)
            Accessible.name: "Use output device " + text
            focusPolicy: Qt.TabFocus
            enabled: panel.usable(modelData)
            onClicked: panel.selectOutput(modelData)
        }
    }
    Text {
        textFormat: Text.PlainText
        visible: panel.streams.length > 0
        text: "APPS"
        color: Theme.textMuted
        font {
            pixelSize: 11
            letterSpacing: 2
        }
    }
    Repeater {
        model: panel.streams
        delegate: ColumnLayout {
            id: streamRow
            required property var modelData
            readonly property string streamName: Policy.streamLabel(streamRow.modelData.properties["application.name"], streamRow.modelData.properties["media.name"], streamRow.modelData.name)

            Layout.fillWidth: true
            spacing: 2
            Text {
                textFormat: Text.PlainText
                text: ((panel.usable(streamRow.modelData) && streamRow.modelData.audio.muted) ? "Muted · " : "") + streamRow.streamName
                color: Theme.text
                Layout.fillWidth: true
                wrapMode: Text.WrapAnywhere
            }
            RowLayout {
                Layout.fillWidth: true
                LevelSlider {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 3
                    from: 0
                    to: 1
                    value: panel.usable(streamRow.modelData) ? streamRow.modelData.audio.volume : 0
                    enabled: panel.usable(streamRow.modelData)
                    accentColor: panel.accentColor
                    Accessible.name: "Volume for " + streamRow.streamName
                    onMoved: panel.setStreamVolume(streamRow.modelData, value)
                }
                TouchButton {
                    enabled: panel.usable(streamRow.modelData)
                    focusPolicy: Qt.TabFocus
                    text: (panel.usable(streamRow.modelData) && streamRow.modelData.audio.muted) ? "Unmute" : "Mute"
                    accentColor: panel.accentColor
                    Layout.preferredWidth: 1
                    Accessible.name: ((panel.usable(streamRow.modelData) && streamRow.modelData.audio.muted) ? "Unmute " : "Mute ") + streamRow.streamName
                    onClicked: panel.toggleStreamMuted(streamRow.modelData)
                }
            }
        }
    }
}
