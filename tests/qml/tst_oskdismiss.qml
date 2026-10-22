import QtQuick
import QtTest
import "../../shell/OskDismissPolicy.js" as Osk

TestCase {
    name: "OskDismissPolicy"
    function rect(monitor, y, x, w) {
        return { monitor: monitor, x: x === undefined ? 0 : x, y: y,
                 w: w === undefined ? 800 : w, h: 300 };
    }
    function test_touch_modes_have_a_target_above_keys() {
        for (const mode of ["phone", "tablet"]) {
            const r = Osk.placement(mode, 800, 1000, 0, [rect(0, 700)], 48);
            verify(r !== null);
            compare(r.width, 48); compare(r.height, 48);
            verify(r.y >= 48); verify(r.y + r.height < 700);
            verify(r.x >= 16); verify(r.x + r.width <= 784);
        }
    }
    function test_desktop_wrong_output_and_missing_keyboard() {
        compare(Osk.placement("desktop", 800, 1000, 0, [rect(0, 700)], 48), null);
        compare(Osk.placement("phone", 800, 1000, 0, [rect(1, 700)], 48), null);
        compare(Osk.placement("phone", 800, 1000, 0, [], 48), null);
        compare(Osk.placement("phone", 800, 1000, -1, [rect(-1, 700)], 48), null);
    }
    function test_portrait_landscape_and_logical_scale() {
        for (const size of [[360, 800], [800, 360], [1280, 720], [480, 853]]) {
            const y = size[1] - 180;
            const r = Osk.placement("tablet", size[0], size[1], 7, [rect(7, y, 0, size[0])], 48);
            verify(r !== null);
            verify(r.x + r.width <= size[0]); verify(r.y + r.height < y);
        }
    }
    function test_output_local_coordinates_not_global_origin() {
        // Hyprland layer geometry is output-local, even on offset outputs.
        const r = Osk.placement("tablet", 800, 1000, 9, [rect(9, 700, 150, 500)], 48);
        verify(r !== null);
        verify(r.x + r.width <= 650); verify(r.x >= 150);
    }
    function test_invalid_and_insufficient_space_fail_closed() {
        for (const layer of [rect(0, 80), rect(0, -1), rect(0, 700, 0, 0),
                             { monitor: 0, x: 0, y: NaN, w: 800, h: 300 }]) {
            compare(Osk.placement("tablet", 800, 1000, 0, [layer], 48), null);
        }
        compare(Osk.placement("tablet", 40, 1000, 0, [rect(0, 700)], 48), null);
        compare(Osk.placement("tablet", 800, 1000, 0, null, 48), null);
    }
    function test_multiple_layers_do_not_cover_another_keyboard() {
        const r = Osk.placement("tablet", 800, 1000, 0, [rect(0, 700), rect(0, 500)], 48);
        verify(r !== null);
        verify(r.y + r.height < 500);
    }
}
