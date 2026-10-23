import QtQuick
import QtTest
import "../../shell/components"

TestCase {
    id: test
    name: "WindowTape"
    width: 400
    height: 200
    when: windowShown
    visible: true
    Component {
        id: factory
        WindowTapeControl {
            width: implicitWidth
            height: implicitHeight
            property var movements: []
            property int finishes: 0
            onMoved: delta => movements = movements.concat([delta])
            onSettled: finishes++
        }
    }
    function test_reveal_and_idle_hide() {
        const control = createTemporaryObject(factory, test, {hideDelay: 100});
        compare(control.expanded, false);
        mouseClick(control, 24, 24);
        compare(control.expanded, true);
        tryCompare(control, "expanded", false, 500);
    }
    function test_tessa_cube_and_narrow_screen() {
        const control = createTemporaryObject(factory, test, {maxControlWidth: 304});
        compare(control.implicitWidth, 56);
        control.expanded = true;
        compare(control.implicitWidth, 304);
        control.tessaCube = false;
        compare(control.implicitWidth, 304);
    }
    function test_drag_coalesces_and_settles_without_reversing() {
        const control = createTemporaryObject(factory, test, {expanded: true});
        const area = findChild(control, "tapeDrag");
        mousePress(area, 120, 24);
        mouseMove(area, 90, 24, 5);
        mouseMove(area, 60, 24, 5);
        mouseRelease(area, 60, 24);
        compare(control.movements.reduce((sum, value) => sum + value, 0), -60);
        compare(control.finishes, 1);
        wait(50);
        compare(control.movements.reduce((sum, value) => sum + value, 0), -60);
    }
    function test_hidden_control_discards_pending_movement() {
        const control = createTemporaryObject(factory, test, {expanded: true});
        control.pending = 99;
        control.visible = false;
        wait(30);
        compare(control.pending, 0);
        compare(control.movements.length, 0);
        compare(control.expanded, false);
    }
    function test_idle_does_not_hide_under_finger() {
        const control = createTemporaryObject(factory, test, {expanded: true, hideDelay: 80});
        const area = findChild(control, "tapeDrag");
        mousePress(area, 80, 24);
        wait(180);
        compare(control.expanded, true);
        mouseRelease(area, 80, 24);
        tryCompare(control, "expanded", false, 500);
    }
    function test_touch_drag_preserves_direction_and_releases_once() {
        const control = createTemporaryObject(factory, test, {expanded: true});
        const area = findChild(control, "tapeDrag");
        const sequence = touchEvent(control);
        sequence.press(0, area, 120, 24).commit();
        sequence.move(0, area, 60, 24).commit();
        sequence.release(0, area, 60, 24).commit();
        tryCompare(control, "finishes", 1);
        compare(control.movements.reduce((sum, value) => sum + value, 0), -60);
    }
}
