pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: app
    required property var backend
    property color accentColor: Theme.accent
    property string recipient: ""
    readonly property bool wide: width >= 600
    readonly property var threads: {
        const list = [];
        for (const message of backend.state.messages.slice().reverse()) if (list.indexOf(message.number) < 0) list.push(message.number);
        return list;
    }
    spacing: 12
    Connections {
        target: app.backend
        function onCompleted(action, success) { if (action === "send-sms" && success) compose.text = ""; }
    }
    Text { textFormat: Text.PlainText; text: app.backend.state.cellular.label; color: Theme.hintText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    RowLayout {
        Layout.fillWidth: true
        GlassField { id: recipient; text: app.recipient; placeholderText: "Phone number"; inputMethodHints: Qt.ImhDialableCharactersOnly; onTextEdited: app.recipient = text; maximumLength: 32 }
        NavButton { text: "New conversation"; symbol: "add"; showLabel: false; Layout.fillWidth: false; Layout.preferredWidth: 48; focusPolicy: Qt.StrongFocus; onClicked: { app.recipient = ""; recipient.forceActiveFocus(); } }
    }
    GlassCombo {
        Layout.fillWidth: true; Layout.minimumHeight: 48
        visible: app.backend.state.contacts.length > 0
        model: app.backend.state.contacts
        textRole: "name"
        displayText: currentIndex >= 0 ? currentText : "Choose a contact"
        onActivated: app.recipient = app.backend.state.contacts[currentIndex].number
        Accessible.name: "Message a contact"
    }
    GridLayout {
        columns: app.wide ? 2 : 1
        Layout.fillWidth: true
        columnSpacing: 20; rowSpacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: app.wide ? 220 : 1
            visible: app.wide || app.recipient === ""
            Repeater {
                model: app.threads
                delegate: TouchButton {
                    required property string modelData
                    text: app.backend.contactName(modelData)
                    selected: app.recipient === modelData
                    Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
                    onClicked: app.recipient = modelData
                }
            }
            Text { textFormat: Text.PlainText; visible: app.threads.length === 0; text: "Start a conversation. Your SMS threads stay here."; color: Theme.hintText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: app.wide ? 420 : 1
            visible: app.recipient !== ""
            Text { textFormat: Text.PlainText; text: app.backend.contactName(app.recipient); color: app.accentColor; font.pixelSize: 20; Layout.fillWidth: true; elide: Text.ElideRight }
            Repeater {
                model: app.backend.state.messages.filter(m => m.number === app.recipient)
                delegate: Rectangle {
                    id: messageCard
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: bubble.implicitHeight + 24
                    radius: Theme.radius("card", 18, height)
                    color: messageCard.modelData.incoming ? Theme.messageIncoming : Qt.alpha(app.accentColor, 0.15)
                    border.width: Theme.borderWidth(1)
                    border.color: Qt.alpha(app.accentColor, 0.12)
                    Column {
                        id: bubble
                        x: 12; y: 12; width: parent.width - 24; spacing: 8
                        Text { text: messageCard.modelData.text; textFormat: Text.PlainText; color: Theme.itemText; font.pixelSize: 16; width: parent.width; wrapMode: Text.WrapAnywhere }
                        Text { textFormat: Text.PlainText; text: messageCard.modelData.status + (messageCard.modelData.timestamp ? " · " + messageCard.modelData.timestamp : ""); color: Theme.captionText; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
                    }
                }
            }
            TextArea {
                id: compose
                placeholderText: "Message"
                placeholderTextColor: Theme.captionText; color: Theme.itemText
                font.pixelSize: 16
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                Layout.fillWidth: true; Layout.minimumHeight: 104
                padding: 14; selectByMouse: true
                background: Rectangle { radius: Theme.radius("field", 18, height); color: Theme.glass; border.width: Theme.borderWidth(1); border.color: compose.activeFocus ? app.accentColor : Theme.inputBorder }
                Accessible.name: "Message text"
            }
            NavButton {
                text: "Send SMS"; symbol: "send"; showLabel: true; selected: true
                implicitHeight: 56; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
                enabled: !app.backend.busy && !!app.backend.state.cellular.sms && !!app.backend.state.cellular.registered && compose.text.trim().length > 0 && compose.text.length <= 1600
                onClicked: app.backend.request("send-sms", {number: app.recipient, text: compose.text})
            }
            Text { textFormat: Text.PlainText; text: compose.text.length + "/1600 · SMS"; color: Theme.captionText; font.pixelSize: 11 }
        }
    }
    Text { textFormat: Text.PlainText; text: app.backend.state.error || app.backend.state.notice || ""; visible: text.length > 0; color: app.backend.state.error ? Theme.errorText : app.accentColor; Layout.fillWidth: true; wrapMode: Text.WordWrap }
}
