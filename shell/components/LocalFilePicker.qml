pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: picker
    required property var backend
    property string kind: "photo"
    signal selected(string file)
    signal canceled
    spacing: 10
    function open() { backend.request("browse", {kind: kind}); }
    RowLayout {
        Layout.fillWidth: true
        NavButton {
            text: "Parent folder"; symbol: "back"; showLabel: false
            Layout.fillWidth: false; Layout.preferredWidth: 48
            enabled: !picker.backend.busy
            onClicked: picker.backend.request("browse", {kind: picker.kind, folder: picker.backend.picker.parent})
        }
        Text { textFormat: Text.PlainText; text: picker.backend.picker.title || "Files"; color: Theme.accent; font.pixelSize: 20; Layout.fillWidth: true; elide: Text.ElideRight }
        TouchButton { text: "Cancel"; Layout.preferredWidth: 96; focusPolicy: Qt.StrongFocus; onClicked: picker.canceled() }
    }
    GlassField {
        id: folder
        placeholderText: "Open a folder or local file"
        onAccepted: {
            if (text.toLowerCase().match(picker.kind === "photo" ? /\.(png|jpe?g|webp)$/ : /\.mp3$/)) picker.selected(text);
            else picker.backend.request("browse", {kind: picker.kind, folder: text});
        }
    }
    TouchButton {
        text: "Open location"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
        enabled: !picker.backend.busy && folder.text.trim() !== ""
        onClicked: {
            if (folder.text.toLowerCase().match(picker.kind === "photo" ? /\.(png|jpe?g|webp)$/ : /\.mp3$/)) picker.selected(folder.text);
            else picker.backend.request("browse", {kind: picker.kind, folder: folder.text});
        }
    }
    Repeater {
        model: picker.backend.picker.entries || []
        delegate: TouchButton {
            required property var modelData
            text: (modelData.directory ? "▸  " : "") + modelData.name
            Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
            enabled: !picker.backend.busy
            onClicked: {
                if (modelData.directory) picker.backend.request("browse", {kind: picker.kind, folder: modelData.path});
                else picker.selected(modelData.path);
            }
        }
    }
    Text { textFormat: Text.PlainText; visible: !(picker.backend.picker.entries || []).length; text: "No matching files in this folder."; color: Theme.hintText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
}
