import QtQuick
import QtQuick.Layouts
import QtTest
import "../../shell/components"

TestCase {
    name: "StatusRender"
    visible: true
    width: 760
    height: 480
    Rectangle {
        id: matrix
        anchors.fill: parent
        color: Theme.background
        Column {
            x: 12; y: 12; spacing: 4
            Text { text: "Fixture inputs (not device measurements) — compact / regular"; color: Theme.text; font.pixelSize: 15 }
            Repeater {
                model: [
                    {label: "Unavailable", signal: -1, present: false, percent: -1, state: "unknown"},
                    {label: "10% signal / 10% battery", signal: 0.1, present: true, percent: 0.1, state: "discharging"},
                    {label: "55% signal / 55% battery", signal: 0.55, present: true, percent: 0.55, state: "discharging"},
                    {label: "100% / fully charged", signal: 1, present: true, percent: 1, state: "full"},
                    {label: "55% / charging", signal: 0.55, present: true, percent: 0.55, state: "charging"},
                    {label: "55% / pending charge", signal: 0.55, present: true, percent: 0.55, state: "pending-charge"},
                    {label: "Empty battery / zero signal", signal: 0, present: true, percent: 0, state: "empty"},
                    {label: "Invalid data", signal: NaN, present: true, percent: NaN, state: "charging"}
                ]
                Row {
                    required property var modelData
                    spacing: 16
                    Text { width: 210; height: 48; verticalAlignment: Text.AlignVCenter; text: modelData.label; color: Theme.text; font.pixelSize: 13 }
                    Repeater {
                        model: [true, false]
                        StatusIndicators {
                            required property bool modelData
                            compact: modelData
                            showBatteryText: !compact
                            showVolume: false
                            showSettings: false
                            cellularStrength: parent.modelData.signal
                            wifiStrength: parent.modelData.signal
                            batteryPresent: parent.modelData.present
                            batteryPercent: parent.modelData.percent
                            Component.onCompleted: {
                                if ("batteryState" in this) this.batteryState = parent.modelData.state;
                            }
                        }
                    }
                }
            }
        }
    }
    function test_render() {
        wait(100);
        grabImage(matrix).save(Qt.resolvedUrl("../../build/status-indicators.png").toString().replace("file://", ""));
    }
}
