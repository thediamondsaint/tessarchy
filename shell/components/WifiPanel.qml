pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: panel
    required property var backend
    signal advancedRequested
    property color accentColor: "#a9e8d5"
    readonly property var wifi: backend.state.wifi
    property var target: null
    property string form: ""
    property string formDevice: ""
    property var forget: null
    property bool remember: true
    property bool autoconnect: true
    property string localError: ""
    readonly property string selectedSecurity: security.currentIndex >= 0 ? security.model[security.currentIndex].value : "wpa-psk"
    readonly property bool needsKeyboard: form !== ""
    spacing: 8

    function closeForm() { form = ""; target = null; password.text = ""; ssid.text = ""; localError = ""; }
    function openForm(kind, network) {
        closeForm(); security.currentIndex = 0; formDevice = wifi.device; form = kind; target = network || null;
        autoconnect = kind !== "hotspot"; remember = true;
    }
    function choose(network) {
        if (network.connected) { backend.request("wifi-disconnect", {device: wifi.device}); return; }
        if (network.profile || ["open", "owe"].indexOf(network.security) >= 0) {
            backend.request("wifi-connect", {device: wifi.device, accessPoint: network.id, profile: network.profile});
        } else if (["wpa-psk", "sae", "wep"].indexOf(network.security) < 0) {
            localError = "Configure enterprise Wi-Fi in Connections, then connect using its saved profile.";
        } else openForm("password", network);
    }
    function submit() {
        const values = {device: wifi.device, accessPoint: target ? target.id : "", password: password.text,
            hidden: form === "hidden", hotspot: form === "hotspot", ssid: ssid.text,
            security: form === "hotspot" ? "wpa-psk" : panel.selectedSecurity,
            remember: remember, autoconnect: autoconnect};
        password.text = "";
        if (backend.request("wifi-connect", values)) closeForm();
    }
    function scan() { if (wifi.device) backend.request("wifi-scan", {device: wifi.device}); }
    onVisibleChanged: { backend.watch(panel, visible); if (!visible) { closeForm(); forget = null; } }
    Component.onCompleted: backend.watch(panel, visible)
    Component.onDestruction: if (backend && typeof backend.watch === "function") backend.watch(panel, false)
    Connections {
        target: panel.backend
        function onStateChanged() {
            if (panel.target && !panel.wifi.networks.some(n => n.id === panel.target.id)) panel.closeForm();
            if (!panel.wifi.enabled || (panel.form !== "" && panel.formDevice !== panel.wifi.device)) panel.closeForm();
        }
    }
    Text {
        text: panel.wifi.label + (panel.wifi.strength >= 0 ? " · " + panel.wifi.strength + "%" : "")
        textFormat: Text.PlainText; color: panel.accentColor; font.pixelSize: 16
        Layout.fillWidth: true; wrapMode: Text.WordWrap
    }
    Text { text: panel.wifi.connectivity || "Unknown connectivity"; textFormat: Text.PlainText; color: "#a7bdc6"; Layout.fillWidth: true }
    Text {
        visible: !!panel.wifi.addresses && panel.wifi.addresses.length > 0
        text: (panel.wifi.addresses || []).join(" · ") + (panel.wifi.gateway ? " · Gateway " + panel.wifi.gateway : "")
        textFormat: Text.PlainText; color: "#a7bdc6"; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
    }
    GlassCombo {
        visible: panel.wifi.devices.length > 1
        model: panel.wifi.devices; textRole: "name"; Layout.fillWidth: true
        Accessible.name: "Wi-Fi adapter"
        onActivated: { panel.closeForm(); panel.backend.wifiDevice = panel.wifi.devices[currentIndex].id; panel.backend.refresh(); }
    }
    RowLayout {
        Layout.fillWidth: true
        TouchButton {
            text: "Scan"; Layout.fillWidth: true
            enabled: panel.wifi.available && panel.wifi.enabled && panel.wifi.hardwareEnabled && panel.wifi.status !== "hotspot" && !panel.backend.busy
            focusPolicy: Qt.StrongFocus; onClicked: panel.scan()
        }
        TouchButton {
            text: panel.wifi.status === "connecting" ? "Cancel connection" : "Disconnect"
            Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
            enabled: ["connected", "hotspot", "connecting", "failed"].indexOf(panel.wifi.status) >= 0 && !panel.backend.busy
            onClicked: panel.backend.request("wifi-disconnect", {device: panel.wifi.device})
        }
    }
    Text {
        visible: panel.wifi.enabled && panel.wifi.available && panel.wifi.networks.length === 0
        text: "No networks reported. Scan again or add a hidden network."
        color: "#a7bdc6"; Layout.fillWidth: true; wrapMode: Text.WordWrap
    }
    Repeater {
        model: panel.wifi.enabled ? panel.wifi.networks : []
        delegate: TouchButton {
            required property var modelData
            Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
            selected: modelData.connected
            enabled: !panel.backend.busy && panel.wifi.managed
            text: modelData.name + " · " + (modelData.strength >= 0 ? modelData.strength + "% · " : "") +
                (modelData.connected ? "Connected" : modelData.profile ? "Saved" : modelData.security)
            onClicked: panel.choose(modelData)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        TouchButton {
            text: "Hidden network"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
            enabled: panel.wifi.enabled && panel.wifi.available && !panel.backend.busy
            onClicked: panel.openForm("hidden")
        }
        TouchButton {
            text: "Hotspot"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
            enabled: panel.wifi.enabled && panel.wifi.canHotspot && !panel.backend.busy
            onClicked: panel.openForm("hotspot")
        }
    }
    ColumnLayout {
        visible: panel.form !== ""
        Layout.fillWidth: true
        Text {
            text: panel.target ? "Connect to " + panel.target.name : panel.form === "hotspot" ? "Share this device's connection" : "Hidden Wi-Fi network"
            textFormat: Text.PlainText; color: panel.accentColor; Layout.fillWidth: true; wrapMode: Text.WordWrap
        }
        GlassField {
            id: ssid; objectName: "networkSsid"
            visible: panel.form !== "password"; Layout.fillWidth: true
            placeholderText: "Network name"; maximumLength: 32; Accessible.name: "Network name"
        }
        GlassCombo {
            id: security
            visible: panel.form === "hidden"
            Layout.fillWidth: true
            textRole: "name"; currentIndex: 0
            model: [{name: "WPA/WPA2 Personal", value: "wpa-psk"}, {name: "WPA3 Personal", value: "sae"},
                    {name: "Enhanced open", value: "owe"}, {name: "Open", value: "open"}, {name: "WEP", value: "wep"}]
            Accessible.name: "Wi-Fi security"
        }
        GlassField {
            id: password; objectName: "networkPassword"
            visible: panel.form !== "hidden" || ["open", "owe"].indexOf(panel.selectedSecurity) < 0
            Layout.fillWidth: true; placeholderText: "Wi-Fi password"; echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText; maximumLength: 64
            Accessible.name: "Wi-Fi password"; onAccepted: panel.submit()
        }
        TouchButton { text: "Remember connection"; selected: panel.remember; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: panel.remember = !panel.remember }
        TouchButton { text: "Connect automatically"; selected: panel.autoconnect; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: panel.autoconnect = !panel.autoconnect }
        Text {
            visible: panel.form === "hotspot"
            text: "Starting a hotspot disconnects this adapter from its current Wi-Fi network."
            color: "#a7bdc6"; Layout.fillWidth: true; wrapMode: Text.WordWrap
        }
        RowLayout {
            TouchButton { text: "Cancel"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: panel.closeForm() }
            TouchButton { text: panel.form === "hotspot" ? "Start hotspot" : "Connect"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; enabled: !panel.backend.busy; onClicked: panel.submit() }
        }
    }
    Text { visible: panel.wifi.profiles.length > 0; text: "Saved connections"; color: panel.accentColor }
    Repeater {
        model: panel.wifi.profiles
        delegate: RowLayout {
            id: savedWifi
            required property var modelData
            Layout.fillWidth: true
            TouchButton {
                text: savedWifi.modelData.name; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; enabled: !panel.backend.busy && panel.wifi.enabled
                onClicked: panel.backend.request("wifi-connect", {device: panel.wifi.device, profile: savedWifi.modelData.id})
            }
            TouchButton { text: "Forget…"; Layout.preferredWidth: 100; focusPolicy: Qt.StrongFocus; enabled: !panel.backend.busy; onClicked: panel.forget = savedWifi.modelData }
        }
    }
    RowLayout {
        visible: panel.forget !== null
        TouchButton { text: "Cancel"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: panel.forget = null }
        TouchButton {
            text: "Forget saved connection"; destructive: true; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; enabled: !panel.backend.busy
            onClicked: { panel.backend.request("wifi-forget", {device: panel.wifi.device, profile: panel.forget.id, confirmed: true}); panel.forget = null; }
        }
    }
    TouchButton {
        text: "Advanced Wi-Fi settings"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus
        enabled: !!panel.backend.state.editorAvailable
        onClicked: panel.advancedRequested()
    }
    Text {
        visible: text !== ""; text: panel.localError || panel.backend.state.error || panel.backend.state.notice || ""
        textFormat: Text.PlainText; color: panel.localError || panel.backend.state.error ? "#efb6bd" : panel.accentColor
        Layout.fillWidth: true; wrapMode: Text.WordWrap
    }
}
