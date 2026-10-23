import QtQuick
import QtTest
import "../../shell/components"

TestCase {
    id: testCase
    name: "StartApplications"
    when: windowShown
    visible: true
    width: 440
    height: 500
    Component { id: factory; StartAppGrid { width: 424 } }
    function app(id, name, categories) {
        return {id: id, name: name, categories: categories || [], icon: "", command: ["test"]};
    }
    function button(grid, label) {
        const items = grid.children;
        for (let i = 0; i < items.length; i++) {
            if (items[i].item && items[i].item.text === label && !items[i].heading) return items[i].item;
        }
        return null;
    }
    function test_launch_focus_and_live_model_updates() {
        const grid = createTemporaryObject(factory, testCase, {
            applications: [app("a", "Alpha", ["Office"]), app("b", "Beta")]
        });
        verify(grid !== null);
        tryVerify(() => button(grid, "Beta") !== null);
        grid.focusApp("b");
        tryVerify(() => button(grid, "Beta").activeFocus);
        grid.applications = [app("new", "New app", ["Network"]), app("a", "Alpha", ["Office"]), app("b", "Beta")];
        tryVerify(() => button(grid, "New app") !== null);
        tryVerify(() => button(grid, "Beta").activeFocus);
        let launched = "";
        grid.launchRequested.connect(id => launched = id);
        keyClick(Qt.Key_Return);
        compare(launched, "b");
        grid.applications = [app("a", "Alpha", ["Office"])];
        tryVerify(() => button(grid, "Beta") === null);
        tryVerify(() => button(grid, "Alpha").activeFocus);
        grid.applications = [app("a", "Renamed", ["Utility"])];
        tryVerify(() => button(grid, "Renamed") !== null);
        tryVerify(() => button(grid, "Renamed").activeFocus);
        verify(button(grid, "Renamed").width >= 48);
        verify(button(grid, "Renamed").height >= 48);
    }
}
