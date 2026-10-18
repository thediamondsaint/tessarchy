pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Networking
import "components"
import "LayoutPolicy.js" as Policy

ShellRoot {
    id: root
    signal controlsRequested
    IpcHandler {
        target: "controls"
        function toggle(): void { root.controlsRequested(); }
    }
    signal replayBrand
    readonly property var activeWindow: Hyprland.activeToplevel || Hyprland.toplevels.values.find(window => window.wayland && window.wayland.activated) || null
    signal actionRequested(string action)
    IpcHandler {
        target: "actions"
        function closeWindow(): void { root.actionRequested("close"); }
        function endSession(): void { root.actionRequested("exit"); }
    }
    signal switcherCommand(string action)
    IpcHandler {
        target: "switcher"
        function next(): void { root.switcherCommand("next"); }
        function previous(): void { root.switcherCommand("previous"); }
        function accept(): void { root.switcherCommand("accept"); }
        function cancel(): void { root.switcherCommand("cancel"); }
    }
    readonly property color accentColor: shellPreferences.accent === "iris" ? "#c6b7ff" : shellPreferences.accent === "ice" ? "#99d7ff" : "#a9e8d5"
    Settings {
        id: shellPreferences
        location: "file://" + (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/tessarchy/shell.ini"
        category: "Shell"
        property string layoutMode: "auto"
        property string accent: "mint"
        property bool reducedMotion: false
        property bool showLabels: false
        property bool use24Hour: true
        property real barOpacity: 0.22
        property real wallpaperDim: 0.12
    }
    RadioBackend { id: radioBackend }
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    // NetworkManager through Quickshell's Networking service: the first
    // Wi-Fi device and its connected network feed the status icon. Negative
    // strength means no connected network; `networkBackend` distinguishes a
    // present-but-idle radio from a missing backend.
    readonly property bool networkBackend: Networking.backend !== NetworkBackendType.None
    readonly property var wifiDevice: {
        if (!root.networkBackend)
            return null;
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }
    readonly property var wifiConnected: {
        if (!root.wifiDevice)
            return null;
        const networks = root.wifiDevice.networks.values;
        for (let i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i];
        }
        return null;
    }
    readonly property real wifiStrength: root.wifiConnected ? root.wifiConnected.signalStrength : -1
    property real cellularStrength: -1
    // squeekboard via tessarchy-osk; it also appears by itself for text fields.
    readonly property bool oskAvailable: Quickshell.env("TESSARCHY_OSK") === "1"
    readonly property var audioSink: audioLoader.item ? (audioLoader.item as AudioStatus).sink : null
    readonly property bool audioAvailable: !!(audioSink && audioSink.ready && audioSink.audio)
    readonly property int volumePercent: audioAvailable ? Math.round(audioSink.audio.volume * 100) : 0
    Loader {
        id: audioLoader
        active: Quickshell.env("TESSARCHY_AUDIO") === "1"
        source: "components/AudioStatus.qml"
    }
    readonly property var activePlayer: {
        const players = Mpris.players.values;
        const index = Policy.preferredPlayerIndex(players.map(player => player.isPlaying));
        return index < 0 ? null : players[index];
    }
    Variants {
        model: Quickshell.screens
        Scope {
            id: surface
            required property var modelData
            readonly property string mode: Policy.effectiveMode(shellPreferences.layoutMode, modelData.width, modelData.height)
            readonly property bool isPhone: mode === "phone"
            readonly property int navHeight: isPhone ? 76 : 84
            readonly property int launcherRows: Math.ceil((panel.appEntries.length + 2) / Policy.columns(mode, Policy.panelWidth(mode, modelData.width) - 32))
            readonly property bool showWorkspaces: Policy.showWorkspaces(mode, modelData.width)
            readonly property var workspaceIds: {
                const ids = [];
                const workspaces = Hyprland.workspaces.values;
                for (let i = 0; i < workspaces.length; i++) ids.push(workspaces[i].id);
                return ids;
            }
            readonly property int workspaceCount: Policy.workspaceSlots(workspaceIds)

            // Hyprland.workspaces only holds existing workspaces; numbered slots
            // may refer to one that has not been created yet.
            function workspaceFor(id) {
                const workspaces = Hyprland.workspaces.values;
                for (let i = 0; i < workspaces.length; i++) {
                    if (workspaces[i].id === id) return workspaces[i];
                }
                return null;
            }
            function switchWorkspace(id) {
                const workspace = workspaceFor(id);
                if (workspace) {
                    // activate() handles both classic and Lua dispatch modes.
                    workspace.activate();
                    return;
                }
                if (Hyprland.usingLua) Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
                else Hyprland.dispatch("workspace " + id);
            }
            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }
            PanelWindow {
                id: panel
                screen: surface.modelData
                readonly property var appEntries: DesktopEntries.applications.values
                    .filter(entry => !entry.noDisplay && entry.command.length > 0)
                    .sort((a, b) => a.name.localeCompare(b.name))
                property string page: ""
                property var closeTarget: null
                property bool keyboardSwitch: false
                readonly property bool expanded: page !== ""
                // The keyboard is a separate top-layer surface that would cover
                // the drawer, so shell pages dismiss it like an IME on Recents.
                onExpandedChanged: {
                    if (expanded && root.oskAvailable)
                        Quickshell.execDetached(["tessarchy-osk", "hide"]);
                }
                anchors {
                    bottom: true
                    left: false
                    right: false
                }
                implicitWidth: expanded ? Policy.panelWidth(surface.mode, surface.modelData.width) : Math.min(surface.modelData.width - 32, surface.isPhone ? 272 : 360)
                implicitHeight: expanded ? Math.min(page === "windows" ? surface.modelData.height - 60 : page === "apps" ? surface.launcherRows * 124 + 156 : surface.mode === "tablet" ? 740 : 640, surface.modelData.height - 64) : surface.navHeight
                exclusiveZone: surface.navHeight
                color: "transparent"
                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: panel.expanded ? 0 : 12
                    radius: 26
                    color: panel.expanded ? (panel.page === "windows" ? "#b3101b30" : "#c2101b30") : Qt.rgba(0.063, 0.106, 0.188, shellPreferences.barOpacity)
                    border.width: 1
                    border.color: Qt.alpha(root.accentColor, 0.15)
                }
                WlrLayershell.namespace: "tessera"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: panel.keyboardSwitch && panel.page === "windows" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                function showPage(name) {
                    if (name === "windows" && page !== "windows") switcher.selectActive();
                    keyboardSwitch = false;
                    closeTarget = null;
                    page = page === name ? "" : name;
                }
                function launch(command) {
                    Quickshell.execDetached(command);
                    page = "";
                }
                onPageChanged: { if (page !== "windows") keyboardSwitch = false; }
                Connections {
                    target: root
                    function onSwitcherCommand(action) {
                        if (!Hyprland.focusedMonitor || Hyprland.focusedMonitor.name !== surface.modelData.name) return;
                        if (action === "accept") {
                            if (panel.keyboardSwitch && panel.page === "windows") switcher.activateCurrent();
                        } else if (action === "cancel") {
                            if (panel.keyboardSwitch) panel.page = "";
                        } else {
                            const opening = panel.page !== "windows";
                            if (opening) switcher.selectActive();
                            panel.keyboardSwitch = true;
                            panel.page = "windows";
                            switcher.step(action === "previous" ? -1 : 1);
                            switcher.forceActiveFocus();
                        }
                    }
                }
                Connections {
                    target: root
                    function onActionRequested(action) {
                        if (!Hyprland.focusedMonitor || Hyprland.focusedMonitor.name !== surface.modelData.name) return;
                        panel.keyboardSwitch = false;
                        panel.closeTarget = action === "close" ? root.activeWindow : null;
                        panel.page = action === "exit" ? "session" : panel.closeTarget ? "close" : "";
                    }
                }
                Connections {
                    target: panel.closeTarget
                    function onClosed() {
                        panel.closeTarget = null;
                        panel.page = "windows";
                    }
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    anchors.bottomMargin: panel.expanded ? 12 : 18
                    anchors.leftMargin: surface.isPhone ? 12 : 16
                    anchors.rightMargin: surface.isPhone ? 12 : 16
                    spacing: 8
                    ColumnLayout {
                        visible: panel.expanded
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8
                        Text {
                            visible: panel.page !== "windows"
                            text: panel.page === "apps" ? "Your space" : panel.page === "close" ? "Close this window?" : panel.page === "settings" ? "Settings" : "End this session?"
                            color: root.accentColor
                            font.pixelSize: 22
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        AppSwitcher {
                            id: switcher
                            visible: panel.page === "windows"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            windows: Hyprland.toplevels.values
                            fillApp: surface.mode !== "desktop"
                            accentColor: root.accentColor
                            reducedMotion: shellPreferences.reducedMotion
                            onActivated: panel.page = ""
                            onDismissed: panel.page = ""
                            onCloseRequested: target => {
                                panel.closeTarget = target;
                                panel.page = "close";
                            }
                        }
                        ScrollView {
                            visible: panel.page !== "windows"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth
                            ColumnLayout {
                                width: parent.width
                                spacing: 8
                                ColumnLayout {
                                    visible: panel.page === "apps"
                                    Layout.fillWidth: true
                                    GridLayout {
                                        columns: Policy.columns(surface.mode, width)
                                        columnSpacing: 12
                                        Layout.fillWidth: true
                                        Repeater {
                                            model: panel.appEntries
                                            delegate: AppTile {
                                                required property var modelData
                                                text: modelData.name
                                                symbol: "browser"
                                                iconSource: Quickshell.iconPath(modelData.icon, true)
                                                accentColor: root.accentColor
                                                onClicked: {
                                                    panel.page = "";
                                                    modelData.execute();
                                                }
                                            }
                                        }
                                        AppTile {
                                            text: "Settings"
                                            symbol: "settings"
                                            accentColor: root.accentColor
                                            onClicked: panel.showPage("settings")
                                        }
                                        AppTile {
                                            text: "Controls"
                                            symbol: "controls"
                                            accentColor: root.accentColor
                                            onClicked: statusBar.toggleDrawer()
                                        }
                                    }
                                    Text {
                                        text: root.oskAvailable ? "Prototype · The keyboard opens for text fields; Keyboard shows or hides it." : "Prototype · Physical keyboard needed for text input."
                                        color: "#b7c7cc"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                                Loader {
                                    visible: active
                                    active: panel.page === "settings"
                                    Layout.fillWidth: true
                                    sourceComponent: SettingsPage {
                                        preferences: shellPreferences
                                        activeMode: Policy.title(surface.mode)
                                        displayWidth: surface.modelData.width
                                        displayHeight: surface.modelData.height
                                        accentColor: root.accentColor
                                        onEndSessionRequested: panel.page = "session"
                                        onControlsRequested: statusBar.toggleDrawer()
                                        onReplayRequested: root.replayBrand()
                                    }
                                }
                                ColumnLayout {
                                    visible: panel.page === "close"
                                    Layout.fillWidth: true
                                    Text {
                                        text: panel.closeTarget ? panel.closeTarget.title : "Window is no longer available."
                                        color: "#f0f5f5"
                                        wrapMode: Text.WrapAnywhere
                                        Layout.fillWidth: true
                                    }
                                    TouchButton {
                                        text: "Cancel"
                                        Layout.fillWidth: true
                                        onClicked: {
                                            panel.closeTarget = null;
                                            panel.page = "windows";
                                        }
                                    }
                                    TouchButton {
                                        text: "Close window"
                                        destructive: true
                                        enabled: panel.closeTarget !== null
                                        Layout.fillWidth: true
                                        onClicked: {
                                            const target = panel.closeTarget;
                                            panel.closeTarget = null;
                                            panel.page = "windows";
                                            if (target)
                                                target.close();
                                        }
                                    }
                                }
                                ColumnLayout {
                                    visible: panel.page === "session"
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Save your work before ending Tessarchy. This closes the desktop session."
                                        color: "#f0f5f5"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                    TouchButton {
                                        text: "Cancel"
                                        Layout.fillWidth: true
                                        onClicked: panel.page = ""
                                    }
                                    TouchButton {
                                        text: "End session"
                                        destructive: true
                                        Layout.fillWidth: true
                                        onClicked: Hyprland.dispatch("hl.dsp.exit()")
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        spacing: 8
                        NavButton {
                            text: "Back"
                            symbol: "back"
                            showLabel: shellPreferences.showLabels
                            accentColor: root.accentColor
                            enabled: panel.expanded || statusBar.drawerOpen
                            onClicked: {
                                statusBar.drawerOpen = false;
                                panel.closeTarget = null;
                                panel.page = "";
                            }
                        }
                        NavButton {
                            text: surface.mode === "desktop" ? "Apps" : "Home"
                            symbol: "home"
                            showLabel: shellPreferences.showLabels
                            accentColor: root.accentColor
                            selected: panel.page === "apps"
                            onClicked: panel.showPage("apps")
                        }
                        NavButton {
                            text: surface.mode === "desktop" ? "Windows" : "Recents"
                            symbol: "recents"
                            showLabel: shellPreferences.showLabels
                            accentColor: root.accentColor
                            selected: panel.page === "windows"
                            onClicked: panel.showPage("windows")
                        }
                        NavButton {
                            visible: !surface.isPhone
                            text: "Settings"
                            symbol: "settings"
                            showLabel: shellPreferences.showLabels
                            accentColor: root.accentColor
                            selected: panel.page === "settings"
                            onClicked: panel.showPage("settings")
                        }
                        NavButton {
                            // Panel never takes keyboard focus, so the app keeps its text field.
                            visible: root.oskAvailable && surface.mode !== "desktop"
                            text: "Keyboard"
                            symbol: "keyboard"
                            showLabel: shellPreferences.showLabels
                            accentColor: root.accentColor
                            onClicked: Quickshell.execDetached(["tessarchy-osk", "toggle"])
                        }
                    }
                }
            }
            PanelWindow {
                id: statusBar
                Timer {
                    id: screenshotTimer
                    interval: shellPreferences.reducedMotion ? 100 : 300
                    onTriggered: Quickshell.execDetached(["tessera-screenshot"])
                }
                property bool drawerOpen: false
                function toggleDrawer() {
                    drawerOpen = !drawerOpen;
                    if (drawerOpen) {
                        panel.closeTarget = null;
                        panel.page = "";
                        radioBackend.refresh();
                        if (root.oskAvailable) Quickshell.execDetached(["tessarchy-osk", "hide"]);
                    }
                }
                Connections {
                    target: root
                    function onControlsRequested() {
                        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === surface.modelData.name) statusBar.toggleDrawer();
                    }
                }
                screen: surface.modelData
                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: drawerOpen ? Math.min(surface.modelData.height - surface.navHeight - 12, quickSheet.implicitHeight + 76) : 48
                exclusiveZone: 48
                color: "transparent"
                Rectangle {
                    anchors.fill: parent
                    radius: statusBar.drawerOpen ? 28 : 0
                    color: Qt.rgba(0.063, 0.106, 0.188, statusBar.drawerOpen ? 0.76 : shellPreferences.barOpacity)
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.alpha(root.accentColor, 0.1) }
                }
                WlrLayershell.namespace: "tessera-status"
                WlrLayershell.layer: WlrLayer.Top
                // The drawer grants keyboard focus only while the Wi-Fi
                // password prompt is open so hardware typing and the
                // on-screen keyboard reach the field; everything else stays
                // non-interactive for the keyboard.
                WlrLayershell.keyboardFocus: quickSheet.wifiPromptOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                Item {
                    id: statusHeader
                    width: parent.width
                    height: 48
                    DragHandler {
                        target: null
                        xAxis.enabled: false
                        dragThreshold: 6
                        grabPermissions: PointerHandler.CanTakeOverFromAnything
                        property bool triggered: false
                        onActiveChanged: { if (active) triggered = false; }
                        onActiveTranslationChanged: {
                            // Expand before the pointer leaves the 48px input strip.
                            if (!triggered && activeTranslation.y > 10 && !statusBar.drawerOpen) {
                                triggered = true;
                                statusBar.toggleDrawer();
                            } else if (!triggered && activeTranslation.y < -10 && statusBar.drawerOpen) {
                                triggered = true;
                                statusBar.toggleDrawer();
                            }
                        }
                    }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 8
                    spacing: surface.modelData.width < 360 ? 4 : 8
                    TouchButton {
                        id: mobileClock
                        text: Qt.formatDateTime(clock.date, shellPreferences.use24Hour ? "h:mm" : "h:mm AP").replace(/ [AP]M$/, "")
                        Accessible.name: "Clock " + Qt.formatDateTime(clock.date, shellPreferences.use24Hour ? "h:mm" : "h:mm AP") + ", quick controls"
                        Layout.minimumHeight: 48
                        Layout.preferredWidth: 66
                        implicitHeight: 48
                        padding: 0
                        background: Item {}
                        contentItem: Text {
                            text: mobileClock.text
                            color: "#f0f5ff"
                            verticalAlignment: Text.AlignVCenter
                            font { pixelSize: 16; weight: Font.DemiBold; letterSpacing: 0.2 }
                        }
                        onClicked: statusBar.toggleDrawer()
                    }
                    RowLayout {
                        visible: surface.showWorkspaces
                        spacing: 4
                        Repeater {
                            model: surface.workspaceCount
                            delegate: TouchButton {
                                id: workspaceButton
                                required property int index
                                readonly property int workspaceId: index + 1
                                readonly property var workspace: surface.workspaceFor(workspaceId)
                                text: String(workspaceId)
                                selected: workspace ? (workspace.focused || workspace.active) : false
                                implicitWidth: 48
                                implicitHeight: 48
                                Layout.minimumWidth: 48
                                Layout.minimumHeight: 48
                                Layout.preferredWidth: 48
                                padding: 0
                                accentColor: root.accentColor
                                Accessible.name: "Workspace " + workspaceId + (selected ? " active" : " inactive")
                                Accessible.role: Accessible.Button
                                onClicked: surface.switchWorkspace(workspaceId)
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    // Focused window title; only meaningful in the desktop layout.
                    Text {
                        visible: surface.showWorkspaces && surface.mode === "desktop" && text.length > 0
                        text: root.activeWindow ? (root.activeWindow.title || "") : ""
                        color: "#d0dced"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.maximumWidth: 360
                        Layout.leftMargin: 8
                        Accessible.name: text.length > 0 ? "Focused window " + text : ""
                    }
                    // Only registered application icons appear; no simulated signals.
                    RowLayout {
                        Layout.maximumWidth: Math.max(0, surface.modelData.width - 370)
                        clip: true
                        spacing: 0
                        Repeater {
                            model: SystemTray.items
                            delegate: TouchButton {
                                id: trayButton
                                required property var modelData
                                text: modelData.title
                                implicitWidth: 48
                                implicitHeight: 48
                                Layout.minimumHeight: 48
                                Layout.preferredWidth: 48
                                contentItem: Image {
                                    source: trayButton.modelData.icon
                                    sourceSize.width: 20
                                    sourceSize.height: 20
                                    fillMode: Image.Pad
                                }
                                onClicked: {
                                    if (modelData.hasMenu)
                                        modelData.display(trayButton.QsWindow.window, 0, 48);
                                    else
                                        modelData.activate();
                                }
                            }
                        }
                    }
                    Image {
                        visible: !!(radioBackend.state.airplane && radioBackend.state.airplane.enabled)
                        Layout.preferredWidth: 18; Layout.preferredHeight: 18
                        source: "icons/airplane.svg"
                        sourceSize.width: 18; sourceSize.height: 18
                        Accessible.name: "Airplane mode on"
                    }
                    StatusIcon {
                        symbol: "cellular"
                        label: "Cellular"
                        strength: root.cellularStrength
                    }
                    StatusIcon {
                        symbol: "wifi"
                        label: "Wi-Fi"
                        strength: root.wifiStrength
                        available: root.networkBackend
                    }
                    NavButton {
                        text: root.audioAvailable ? "Volume " + root.volumePercent + "%" : "Quick controls · audio unavailable"
                        symbol: root.audioAvailable && root.audioSink.audio.muted ? "volume-muted" : "volume"
                        showLabel: false
                        implicitWidth: 48
                        implicitHeight: 48
                        Layout.minimumHeight: 48
                        Layout.fillWidth: false
                        Layout.preferredWidth: 48
                        selected: statusBar.drawerOpen
                        onClicked: statusBar.toggleDrawer()
                    }
                    RowLayout {
                        spacing: 4
                        Image {
                            source: "icons/battery.svg"
                            sourceSize.width: 22
                            sourceSize.height: 22
                            opacity: UPower.displayDevice.isPresent ? 1 : 0.35
                        }
                        Text {
                            visible: surface.modelData.width >= 380
                            text: UPower.displayDevice.isPresent ? Math.round(UPower.displayDevice.percentage * 100) + "%" : "—"
                            color: "#a9e8d5"
                            font.pixelSize: 11
                            Accessible.name: UPower.displayDevice.isPresent ? "Battery " + text : "Battery status unavailable"
                        }
                    }
                    NavButton {
                        text: "Settings"
                        symbol: "settings"
                        showLabel: false
                        implicitWidth: 48
                        implicitHeight: 48
                        Layout.minimumHeight: 48
                        Layout.fillWidth: false
                        Layout.preferredWidth: 48
                        accentColor: root.accentColor
                        selected: panel.page === "settings"
                        onClicked: { statusBar.drawerOpen = false; panel.showPage("settings"); }
                    }
                }
                }
                ScrollView {
                    x: 16; y: 60
                    width: parent.width - 32
                    height: parent.height - y
                    visible: statusBar.drawerOpen
                    clip: true
                    contentWidth: availableWidth
                    QuickSettings {
                        bluetoothAdapter: root.bluetoothAdapter
                        wifiDevice: root.wifiDevice
                        id: quickSheet
                        width: parent.width
                        radios: radioBackend
                        preferences: shellPreferences
                        activeMode: Policy.title(surface.mode)
                        date: clock.date
                        use24Hour: shellPreferences.use24Hour
                        accentColor: root.accentColor
                        audioSink: root.audioSink
                        audioBackendAvailable: audioLoader.active
                        onScreenshotRequested: {
                            statusBar.drawerOpen = false;
                            screenshotTimer.restart();
                        }
                        mediaPlayer: root.activePlayer
                        onDismissed: statusBar.drawerOpen = false
                        onSettingsRequested: { statusBar.drawerOpen = false; panel.showPage("settings"); }
                    }
                }
                Connections {
                    target: panel
                    function onPageChanged() { if (panel.page !== "") statusBar.drawerOpen = false; }
                }
            }
            PanelWindow {
                screen: surface.modelData
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                color: "#101b30"
                WlrLayershell.namespace: "tessera-home"
                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                Image {
                    anchors.fill: parent
                    source: "artwork/aurora-fold.png"
                    fillMode: Image.PreserveAspectCrop
                }
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0.016, 0.05, 0.1, shellPreferences.wallpaperDim)
                }
                Column {
                    visible: !panel.expanded
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.max(64, parent.height * (surface.isPhone ? 0.14 : 0.18))
                    spacing: 12
                    BrandMark {
                        id: homeBrand
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 96
                        height: 96
                        reducedMotion: shellPreferences.reducedMotion
                    }
                    Connections {
                        target: root
                        function onReplayBrand() {
                            homeBrand.replay();
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, shellPreferences.use24Hour ? "hh:mm" : "h:mm AP")
                        color: "#f0f5ff"
                        font {
                            pixelSize: surface.isPhone ? 58 : 72
                            weight: Font.Light
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                        color: "#a9e8d5"
                        font.pixelSize: 18
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "TESSARCHY"
                        color: root.accentColor
                        font {
                            pixelSize: 12
                            bold: true
                            letterSpacing: 5
                        }
                    }
                }
            }
        }
    }
}
