import QtQuick
import QtTest
import "../../shell/components"

TestCase {
    id: test
    name: "TessaLauncher"
    width: 320; height: 640
    when: windowShown
    visible: true
    AppLauncher {
        id: launcher
        width: 304; height: 580
        applications: [
            {id: "firefox", name: "Firefox", icon: "", command: ["firefox"]},
            {id: "foot", name: "Foot", icon: "", command: ["foot"]}
        ]
    }
    SignalSpy { id: launches; target: launcher; signalName: "launched" }
    function test_search_keyboard_and_reopen() {
        const input = findChild(launcher, "launcherSearch");
        launches.clear();
        input.forceActiveFocus();
        keyClick(Qt.Key_F); keyClick(Qt.Key_F); keyClick(Qt.Key_X);
        compare(launcher.matches.length, 1);
        keyClick(Qt.Key_Return);
        compare(launches.signalArguments[0][0], "firefox");
        launcher.visible = false;
        launcher.visible = true;
        compare(input.text, "");
        compare(launcher.matches.length, 2);
        wait(1);
        keyClick(Qt.Key_F); keyClick(Qt.Key_F); keyClick(Qt.Key_X);
        compare(input.text, "ffx");
        compare(launcher.matches.length, 1);
        input.text = "";
        input.forceActiveFocus();
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(launches.signalArguments[1][0], "foot");
    }
    function test_touch_activation_and_empty_search() {
        const input = findChild(launcher, "launcherSearch");
        const results = findChild(launcher, "launcherResults");
        launches.clear();
        input.text = "";
        tryCompare(results, "count", 2);
        const row = results.itemAtIndex(1);
        verify(row !== null);
        const touch = touchEvent(launcher);
        touch.press(0, row, 100, 32).commit();
        touch.release(0, row, 100, 32).commit();
        tryCompare(launches, "count", 1);
        compare(launches.signalArguments[0][0], "foot");
        input.text = "no-such-app";
        input.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(launches.count, 1);
        compare(results.count, 0);
        input.text = "";
    }

}
