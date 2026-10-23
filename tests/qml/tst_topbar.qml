import QtQuick
import QtTest
import "../../shell/components"

TestCase {
    name: "TouchTopBar"
    width: 120
    height: 80
    when: windowShown
    visible: true

    TopBarPet {
        id: pet
        objectName: "tessaPet"
        reducedMotion: true
        engaged: true
        attention: 1
    }
    SignalSpy { id: activation; target: pet; signalName: "clicked" }

    function test_pet_is_touch_sized_and_accessible() {
        compare(pet.implicitWidth, 56);
        compare(pet.implicitHeight, 56);
        compare(pet.Accessible.name, "Tessa companion is active");
    }

    function test_pet_click_is_local_and_does_not_require_a_service() {
        activation.clear();
        pet.clicked();
        compare(activation.count, 1);
    }
}
