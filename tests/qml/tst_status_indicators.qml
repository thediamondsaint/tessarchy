import QtQuick
import QtQuick.Controls
import QtTest
import "../../shell/components"
import "../../shell/StatusPolicy.js" as StatusPolicy

TestCase {
    name: "StatusIndicators"
    visible: true
    width: 400
    height: 120
    Component { id: stripFactory; StatusIndicators {} }
    Component { id: signalFactory; StatusIcon { symbol: "cellular"; label: "Cellular" } }
    Component { id: batteryFactory; BatteryIndicator {} }
    SignalSpy { id: clickSpy; signalName: "panelRequested" }

    function test_fractional_signals_survive() {
        const strip = createTemporaryObject(stripFactory, this, {cellularStrength: 0.55, wifiStrength: 0.23});
        compare(strip.cellularStrength, 0.55);
        compare(strip.wifiStrength, 0.23);
    }
    function test_compact_unavailable_is_not_connected() {
        const strip = createTemporaryObject(stripFactory, this, {compact: true});
        const cellular = strip.children[2];
        compare(cellular.Accessible.name, "Cellular unavailable");
    }
    function test_strength_changes_image() {
        const icon = createTemporaryObject(signalFactory, this, {strength: 0.1});
        const image = findChild(icon, "signalLevelImage");
        const low = image.source.toString();
        icon.strength = 0.9;
        verify(image.source.toString() !== low, "Measured signal must change the glyph");
    }
    function test_signal_levels_data() {
        return [
            {tag: "missing", value: -1, level: -1},
            {tag: "nan", value: NaN, level: -1},
            {tag: "infinite", value: Infinity, level: -1},
            {tag: "over-range", value: 1.1, level: -1},
            {tag: "zero", value: 0, level: 0},
            {tag: "weak", value: 0.01, level: 1},
            {tag: "quarter", value: 0.25, level: 1},
            {tag: "half", value: 0.5, level: 2},
            {tag: "three", value: 0.55, level: 3},
            {tag: "full", value: 1, level: 4}
        ];
    }
    function test_signal_levels(data) {
        compare(StatusPolicy.signalLevel(data.value), data.level);
        for (const symbol of ["wifi", "cellular"]) {
            const icon = createTemporaryObject(signalFactory, this, {symbol: symbol, strength: data.value});
            compare(icon.level, data.level);
            const expectedLevel = Math.max(0, data.level);
            compare(findChild(icon, "signalLevelImage").source.toString(),
                    "../icons/" + symbol + "-level-" + expectedLevel + ".svg");
            compare(icon.reported, data.level >= 0);
            compare(findChild(icon, "unavailableSlash").visible, data.level < 0);
            verify(icon.Accessible.name.indexOf(data.level < 0 ? "unavailable" : "signal") >= 0);
        }
    }
    function test_cellular_readiness() {
        const ready = {available: true, enabled: true, registered: true, signal: 55};
        compare(StatusPolicy.cellularStrength(ready), 0.55);
        compare(StatusPolicy.cellularStrength(null), -1);
        compare(StatusPolicy.cellularStrength({}), -1);
        for (const flag of ["available", "enabled", "registered"]) {
            const absent = Object.assign({}, ready);
            absent[flag] = false;
            compare(StatusPolicy.cellularStrength(absent), -1);
        }
        for (const signal of [undefined, null, "55", NaN, Infinity, -1, 101])
            compare(StatusPolicy.cellularStrength(Object.assign({}, ready, {signal: signal})), -1);
        compare(StatusPolicy.cellularStrength(Object.assign({}, ready, {signal: 0})), 0);
    }
    function test_battery_states_data() {
        return [
            {tag: "unknown", state: "unknown", charging: false, text: "state unknown"},
            {tag: "charging", state: "charging", charging: true, text: "charging"},
            {tag: "discharging", state: "discharging", charging: false, text: "discharging"},
            {tag: "full", state: "full", charging: false, text: "fully charged"},
            {tag: "pending", state: "pending-charge", charging: false, text: "not charging"},
            {tag: "pending-discharge", state: "pending-discharge", charging: false, text: "pending discharge"},
            {tag: "empty", state: "empty", charging: false, text: "empty"}
        ];
    }
    function test_battery_states(data) {
        const battery = createTemporaryObject(batteryFactory, this, {present: true, percentage: 0.55, powerState: data.state});
        compare(battery.reported, true);
        compare(battery.charging, data.charging);
        compare(findChild(battery, "chargingBolt").visible, data.charging);
        verify(battery.Accessible.name.indexOf(data.text) >= 0);
        verify(battery.Accessible.name.indexOf("55%") >= 0);
        compare(findChild(battery, "batteryFill").width, 6.6);
    }
    function test_battery_level_and_loss() {
        const battery = createTemporaryObject(batteryFactory, this, {present: true, percentage: 1, powerState: "charging"});
        compare(findChild(battery, "batteryFill").width, 12);
        battery.percentage = 0;
        compare(battery.reported, true);
        compare(findChild(battery, "batteryFill").width, 0);
        for (const value of [-1, 1.1, NaN, Infinity]) {
            battery.percentage = value;
            compare(battery.reported, false);
            compare(battery.charging, false);
            compare(findChild(battery, "batteryFill").width, 0);
            compare(battery.Accessible.name, "Battery status unavailable");
        }
        battery.percentage = 0.55;
        battery.present = false;
        compare(battery.charging, false);
        compare(findChild(battery, "batteryFill").width, 0);
        battery.present = true;
        compare(battery.charging, true);
    }
    function test_battery_pixels_change_with_level_and_charging() {
        const battery = createTemporaryObject(batteryFactory, this, {present: true, percentage: 0.1, powerState: "discharging"});
        wait(20);
        const low = grabImage(battery);
        battery.percentage = 1;
        wait(20);
        verify(!low.equals(grabImage(battery)), "Battery level must change visible pixels");
        battery.percentage = 0.55;
        wait(20);
        const discharging = grabImage(battery);
        battery.powerState = "charging";
        wait(20);
        verify(!discharging.equals(grabImage(battery)), "Charging must change visible pixels");
        battery.powerState = "pending-charge";
        wait(20);
        verify(discharging.equals(grabImage(battery)), "Pending charge must not draw a charging bolt");
        battery.present = false;
        wait(20);
        verify(!discharging.equals(grabImage(battery)), "Unavailable must not look charged");
    }
    function test_battery_hover_detail() {
        const battery = createTemporaryObject(batteryFactory, this, {present: true, percentage: 0.55, powerState: "pending-charge"});
        mouseMove(battery, battery.width / 2, battery.height / 2);
        tryCompare(battery.ToolTip, "visible", true);
        compare(battery.ToolTip.text, "Battery plugged in, not charging · 55%");
        compare(battery.activeFocus, false);
        mouseMove(this, width - 1, height - 1);
        tryCompare(battery.ToolTip, "visible", false);
    }
    function test_strip_battery_wiring_and_clicks() {
        for (const compact of [true, false]) {
            const strip = createTemporaryObject(stripFactory, this, {compact: compact, batteryPresent: true, batteryPercent: 0.55, batteryState: "charging"});
            const battery = findChild(strip, "batteryIndicator");
            verify(battery !== null);
            compare(battery.charging, true);
            strip.batteryState = "pending-charge";
            compare(battery.charging, false);
            strip.batteryPresent = false;
            compare(battery.reported, false);
            clickSpy.target = strip;
            clickSpy.clear();
            const cellular = strip.children[2];
            compare(cellular.height, 48);
            compare(cellular.width, compact ? 28 : 18);
            compare(cellular.activeFocus, false);
            mouseClick(cellular, cellular.width / 2, cellular.height / 2);
            compare(clickSpy.count, 1);
            compare(cellular.activeFocus, false);
            clickSpy.target = null;
        }
    }
}
