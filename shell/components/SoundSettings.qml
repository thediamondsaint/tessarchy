pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page
    required property var backend
    property color accentColor: Theme.accent
    property bool browsing: false
    spacing: 12
    Text { text: "SOUNDS"; color: page.accentColor; font { pixelSize: 11; bold: true; letterSpacing: 2 } }
    Text { text: "VoidRing · Your sound, your signal."; color: Theme.subtitleText; font.pixelSize: 15; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    LocalFilePicker {
        id: picker
        backend: page.backend
        kind: "tone"
        visible: page.browsing
        Layout.fillWidth: true
        onSelected: file => { page.backend.request("import-tone", {file: file}); page.browsing = false; }
        onCanceled: page.browsing = false
    }
    ColumnLayout {
        visible: !page.browsing
        Layout.fillWidth: true
        spacing: 12
    Repeater {
        model: [{kind: "ringtone", name: "Incoming calls", defaultTone: "Starcast"}, {kind: "message", name: "Messages", defaultTone: "Stage"}, {kind: "alarm", name: "Alarm sound", defaultTone: "MoonLight"}]
        delegate: ColumnLayout {
            id: choice
            required property var modelData
            readonly property var tones: [{id: "silent", name: "Silent", path: ""}].concat(page.backend.state.tones)
            Layout.fillWidth: true
            Text { text: choice.modelData.name; color: Theme.itemText; font.pixelSize: 15 }
            RowLayout {
                Layout.fillWidth: true
                GlassCombo {
                    id: selector
                    model: choice.tones; textRole: "name"
                    currentIndex: choice.tones.findIndex(t => t.id === (page.backend.state.sounds[choice.modelData.kind] || choice.modelData.defaultTone))
                    enabled: !page.backend.busy
                    Accessible.name: choice.modelData.name + " sound"
                    onActivated: page.backend.request("set-sound", {kind: choice.modelData.kind, tone: choice.tones[currentIndex].id})
                }
                NavButton {
                    text: "Preview " + choice.modelData.name; symbol: "media-play"; showLabel: false
                    Layout.fillWidth: false; Layout.preferredWidth: 48
                    focusPolicy: Qt.StrongFocus
                    enabled: !!page.backend.state.playerAvailable && selector.currentIndex > 0
                    onClicked: page.backend.preview(choice.tones[selector.currentIndex].path)
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        TouchButton { text: "Import MP3"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; enabled: !page.backend.busy; onClicked: { page.browsing = true; picker.open(); } }
        TouchButton { text: "Stop preview"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: page.backend.preview("") }
    }
    Text { visible: !page.backend.state.playerAvailable; text: "Install ffmpeg to preview and play alert sounds."; color: Theme.hintText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    Text { text: "Alarm sound is saved for alarm apps. Incoming calls ring until answered or ended; new SMS messages use the selected message tone."; color: Theme.hintText; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12 }
    }
}
