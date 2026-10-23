import QtQuick
import QtTest
import "../../shell/components"

TestCase {
    name: "QuickSwitcher"
    when: windowShown
    visible: true
    width: 400
    height: 120
    Component { id: factory; QuickSwitcher { width: 240; height: 96 } }
    Component {
        id: windowFactory
        QtObject {
            property string title: "Application"
            property bool activated: false
            property QtObject wayland: QtObject {}
        }
    }
    SignalSpy { id: requests; signalName: "windowRequested" }
    SignalSpy { id: dismissals; signalName: "dismissed" }

    function model() {
        return [createTemporaryObject(windowFactory, this, {title: "Terminal", activated: true}),
                createTemporaryObject(windowFactory, this, {title: "Files"}),
                createTemporaryObject(windowFactory, this, {title: "Browser"})];
    }
    function test_glass_icons_touch_flick_and_focus() {
        const windows = model().concat(model());
        const switcher = createTemporaryObject(factory, this, {windows: windows, glassMode: true, reducedMotion: true});
        requests.target = switcher;
        requests.clear();
        switcher.selectActive();
        const list = findChild(switcher, "quickSwitcherIcons");
        tryVerify(() => list.itemAtIndex(1) !== null);
        const row = list.itemAtIndex(1);
        const touch = touchEvent(switcher);
        touch.press(0, row, 48, 48).commit();
        touch.release(0, row, 48, 48).commit();
        tryCompare(requests, "count", 1);
        compare(requests.signalArguments[0][0], windows[1]);
        compare(switcher.activeFocus, false);
        switcher.reset();
        touch.press(0, list, 210, 48).commit();
        touch.move(0, list, 130, 48).commit();
        wait(20);
        touch.move(0, list, 20, 48).commit();
        touch.release(0, list, 20, 48).commit();
        tryVerify(() => list.contentX > 0);
        compare(requests.count, 1);
        requests.target = null;
    }
    function test_cycle_forward_backward_and_alt_release() {
        const windows = model();
        const switcher = createTemporaryObject(factory, this, {windows: windows});
        requests.target = switcher;
        requests.clear();
        switcher.selectActive();
        switcher.forceActiveFocus();
        keyClick(Qt.Key_Tab, Qt.AltModifier);
        compare(switcher.currentIndex, 1);
        keyClick(Qt.Key_Backtab, Qt.AltModifier | Qt.ShiftModifier);
        compare(switcher.currentIndex, 0);
        switcher.step(-1);
        compare(switcher.currentIndex, 2);
        requests.clear();
        keyRelease(Qt.Key_Alt);
        compare(requests.count, 1);
        compare(requests.signalArguments[0][0], windows[2]);
        requests.target = null;
    }
    function test_escape_and_selection_survives_model_changes() {
        const windows = model();
        const switcher = createTemporaryObject(factory, this, {windows: windows});
        dismissals.target = switcher;
        dismissals.clear();
        switcher.selectActive();
        switcher.step(1);
        switcher.windows = [windows[1], windows[2]];
        compare(switcher.selection, windows[1]);
        switcher.windows = [windows[2]];
        compare(switcher.selection, windows[2]);
        switcher.forceActiveFocus();
        keyClick(Qt.Key_Escape);
        compare(dismissals.count, 1);
        switcher.windows = [];
        compare(switcher.selection, null);
        switcher.activateCurrent();
        verify(dismissals.count >= 2);
        dismissals.target = null;
    }
    // The compositor key binding and the QML key release both raise accept, so
    // a single Alt+Tab must switch once, and cycling must re-arm it.
    function test_duplicate_accept_commits_once_and_step_rearms() {
        const windows = model();
        const switcher = createTemporaryObject(factory, this, {windows: windows});
        requests.target = switcher;
        requests.clear();
        switcher.selectActive();
        switcher.step(1);
        switcher.activateCurrent();
        switcher.activateCurrent();
        compare(requests.count, 1);
        switcher.reset();
        switcher.step(1);
        switcher.activateCurrent();
        compare(requests.count, 2);
        requests.target = null;
    }
}
