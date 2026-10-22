import QtQuick
import QtQuick.Layouts
import QtTest
import "../../shell/components"

TestCase {
    name: "DesktopTaskButton"
    when: windowShown
    visible: true
    width: 800
    height: 360
    Component { id: buttonFactory; TaskButton { width: 210; height: 48 } }
    Component {
        id: barFactory
        RowLayout {
            width: 760
            height: 48
            spacing: 0
            StartButton { Layout.alignment: Qt.AlignVCenter }
            TaskStrip {
                Layout.fillWidth: true
                Layout.fillHeight: true
                windows: [
                    {title: "Files", activated: false, wayland: {}},
                    {title: "Terminal", activated: true, wayland: {}}
                ]
                iconForWindow: window => Qt.resolvedUrl("../../shell/icons/terminal.svg")
            }
            Rectangle { Layout.preferredWidth: 48; Layout.fillHeight: true }
        }
    }
    SignalSpy { id: clicks; signalName: "clicked" }

    function descendant(item, propertyName) {
        for (const child of item.children) {
            if (child[propertyName] !== undefined) return child;
            const found = descendant(child, propertyName);
            if (found) return found;
        }
        return null;
    }
    function decodeIcon(button, size) {
        const icon = descendant(button.contentItem, "sourceSize");
        verify(icon);
        // Exercise actual Qt image/layout geometry with two decoded sizes.
        if (size) {
            icon.sourceSize = Qt.size(size, size);
            tryCompare(icon, "status", Image.Ready);
        }
        verify(waitForRendering(button));
        return icon;
    }
    function verifyVerticalAndLeftAlignment(button, hasIcon) {
        const label = descendant(button.contentItem, "textFormat");
        const icon = descendant(button.contentItem, "sourceSize");
        verify(label);
        const labelPosition = label.mapToItem(button, 0, 0);
        const centre = button.background.y + button.background.height / 2;
        fuzzyCompare(labelPosition.y + label.height / 2, centre, 0.5,
            "Title must be vertically centred in its button");
        if (hasIcon) {
            const position = icon.mapToItem(button, 0, 0);
            fuzzyCompare(position.y + icon.height / 2, centre, 0.5,
                "Icon must be vertically centred in its button");
            fuzzyCompare(position.x, button.leftPadding, 0.5,
                "Keep the icon left-aligned, not horizontally centred");
            fuzzyCompare(labelPosition.x - position.x - icon.width, 8, 0.5);
            verify(position.y >= 0);
            verify(position.y + icon.height <= button.height);
        } else {
            fuzzyCompare(labelPosition.x, button.leftPadding, 0.5,
                "Iconless titles retain the original left padding");
        }
    }
    function test_vertical_content_data() {
        const rows = [];
        for (const size of [150, 210, 240]) {
            for (const state of ["ordinary", "selected", "disabled"]) {
                for (const decodedSize of [0, 18, 36]) {
                    rows.push({tag: size + "-" + state + "-" + decodedSize,
                        size: size, state: state, decodedSize: decodedSize});
                }
            }
        }
        return rows;
    }
    function test_vertical_content(data) {
        const button = createTemporaryObject(buttonFactory, this, {
            width: data.size, text: "Files", selected: data.state === "selected",
            enabled: data.state !== "disabled",
            iconSource: data.decodedSize ? Qt.resolvedUrl("../../shell/icons/terminal.svg") : ""
        });
        verify(button);
        const icon = decodeIcon(button, data.decodedSize);
        if (data.decodedSize) compare(icon.height, data.decodedSize);
        verifyVerticalAndLeftAlignment(button, !!data.decodedSize);
        compare(button.focusPolicy, Qt.NoFocus);
        compare(button.Accessible.name, "Files");
    }
    function test_taskstrip_vertical_data() {
        return [{tag: "narrow", size: 480}, {tag: "wide", size: 760}];
    }
    function test_taskstrip_vertical(data) {
        const bar = createTemporaryObject(barFactory, this, {width: data.size});
        verify(bar);
        const list = findChild(bar, "desktopTaskList");
        verify(list);
        tryCompare(list, "count", 2);
        list.forceLayout();
        verify(waitForRendering(bar));
        for (let index = 0; index < list.count; ++index) {
            const button = list.itemAtIndex(index);
            verify(button);
            decodeIcon(button, 36);
            verifyVerticalAndLeftAlignment(button, true);
            compare(button.height, 48);
            fuzzyCompare(button.mapToItem(bar, 0, 0).y + button.height / 2, bar.height / 2, 0.5);
        }
    }
    function test_long_title_data() {
        return [0, 18, 36].map(size => ({tag: String(size), decodedSize: size}));
    }
    function test_long_title(data) {
        const button = createTemporaryObject(buttonFactory, this, {
            width: 150, text: "A very long application title that cannot fit inside a task button",
            iconSource: data.decodedSize ? Qt.resolvedUrl("../../shell/icons/terminal.svg") : ""
        });
        decodeIcon(button, data.decodedSize);
        const label = descendant(button.contentItem, "textFormat");
        tryCompare(label, "truncated", true);
        verifyVerticalAndLeftAlignment(button, !!data.decodedSize);
        const position = label.mapToItem(button, 0, 0);
        verify(position.x + label.width <= button.width - button.rightPadding + 0.5);
        compare(label.elide, Text.ElideRight);
        compare(label.textFormat, Text.PlainText);
    }
    function test_activation_keeps_application_focus() {
        const button = createTemporaryObject(buttonFactory, this, {text: "Files"});
        clicks.target = button;
        clicks.clear();
        mouseClick(button, button.width / 2, button.height / 2);
        compare(clicks.count, 1);
        verify(!button.activeFocus);
        clicks.target = null;
    }
}
