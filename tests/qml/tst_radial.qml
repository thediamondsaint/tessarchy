import QtQuick
import QtTest
import "../../shell/components"

TestCase {
    id: test
    name: "RadialActions"
    width: 320; height: 320
    when: windowShown
    visible: true
    RadialActions { id: menu; width: 280; height: 280 }
    SignalSpy { id: actions; target: menu; signalName: "triggered" }
    SignalSpy { id: dismiss; target: menu; signalName: "dismissed" }
    function test_all_actions_and_dead_center() {
        actions.clear(); dismiss.clear();
        for (let i = 0; i < menu.actions.length; i++) {
            const angle = -Math.PI / 2 + i * Math.PI * 2 / menu.actions.length;
            mouseClick(menu, 140 + Math.cos(angle) * 94, 140 + Math.sin(angle) * 94);
            compare(actions.signalArguments[i][0], menu.actions[i].action);
        }
        mouseClick(menu, 140, 140);
        compare(dismiss.count, 1);
        compare(actions.count, menu.actions.length);
        compare(menu.activeFocus, false);
    }
}
