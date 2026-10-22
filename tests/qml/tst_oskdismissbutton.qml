import QtQuick
import QtQuick.Controls
import QtTest
import "../../shell/components"

TestCase {
    id: test
    name: "OskDismissButton"
    width: 320
    height: 220
    when: windowShown
    visible: true
    Rectangle { anchors.fill: parent; color: Theme.background }
    TextField {
        id: field
        x: 16; y: 24; width: 288; height: 56
        text: "unsent draft"
    }
    OskDismissButton { id: button; x: 248; y: 144; width: 48; height: 48 }
    SignalSpy { id: clicked; target: button; signalName: "clicked" }
    function test_click_keeps_focus_text_and_typing() {
        field.forceActiveFocus();
        field.cursorPosition = field.text.length;
        verify(field.activeFocus);
        clicked.clear();
        mouseClick(button, 24, 24);
        compare(clicked.count, 1);
        verify(field.activeFocus);
        compare(field.text, "unsent draft");
        keyClick(Qt.Key_X);
        compare(field.text, "unsent draftx");
        compare(button.width, 48); compare(button.height, 48);
        compare(button.Accessible.name, "Hide keyboard");
    }
}
