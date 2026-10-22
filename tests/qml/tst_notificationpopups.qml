import QtQuick
import QtTest
import "../../shell/components"

TestCase {
    name: "NotificationPopupLifecycle"
    Component { id: queueFactory; NotificationPopupQueue {} }
    Component { id: modelFactory; QtObject { property var values: [] } }
    Component {
        id: notificationFactory
        QtObject {
            property bool tracked: true
            property int urgency: 1
            property string summary: "First summary"
        }
    }
    property var history
    property var queue

    function init() {
        history = createTemporaryObject(modelFactory, this);
        queue = createTemporaryObject(queueFactory, this, {trackedModel: history});
        verify(queue !== null);
    }
    function notification(urgency) {
        const n = createTemporaryObject(notificationFactory, this, {urgency: urgency || 1});
        history.values = history.values.concat([n]);
        return n;
    }
    function expectItems(expected) {
        compare(queue.items.length, expected.length);
        for (let i = 0; i < expected.length; i++) verify(queue.items[i] === expected[i]);
    }
    function test_empty_and_missing_removal_are_noops() {
        expectItems([]);
        queue.remove(null);
        expectItems([]);
    }
    function test_newest_first_limit_does_not_discard_history() {
        const a = notification(), b = notification(), c = notification(), d = notification();
        for (const n of [a, b, c, d]) queue.add(n);
        expectItems([d, c, b]);
        compare(history.values.length, 4);
    }
    function test_duplicate_add_keeps_single_object_and_updated_content() {
        const a = notification();
        queue.add(a);
        a.summary = "Replacement summary";
        queue.add(a);
        expectItems([a]);
        compare(queue.items[0].summary, "Replacement summary");
    }
    function test_existing_popup_add_moves_front_once() {
        const a = notification(), b = notification(), c = notification();
        for (const n of [a, b, c]) queue.add(n);
        queue.add(a);
        expectItems([a, c, b]);
    }
    function test_application_withdrawal_removes_popup_slot() {
        const a = notification(), b = notification();
        queue.add(a); queue.add(b);
        history.values = [b];
        expectItems([b]);
    }
    function test_urgent_withdrawal_needs_no_popup_timeout() {
        const a = notification(2);
        queue.add(a);
        history.values = [];
        expectItems([]);
    }
    function test_bulk_history_clear_removes_all_popups() {
        const a = notification(), b = notification();
        queue.add(a); queue.add(b);
        history.values = [];
        expectItems([]);
    }
    function test_body_hide_preserves_history_and_other_popup() {
        const a = notification(), b = notification();
        queue.add(a); queue.add(b);
        queue.remove(b);
        expectItems([a]);
        compare(history.values.length, 2);
        verify(a.tracked && b.tracked);
    }
    function test_removal_does_not_resurrect_overflowed_alert() {
        const a = notification(), b = notification(), c = notification(), d = notification();
        for (const n of [a, b, c, d]) queue.add(n);
        history.values = [a, b, c];
        expectItems([c, b]);
        queue.remove(c);
        expectItems([b]);
    }
    function test_history_arrival_does_not_auto_queue_muted_delivery() {
        notification();
        expectItems([]);
    }
    function test_history_updates_do_not_restart_unaffected_popup_timer_model() {
        const a = notification();
        queue.add(a);
        const before = queue.items;
        notification();
        verify(queue.items === before, "An unchanged popup array must retain identity");
        expectItems([a]);
    }
    function test_no_null_or_untracked_delivery() {
        queue.add(null);
        const a = notification();
        a.tracked = false;
        history.values = [];
        queue.add(a);
        expectItems([]);
    }
    function test_model_replacement_prunes_old_popups_without_backfill() {
        const a = notification(); queue.add(a);
        const replacement = createTemporaryObject(modelFactory, this);
        queue.trackedModel = replacement;
        expectItems([]);
        history.values = [];
        expectItems([]);
    }
    function test_delivery_precedes_server_model_insertion() {
        const a = createTemporaryObject(notificationFactory, this);
        queue.add(a);
        expectItems([a]);
        history.values = [a];
        expectItems([a]);
    }
    function test_model_unavailable_clears_queue() {
        const a = notification(); queue.add(a);
        queue.trackedModel = null;
        expectItems([]);
    }
}
