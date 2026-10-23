import QtQuick
import QtTest
import "../../shell/components"
import "../../shell/LayoutPolicy.js" as Policy

// Drives EdgeSwipeArea with press/move/release sequences, as a strip would see them.
TestCase {
    id: test
    name: "NavigationGestures"
    width: 400
    height: 800
    when: windowShown
    visible: true

    Component {
        id: bottomFactory
        EdgeSwipeArea {
            property var actions: []
            x: 0
            y: 780
            width: 400
            height: 20
            edge: "bottom"
            onGesture: action => actions = actions.concat([action])
        }
    }
    Component {
        id: sideFactory
        EdgeSwipeArea {
            property var actions: []
            y: 100
            width: 16
            height: 600
            onGesture: action => actions = actions.concat([action])
        }
    }

    function swipe(area, x1, y1, x2, y2, steps, holdMs) {
        mousePress(area, x1, y1);
        for (let i = 1; i <= steps; i++)
            mouseMove(area, x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps, 10);
        if (holdMs > 0) wait(holdMs);
        mouseRelease(area, x2, y2);
    }

    function test_quick_swipe_up_is_home() {
        const area = createTemporaryObject(bottomFactory, test);
        swipe(area, 200, 10, 200, 10 - 2 * Policy.GESTURE_DISTANCE, 8, 0);
        compare(area.actions, ["home"]);
    }
    function test_short_swipe_up_does_nothing() {
        const area = createTemporaryObject(bottomFactory, test);
        swipe(area, 200, 10, 200, 10 - (Policy.GESTURE_DISTANCE - 8), 4, 0);
        compare(area.actions, []);
    }
    function test_swipe_up_and_hold_is_recents_once() {
        const area = createTemporaryObject(bottomFactory, test);
        swipe(area, 200, 10, 200, 10 - 2 * Policy.GESTURE_DISTANCE, 8, Policy.GESTURE_HOLD + 200);
        // Recents fires while held; the release does not add Home.
        compare(area.actions, ["recents"]);
    }
    function test_tap_on_strip_does_nothing() {
        const area = createTemporaryObject(bottomFactory, test);
        mouseClick(area, 200, 10);
        compare(area.actions, []);
    }
    function test_inward_side_swipes_are_back() {
        const left = createTemporaryObject(sideFactory, test, {edge: "left", x: 0});
        swipe(left, 4, 300, 4 + 2 * Policy.GESTURE_BACK_DISTANCE, 300, 6, 0);
        compare(left.actions, ["back"]);
        const right = createTemporaryObject(sideFactory, test, {edge: "right", x: 384});
        swipe(right, 12, 300, 12 - 2 * Policy.GESTURE_BACK_DISTANCE, 300, 6, 0);
        compare(right.actions, ["back"]);
    }
    function test_vertical_drag_on_side_strip_is_not_back() {
        const left = createTemporaryObject(sideFactory, test, {edge: "left", x: 0});
        swipe(left, 4, 100, 20, 400, 6, 0);
        compare(left.actions, []);
    }
    Component {
        id: handleFactory
        GestureHandle {}
    }
    function test_handle_has_one_visibility_switch() {
        const handle = createTemporaryObject(handleFactory, test);
        verify(handle.visible);
        handle.shown = false;
        verify(!handle.visible);
    }
}
