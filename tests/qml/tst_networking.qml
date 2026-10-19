import QtQuick
import QtTest
import "../../shell/components"

TestCase {
    name: "NetworkingControls"
    visible: true
    when: windowShown
    width: 800
    height: 1000
    Component {
        id: backendFactory
        QtObject {
            property bool busy: false
            property string wifiDevice: ""
            property string modem: ""
            property var requests: []
            property var state: ({connectivity: "Internet available", error: "", notice: "", editorAvailable: false,
                wifi: {available: true, enabled: true, managed: true, hardwareEnabled: true, status: "connected", label: "Fixture", device: "/wifi/1", strength: 37,
                    networks: [{id: "/ap/1", name: "<b>Literal</b>", security: "wpa-psk", strength: 37, connected: false, profile: ""}], profiles: [], devices: [], canHotspot: true},
                cellular: {available: true, enabled: true, managed: true, registered: true, status: "registered", label: "Fixture carrier", strength: 63,
                    device: "/modem/1", id: "/mm/0", dataStatus: "disconnected", locked: 1, profiles: [], modems: [], technology: "4G", roaming: false}})
            function watch(view, active) {}
            function refresh() {}
            function request(action, values) { requests = requests.concat([{action: action, values: values}]); return !busy; }
        }
    }
    Component { id: wifiFactory; WifiPanel { width: 400 } }
    Component { id: dataFactory; MobileDataPanel { width: 400 } }
    Component { id: iconFactory; StatusIcon { symbol: "wifi"; label: "Wi-Fi"; width: 48; height: 48 } }
    Component { id: inputFactory; TextInput { x: 500; width: 150; height: 48 } }
    Component { id: stripFactory; StatusIndicators { dense: true; showAirplane: false; showBatteryText: false; showVolume: false; showSettings: false } }
    SignalSpy { id: clicked; signalName: "clicked" }

    function test_signal_icons_follow_real_percentages_and_do_not_take_focus() {
        const icon = createTemporaryObject(iconFactory, this, {strength: 37, status: "connected"});
        const input = createTemporaryObject(inputFactory, this);
        compare(icon.level, 2);
        verify(findChild(icon, "networkSignalGlyph").source.toString().endsWith("wifi-level-2.svg"));
        icon.strength = 0;
        compare(icon.level, 0);
        icon.strength = 100;
        compare(icon.level, 4);
        icon.strength = -1; icon.status = "unavailable";
        compare(icon.level, 0);
        verify(icon.Accessible.name.indexOf("signal unavailable") >= 0);
        input.forceActiveFocus();
        clicked.target = icon; clicked.clear();
        mouseClick(icon, 24, 24);
        compare(clicked.count, 1);
        verify(input.activeFocus);
        clicked.target = null;
    }
    function test_narrow_phone_strip_keeps_network_touch_targets_and_fits() {
        const strip = createTemporaryObject(stripFactory, this, {airplaneOn: true});
        wait(0);
        verify(strip.implicitWidth <= 166);
        const icons = strip.children.filter(child => child.symbol === "wifi" || child.symbol === "cellular");
        compare(icons.length, 2);
        for (const icon of icons) { verify(icon.width >= 48); verify(icon.height >= 48); }
        verify(26 + 66 + 48 + 8 + strip.implicitWidth <= 320);
    }
    function test_password_cancel_and_hiding_never_send_credentials() {
        const backend = createTemporaryObject(backendFactory, this);
        const panel = createTemporaryObject(wifiFactory, this, {backend: backend});
        panel.openForm("password", backend.state.wifi.networks[0]);
        verify(panel.needsKeyboard);
        const field = findChild(panel, "networkPassword");
        field.text = "synthetic-password";
        panel.closeForm();
        compare(field.text, "");
        compare(backend.requests.length, 0);
        panel.openForm("password", backend.state.wifi.networks[0]);
        field.text = "another-fixture-secret";
        panel.visible = false;
        compare(field.text, "");
        compare(backend.requests.length, 0);
    }
    function test_connect_clears_field_and_disappearance_cancels_prompt() {
        const backend = createTemporaryObject(backendFactory, this);
        const panel = createTemporaryObject(wifiFactory, this, {backend: backend});
        const field = findChild(panel, "networkPassword");
        panel.openForm("password", backend.state.wifi.networks[0]);
        field.text = "synthetic-password";
        panel.submit();
        compare(field.text, "");
        compare(backend.requests.length, 1);
        compare(backend.requests[0].values.password, "synthetic-password");
        compare(backend.requests[0].values.accessPoint, "/ap/1");
        panel.openForm("password", backend.state.wifi.networks[0]);
        field.text = "private-fixture";
        backend.state = Object.assign({}, backend.state, {wifi: Object.assign({}, backend.state.wifi, {networks: []})});
        compare(panel.form, "");
        compare(field.text, "");
        compare(backend.requests.length, 1);
    }
    function test_open_network_does_not_prompt_and_enterprise_uses_advanced_setup() {
        const backend = createTemporaryObject(backendFactory, this);
        const panel = createTemporaryObject(wifiFactory, this, {backend: backend});
        panel.choose({id: "/ap/open", security: "open", profile: "", connected: false});
        compare(backend.requests.length, 1);
        compare(panel.form, "");
        panel.choose({id: "/ap/eap", security: "enterprise", profile: "", connected: false});
        compare(backend.requests.length, 1);
        verify(panel.localError.indexOf("Connections") >= 0);
    }
    function test_mobile_apn_and_password_are_only_sent_on_submit() {
        const backend = createTemporaryObject(backendFactory, this);
        const panel = createTemporaryObject(dataFactory, this, {backend: backend});
        panel.editing = true;
        findChild(panel, "mobileApn").text = "example.invalid";
        findChild(panel, "apnPassword").text = "synthetic-password";
        compare(backend.requests.length, 0);
        panel.connectNew();
        compare(backend.requests.length, 1);
        compare(backend.requests[0].action, "cellular-connect");
        compare(backend.requests[0].values.allowRoaming, false);
        compare(backend.requests[0].values.apn, "example.invalid");
        compare(findChild(panel, "apnPassword").text, "");
        verify(!panel.editing);
    }
}
