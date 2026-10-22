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
        }
    }
    Component {
        id: wheelFactory
        EdgeWheel {
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
    Component {
        id: recentContent
        Item {
            property bool interacting: false
            property int selections: 0
            function selectActive() { selections++; }
        }
    }
    function test_recent_shelf_preserves_focus_and_browsing() {
        const control = createTemporaryObject(factory, test, {hideDelay: 100, recentsComponent: recentContent, reducedMotion: true});
        const loader = findChild(control, "cubeRecents");
        verify(loader.item !== null);
        const touch = touchEvent(control);
        touch.press(0, control, 24, 24).commit();
        touch.release(0, control, 24, 24).commit();
        tryCompare(control, "expanded", true);
        compare(loader.visible, true);
        compare(loader.item.selections, 1);
        compare(control.activeFocus, false);
        loader.item.interacting = true;
        wait(150);
        compare(control.expanded, true);
        loader.item.interacting = false;
        tryCompare(control, "expanded", false, 500);
        compare(loader.visible, false);
        // Keep the loaded switcher alive for its deferred focus handoff.
        verify(loader.item !== null);
        control.expanded = true;
        compare(loader.item.selections, 2);
        mouseClick(findChild(control, "collapseCube"));
        compare(control.expanded, false);
    }
    function test_cube_contains_touch_shortcuts() {
        const control = createTemporaryObject(factory, test, {reducedMotion: true});
        const phone = findChild(control, "cubePhone");
        const messages = findChild(control, "cubeMessages");
        const keyboard = findChild(control, "cubeKeyboard");
        verify(phone !== null);
        verify(messages !== null);
        verify(keyboard !== null);
        verify(!phone.visible);
        control.expanded = true;
        verify(phone.visible);
        verify(messages.visible);
        verify(keyboard.visible);
        compare(control.implicitHeight, 256);
    }
    function test_drag_coalesces_and_settles_without_reversing() {
        const control = createTemporaryObject(wheelFactory, test);
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
    function test_tablet_thumb_distance_scales_to_window_width() {
        const control = createTemporaryObject(wheelFactory, test, {movementScale: 2.56});
        const area = findChild(control, "tapeDrag");
        mousePress(area, 20, 24);
        mouseMove(area, 260, 24, 5);
        mouseRelease(area, 260, 24);
        compare(control.movements.reduce((sum, value) => sum + value, 0), 614);
        compare(control.finishes, 1);
    }
    function test_hidden_control_discards_pending_movement() {
        const control = createTemporaryObject(wheelFactory, test);
        control.pending = 99;
        control.visible = false;
        wait(30);
        compare(control.pending, 0);
        compare(control.movements.length, 0);
    }
    function test_vertical_drag_and_rotation_cancel() {
        const control = createTemporaryObject(wheelFactory, test, {placement: "left"});
        const area = findChild(control, "tapeDrag");
        mousePress(area, 24, 120);
        mouseMove(area, 24, 60, 5);
        mouseRelease(area, 24, 60);
        compare(control.movements.reduce((sum, value) => sum + value, 0), -60);
        compare(control.finishes, 1);
        mousePress(area, 24, 120);
        mouseMove(area, 24, 90, 1);
        control.placement = "right";
        compare(control.pending, 0);
        mouseMove(area, 24, 60, 1);
        mouseRelease(area, 24, 60);
        compare(control.finishes, 1);
        compare(control.movements.reduce((sum, value) => sum + value, 0), -60);
    }
    function test_touch_drag_preserves_direction_and_releases_once() {
        const control = createTemporaryObject(wheelFactory, test);
        const area = findChild(control, "tapeDrag");
        const sequence = touchEvent(control);
        sequence.press(0, area, 120, 24).commit();
        sequence.move(0, area, 60, 24).commit();
        sequence.release(0, area, 60, 24).commit();
        tryCompare(control, "finishes", 1);
        compare(control.movements.reduce((sum, value) => sum + value, 0), -60);
    }
}
