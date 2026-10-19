import QtQuick
import Quickshell.Io

QtObject {
    id: backend
    property var state: ({available: false, connectivity: "Unknown", error: "", notice: "",
        wifi: {available: false, enabled: false, hardwareEnabled: false, strength: -1, status: "unavailable", label: "Wi-Fi unavailable", devices: [], networks: [], profiles: []},
        cellular: {available: false, enabled: false, hardwareEnabled: false, strength: -1, status: "unavailable", label: "Cellular unavailable", modems: [], profiles: []},
        airplane: {available: false, enabled: false, label: "Unavailable"}})
    property string wifiDevice: ""
    property string modem: ""
    property var views: []
    property var pending: ({})
    property string lastError: ""
    property int epoch: 0
    property int readEpoch: -1
    property bool automatic: true
    readonly property bool busy: writer.running
    readonly property bool refreshing: reader.running
    readonly property bool details: views.length > 0
    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../helpers/networking.py").toString().replace("file://", ""))
    signal completed(string action, bool success)

    function watch(view, active) {
        const next = views.filter(item => item && item !== view);
        if (active) next.push(view);
        views = next;
        if (active) refresh();
    }
    function query() { return {action: "status", wifiDevice: wifiDevice, modem: modem, details: details}; }
    function accept(text, actionResult) {
        try {
            const result = JSON.parse(text);
            if (!result.wifi || !result.cellular || !Array.isArray(result.wifi.devices) || !Array.isArray(result.cellular.modems)) return false;
            if (actionResult) lastError = result.error || "";
            else if (lastError && !result.error) result.error = lastError;
            state = result;
            return true;
        } catch (error) { return false; }
    }
    function refresh() {
        if (!reader.running && !writer.running) reader.running = true;
    }
    function request(action, values) {
        if (writer.running) return false;
        epoch++;
        lastError = "";
        reader.running = false;
        pending = Object.assign({action: action, wifiDevice: wifiDevice, modem: modem, details: true}, values || {});
        writer.running = true;
        return true;
    }
    property Process reader: Process {
        command: ["python3", backend.helperPath]
        stdinEnabled: true
        onStarted: { backend.readEpoch = backend.epoch; write(JSON.stringify(backend.query()) + "\n"); }
        stdout: StdioCollector {
            onStreamFinished: {
                if (backend.readEpoch === backend.epoch && !backend.busy && !backend.accept(text, false))
                    backend.state = Object.assign({}, backend.state, {error: "Network service returned an invalid response"});
            }
        }
        stderr: StdioCollector {}
    }
    property Process writer: Process {
        id: actionWorker
        property string operation: ""
        command: ["python3", backend.helperPath]
        stdinEnabled: true
        onStarted: {
            operation = backend.pending.action;
            write(JSON.stringify(backend.pending) + "\n");

            backend.pending = {};
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const valid = backend.accept(text, true);
                if (!valid) backend.state = Object.assign({}, backend.state, {error: "Network service returned an invalid response"});
                backend.completed(actionWorker.operation, valid && !backend.state.error);
            }
        }
        stderr: StdioCollector {}
        onRunningChanged: if (!running) backend.pending = {}
        onExited: Qt.callLater(() => backend.refresh())
    }
    property Timer operationTimeout: Timer {
        interval: 20000
        running: backend.busy
        onTriggered: {
            backend.writer.running = false;
            backend.pending = {};
            backend.lastError = "Network request timed out. Check the connection state before retrying.";
            backend.state = Object.assign({}, backend.state, {error: backend.lastError});
        }
    }
    property Timer poller: Timer {
        interval: backend.details || backend.state.wifi.status === "connecting" || backend.state.cellular.dataStatus === "connecting" ? 3000 :
            backend.state.wifi.available || backend.state.cellular.available ? 10000 : 30000
        running: backend.automatic
        repeat: true
        triggeredOnStart: true
        onTriggered: backend.refresh()
    }
}
