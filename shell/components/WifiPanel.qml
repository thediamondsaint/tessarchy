pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import "../LayoutPolicy.js" as Policy

// Wi-Fi networks backed by NetworkManager through Quickshell's Networking
// service. The device scans only while this panel is visible with the radio
// on; tapping connects saved and open networks, disconnects the connected
// one, and opens a password prompt for unsaved secured networks. A password
// handed to NetworkManager is never stored here: the field is cleared before
// the attempt and on cancel, and cancel sends nothing.
ColumnLayout {
    id: panel
    required property var device
    property color accentColor: "#a9e8d5"
    property var promptNetwork: null
    property bool promptFieldShown: false
    property string errorText: ""

    readonly property bool wifiAvailable: !!panel.device
    readonly property bool wifiOn: panel.wifiAvailable && Networking.wifiEnabled
    readonly property bool wifiHardwareOn: panel.wifiAvailable && Networking.wifiHardwareEnabled
    readonly property bool promptOpen: panel.promptNetwork !== null
    readonly property var networks: {
        if (!panel.device || !panel.device.networks)
            return [];
        const list = panel.device.networks.values.slice();
        list.sort(function (a, b) {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
        return list;
    }

    spacing: 8

    // Scan ownership: the radio scans only while the panel is visible and on.
    // Hiding the panel releases the scanner and any open password prompt.
    function syncScanner() {
        if (panel.device)
            panel.device.scannerEnabled = panel.visible && panel.wifiOn;
        if (!panel.visible)
            panel.closePrompt();
    }
    Component.onCompleted: syncScanner()
    onVisibleChanged: syncScanner()
    onDeviceChanged: syncScanner()
    onWifiOnChanged: syncScanner()

    function openSecurity(network) {
        return network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe;
    }
    function labelFor(network) {
        const signal = Policy.signalPercent(network.signalStrength) + "%";
        if (network.connected)
            return network.name + " · " + signal + " · connected";
        if (network.state === ConnectionState.Connecting)
            return network.name + " · " + signal + " · connecting…";
        if (network.known)
            return network.name + " · " + signal + " · saved";
        if (panel.openSecurity(network))
            return network.name + " · " + signal + " · open";
        return network.name + " · " + signal + " · password required";
    }
    function request(network) {
        panel.errorText = "";
        // A connection attempt in flight is not re-issued; NetworkManager
        // times out on its own and reports back through the state.
        if (network.state === ConnectionState.Connecting) {
            panel.closePrompt();
            return;
        }
        const action = Policy.wifiAction(network.connected, network.known, panel.openSecurity(network));
        if (action === "disconnect") {
            panel.closePrompt();
            network.disconnect();
        } else if (action === "connect") {
            panel.closePrompt();
            network.connect();
        } else if (panel.promptNetwork === network) {
            panel.closePrompt();
        } else {
            panel.promptNetwork = network;
        }
    }
    function closePrompt() {
        panel.promptNetwork = null;
        panel.promptFieldShown = false;
        pskField.text = "";
    }
    function submitPsk() {
        const network = panel.promptNetwork;
        if (!network)
            return;
        const psk = pskField.text;
        if (psk.length < 8) {
            panel.errorText = "Wi-Fi passwords are at least 8 characters.";
            return;
        }
        panel.errorText = "";
        pskField.text = "";
        panel.promptNetwork = null;
        panel.promptFieldShown = false;
        network.connectWithPsk(psk);
    }

    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: 14
        color: "#d0dced"
        text: {
            if (!panel.wifiAvailable)
                return "Wi-Fi · no NetworkManager backend";
            if (!panel.wifiHardwareOn)
                return "Wi-Fi · blocked by the hardware switch";
            return panel.wifiOn ? "Wi-Fi · on" : "Wi-Fi · off";
        }
    }
    TouchButton {
        Layout.fillWidth: true
        visible: panel.wifiAvailable
        selected: panel.wifiOn
        enabled: panel.wifiHardwareOn
        accentColor: panel.accentColor
        text: panel.wifiOn ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
        Accessible.description: "Toggle the Wi-Fi radio"
        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
    }
    Text {
        Layout.fillWidth: true
        visible: panel.wifiOn && panel.networks.length === 0
        text: "Scanning for networks…"
        color: "#a7bdc6"
        font.pixelSize: 12
    }
    Repeater {
        model: panel.wifiOn ? panel.networks : []
        delegate: TouchButton {
            required property var modelData
            readonly property var network: modelData
            Layout.fillWidth: true
            selected: network.connected
            accentColor: panel.accentColor
            text: panel.labelFor(network)
            Accessible.description: network.connected ? "Disconnect this network" : "Connect to this network"
            onClicked: panel.request(network)
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: panel.promptOpen
        spacing: 6
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: "#f0f5ff"
            font.pixelSize: 14
            text: panel.promptNetwork ? "Password for " + panel.promptNetwork.name : ""
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 56
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#401c2c43"
                border.color: pskField.activeFocus ? Qt.alpha(panel.accentColor, 0.6) : "#504d687d"
            }
            TextInput {
                id: pskField
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 16
                color: "#f0f5ff"
                echoMode: panel.promptFieldShown ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                selectByMouse: true
                onAccepted: panel.submitPsk()
                onVisibleChanged: if (visible && panel.promptOpen) forceActiveFocus()
                Keys.onEscapePressed: panel.closePrompt()
            }
            Text {
                anchors.verticalCenter: pskField.verticalCenter
                anchors.left: pskField.left
                anchors.leftMargin: 12
                visible: pskField.text.length === 0
                text: "Wi-Fi password"
                color: "#8da7b9"
                font.pixelSize: 16
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TouchButton {
                Layout.fillWidth: true
                accentColor: panel.accentColor
                text: "Connect"
                Accessible.description: "Send the password and connect"
                onClicked: panel.submitPsk()
            }
            TouchButton {
                Layout.fillWidth: true
                selected: panel.promptFieldShown
                accentColor: panel.accentColor
                text: panel.promptFieldShown ? "Hide" : "Show"
                Accessible.description: "Toggle password visibility on screen"
                onClicked: panel.promptFieldShown = !panel.promptFieldShown
            }
            TouchButton {
                Layout.fillWidth: true
                destructive: true
                accentColor: panel.accentColor
                text: "Cancel"
                Accessible.description: "Close without connecting"
                onClicked: panel.closePrompt()
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: panel.errorText !== ""
        wrapMode: Text.WordWrap
        text: panel.errorText
        color: "#ebbbbd"
        font.pixelSize: 12
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Passwords go to NetworkManager, which stores the profile; this panel clears the field and keeps no copy."
        color: "#99afbe"
        font.pixelSize: 11
    }
}
