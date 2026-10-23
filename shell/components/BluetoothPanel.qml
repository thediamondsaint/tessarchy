pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../LayoutPolicy.js" as Policy

ColumnLayout {
    id: panel
    required property var adapter
    property color accentColor: Theme.accent

    readonly property bool bluetoothAvailable: !!panel.adapter
    readonly property bool bluetoothOn: panel.bluetoothAvailable && panel.adapter.enabled
    readonly property var devices: {
        if (!panel.adapter || !panel.adapter.devices)
            return [];
        const list = panel.adapter.devices.values.slice();
        list.sort(function (a, b) {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return panel.nameFor(a).localeCompare(panel.nameFor(b));
        });
        return list;
    }

    spacing: 8

    property var discoveryAdapter: null
    readonly property bool shouldDiscover: visible && bluetoothOn
    function releaseDiscovery() {
        if (discoveryAdapter) discoveryAdapter.discovering = false;
        discoveryAdapter = null;
    }
    function syncDiscovery() {
        if (discoveryAdapter && (discoveryAdapter !== adapter || !shouldDiscover)) releaseDiscovery();
        if (shouldDiscover && !adapter.discovering) {
            discoveryAdapter = adapter;
            adapter.discovering = true;
        }
    }
    Component.onCompleted: syncDiscovery()
    Component.onDestruction: releaseDiscovery()
    onShouldDiscoverChanged: syncDiscovery()
    onAdapterChanged: syncDiscovery()

    function busy(device) {
        return device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting;
    }

    function nameFor(device) {
        return String(device.name || device.deviceName || device.address);
    }

    function isPaired(device) {
        return device.paired || device.bonded;
    }

    function labelFor(device) {
        const name = panel.nameFor(device);
        const battery = Policy.btBatteryLabel(device.batteryAvailable, device.battery);
        if (device.state === BluetoothDeviceState.Connecting)
            return name + " · connecting…" + battery;
        if (device.state === BluetoothDeviceState.Disconnecting)
            return name + " · disconnecting…" + battery;
        if (device.connected)
            return name + " · connected" + battery;
        if (device.blocked)
            return name + " · blocked" + battery;
        if (panel.isPaired(device))
            return name + " · paired" + battery;
        return name + " · pair in an external Bluetooth manager" + battery;
    }

    function activate(device) {
        if (!bluetoothOn || devices.indexOf(device) < 0 || busy(device) || device.blocked) return;
        const action = Policy.btAction(device.connected, panel.isPaired(device));
        if (action === "disconnect")
            device.disconnect();
        else if (action === "connect")
            device.connect();
    }

    Text {
        visible: !panel.bluetoothAvailable
        textFormat: Text.PlainText
        text: "Bluetooth · no adapter available"
        color: Theme.textMuted
        font.pixelSize: 13
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    TouchButton {
        visible: panel.bluetoothAvailable
        text: panel.adapter && panel.adapter.state === BluetoothAdapterState.Blocked ? "Bluetooth · blocked" : panel.bluetoothOn ? "Bluetooth · on" : "Bluetooth · off"
        focusPolicy: Qt.TabFocus
        enabled: panel.adapter && [BluetoothAdapterState.Enabled, BluetoothAdapterState.Disabled].indexOf(panel.adapter.state) >= 0
        selected: panel.bluetoothOn
        accentColor: panel.accentColor
        Layout.fillWidth: true
        Accessible.name: text
        onClicked: panel.adapter.enabled = !panel.adapter.enabled
    }
    Text {
        textFormat: Text.PlainText
        visible: panel.bluetoothAvailable && panel.bluetoothOn && panel.devices.length === 0
        text: panel.adapter && panel.adapter.discovering ? "Discovering nearby devices…" : "No known devices"
        color: Theme.textMuted
        font.pixelSize: 13
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: panel.bluetoothAvailable && panel.bluetoothOn ? panel.devices : []
        delegate: TouchButton {
            focusPolicy: Qt.TabFocus
            required property var modelData
            readonly property bool actionable: Policy.btAction(modelData.connected, panel.isPaired(modelData)) !== "none"
            text: panel.labelFor(modelData)
            selected: modelData.connected
            enabled: actionable && !panel.busy(modelData) && !modelData.blocked
            accentColor: panel.accentColor
            Layout.fillWidth: true
            Accessible.name: text
            onClicked: panel.activate(modelData)
        }
    }
}
