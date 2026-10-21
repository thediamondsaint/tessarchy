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
import Quickshell.Services.Notifications
import "components"
import "LayoutPolicy.js" as Policy
import "AppPolicy.js" as Apps

ShellRoot {
    id: root
    signal controlsRequested
    IpcHandler {
        target: "controls"
        function toggle(): void { root.controlsRequested(); }
    }
    signal openAppRequested(string page)
    IpcHandler {
        target: "apps"
        function phone(): void { root.openAppRequested("phone"); }
        function messages(): void { root.openAppRequested("messages"); }
        function cellular(): void { root.openAppRequested("cellular"); }
        function sounds(): void { root.openAppRequested("sounds"); }
    }
    signal replayBrand
    function activateWindow(window) {
        if (!window || !window.wayland) return;
        const workspace = window.workspace || (window.lastIpcObject && window.lastIpcObject.workspace);
        const address = String(window.address).replace(/^0x/i, "");
        if (Hyprland.usingLua && workspace && workspace.name.startsWith("special:tessarchy-minimized-")
                && /^[0-9a-f]+$/i.test(address)) {
            Quickshell.execDetached(["hyprctl", "eval", "TessarchyWindows.activate(\"address:0x" + address + "\")"]);
        } else window.wayland.activate();
    }
    function activateHandle(target) {
        const window = Hyprland.toplevels.values.find(window => window.wayland === target);
        if (window) activateWindow(window);
    }
    readonly property var activeWindow: Hyprland.activeToplevel || Hyprland.toplevels.values.find(window => window.wayland && window.wayland.activated) || null
    property var windowHistory: []
    readonly property var switcherWindows: windowHistory.filter(window => Hyprland.toplevels.values.indexOf(window) >= 0)
        .concat(Hyprland.toplevels.values.filter(window => windowHistory.indexOf(window) < 0))
    onActiveWindowChanged: {
        if (activeWindow) windowHistory = [activeWindow].concat(windowHistory.filter(window =>
            window !== activeWindow && Hyprland.toplevels.values.indexOf(window) >= 0));
    }
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
    readonly property color accentColor: Theme.accent
    Settings {
        id: shellPreferences
        location: "file://" + (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/tessarchy/shell.ini"
        category: "Shell"
        property string layoutMode: "auto"
        property string accent: "mint"
        property bool reducedMotion: false
        property bool showLabels: false
        // "gestures" swipes for Back/Home/Recents on Phone and Tablet;
        // "buttons" keeps them in the dock.
        property string navigation: "gestures"
        // The gesture handle pill above the bottom edge.
        property bool showGestureHandle: true
        property bool use24Hour: true
        property real barOpacity: 0.44
        property real wallpaperDim: 0.12
        property bool doNotDisturb: false
        // "windowed" opens desktop windows floating and sized; "tiled" restores
        // the dwindle layout. Read by the Hyprland config on load.
        property string desktopWindows: "windowed"
        property bool nightLight: false
    }
    RadioBackend { id: radioBackend }
    CommunicationBackend { id: communications }
    WeatherBackend { id: weatherBackend }
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    // Signal strength remains unavailable until a real connection backend is added.
    // System theme: tessarchy-theme stages an Omarchy-format colors.toml (and
    // optional wallpaper) here; the keyboard and apps render from the same file.
    readonly property string themeDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/tessarchy/theme"
    property string themeName: ""
    property string themeBackground: ""
    property var themes: []
    function setTheme(name) {
        themeSetter.command = ["tessarchy-theme", "set", name];
        themeSetter.running = true;
    }
    FileView {
        id: themeColors
        path: root.themeDir + "/colors.toml"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            Theme.load(text());
            themeNameFile.reload();
        }
    }
    FileView {
        id: themeNameFile
        path: root.themeDir + "/name"
        printErrors: false
        onLoaded: {
            root.themeName = text().trim();
            themeWallpaperFile.reload();
        }
    }
    FileView {
        id: themeWallpaperFile
        path: root.themeDir + "/wallpaper"
        printErrors: false
        onLoaded: {
            const path = text().trim();
            root.themeBackground = path.length > 0 ? "file://" + path : "";
        }
    }
    Process {
        id: themeSetter
        onRunningChanged: if (!running)
            themeColors.reload()
    }
    Process {
        id: themeList
        command: ["tessarchy-theme", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.themes = text.split("\n").filter(line => line.length > 0).map(line => {
                const field = line.split("\t");
                return {
                    name: field[0],
                    mode: field[1],
                    background: field[2],
                    foreground: field[3],
                    accent: field[4],
                    preview: field[5] || ""
                };
            })
        }
    }
    // Bind these when wireless/modem integrations land. Never invent a signal.
    property real wifiStrength: -1
    readonly property real cellularStrength: communications.state.cellular.signal === undefined ? -1 : communications.state.cellular.signal / 100
    // squeekboard via tessarchy-osk; it also appears by itself for text fields.
    readonly property bool oskAvailable: Quickshell.env("TESSARCHY_OSK") === "1"
    // Desktop mode must never raise the on-screen keyboard; touch modes may.
    function applyOskMode(mode) {
        if (!oskAvailable) return;
        Quickshell.execDetached(["tessarchy-osk", Policy.oskArmed(mode) ? "enable" : "disable"]);
    }
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
    // Notifications: the server tracks every delivered alert (history truth),
    // while pop-ups are ephemeral views over at most the three newest items.
    // Capability flags match what the card actually renders: plain body text.
    readonly property int notificationCount: notificationServer.trackedNotifications.values.length
    property var popupNotifications: []
    function queuePopup(notification) {
        const next = root.popupNotifications.slice();
        next.unshift(notification);
        root.popupNotifications = next.slice(0, 3);
    }
    function hidePopup(notification) {
        root.popupNotifications = root.popupNotifications.filter(n => n !== notification);
    }
    function closeNotification(notification) {
        root.hidePopup(notification);
        notification.dismiss();
    }
    function dismissAllNotifications() {
        const items = notificationServer.trackedNotifications.values.slice();
        for (let i = 0; i < items.length; i++) items[i].dismiss();
    }
    NotificationServer {
        id: notificationServer
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: false
        actionIconsSupported: false
        imageSupported: false
        inlineReplySupported: false
        persistenceSupported: false
        onNotification: notification => {
            notification.tracked = true;
            if (shellPreferences.doNotDisturb)
                return;
            root.queuePopup(notification);
        }
    }
    // App file dialogs on Phone/Tablet (tessarchy-portal asks; see FilePicker).
    readonly property var focusedScreen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
    FilePicker {
        id: filePicker
        screen: root.focusedScreen
    }
    IpcHandler {
        target: "picker"
        // "ok": the picker will answer on fifo; anything else: use GTK's dialog.
        function pick(fifo: string, mode: string, multiple: string, folder: string, name: string, title: string, globs: string): string {
            const screen = root.focusedScreen;
            if (!screen || Policy.effectiveMode(shellPreferences.layoutMode, screen.width, screen.height) === "desktop")
                return "desktop";
            if (["open", "folder", "save"].indexOf(mode) < 0 || fifo.length === 0)
                return "invalid";
            filePicker.open({ fifo: fifo, mode: mode, multiple: multiple === "1", folder: folder, name: name, title: title, globs: globs });
            return "ok";
        }
        function dismiss(fifo: string): void {
            filePicker.dismiss(fifo);
        }
    }
    Variants {
        model: Quickshell.screens
        Scope {
            id: surface
            required property var modelData
            readonly property string mode: Policy.effectiveMode(shellPreferences.layoutMode, modelData.width, modelData.height)
            readonly property bool isPhone: mode === "phone"
            readonly property bool gestures: Policy.gestureNavigation(mode, shellPreferences.navigation)
            readonly property var dock: Policy.dockLayout(mode, modelData.width, root.oskAvailable, gestures)
            readonly property var gestureEdge: Policy.gestureEdgeSize(mode, panel.expanded)
            // Bar geometry comes from Policy.barGeometry; do not add literals here.
            readonly property var bar: Policy.barGeometry(mode, dock.rows)
            readonly property int navHeight: bar.height
            readonly property int launcherRows: Math.ceil((panel.appEntries.length + 4) / Policy.columns(mode, Policy.panelWidth(mode, modelData.width) - 32))
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
            readonly property string modeLabel: (shellPreferences.layoutMode === "auto" ? "Auto · " : "") + Policy.title(mode)
            // Pop-ups render once, on the first screen, not on every output.
            readonly property bool isPrimaryScreen: Quickshell.screens.length > 0 && Quickshell.screens[0] === modelData
            // Arm or disarm the keyboard whenever the layout for this output changes.
            onModeChanged: {
                if (isPrimaryScreen) root.applyOskMode(mode);
                if (mode !== "desktop") panel.startMenuOpen = false;
            }
            Component.onCompleted: if (isPrimaryScreen) root.applyOskMode(mode)
            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }
            PanelWindow {
                id: panel
                screen: surface.modelData
                readonly property var appEntries: Apps.majorApplications(DesktopEntries.applications.values)
                property string page: ""
                // Desktop Start menu, opened by the taskbar's Start button.
                property bool startMenuOpen: false
                property var closeTarget: null
                property string messageRecipient: ""
                readonly property bool expanded: page !== ""
                // The keyboard is a separate top-layer surface that would cover
                // the drawer, so shell pages dismiss it like an IME on Recents.
                onExpandedChanged: {
                    if (expanded && root.oskAvailable)
                        Quickshell.execDetached(["tessarchy-osk", "hide"]);
                }
                anchors {
                    bottom: true
                    // Desktop uses a full-width taskbar, open page or not; touch
                    // layouts keep the floating centred dock sized to its content.
                    left: surface.mode === "desktop"
                    right: surface.mode === "desktop"
                }
                implicitWidth: expanded ? Policy.panelWidth(surface.mode, surface.modelData.width) : surface.dock.width
                implicitHeight: expanded && surface.isPhone && page === "windows" ? surface.modelData.height - 48 : expanded ? Math.min(page === "windows" ? surface.modelData.height - 60 : page === "apps" ? surface.launcherRows * 124 + 156 : surface.mode === "tablet" ? 740 : 640, surface.modelData.height - 64) : surface.navHeight
                exclusiveZone: surface.navHeight
                color: "transparent"
                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: panel.expanded ? 0 : surface.bar.gap
                    width: surface.isPhone && panel.page === "windows" ? parent.width : panel.expanded ? Math.min(parent.width, expandedContent.width + pageColumn.anchors.leftMargin + pageColumn.anchors.rightMargin) : parent.width
                    radius: panel.expanded && panel.page === "windows" ? 0 : Theme.radius("card", panel.expanded ? 26 : (surface.mode === "desktop" ? 14 : 26), height)
                    color: panel.expanded ? (panel.page === "windows" ? Theme.switcherGlass : Theme.glassStrong) : Theme.bar(shellPreferences.barOpacity)
                    border.width: surface.isPhone && panel.page === "windows" ? 0 : Theme.borderWidth(1)
                    border.color: Qt.alpha(root.accentColor, 0.15)
                    Loader {
                        anchors.fill: parent
                        active: surface.isPhone && panel.page === "windows"
                        sourceComponent: RecentsBackdrop {}
                    }
                }
                WlrLayershell.namespace: "tessera"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: ["phone", "messages", "cellular", "settings", "sounds"].indexOf(panel.page) >= 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

                function showPage(name) {
                    if (name === "windows" && page !== "windows") switcher.selectActive();
                    closeTarget = null;
                    startMenuOpen = false;
                    page = page === name ? "" : name;
                }
                function launch(command) {
                    Quickshell.execDetached(command);
                    page = "";
                }
                // Navigation actions shared by the dock buttons and edge gestures.
                function goBack() {
                    statusBar.drawerOpen = false;
                    closeTarget = null;
                    page = "";
                }
                function navigate(action) {
                    if (action === "back") goBack();
                    else if (action === "home") showPage("apps");
                    else if (action === "recents") showPage("windows");
                }
                onPageChanged: {
                    if (["phone", "messages", "cellular", "sounds"].indexOf(page) >= 0) communications.request("status");
                }
                Connections {
                    target: root
                    function onSwitcherCommand(action) {
                        if (!Hyprland.focusedMonitor || Hyprland.focusedMonitor.name !== surface.modelData.name) return;
                        if (action === "cancel") quickSwitcher.cancel();
                        else if (action === "accept") quickSwitcher.commit();
                        else if (Hyprland.toplevels.values.length) quickSwitcher.show(action === "previous" ? -1 : 1);
                    }
                }
                Connections {
                    target: root
                    function onActionRequested(action) {
                        if (!Hyprland.focusedMonitor || Hyprland.focusedMonitor.name !== surface.modelData.name) return;
                        panel.closeTarget = action === "close" && root.activeWindow ? root.activeWindow.wayland : null;
                        panel.page = action === "exit" ? "session" : panel.closeTarget ? "close" : "";
                    }
                }
                Connections {
                    target: root
                    function onOpenAppRequested(name) {
                        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === surface.modelData.name) panel.page = name;
                    }
                }
                Connections {
                    target: communications
                    function onIncoming() {
                        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === surface.modelData.name) {
                            panel.page = "phone";
                            statusBar.drawerOpen = false;
                        }
                    }
                }
                Connections {
                    target: panel.closeTarget
                    function onClosed() {
                        panel.closeTarget = null;
                        panel.page = surface.mode === "desktop" ? "" : "windows";
                    }
                }
                ColumnLayout {
                    id: pageColumn
                    anchors.fill: parent
                    // Collapsed, the rows sit bar.inset inside the frame on both sides.
                    anchors.topMargin: panel.expanded ? surface.bar.pageTop : surface.bar.inset
                    anchors.bottomMargin: panel.expanded ? surface.bar.pageBottom : surface.bar.inset + surface.bar.gap
                    anchors.leftMargin: surface.bar.padding
                    anchors.rightMargin: surface.bar.padding
                    spacing: 8
                    ColumnLayout {
                        id: expandedContent
                        visible: panel.expanded
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        // Desktop keeps the taskbar full width, so the page is a
                        // centred column rather than the whole bar.
                        Layout.maximumWidth: surface.mode === "desktop" ? Policy.panelWidth(surface.mode, surface.modelData.width) : surface.modelData.width
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        Text {
                            // The launcher page carries no heading; Desktop gets
                            // the Start menu instead.
                            visible: panel.page !== "windows" && panel.page !== "apps"
                            text: panel.page === "close" ? "Close this window?" : panel.page === "settings" ? "Settings" : panel.page === "phone" ? "Phone" : panel.page === "messages" ? "Messages" : panel.page === "cellular" ? "SIM & cellular" : panel.page === "sounds" ? "Sounds & ringtones" : panel.page === "notifications" ? "Alerts" : "End this session?"
                            color: root.accentColor
                            font.pixelSize: 22
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        // Marks the scroll edge once content has moved under the heading.
                        Rectangle {
                            visible: pageScroll.visible
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.alpha(root.accentColor, 0.25)
                            opacity: pageScroll.ScrollBar.vertical.position > 0 ? 1 : 0
                        }
                        AppSwitcher {
                            id: switcher
                            visible: panel.page === "windows"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            windows: surface.isPhone ? root.switcherWindows.slice().reverse() : Hyprland.toplevels.values
                            phoneMode: surface.isPhone
                            activeWindow: root.activeWindow
                            iconForWindow: window => {
                                const entry = window.wayland ? DesktopEntries.heuristicLookup(window.wayland.appId) : null;
                                return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
                            }
                            nameForWindow: window => {
                                const entry = window.wayland ? DesktopEntries.heuristicLookup(window.wayland.appId) : null;
                                return entry ? entry.name : (window.wayland && window.wayland.appId) || window.title || "Application";
                            }
                            // Phone previews match the app area between the status bar and dock.
                            screenSize: Qt.size(surface.modelData.width, Math.max(1, surface.modelData.height - surface.navHeight - 48))
                            fillApp: surface.mode !== "desktop"
                            emptyHint: surface.mode === "desktop"
                                ? "Your open apps will appear here.\nOpen one from the Start menu."
                                : "Your open apps will appear here.\nTap Home to launch your first."
                            accentColor: root.accentColor
                            reducedMotion: shellPreferences.reducedMotion
                            activateTarget: target => root.activateHandle(target)
                            onActivated: panel.page = ""
                            onDismissed: panel.page = ""
                            onCloseRequested: target => { if (target) target.close(); }
                        }
                        ScrollView {
                            id: pageScroll
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
                                        AppTile { text: "Phone"; symbol: "call"; accentColor: root.accentColor; onClicked: panel.showPage("phone") }
                                        AppTile { text: "Messages"; symbol: "messages"; accentColor: root.accentColor; onClicked: panel.showPage("messages") }
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
                                        AppTile {
                                            text: "Alerts"
                                            symbol: "bell"
                                            accentColor: root.accentColor
                                            onClicked: panel.showPage("notifications")
                                        }
                                    }
                                    Text {
                                        text: root.oskAvailable ? "Prototype · The keyboard opens for text fields; Keyboard shows or hides it." : "Prototype · Physical keyboard needed for text input."
                                        color: Theme.textSecondary
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                                Loader {
                                    visible: active
                                    active: panel.page === "phone"
                                    Layout.fillWidth: true
                                    sourceComponent: PhoneApp {
                                        backend: communications
                                        accentColor: root.accentColor
                                        onSimRequested: panel.page = "cellular"
                                        onMessageRequested: number => { panel.messageRecipient = number; panel.page = "messages"; }
                                    }
                                }
                                Loader {
                                    visible: active
                                    active: panel.page === "messages"
                                    Layout.fillWidth: true
                                    sourceComponent: MessagesApp {
                                        backend: communications
                                        accentColor: root.accentColor
                                        recipient: panel.messageRecipient
                                    }
                                }
                                Loader {
                                    visible: active
                                    active: panel.page === "sounds"
                                    Layout.fillWidth: true
                                    sourceComponent: SoundSettings { backend: communications; accentColor: root.accentColor }
                                }
                                Loader {
                                    visible: active
                                    active: panel.page === "cellular"
                                    Layout.fillWidth: true
                                    sourceComponent: CellularSettings { backend: communications; accentColor: root.accentColor }
                                }
                                Loader {
                                    visible: active
                                    active: panel.page === "settings"
                                    onActiveChanged: if (active) themeList.running = true
                                    Layout.fillWidth: true
                                    sourceComponent: SettingsPage {
                                        backend: communications
                                        onCellularRequested: panel.page = "cellular"
                                        onSoundsRequested: panel.page = "sounds"
                                        preferences: shellPreferences
                                        themes: root.themes
                                        currentTheme: root.themeName
                                        onThemeRequested: name => root.setTheme(name)
                                        activeMode: Policy.title(surface.mode)
                                        displayWidth: surface.modelData.width
                                        displayHeight: surface.modelData.height
                                        accentColor: root.accentColor
                                        onEndSessionRequested: panel.page = "session"
                                        onControlsRequested: statusBar.toggleDrawer()
                                        onReplayRequested: root.replayBrand()
                                    }
                                }
                                Loader {
                                    visible: active
                                    active: panel.page === "notifications"
                                    Layout.fillWidth: true
                                    sourceComponent: NotificationCenter {
                                        server: notificationServer
                                        preferences: shellPreferences
                                        accentColor: root.accentColor
                                        onClearAllRequested: root.dismissAllNotifications()
                                    }
                                }
                                ColumnLayout {
                                    visible: panel.page === "close"
                                    Layout.fillWidth: true
                                    Text {
                                        text: panel.closeTarget ? panel.closeTarget.title : "Window is no longer available."
                                        color: Theme.text
                                        wrapMode: Text.WrapAnywhere
                                        Layout.fillWidth: true
                                    }
                                    TouchButton {
                                        text: "Cancel"
                                        Layout.fillWidth: true
                                        onClicked: {
                                            panel.closeTarget = null;
                                            panel.page = surface.mode === "desktop" ? "" : "windows";
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
                                            panel.page = surface.mode === "desktop" ? "" : "windows";
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
                                        color: Theme.text
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
                        // Marks the scroll edge above the dock while more content follows.
                        Rectangle {
                            visible: pageScroll.visible
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.alpha(root.accentColor, 0.25)
                            opacity: pageScroll.ScrollBar.vertical.size < 1 && pageScroll.ScrollBar.vertical.position + pageScroll.ScrollBar.vertical.size < 0.999 ? 1 : 0
                        }
                    }
                    GridLayout {
                        layer.enabled: panel.page === "windows"
                        visible: surface.mode !== "desktop"
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: surface.bar.rowsHeight
                        columns: surface.dock.columns
                        columnSpacing: surface.bar.columnGap
                        rowSpacing: surface.bar.rowGap
                        NavButton {
                            text: "Phone"; symbol: "call"
                            showLabel: shellPreferences.showLabels
                            accentColor: root.accentColor
                            selected: panel.page === "phone"
                            onClicked: panel.showPage("phone")
                        }
                        NavButton {
                            text: "Messages"; symbol: "messages"
                            showLabel: shellPreferences.showLabels
                            accentColor: root.accentColor
                            selected: panel.page === "messages"
                            onClicked: panel.showPage("messages")
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
                        NavButton {
                            // Gesture navigation replaces Back and Home only.
                            visible: !surface.gestures
                            text: "Back"
                            symbol: "back"
                            showLabel: shellPreferences.showLabels
                            accentColor: root.accentColor
                            enabled: panel.expanded || statusBar.drawerOpen
                            onClicked: panel.navigate("back")
                        }
                        NavButton {
                            visible: !surface.gestures
                            text: surface.mode === "desktop" ? "Apps" : "Home"
                            symbol: "home"
                            showLabel: shellPreferences.showLabels
                            accentColor: root.accentColor
                            selected: panel.page === "apps"
                            onClicked: panel.navigate("home")
                        }
                        NavButton {
                            text: surface.mode === "desktop" ? "Windows" : "Recents"
                            symbol: "recents"
                            showLabel: shellPreferences.showLabels
                            accentColor: root.accentColor
                            selected: panel.page === "windows"
                            onClicked: panel.navigate("recents")
                        }
                    }
                    // Desktop taskbar in the spirit of Windows XP, rendered as
                    // glass: Start and quick-launch on the left, wide bevelled
                    // task buttons, and a sunken tray with the clock on the right.
                    RowLayout {
                        visible: surface.mode === "desktop"
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: surface.bar.row
                        spacing: 0
                        StartButton {
                            Layout.alignment: Qt.AlignVCenter
                            accentColor: root.accentColor
                            selected: panel.startMenuOpen
                            onClicked: {
                                panel.page = "";
                                panel.startMenuOpen = !panel.startMenuOpen;
                            }
                        }
                        WeatherChip {
                            visible: weatherBackend.available
                            conditions: weatherBackend.state
                            glyphSize: 18
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 6
                            Layout.rightMargin: 6
                        }
                        NavButton {
                            Layout.fillWidth: false
                            Layout.minimumWidth: 32
                            Layout.preferredWidth: 32
                            text: "Windows"; symbol: "recents"; showLabel: false
                            iconSize: 18
                            accentColor: root.accentColor
                            selected: quickSwitcher.open
                            onClicked: quickSwitcher.toggle()
                        }
                        NavButton {
                            Layout.fillWidth: false
                            Layout.minimumWidth: 32
                            Layout.preferredWidth: 32
                            text: "Settings"; symbol: "settings"; showLabel: false
                            iconSize: 18
                            accentColor: root.accentColor
                            selected: panel.page === "settings"
                            onClicked: panel.showPage("settings")
                        }
                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                            color: Qt.alpha(root.accentColor, 0.18)
                        }
                        TaskStrip {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            windows: Hyprland.toplevels.values
                            activeWindow: root.activeWindow
                            accentColor: root.accentColor
                            iconForWindow: window => {
                                const entry = window.wayland ? DesktopEntries.heuristicLookup(window.wayland.appId) : null;
                                return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
                            }
                            onWindowRequested: window => {
                                panel.startMenuOpen = false;
                                panel.page = "";
                                Qt.callLater(() => root.activateWindow(window));
                            }
                        }
                        // Sunken tray, as on the XP taskbar: indicators and clock.
                        Rectangle {
                            implicitHeight: surface.bar.row
                            implicitWidth: trayRow.implicitWidth + 12
                            Layout.alignment: Qt.AlignVCenter
                            radius: Theme.radius("tile", 8, height)
                            color: Qt.alpha(Theme.trayGlass, 0.20)
                            border.width: 1
                            border.color: Qt.alpha(Theme.trayBorder, 0.12)
                            RowLayout {
                                id: trayRow
                                anchors.centerIn: parent
                                spacing: 0
                                // Built-in indicators, as in a Windows tray.
                                StatusIndicators {
                                    compact: true
                                    showBatteryText: false
                                    accentColor: root.accentColor
                                    notificationCount: root.notificationCount
                                    cellularStrength: root.cellularStrength
                                    wifiStrength: root.wifiStrength
                                    airplaneOn: !!(radioBackend.state.airplane && radioBackend.state.airplane.enabled)
                                    batteryPresent: UPower.displayDevice.isPresent
                                    batteryPercent: UPower.displayDevice.percentage
                                    audioAvailable: root.audioAvailable
                                    audioMuted: root.audioAvailable && root.audioSink.audio.muted
                                    notificationsSelected: panel.page === "notifications"
                                    settingsSelected: panel.page === "settings"
                                    onNotificationsRequested: panel.showPage("notifications")
                                    onMuteToggled: root.audioSink.audio.muted = !root.audioSink.audio.muted
                                    onSettingsRequested: panel.showPage("settings")
                                }
                                Repeater {
                                    model: SystemTray.items
                                    delegate: TrayButton {
                                        id: taskTrayButton
                                        slotWidth: 32
                                        required property var modelData
                                        accentColor: root.accentColor
                                        icon.source: /nm-applet|networkmanager|network manager/i.test(modelData.id + " " + modelData.title)
                                            ? "icons/network-wired.svg" : modelData.icon
                                        Accessible.name: modelData.title || "Tray item"
                                        onClicked: {
                                            if (modelData.hasMenu)
                                                modelData.display(taskTrayButton.QsWindow.window, 0, 48);
                                            else
                                                modelData.activate();
                                        }
                                    }
                                }
                                Text {
                                    text: Qt.formatDateTime(clock.date, shellPreferences.use24Hour ? "h:mm" : "h:mm AP")
                                    color: Theme.panelText
                                    font.pixelSize: 12
                                    leftPadding: 6
                                    rightPadding: 10
                                    verticalAlignment: Text.AlignVCenter
                                    Layout.alignment: Qt.AlignVCenter
                                    Accessible.name: "Time in the taskbar"
                                }
                            }
                        }
                    }
                }
            }
            // Gesture navigation: thin edge strips catch swipes that start at
            // the screen edge. Touches inside a strip do not reach the app below,
            // so the strips stay a few pixels wide. The bottom strip covers the
            // gap under the dock row and spans the screen.
            PanelWindow {
                id: bottomGesture
                screen: surface.modelData
                visible: surface.gestures
                anchors {
                    bottom: true
                    left: true
                    right: true
                }
                implicitHeight: surface.gestureEdge.bottom
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "tessera-gesture"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                EdgeSwipeArea {
                    id: bottomSwipe
                    anchors.fill: parent
                    edge: "bottom"
                    onGesture: action => panel.navigate(action)
                }
                GestureHandle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.bottom
                    anchors.verticalCenterOffset: -surface.gestureEdge.handle
                    shown: shellPreferences.showGestureHandle
                    accentColor: root.accentColor
                    reducedMotion: shellPreferences.reducedMotion
                    progress: bottomSwipe.progress
                }
            }
            // Side strips keep exclusiveZone 0, so they sit between the status
            // bar and the dock (and the on-screen keyboard), above open pages.
            Variants {
                model: ["left", "right"]
                PanelWindow {
                    id: sideGesture
                    required property string modelData
                    screen: surface.modelData
                    visible: surface.gestures
                    anchors {
                        top: true
                        bottom: true
                        left: modelData === "left"
                        right: modelData === "right"
                    }
                    implicitWidth: surface.gestureEdge.side
                    exclusiveZone: 0
                    color: "transparent"
                    WlrLayershell.namespace: "tessera-gesture"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                    EdgeSwipeArea {
                        anchors.fill: parent
                        edge: sideGesture.modelData
                        onGesture: action => panel.navigate(action)
                    }
                }
            }
            PanelWindow {
                id: quickSwitcher
                property bool open: false
                property var pendingTarget: null
                // Timestamp of an Alt release that arrived before the switcher
                // opened. A fast Alt+Tab spawns two shell commands whose order
                // is not guaranteed, so the release can land first; remembering
                // it makes the tap switch immediately instead of leaving the
                // overlay stuck open with the keyboard grabbed. An early cancel
                // (Escape) is remembered the same way and skips the open.
                property double releasedAt: 0
                property double cancelledAt: 0
                readonly property int tapWindow: 300
                screen: surface.modelData
                visible: open && Hyprland.toplevels.values.length > 0
                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true
                exclusiveZone: 0
                color: "transparent"
                WlrLayershell.namespace: "tessera-quick-switcher"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                // Alt release: commit when the switcher is up, otherwise note
                // that the tap is already over.
                function commit() {
                    if (open) quickIcons.activateCurrent();
                    else releasedAt = Date.now();
                }
                // Escape: close when up, otherwise note the cancel.
                function cancel() {
                    if (open) open = false;
                    else cancelledAt = Date.now();
                }
                function show(direction) {
                    const tapped = !open && releasedAt > 0 && Date.now() - releasedAt < tapWindow;
                    const cancelled = !open && cancelledAt > 0 && Date.now() - cancelledAt < tapWindow;
                    releasedAt = 0;
                    cancelledAt = 0;
                    if (cancelled) return;
                    if (!open) {
                        quickIcons.reset();
                        quickIcons.selectActive();
                    }
                    panel.page = "";
                    panel.startMenuOpen = false;
                    statusBar.drawerOpen = false;
                    open = true;
                    quickIcons.step(direction);
                    Qt.callLater(() => quickIcons.forceActiveFocus());
                    if (tapped) quickIcons.activateCurrent();
                }
                // The desktop taskbar's Windows button. Opens the bare icon
                // row over the desktop with the current window already
                // selected; pressing it again walks forward through the open
                // windows, so it cycles without a keyboard.
                function toggle() {
                    panel.page = "";
                    panel.startMenuOpen = false;
                    statusBar.drawerOpen = false;
                    if (!open) {
                        quickIcons.reset();
                        quickIcons.selectActive();
                        open = true;
                        Qt.callLater(() => quickIcons.forceActiveFocus());
                    } else {
                        quickIcons.step(1);
                    }
                }

                // Clicking anywhere but an icon dismisses. Deliberately
                // invisible: no backdrop and no panel, so the icons read as
                // floating in the middle of the screen.
                MouseArea {
                    anchors.fill: parent
                    onClicked: quickSwitcher.open = false
                }
                QuickSwitcher {
                    id: quickIcons
                    anchors.centerIn: parent
                    width: Math.min(quickSwitcher.width - 64, implicitWidth)
                    height: implicitHeight
                    windows: root.switcherWindows
                    accentColor: root.accentColor
                    reducedMotion: shellPreferences.reducedMotion
                    iconForWindow: window => {
                        const entry = window.wayland ? DesktopEntries.heuristicLookup(window.wayland.appId) : null;
                        return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
                    }
                    onDismissed: quickSwitcher.open = false
                    onWindowRequested: window => {
                        quickSwitcher.pendingTarget = window.wayland;
                        quickSwitcher.open = false;
                        quickActivate.restart();
                    }
                }
                Timer {
                    id: quickActivate
                    interval: 100
                    onTriggered: {
                        const target = quickSwitcher.pendingTarget;
                        quickSwitcher.pendingTarget = null;
                        if (target) {
                            root.activateHandle(target);
                            if (surface.mode !== "desktop") target.maximized = true;
                        }
                    }
                }
                Connections {
                    target: quickSwitcher.pendingTarget
                    function onClosed() { quickSwitcher.pendingTarget = null; }
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
                    radius: Theme.radius("card", statusBar.drawerOpen ? 28 : 0, height)
                    visible: surface.mode !== "desktop" || statusBar.drawerOpen
                    color: statusBar.drawerOpen ? Theme.glassStrong : Theme.bar(shellPreferences.barOpacity)
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.alpha(root.accentColor, 0.1) }
                }
                WlrLayershell.namespace: "tessera-status"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
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
                    anchors.leftMargin: surface.mode === "desktop" ? 0 : 18
                    anchors.rightMargin: surface.mode === "desktop" ? 0 : 8
                    spacing: surface.mode === "phone" ? 4 : surface.modelData.width < 360 ? 4 : 8
                    TouchButton {
                        id: mobileClock
                        visible: surface.mode !== "desktop"
                        text: Qt.formatDateTime(clock.date, shellPreferences.use24Hour ? "h:mm" : "h:mm AP").replace(/ [AP]M$/, "")
                        Accessible.name: "Clock " + Qt.formatDateTime(clock.date, shellPreferences.use24Hour ? "h:mm" : "h:mm AP") + ", quick controls"
                        Layout.minimumHeight: 48
                        Layout.preferredWidth: 66
                        implicitHeight: 48
                        padding: 0
                        background: Item {}
                        contentItem: Text {
                            text: mobileClock.text
                            color: Theme.text
                            verticalAlignment: Text.AlignVCenter
                            font { pixelSize: 16; weight: Font.DemiBold; letterSpacing: 0.2 }
                        }
                        onClicked: statusBar.toggleDrawer()
                    }
                    TouchButton {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 64
                        Layout.minimumHeight: 48
                        implicitHeight: 48
                        text: "Quick controls"
                        Accessible.name: statusBar.drawerOpen ? "Collapse quick controls" : "Open quick controls, or swipe down"
                        padding: 0
                        background: Item {}
                        contentItem: Item { }
                        onClicked: statusBar.toggleDrawer()
                    }
                    WeatherChip {
                        visible: weatherBackend.available && surface.mode !== "desktop"
                        conditions: weatherBackend.state
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 4
                    }
                    // Built-in indicators move to the taskbar tray in Desktop
                    // mode; the mobile strip keeps them along the top edge.
                    StatusIndicators {
                        visible: surface.mode !== "desktop"
                        compact: surface.mode === "phone"
                        accentColor: root.accentColor
                        notificationCount: root.notificationCount
                        cellularStrength: root.cellularStrength
                        wifiStrength: root.wifiStrength
                        airplaneOn: !!(radioBackend.state.airplane && radioBackend.state.airplane.enabled)
                        batteryPresent: UPower.displayDevice.isPresent
                        batteryPercent: UPower.displayDevice.percentage
                        audioAvailable: root.audioAvailable
                        audioMuted: root.audioAvailable && root.audioSink.audio.muted
                        notificationsSelected: panel.page === "notifications"
                        settingsSelected: panel.page === "settings"
                        showBatteryText: surface.modelData.width >= 380
                        showVolume: surface.modelData.width >= 700
                        showSettings: surface.modelData.width >= 560
                        onNotificationsRequested: panel.showPage("notifications")
                        onPanelRequested: statusBar.toggleDrawer()
                        onMuteToggled: root.audioSink.audio.muted = !root.audioSink.audio.muted
                        onSettingsRequested: { statusBar.drawerOpen = false; panel.showPage("settings"); }
                    }
                }
                }
                ScrollView {
                    x: (parent.width - width) / 2; y: 60
                    width: Math.min(parent.width - 32, 720)
                    height: Math.max(0, parent.height - y - 56)
                    visible: statusBar.drawerOpen
                    clip: true
                    contentWidth: availableWidth
                    QuickSettings {
                        bluetoothAdapter: root.bluetoothAdapter
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
                        onCellularRequested: { statusBar.drawerOpen = false; panel.page = "cellular"; }
                        onDismissed: statusBar.drawerOpen = false
                        onSettingsRequested: { statusBar.drawerOpen = false; panel.showPage("settings"); }
                    }
                }
                TouchButton {
                    visible: statusBar.drawerOpen
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width - 32, 720)
                    height: 48
                    text: "Collapse quick controls"
                    background: Item {}
                    contentItem: Item { Rectangle { anchors.centerIn: parent; width: 40; height: 4; radius: Theme.radius("card", 2, height); color: root.accentColor } }
                    onClicked: statusBar.drawerOpen = false
                    DragHandler {
                        target: null
                        xAxis.enabled: false
                        onActiveTranslationChanged: { if (activeTranslation.y < -20) statusBar.drawerOpen = false; }
                    }
                }
                Connections {
                    target: panel
                    function onPageChanged() { if (panel.page !== "") statusBar.drawerOpen = false; }
                }
            }
            // Windows-XP-style Start menu: a compact blue-tinted glass panel that
            // opens above the Start button on the primary output. The button
            // toggles it, choosing an app closes it, and it is Desktop-only.
            PanelWindow {
                id: startMenu
                screen: surface.modelData
                visible: surface.isPrimaryScreen && surface.mode === "desktop" && panel.startMenuOpen
                readonly property int gridColumns: 4
                readonly property int rows: Math.ceil(panel.appEntries.length / gridColumns)
                readonly property int gridHeight: Math.min(rows * 92, 300)
                anchors {
                    bottom: true
                    left: true
                }
                // Hyprland already offsets by the taskbar's exclusive zone, so a
                // zero margin lands the panel exactly on the taskbar's top edge.
                margins.bottom: 0
                margins.left: 12
                implicitWidth: 452
                implicitHeight: gridHeight + 78
                exclusiveZone: 0
                color: "transparent"
                WlrLayershell.namespace: "tessera-start"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                onVisibleChanged: {
                    if (visible) Qt.callLater(() => {
                        if (!startMenu.visible) return;
                        const first = startApplications.itemAt(0);
                        if (first) first.forceActiveFocus();
                        else startContent.forceActiveFocus();
                    });
                }
                HyprlandFocusGrab {
                    id: startGrab
                    windows: [startMenu, panel]
                    active: startMenu.visible
                    onCleared: panel.startMenuOpen = false
                }
                Rectangle {
                    id: startContent
                    focus: true
                    Keys.onEscapePressed: panel.startMenuOpen = false
                    anchors.fill: parent
                    // Flush with the taskbar, so only the top corners round.
                    topLeftRadius: 16
                    topRightRadius: 16
                    // Same frosted glass as the taskbar: a translucent accent
                    // fill the compositor blurs behind (namespace tessera-start).
                    color: Theme.bar(shellPreferences.barOpacity)
                    border.width: 1
                    border.color: Qt.alpha(root.accentColor, 0.15)
                    // Blue header band, the Start menu's signature.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 40
                        topLeftRadius: parent.topLeftRadius
                        topRightRadius: parent.topRightRadius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.startHeaderTop }
                            GradientStop { position: 1.0; color: Theme.startHeaderBottom }
                        }
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        Text {
                            text: "ALL APPS"
                            color: Theme.startHeaderText
                            Layout.leftMargin: 2
                            font {
                                pixelSize: 11
                                bold: true
                                letterSpacing: 2
                            }
                        }
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: startMenu.gridHeight
                            clip: true
                            contentWidth: availableWidth
                            GridLayout {
                                width: parent.width
                                columns: startMenu.gridColumns
                                columnSpacing: 8
                                rowSpacing: 8
                                Repeater {
                                    id: startApplications
                                    model: panel.appEntries
                                    delegate: StartMenuTile {
                                        required property var modelData
                                        text: modelData.name
                                        symbol: "browser"
                                        iconSource: Quickshell.iconPath(modelData.icon, true)
                                        accentColor: root.accentColor
                                        onClicked: {
                                            panel.startMenuOpen = false;
                                            modelData.execute();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // Pop-up host: an overlay window that never reserves space and
            // disappears entirely when no pop-ups are queued.
            PanelWindow {
                id: popupHost
                screen: surface.modelData
                visible: surface.isPrimaryScreen && root.popupNotifications.length > 0 && panel.page === ""
                readonly property var placement: Policy.notificationPlacement(surface.mode, surface.modelData.width)
                anchors {
                    top: true
                    right: true
                    left: placement.fullWidth
                }
                margins.top: placement.topOffset
                implicitWidth: placement.maxWidth
                implicitHeight: popupColumn.implicitHeight
                exclusiveZone: 0
                color: "transparent"
                WlrLayershell.namespace: "tessera-notifications"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                ColumnLayout {
                    id: popupColumn
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: root.popupNotifications
                        delegate: ColumnLayout {
                            id: popupItem
                            required property var modelData
                            Layout.fillWidth: true
                            NotificationCard {
                                Layout.fillWidth: true
                                notification: popupItem.modelData
                                accentColor: root.accentColor
                                onOpened: root.hidePopup(popupItem.modelData)
                                onClosed: root.closeNotification(popupItem.modelData)
                            }
                            Timer {
                                interval: Policy.notificationTimeout(popupItem.modelData.urgency) * 1000
                                running: interval > 0
                                onTriggered: root.hidePopup(popupItem.modelData)
                            }
                        }
                    }
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
                color: Theme.background
                WlrLayershell.namespace: "tessera-home"
                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                Image {
                    anchors.fill: parent
                    source: root.themeBackground || "artwork/aurora-fold.png"
                    fillMode: Image.PreserveAspectCrop
                }
                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(Theme.darkerBackground, shellPreferences.wallpaperDim)
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
                        color: Theme.text
                        font {
                            pixelSize: surface.isPhone ? 58 : 72
                            weight: Font.Light
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                        color: Theme.accent
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
