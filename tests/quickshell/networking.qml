import QtQuick
import Quickshell
import "../../shell/components"

ShellRoot {
    id: root
    property bool finished: false
    property int step: 0
    NetworkBackend { id: backend; automatic: false }
    Item {
        width: 400; height: 800
        WifiPanel { backend: backend; width: 400 }
        MobileDataPanel { backend: backend; width: 400 }
    }
    Connections {
        target: backend
        function onStateChanged() {
            if (root.finished || backend.state.error === "") return;
            if (root.step === 0) {
                root.step = 1;
                Qt.callLater(() => backend.request("wifi-power", {enabled: true}));
            }
        }
        function onCompleted(action, success) {
            root.finished = true;
            if (action === "wifi-power" && !success && !backend.state.wifi.available && !backend.state.cellular.available
                    && backend.state.wifi.strength === -1 && backend.state.cellular.strength === -1 && Object.keys(backend.pending).length === 0)
                console.log("NETWORK_TEST_PASS");
            else console.log("NETWORK_TEST_FAIL: unavailable action or secret cleanup");
            Qt.quit();
        }
    }
    Timer { interval: 8000; running: true; onTriggered: { console.log("NETWORK_TEST_FAIL: timeout"); Qt.quit(); } }
}
