pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: panel
    required property var backend
    signal advancedRequested
    property color accentColor: "#a9e8d5"
    readonly property var cellular: backend.state.cellular
    property bool editing: false
    property string formModem: ""
    onEditingChanged: if (editing) formModem = cellular.id
    Connections {
        target: panel.backend
        function onStateChanged() {
            if (panel.editing && (!panel.cellular.available || !panel.cellular.enabled || panel.formModem !== panel.cellular.id || panel.cellular.locked > 1)) panel.clearForm();
        }
    }
    property bool roaming: false
    property bool autoconnect: false
    property var forget: null
    spacing: 8
    function clearForm() { password.text = ""; username.text = ""; apn.text = ""; operatorCode.text = ""; editing = false; }
    function connectNew() {
        const values = {device: cellular.device, modem: cellular.id, name: "Mobile data", apn: apn.text,
            username: username.text, password: password.text, operator: operatorCode.text,
            allowRoaming: roaming, autoconnect: autoconnect, remember: true};
        password.text = "";
        if (backend.request("cellular-connect", values)) clearForm();
    }
    onVisibleChanged: { backend.watch(panel, visible); if (!visible) { clearForm(); forget = null; } }
    Component.onCompleted: backend.watch(panel, visible)
    Component.onDestruction: if (backend && typeof backend.watch === "function") backend.watch(panel, false)
    Text {
        text: "Mobile data"; color: panel.accentColor; font.pixelSize: 18; Layout.fillWidth: true
    }
    Text {
        text: panel.cellular.label + (panel.cellular.technology ? " · " + panel.cellular.technology : "") +
            (panel.cellular.roaming ? " · Roaming" : "") + (panel.cellular.strength >= 0 ? " · " + panel.cellular.strength + "%" : "")
        textFormat: Text.PlainText; color: "#d0dced"; Layout.fillWidth: true; wrapMode: Text.WordWrap
    }
    Text {
        text: "Data: " + (panel.cellular.dataStatus || "unavailable") + " · " + panel.backend.state.connectivity
        textFormat: Text.PlainText; color: "#a7bdc6"; Layout.fillWidth: true; wrapMode: Text.WordWrap
    }
    Text {
        visible: !!panel.cellular.dataError
        text: panel.cellular.dataError || ""; textFormat: Text.PlainText
        color: "#efb6bd"; Layout.fillWidth: true; wrapMode: Text.WordWrap
    }
    Text {
        visible: !!panel.cellular.addresses && panel.cellular.addresses.length > 0
        text: (panel.cellular.addresses || []).join(" · ")
        textFormat: Text.PlainText; color: "#a7bdc6"; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
    }
    GlassCombo {
        visible: panel.cellular.modems.length > 1
        model: panel.cellular.modems; textRole: "name"; Layout.fillWidth: true; Accessible.name: "Mobile data modem"
        onActivated: { panel.clearForm(); panel.backend.modem = panel.cellular.modems[currentIndex].id; panel.backend.refresh(); }
    }
    Text {
        visible: panel.cellular.available && !panel.cellular.managed
        text: "This modem is not managed by NetworkManager. SIM, calls and messages may still be available below."
        color: "#a7bdc6"; Layout.fillWidth: true; wrapMode: Text.WordWrap
    }
    TouchButton {
        text: panel.cellular.dataStatus === "connecting" ? "Cancel mobile data connection" : "Disconnect mobile data"
        Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
        enabled: !!panel.cellular.managed && ["connected", "connecting"].indexOf(panel.cellular.dataStatus) >= 0 && !panel.backend.busy
        onClicked: panel.backend.request("cellular-disconnect", {device: panel.cellular.device, modem: panel.cellular.id})
    }
    Repeater {
        model: panel.cellular.profiles
        delegate: RowLayout {
            id: savedData
            required property var modelData
            Layout.fillWidth: true
            TouchButton {
                text: savedData.modelData.name + (savedData.modelData.apn ? " · " + savedData.modelData.apn : " · Automatic APN")
                Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
                enabled: !!panel.cellular.managed && panel.cellular.registered && panel.cellular.enabled && panel.cellular.dataStatus !== "connecting" && !panel.backend.busy
                onClicked: panel.backend.request("cellular-connect", {device: panel.cellular.device, modem: panel.cellular.id, profile: savedData.modelData.id})
            }
            TouchButton { text: "Forget…"; Layout.preferredWidth: 100; focusPolicy: Qt.StrongFocus; enabled: !panel.backend.busy; onClicked: panel.forget = savedData.modelData }
        }
    }
    TouchButton {
        text: panel.editing ? "Cancel APN setup" : "Set up mobile data"
        Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
        enabled: !!panel.cellular.managed && panel.cellular.enabled && panel.cellular.locked <= 1 && !!panel.cellular.supportsApn && !panel.backend.busy
        onClicked: { if (panel.editing) panel.clearForm(); else panel.editing = true; }
    }
    ColumnLayout {
        visible: panel.editing
        Layout.fillWidth: true
        GlassField { id: apn; objectName: "mobileApn"; Layout.fillWidth: true; placeholderText: "APN (blank uses carrier settings)"; maximumLength: 100; Accessible.name: "Mobile data APN" }
        GlassField { id: username; objectName: "mobileUsername"; Layout.fillWidth: true; placeholderText: "Username (optional)"; maximumLength: 256; Accessible.name: "APN username" }
        GlassField { id: password; objectName: "apnPassword"; Layout.fillWidth: true; placeholderText: "Password (optional)"; echoMode: TextInput.Password; inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText; maximumLength: 256; Accessible.name: "APN password" }
        GlassField { id: operatorCode; Layout.fillWidth: true; placeholderText: "Operator MCC/MNC (blank selects automatically)"; maximumLength: 6; inputMethodHints: Qt.ImhDigitsOnly; Accessible.name: "Mobile network operator code" }
        TouchButton { text: "Allow data roaming"; selected: panel.roaming; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: panel.roaming = !panel.roaming }
        Text { visible: panel.roaming; text: "Roaming may incur carrier charges."; color: "#efc5a2"; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        TouchButton { text: "Connect automatically"; selected: panel.autoconnect; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: panel.autoconnect = !panel.autoconnect }
        TouchButton { text: "Save and connect"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; enabled: !panel.backend.busy; onClicked: panel.connectNew() }
    }
    RowLayout {
        visible: panel.forget !== null
        TouchButton { text: "Cancel"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: panel.forget = null }
        TouchButton {
            text: "Forget mobile data profile"; destructive: true; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; enabled: !panel.backend.busy
            onClicked: { panel.backend.request("cellular-forget", {device: panel.cellular.device, modem: panel.cellular.id, profile: panel.forget.id, confirmed: true}); panel.forget = null; }
        }
    }
    TouchButton { text: "Advanced connection settings"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; enabled: !!panel.backend.state.editorAvailable; onClicked: panel.advancedRequested() }
    Text {
        text: panel.backend.state.error || panel.backend.state.notice || ""; visible: text.length > 0
        textFormat: Text.PlainText; color: panel.backend.state.error ? "#efb6bd" : panel.accentColor
        Layout.fillWidth: true; wrapMode: Text.WordWrap
    }
}
