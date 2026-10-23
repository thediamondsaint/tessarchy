import QtQuick
import QtTest
import "../../shell/components"
import "../../shell/LayoutPolicy.js" as Policy

TestCase {
    name: "AdaptiveLayout"
    function test_dock_targets_fit_narrow_and_desktop_layouts() {
        for (const mode of ["phone", "tablet", "desktop"]) {
            for (const width of [320, 360, 400, 800, 1280]) {
                for (const keyboard of [true, false]) {
                    for (const gestures of [true, false]) {
                        const dock = Policy.dockLayout(mode, width, keyboard, gestures);
                        const bar = Policy.barGeometry(mode, dock.rows);
                        const available = dock.width - 2 * bar.padding;
                        verify((available - (dock.columns - 1) * bar.columnGap) / dock.columns >= 48);
                        verify(dock.width <= width);
                        verify(dock.rows >= 1);
                    }
                }
            }
        }
    }
    // Phone and Tablet share one dock: no Settings button (status bar has it).
    function test_touch_docks_have_the_same_buttons() {
        compare(Policy.dockLayout("phone", 400, false).columns, 5);
        compare(Policy.dockLayout("tablet", 800, false).columns, 5);
        compare(Policy.dockLayout("phone", 400, true).columns, 6);
        compare(Policy.dockLayout("tablet", 800, true).columns, 6);
        compare(Policy.dockLayout("tablet", 800, true).rows, 1);
    }
    // Gesture mode leaves Phone, Messages and the optional Keyboard in the dock.
    function test_gesture_dock_drops_back_home_and_recents() {
        for (const mode of ["phone", "tablet"]) {
            const width = mode === "phone" ? 400 : 800;
            const gestures = Policy.gestureNavigation(mode, "gestures");
            verify(gestures);
            compare(Policy.dockLayout(mode, width, true, gestures).columns, 3);
            compare(Policy.dockLayout(mode, width, false, gestures).columns, 2);
            const buttons = Policy.gestureNavigation(mode, "buttons");
            verify(!buttons);
            compare(Policy.dockLayout(mode, width, true, buttons).columns, 6);
            compare(Policy.dockLayout(mode, width, false, buttons).columns, 5);
        }
        // Gestures are the default; unknown values keep them; Desktop never uses them.
        verify(Policy.gestureNavigation("phone", undefined));
        verify(Policy.gestureNavigation("tablet", "other"));
        verify(!Policy.gestureNavigation("desktop", "gestures"));
        compare(Policy.dockLayout("desktop", 1280, true, true).rows, 1);
    }
    function test_bottom_swipe_needs_distance_and_hold_for_recents() {
        const d = Policy.GESTURE_DISTANCE;
        const hold = Policy.GESTURE_HOLD;
        verify(d >= 32);
        verify(hold > 0);
        compare(Policy.classifyGesture("bottom", 0, -(d - 1), 0), "none");
        compare(Policy.classifyGesture("bottom", 0, -d, 0), "home");
        compare(Policy.classifyGesture("bottom", 10, -200, hold - 1), "home");
        compare(Policy.classifyGesture("bottom", 10, -200, hold), "recents");
        // A short hold without enough travel is not Recents.
        compare(Policy.classifyGesture("bottom", 0, -(d - 1), hold * 3), "none");
        // Downward or mostly sideways motion does nothing.
        compare(Policy.classifyGesture("bottom", 0, 200, 0), "none");
        compare(Policy.classifyGesture("bottom", 300, -100, 0), "none");
    }
    function test_side_swipe_inward_is_back() {
        const d = Policy.GESTURE_BACK_DISTANCE;
        compare(Policy.classifyGesture("left", d, 0, 0), "back");
        compare(Policy.classifyGesture("right", -d, 0, 0), "back");
        compare(Policy.classifyGesture("left", d - 1, 0, 0), "none");
        // Outward or mostly vertical motion is not Back; holding does not matter.
        compare(Policy.classifyGesture("left", -d * 2, 0, 0), "none");
        compare(Policy.classifyGesture("right", d * 2, 0, 0), "none");
        compare(Policy.classifyGesture("left", d, d * 2, 0), "none");
        compare(Policy.classifyGesture("right", -d, 0, Policy.GESTURE_HOLD * 2), "back");
        compare(Policy.classifyGesture("top", 0, d * 2, 0), "none");
    }
    function test_bottom_reserved_strip_lifts_keyboard_without_stealing_key_input() {
        for (const mode of ["phone", "tablet"]) {
            const edge = Policy.gestureEdgeSize(mode, false);
            const shown = Policy.gestureStripHeight(mode, true, false, edge);
            const reveal = Policy.gestureStripHeight(mode, true, true, edge);
            compare(shown, edge.bottom);
            compare(reveal, edge.side);
            compare(Policy.gestureStripHeight(mode, false, true, edge), edge.side);
            compare(Policy.gestureStripHeight(mode, false, false, edge), 0);
            for (const [height, keyboardHeight] of [[800, 266], [1280, 180], [400, 225]]) {
                const keyboardBottom = height - shown;
                const keyboardTop = keyboardBottom - keyboardHeight;
                verify(keyboardTop >= 0);
                compare(keyboardBottom, height - shown);
                verify(keyboardBottom <= height - shown); // no OSK/overlay intersection
            }
        }
        compare(Policy.gestureStripHeight("desktop", true, true, Policy.gestureEdgeSize("desktop", false)), 0);
    }
    function test_gesture_strips_leave_dock_buttons_uncovered() {
        for (const mode of ["phone", "tablet"]) {
            const bar = Policy.barGeometry(mode, 1);
            const edge = Policy.gestureEdgeSize(mode, false);
            // The collapsed dock row starts gap + inset above the screen edge.
            compare(edge.bottom, bar.gap + bar.inset);
            // An open page's row starts pageBottom above it.
            verify(Policy.gestureEdgeSize(mode, true).bottom <= bar.pageBottom);
            verify(edge.side > 0 && edge.side <= 24);
            // The pill sits centred in the gap under the dock frame.
            compare(edge.handle, bar.gap / 2);
        }
    }
    // Every bar floats and centres its rows: equal inset above and below.
    function test_bar_rows_are_centred_in_a_floating_frame() {
        for (const mode of ["phone", "tablet", "desktop"]) {
            for (const rows of [1, 2, 3]) {
                const bar = Policy.barGeometry(mode, rows);
                const shown = mode === "desktop" ? 1 : rows;
                compare(bar.row, 48);
                compare(bar.rowsHeight, shown * bar.row + (shown - 1) * bar.rowGap);
                compare(bar.height, bar.frameHeight + bar.gap);
                verify(bar.gap > 0);
                verify(bar.inset > 0);
                // Content margins used by shell.qml: top inset, bottom inset + gap.
                const above = bar.inset;
                const below = bar.height - bar.gap - (bar.inset + bar.rowsHeight);
                compare(above, below);
            }
        }
        compare(Policy.barGeometry("desktop", 1).frameHeight, 56);
        compare(Policy.barGeometry("tablet", 1).frameHeight, 72);
        compare(Policy.barGeometry("phone", 1).frameHeight, 64);
        compare(Policy.barGeometry("phone", 2).frameHeight, 120);
    }
    Component {
        id: markFactory
        BrandMark {
            playOnStart: false
            reducedMotion: true
        }
    }
    function test_logo_finishes_without_an_idle_loop() {
        const mark = createTemporaryObject(markFactory, this);
        mark.reducedMotion = false;
        mark.replay();
        verify(mark.animating);
        tryCompare(mark, "animating", false, 2400);
        compare(mark.assembly, 1);
    }
    function test_reduced_motion_stops_and_settles_logo() {
        const mark = createTemporaryObject(markFactory, this);
        verify(mark !== null);
        mark.replay();
        compare(mark.assembly, 1);
        verify(!mark.animating);
        mark.reducedMotion = false;
        mark.replay();
        verify(mark.animating);
        mark.reducedMotion = true;
        verify(!mark.animating);
        compare(mark.assembly, 1);
    }
    function test_automatic_data() {
        return [
            {
                tag: "small phone",
                w: 320,
                h: 480,
                mode: "phone"
            },
            {
                tag: "portrait phone",
                w: 400,
                h: 800,
                mode: "phone"
            },
            {
                tag: "landscape phone",
                w: 800,
                h: 400,
                mode: "phone"
            },
            {
                tag: "below tablet boundary",
                w: 599,
                h: 1000,
                mode: "phone"
            },
            {
                tag: "tablet boundary",
                w: 600,
                h: 1000,
                mode: "tablet"
            },
            {
                tag: "portrait tablet",
                w: 800,
                h: 1280,
                mode: "tablet"
            },
            {
                tag: "below desktop boundary",
                w: 1099,
                h: 800,
                mode: "tablet"
            },
            {
                tag: "desktop boundary",
                w: 1100,
                h: 650,
                mode: "desktop"
            },
            {
                tag: "desktop",
                w: 1920,
                h: 1080,
                mode: "desktop"
            }
        ];
    }
    function test_automatic(data) {
        compare(Policy.automaticMode(data.w, data.h), data.mode);
    }
    function test_override_and_fallback() {
        compare(Policy.effectiveMode("desktop", 400, 800), "desktop");
        compare(Policy.effectiveMode("phone", 1920, 1080), "phone");
        compare(Policy.effectiveMode("auto", 1920, 1080), "desktop");
        compare(Policy.effectiveMode("invalid", 400, 800), "phone");
    }
    function test_narrow_manual_mode_fits() {
        compare(Policy.columns("desktop", 280), 2);
        compare(Policy.columns("desktop", 120), 1);
        verify(Policy.panelWidth("desktop", 320) <= 320);
        compare(Policy.panelWidth("phone", 320), 320);
        compare(Policy.columns("desktop", 760), 4);
    }
    function test_workspace_strip_placements() {
        verify(Policy.showWorkspaces("desktop", 1100));
        verify(!Policy.showWorkspaces("desktop", 400));
        verify(Policy.showWorkspaces("desktop", 1920));
        verify(Policy.showWorkspaces("tablet", 1024));
        verify(!Policy.showWorkspaces("tablet", 800));
        verify(!Policy.showWorkspaces("phone", 1080));
    }
    function test_workspace_slots() {
        compare(Policy.workspaceSlots([]), 5);
        compare(Policy.workspaceSlots([9999999]), 8);
        compare(Policy.workspaceSlots([7.5]), 5);
        compare(Policy.workspaceSlots([1, 2]), 5);
        compare(Policy.workspaceSlots([1, 7, 3]), 7);
        compare(Policy.workspaceSlots([-1, 2]), 5);
    }
    function test_bluetooth_action_and_battery() {
        compare(Policy.btAction(true, true), "disconnect");
        compare(Policy.btAction(true, false), "disconnect");
        compare(Policy.btAction(false, true), "connect");
        compare(Policy.btAction(false, false), "none");
        compare(Policy.btBatteryLabel(false, 0.5), "");
        compare(Policy.btBatteryLabel(true, NaN), "");
        compare(Policy.btBatteryLabel(true, undefined), "");
        compare(Policy.btBatteryLabel(true, 0.42), " · 42%");
        compare(Policy.btBatteryLabel(true, 2), " · 100%");
        compare(Policy.btBatteryLabel(true, -1), " · 0%");
    }
    function test_media_player_selection() {
        compare(Policy.preferredPlayerIndex([]), -1);
        compare(Policy.preferredPlayerIndex([false, true]), 1);
        compare(Policy.preferredPlayerIndex([false, false]), 0);
        compare(Policy.mediaSummary("", ""), "Unknown track — Unknown artist");
    }
    function test_audio_labels_and_stream_filter() {
        compare(Policy.nodeLabel("", " Speakers ", "node"), "Speakers");
        compare(Policy.nodeLabel(undefined, null, ""), "Unknown device");
        compare(Policy.streamLabel("Browser", "Media", "node"), "Browser");
        compare(Policy.streamLabel("", "", ""), "Unknown app");
        verify(Policy.playbackStream("Stream/Output/Audio"));
        for (const value of [undefined, "", "Stream/Input/Audio", "Stream/Output/Video"]) verify(!Policy.playbackStream(value));
        compare(Policy.volumePercent(0.456), 46);
        compare(Policy.volumePercent(2), 100);
        compare(Policy.volumePercent(-1), 0);
    }
    function test_duration_formatting() {
        compare(Policy.duration(0), "");
        compare(Policy.duration(-5), "");
        compare(Policy.duration(undefined), "");
        compare(Policy.duration(NaN), "");
        compare(Policy.duration(30), "less than a minute");
        compare(Policy.duration(90), "2m");
        compare(Policy.duration(3540), "59m");
        compare(Policy.duration(3599), "1h 00m");
        compare(Policy.duration(3600), "1h 00m");
        compare(Policy.duration(3660), "1h 01m");
        compare(Policy.duration(7325), "2h 02m");
}

    function test_notification_placements() {
        const phone = Policy.notificationPlacement("phone", 400);
        verify(phone.fullWidth);
        verify(phone.maxWidth > 0 && phone.maxWidth <= 400);
        verify(phone.topOffset > 48);
        const narrowPhone = Policy.notificationPlacement("phone", 280);
        verify(narrowPhone.maxWidth <= 280);
        const tablet = Policy.notificationPlacement("tablet", 800);
        verify(!tablet.fullWidth);
        verify(tablet.maxWidth > 0 && tablet.maxWidth <= 800);
        verify(tablet.topOffset > 48);
        const desktop = Policy.notificationPlacement("desktop", 1280);
        verify(!desktop.fullWidth);
        compare(desktop.maxWidth, 420);
        verify(desktop.topOffset > 48);
    }
    function test_notification_timeouts() {
        compare(Policy.notificationTimeout(0), 4);
        compare(Policy.notificationTimeout(1), 8);
        compare(Policy.notificationTimeout(2), 0);
    }
    function test_osk_armed_only_for_touch_layouts() {
        verify(Policy.oskArmed("phone"));
        verify(Policy.oskArmed("tablet"));
        verify(!Policy.oskArmed("desktop"));
    }
}
