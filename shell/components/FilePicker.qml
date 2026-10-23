pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland

// Touch file picker for apps' file dialogs on Phone/Tablet. tessarchy-portal
// asks for it (shell.qml's "picker" IPC target); the answer goes back on the
// request's reply FIFO: picked paths one per line, then an empty line. An
// empty line alone is a cancel.
PanelWindow {
    id: picker
    // { fifo, mode: "open"|"folder"|"save", multiple, folder, name, title, globs }
    property var request: null
    readonly property bool saving: request !== null && request.mode === "save"
    readonly property bool choosingFolder: request !== null && request.mode === "folder"
    property string folder: "/"
    property var selected: []
    property string confirmReplace: ""

    visible: request !== null
    color: Theme.background
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    WlrLayershell.namespace: "tessera-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    // The file name field needs the keyboard; nothing else takes focus.
    WlrLayershell.keyboardFocus: saving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function open(next) {
        if (request !== null)
            reply([]);
        selected = [];
        confirmReplace = "";
        folder = next.folder.length > 0 ? next.folder : Quickshell.env("HOME");
        nameField.text = next.name;
        request = next;
        // Only Save types; otherwise the keyboard just covers the list.
        if (next.mode !== "save" && Quickshell.env("TESSARCHY_OSK") === "1")
            Quickshell.execDetached(["tessarchy-osk", "hide"]);
    }
    function dismiss(fifo) {
        if (request !== null && request.fifo === fifo)
            request = null;
    }
    function reply(paths) {
        if (request === null)
            return;
        Quickshell.execDetached(["sh", "-c", '[ -p "$1" ] || exit 0; f=$1; shift; { for p; do printf "%s\\n" "$p"; done; echo; } > "$f"', "sh", request.fifo].concat(paths));
        request = null;
    }
    function join(dir, name) {
        return dir === "/" ? "/" + name : dir + "/" + name;
    }
    function parentOf(dir) {
        const cut = dir.lastIndexOf("/");
        return cut <= 0 ? "/" : dir.substring(0, cut);
    }
    function accept() {
        if (request === null)
            return;
        if (saving) {
            const name = nameField.text.trim();
            if (name.length === 0 || name.indexOf("/") >= 0)
                return;
            const path = join(folder, name);
            if (confirmReplace !== path && entries.indexOf("file://" + path) >= 0) {
                confirmReplace = path;
                return;
            }
            reply([path]);
        } else if (choosingFolder) {
            reply([folder]);
        } else if (selected.length > 0) {
            reply(selected);
        }
    }
    function tapped(path, isDir) {
        if (isDir) {
            folder = path;
            selected = [];
            confirmReplace = "";
        } else if (saving) {
            nameField.text = path.substring(path.lastIndexOf("/") + 1);
            confirmReplace = "";
        } else if (request.multiple) {
            const at = selected.indexOf(path);
            selected = at >= 0 ? selected.filter(p => p !== path) : selected.concat([path]);
        } else {
            reply([path]);
        }
    }

    FolderListModel {
        id: entries
        folder: "file://" + picker.folder
        showDirsFirst: true
        showHidden: false
        showFiles: !picker.choosingFolder
        showDotAndDotDot: false
        nameFilters: picker.request !== null && picker.request.globs.length > 0 ? picker.request.globs.split(";") : []
        sortCaseSensitive: false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TouchButton {
                text: "Cancel"
                implicitWidth: 96
                onClicked: picker.reply([])
            }
            Text { textFormat: Text.PlainText;
                Layout.fillWidth: true
                text: picker.request !== null && picker.request.title.length > 0 ? picker.request.title : picker.saving ? "Save" : "Open"
                color: Theme.text
                font.pixelSize: 17
                font.bold: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
            TouchButton {
                implicitWidth: picker.request !== null && picker.request.multiple ? 128 : 96
                selected: true
                text: picker.confirmReplace.length > 0 ? "Replace" : picker.saving ? "Save" : picker.choosingFolder ? "Select" : picker.request !== null && picker.request.multiple ? "Open (" + picker.selected.length + ")" : "Open"
                enabled: picker.saving ? nameField.text.trim().length > 0 : picker.choosingFolder || picker.selected.length > 0
                visible: picker.saving || picker.choosingFolder || (picker.request !== null && picker.request.multiple)
                onClicked: picker.accept()
            }
        }

        Text { textFormat: Text.PlainText;
            Layout.fillWidth: true
            visible: picker.confirmReplace.length > 0
            text: "Replace the existing file? Tap Replace again to confirm."
            color: Theme.danger
            font.pixelSize: 14
            wrapMode: Text.Wrap
        }

        TextField {
            id: nameField
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: picker.saving
            font.pixelSize: 16
            color: Theme.text
            placeholderText: "File name"
            placeholderTextColor: Theme.textMuted
            background: Rectangle {
                radius: Theme.radius("card", 12, height)
                color: Theme.surface
                border.color: nameField.activeFocus ? Theme.accent : Theme.selection
            }
            onTextChanged: picker.confirmReplace = ""
            onAccepted: picker.accept()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TouchButton {
                text: "Up"
                implicitWidth: 72
                enabled: picker.folder !== "/"
                onClicked: picker.tapped(picker.parentOf(picker.folder), true)
            }
            TouchButton {
                text: "Home"
                implicitWidth: 88
                onClicked: picker.tapped(Quickshell.env("HOME"), true)
            }
            Text { textFormat: Text.PlainText;
                Layout.fillWidth: true
                text: picker.folder
                color: Theme.textSecondary
                font.pixelSize: 14
                elide: Text.ElideLeft
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: entries
            boundsBehavior: Flickable.StopAtBounds
            delegate: ItemDelegate {
                id: row
                required property string fileName
                required property string filePath
                required property bool fileIsDir
                readonly property bool chosen: picker.selected.indexOf(filePath) >= 0
                width: ListView.view.width
                height: 56
                focusPolicy: Qt.NoFocus
                background: Rectangle {
                    color: row.down ? Qt.alpha(Theme.accent, 0.28) : row.chosen ? Qt.alpha(Theme.accent, 0.18) : "transparent"
                    radius: Theme.radius("card", 10, height)
                }
                contentItem: RowLayout {
                    spacing: 12
                    Text { textFormat: Text.PlainText;
                        text: row.fileIsDir ? "▸" : row.chosen ? "✓" : "·"
                        color: row.fileIsDir || row.chosen ? Theme.accent : Theme.textMuted
                        font.pixelSize: 20
                        Layout.preferredWidth: 20
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text { textFormat: Text.PlainText;
                        Layout.fillWidth: true
                        text: row.fileName
                        color: Theme.text
                        font.pixelSize: 16
                        elide: Text.ElideMiddle
                    }
                }
                onClicked: picker.tapped(row.filePath, row.fileIsDir)
            }
            Text { textFormat: Text.PlainText;
                anchors.centerIn: parent
                visible: list.count === 0
                text: entries.status === FolderListModel.Loading ? "" : picker.choosingFolder ? "No folders" : "Empty"
                color: Theme.textMuted
                font.pixelSize: 15
            }
        }
    }
}
