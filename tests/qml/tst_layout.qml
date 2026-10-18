import QtQuick
import QtTest
import "../../shell/components"
import "../../shell/LayoutPolicy.js" as Policy

TestCase {
    name: "AdaptiveLayout"
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
    function test_wifi_signal_percent() {
        compare(Policy.signalPercent(0.42), 42);
        compare(Policy.signalPercent(-1), 0);
        compare(Policy.signalPercent(2), 100);
        compare(Policy.signalPercent(undefined), 0);
        compare(Policy.signalPercent(NaN), 0);
    }
    function test_wifi_action_matrix() {
        compare(Policy.wifiAction(true, true, false), "disconnect");
        compare(Policy.wifiAction(true, false, false), "disconnect");
        compare(Policy.wifiAction(false, true, false), "connect");
        compare(Policy.wifiAction(false, false, true), "connect");
        compare(Policy.wifiAction(false, false, false), "prompt");
    }
}
