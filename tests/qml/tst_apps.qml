import QtQuick
import QtTest
import "../../shell/AppPolicy.js" as Apps

TestCase {
    name: "InstalledApplications"
    function entry(id, hidden) { return {id: id, name: id, noDisplay: !!hidden, command: ["test"]}; }
    function test_all_launchable_apps_include_unknown_and_multiple_browsers() {
        const entries = [entry("chromium"), entry("browser.desktop"), entry("new-app"), entry("org.gnome.Calculator", true)];
        compare(Apps.applications(entries).map(e => e.id).join(","), "browser.desktop,chromium,new-app");
    }
    function test_empty_and_unlaunchable_entries() {
        compare(Apps.applications([]).length, 0);
        compare(Apps.applications([null, {id: "browser", name: "Browser", command: []}]).length, 0);
    }
    function test_categories_keep_each_app_once() {
        const app = entry("editor");
        app.categories = ["Development", "Utility"];
        compare(Apps.category(app), "Development");
        const rows = Apps.menuRows([entry("unknown"), app]);
        compare(rows.filter(r => r.heading).map(r => r.name).join(","), "Development,Other");
        compare(rows.filter(r => !r.heading).length, 2);
    }
}
