import QtQuick
import QtTest
import "../../shell/WifiPolicy.js" as Wifi

TestCase {
    name: "WifiPolicy"
    function test_strength_data() {
        return [
            {tag: "no adapter", device: null, expected: -1},
            {tag: "no networks model", device: {}, expected: -1},
            {tag: "no networks", device: {networks: {values: []}}, expected: -1},
            {tag: "disconnected", device: {networks: {values: [{connected: false, signalStrength: 0.9}]}}, expected: -1},
            {tag: "connected", device: {networks: {values: [{connected: false, signalStrength: 0.9}, {connected: true, signalStrength: 0.63}]}}, expected: 0.63},
            {tag: "zero signal", device: {networks: {values: [{connected: true, signalStrength: 0}]}}, expected: 0},
            {tag: "full signal", device: {networks: {values: [{connected: true, signalStrength: 1}]}}, expected: 1},
            {tag: "unavailable", device: {networks: {values: [{connected: true, signalStrength: -1}]}}, expected: -1}
        ];
    }
    function test_strength(data) { compare(Wifi.signalStrength(data.device), data.expected); }
    QtObject { id: network; property bool connected: true; property real signalStrength: 0.4 }
    QtObject { id: measured; readonly property real strength: Wifi.signalStrength({networks: {values: [network]}}) }
    function test_live_updates() {
        compare(measured.strength, 0.4);
        network.signalStrength = 0.8;
        compare(measured.strength, 0.8);
        network.connected = false;
        compare(measured.strength, -1);
    }
}
