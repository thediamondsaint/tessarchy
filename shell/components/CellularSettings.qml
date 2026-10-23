pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: page
    required property var backend
    property color accentColor: Theme.accent
    property var pending: null
    readonly property var cellular: backend.state.cellular
    spacing: 12
    Text { text: page.cellular.label; color: page.accentColor; font.pixelSize: 20; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    Text { text: "SIMs, cellular service and eSIM profiles"; color: Theme.hintText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    GlassCombo {
        visible: page.cellular.modems.length > 1
        model: page.cellular.modems; textRole: "name"
        Accessible.name: "Cellular modem"
        onActivated: { page.backend.selectedModem = page.cellular.modems[currentIndex].id; page.backend.request("status"); }
    }
    TouchButton {
        visible: page.cellular.available
        text: page.cellular.enabled ? "Turn cellular service off…" : "Turn cellular service on…"
        Layout.fillWidth: true; enabled: !page.backend.busy; focusPolicy: Qt.StrongFocus
        onClicked: page.pending = {action: "modem-power", enabled: !page.cellular.enabled, title: "Change cellular service?"}
    }
    Repeater {
        model: page.cellular.sims
        delegate: ColumnLayout {
            id: simCard
            required property var modelData
            Layout.fillWidth: true
            Text {
                text: simCard.modelData.name + " · " + simCard.modelData.type + (simCard.modelData.active ? " · Active" : "") + (simCard.modelData.suffix ? " · •••• " + simCard.modelData.suffix : "")
                color: Theme.itemText; font.pixelSize: 16; Layout.fillWidth: true; wrapMode: Text.WordWrap
            }
            Text { visible: !simCard.modelData.present; text: "Empty SIM slot"; color: Theme.hintText }
            TouchButton {
                visible: simCard.modelData.present && !simCard.modelData.active
                text: "Use SIM " + simCard.modelData.slot + "…"
                Layout.fillWidth: true; enabled: !page.backend.busy; focusPolicy: Qt.StrongFocus
                onClicked: page.pending = {action: "select-slot", slot: simCard.modelData.slot, title: "Switch active SIM?"}
            }
        }
    }
    RowLayout {
        visible: page.cellular.locked === 2
        Layout.fillWidth: true
        GlassField { id: pin; placeholderText: "SIM PIN"; echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; maximumLength: 8 }
        TouchButton {
            text: "Unlock"; Layout.preferredWidth: 100; enabled: !page.backend.busy && pin.text.length >= 4; focusPolicy: Qt.StrongFocus
            onClicked: { page.backend.request("unlock-sim", {pin: pin.text}); pin.text = ""; }
        }
    }
    Text { visible: page.cellular.locked > 2; text: "SIM requires carrier recovery. Use your carrier's PUK or supported recovery tools."; color: Theme.errorText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    Text { text: "eSIM"; color: page.accentColor; font { pixelSize: 11; bold: true; letterSpacing: 2 } }
    Text { text: page.backend.esim.label; color: Theme.hintText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    TouchButton { text: "Detect eSIM profiles"; Layout.fillWidth: true; enabled: !page.backend.busy; focusPolicy: Qt.StrongFocus; onClicked: page.backend.request("esim-list") }
    Repeater {
        model: page.backend.esim.profiles
        delegate: TouchButton {
            required property var modelData
            text: modelData.name + (modelData.enabled ? " · Enabled…" : " · Disabled…")
            Layout.fillWidth: true; enabled: !page.backend.busy; focusPolicy: Qt.StrongFocus
            onClicked: page.pending = {action: modelData.enabled ? "esim-disable" : "esim-enable", profile: modelData.id, title: modelData.enabled ? "Disable this eSIM profile?" : "Enable this eSIM profile?"}
        }
    }
    TouchButton {
        text: "Add or manage eSIM profiles"
        Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
        enabled: !!page.backend.state.esimManagerAvailable
        onClicked: Quickshell.execDetached(["lpa-gtk"])
    }
    Text { text: "Profile detection uses lpac and your configured eUICC reader. Add profiles with eSIM Manager (lpa-gtk)."; color: Theme.hintText; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    ColumnLayout {
        visible: page.pending !== null
        Layout.fillWidth: true
        Text { text: page.pending ? page.pending.title : ""; color: Theme.itemText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        Text { text: "This may interrupt cellular service."; color: Theme.hintText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        RowLayout {
            TouchButton { text: "Cancel"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: page.pending = null }
            TouchButton {
                text: "Confirm"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; enabled: !page.backend.busy
                onClicked: { const request = Object.assign({}, page.pending, {confirmed: true}); page.backend.request(request.action, request); page.pending = null; }
            }
        }
    }
    Text { text: page.backend.state.error || page.backend.state.notice || ""; visible: text.length > 0; color: page.backend.state.error ? Theme.errorText : page.accentColor; Layout.fillWidth: true; wrapMode: Text.WordWrap }
}
