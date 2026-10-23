pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: app
    required property var backend
    property color accentColor: Theme.accent
    property string tab: "keypad"
    property string editingId: ""
    property string photo: ""
    property bool editing: false
    property bool browsing: false
    property bool confirmDelete: false
    signal messageRequested(string number)
    signal simRequested
    spacing: 12
    readonly property var activeCalls: (backend.state.cellular.calls || []).filter(c => c.state !== 7)
    Connections {
        target: app.backend
        function onCompleted(action, success) {
            if (action === "save-contact" && success) app.editing = false;
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: [{id: "keypad", title: "Keypad", icon: "dialpad"}, {id: "contacts", title: "Contacts", icon: "contacts"}, {id: "recents", title: "Recents", icon: "recents"}]
            delegate: NavButton {
                required property var modelData
                text: modelData.title; symbol: modelData.icon
                selected: app.tab === modelData.id
                showLabel: true; implicitHeight: 56
                focusPolicy: Qt.StrongFocus
                onClicked: { app.tab = modelData.id; app.editing = false; }
            }
        }
    }
    TouchButton {
        text: app.backend.state.cellular.label + "  ›"
        Layout.fillWidth: true
        focusPolicy: Qt.StrongFocus
        onClicked: app.simRequested()
    }
    Repeater {
        model: app.activeCalls
        delegate: ColumnLayout {
            id: callRow
            required property var modelData
            Layout.fillWidth: true
            Text {
                textFormat: Text.PlainText
                text: app.backend.contactName(callRow.modelData.number) + " · " + (["Preparing", "Dialing", "Ringing", "Incoming call", "Connected", "Held", "Waiting"][callRow.modelData.state] || "Call")
                color: app.accentColor; font.pixelSize: 18
                wrapMode: Text.WrapAnywhere; Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                NavButton {
                    visible: callRow.modelData.state === 3
                    text: "Answer"; symbol: "call"; showLabel: true
                    enabled: !app.backend.busy
                    focusPolicy: Qt.StrongFocus
                    onClicked: app.backend.request("answer", {call: callRow.modelData.id})
                }
                NavButton {
                    text: "End call"; symbol: "call-end"; showLabel: true
                    enabled: !app.backend.busy
                    focusPolicy: Qt.StrongFocus
                    onClicked: app.backend.request("hangup", {call: callRow.modelData.id})
                }
            }
        }
    }
    ColumnLayout {
        visible: app.tab === "keypad"
        Layout.fillWidth: true
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            GlassField { id: dialNumber; placeholderText: "Phone number"; inputMethodHints: Qt.ImhDialableCharactersOnly; maximumLength: 32 }
            NavButton {
                text: "Delete digit"; symbol: "backspace"; showLabel: false
                Layout.fillWidth: false; Layout.preferredWidth: 48
                focusPolicy: Qt.StrongFocus
                onClicked: dialNumber.text = dialNumber.text.slice(0, -1)
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 420
            Layout.alignment: Qt.AlignHCenter
            columns: 3; columnSpacing: 10; rowSpacing: 8
            Repeater {
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
                delegate: TouchButton {
                    required property string modelData
                    text: modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    focusPolicy: Qt.StrongFocus
                    onClicked: {
                        if (app.activeCalls.length && app.activeCalls[0].state === 4)
                            app.backend.request("dtmf", {call: app.activeCalls[0].id, tone: modelData});
                        else dialNumber.text += modelData;
                    }
                    onPressAndHold: { if (modelData === "0" && dialNumber.text === "") dialNumber.text = "+"; }
                }
            }
        }
        NavButton {
            text: "Call"; symbol: "call"; showLabel: true
            Layout.fillWidth: true; implicitHeight: 56
            accentColor: app.accentColor
            selected: true; focusPolicy: Qt.StrongFocus
            enabled: !app.backend.busy && !!app.backend.state.cellular.voice && !!app.backend.state.cellular.registered && dialNumber.text.length > 0 && app.activeCalls.length === 0
            onClicked: app.backend.request("dial", {number: dialNumber.text})
        }
    }
    ColumnLayout {
        visible: app.tab === "contacts"
        Layout.fillWidth: true
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            GlassField { id: search; placeholderText: "Search contacts" }
            NavButton {
                text: "New contact"; symbol: "add"; showLabel: false
                Layout.fillWidth: false; Layout.preferredWidth: 48
                focusPolicy: Qt.StrongFocus
                onClicked: { app.editingId = ""; contactName.text = ""; contactNumber.text = dialNumber.text; app.photo = ""; app.editing = true; app.confirmDelete = false; contactName.forceActiveFocus(); }
            }
        }
        ColumnLayout {
            visible: app.editing && !app.browsing
            Layout.fillWidth: true
            RowLayout {
                ContactAvatar { name: contactName.text; photo: app.photo; Layout.preferredWidth: 64; Layout.preferredHeight: 64 }
                TouchButton { text: "Choose photo"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: { app.browsing = true; photoPicker.open(); } }
            }
            GlassField { id: contactName; placeholderText: "Name"; maximumLength: 120 }
            GlassField { id: contactNumber; placeholderText: "Phone number"; inputMethodHints: Qt.ImhDialableCharactersOnly; maximumLength: 32 }
            RowLayout {
                TouchButton { text: "Cancel"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: app.editing = false }
                TouchButton {
                    text: "Save"; Layout.fillWidth: true; selected: true; focusPolicy: Qt.StrongFocus
                    enabled: !app.backend.busy && contactName.text.trim() !== "" && contactNumber.text.trim() !== ""
                    onClicked: app.backend.request("save-contact", {id: app.editingId, name: contactName.text, number: contactNumber.text, photo: app.photo})
                }
            }
            TouchButton {
                visible: app.editingId !== ""
                text: app.confirmDelete ? "Confirm delete contact" : "Delete contact…"
                destructive: true; Layout.fillWidth: true; enabled: !app.backend.busy; focusPolicy: Qt.StrongFocus
                onClicked: {
                    if (app.confirmDelete) { app.backend.request("delete-contact", {id: app.editingId}); app.editing = false; }
                    else app.confirmDelete = true;
                }
            }
        }
        LocalFilePicker {
            id: photoPicker
            backend: app.backend
            visible: app.browsing
            kind: "photo"
            Layout.fillWidth: true
            onSelected: file => { app.photo = file; app.browsing = false; }
            onCanceled: app.browsing = false
        }
        Repeater {
            model: app.editing ? [] : app.backend.state.contacts.filter(c => (c.name + " " + c.number).toLowerCase().indexOf(search.text.toLowerCase()) >= 0)
            delegate: RowLayout {
                id: contactRow
                required property var modelData
                Layout.fillWidth: true
                ContactAvatar { name: contactRow.modelData.name; photo: contactRow.modelData.photo }
                TouchButton {
                    text: contactRow.modelData.name
                    contentItem: Column {
                        spacing: 4
                        Text { textFormat: Text.PlainText; text: contactRow.modelData.name; color: Theme.itemText; font { pixelSize: 15; weight: Font.DemiBold }
                            width: parent.width; elide: Text.ElideRight }
                        Text { textFormat: Text.PlainText; text: contactRow.modelData.number; color: Theme.hintText; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight }
                    }
                    Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
                    onClicked: { app.editingId = contactRow.modelData.id; contactName.text = contactRow.modelData.name; contactNumber.text = contactRow.modelData.number; app.photo = contactRow.modelData.photo; app.editing = true; app.confirmDelete = false; }
                }
                NavButton { text: "Dial contact"; symbol: "call"; showLabel: false; Layout.fillWidth: false; Layout.preferredWidth: 48; focusPolicy: Qt.StrongFocus; onClicked: { dialNumber.text = contactRow.modelData.number; app.tab = "keypad"; } }
                NavButton { text: "Message contact"; symbol: "messages"; showLabel: false; Layout.fillWidth: false; Layout.preferredWidth: 48; focusPolicy: Qt.StrongFocus; onClicked: app.messageRequested(contactRow.modelData.number) }
            }
        }
        Text { textFormat: Text.PlainText; visible: !app.editing && app.backend.state.contacts.length === 0; text: "Keep your people close. Add your first contact."; color: Theme.hintText; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }
    ColumnLayout {
        visible: app.tab === "recents"
        Layout.fillWidth: true
        Repeater {
            model: app.backend.state.history
            delegate: TouchButton {
                required property var modelData
                text: app.backend.contactName(modelData.number) + " · " + modelData.timestamp
                Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
                onClicked: { dialNumber.text = modelData.number; app.tab = "keypad"; }
            }
        }
        Text { textFormat: Text.PlainText; visible: app.backend.state.history.length === 0; text: "Your recent calls will appear here."; color: Theme.hintText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    }
    Text { textFormat: Text.PlainText; text: app.backend.state.error || app.backend.state.notice || ""; visible: text.length > 0; color: app.backend.state.error ? Theme.errorText : app.accentColor; Layout.fillWidth: true; wrapMode: Text.WordWrap }
}
