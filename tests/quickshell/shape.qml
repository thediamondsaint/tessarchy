import QtQuick
import Quickshell
import "../../shell/components"

ShellRoot {
    Timer {
        interval: 200; running: true
        onTriggered: {
        Theme.load('background = "#101b30"\n[surface]\nradius_card = 4\nradius_button = 400\nborder_width = 9\n');
        if (Theme.radius("card", 20, 48) !== 4 || Theme.radius("button", 12, 48) !== 24 || Theme.borderWidth(1) !== 4)
            console.log("SHAPE_TEST_FAIL overrides");
        else {
            Theme.load('background = "#101b30"\n[surface]\nradius_card = -1\nborder_width = banana\n');
            if (Theme.radius("card", 20, 48) === 20 && Theme.borderWidth(1) === 1)
                console.log("SHAPE_TEST_PASS");
            else console.log("SHAPE_TEST_FAIL fallback");
        }
        Qt.quit();
        }
    }
}
