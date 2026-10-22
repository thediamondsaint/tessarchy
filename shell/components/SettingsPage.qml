pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
ColumnLayout {
    id: page
    required property var backend
    signal soundsRequested
    signal cellularRequested
    required property var preferences
    required property string activeMode
    required property int displayWidth
    required property int displayHeight
    property color accentColor: Theme.accent
    // tessarchy-theme list rows: { name, mode, background, foreground, accent, preview }.
    property var themes: []
    property string currentTheme: ""
    property bool themeBusy: false
    property string themeError: ""
    function themeLabel(name) {
        if (name === "tessera") return "Tessa Night";
        if (name === "tessera-light") return "Tessa Light";
        return name.split("-").map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(" ");
    }
    signal themeRequested(string name)
    signal endSessionRequested
    signal controlsRequested
    signal tapeRequested
    signal replayRequested
    spacing: 20

    RowLayout {
        Layout.fillWidth: true
        BrandMark {
            id: previewBrand
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            playOnStart: false
            reducedMotion: page.preferences.reducedMotion
        }
        ColumnLayout {
            Layout.fillWidth: true
            Text {
                text: "TESSA"
                color: Theme.text
                font {
                    pixelSize: 20
                    bold: true
                    letterSpacing: 2
                }
            }
            Text {
                text: "Running on Tessarchy · One shell. Every screen."
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.textMuted
                font.pixelSize: 13
            }
        }
    }
    Text {
        text: "WORKSPACE MODE"
        color: page.accentColor
        font {
            pixelSize: 11
            bold: true
            letterSpacing: 2
        }
    }
    Text {
        text: page.displayWidth + " × " + page.displayHeight + " logical pixels · " + page.activeMode
        color: Theme.textMuted
        font.pixelSize: 13
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    GridLayout {
        columns: width >= 560 ? 4 : 2
        columnSpacing: 10
        rowSpacing: 10
        Layout.fillWidth: true
        Repeater {
            model: [
                {
                    value: "auto",
                    label: "Automatic",
                    icon: "auto"
                },
                {
                    value: "phone",
                    label: "Phone",
                    icon: "phone"
                },
                {
                    value: "tablet",
                    label: "Tablet",
                    icon: "tablet"
                },
                {
                    value: "desktop",
                    label: "Desktop",
                    icon: "desktop"
                }
            ]
            delegate: AppTile {
                required property var modelData
                text: modelData.label
                symbol: modelData.icon
                selected: page.preferences.layoutMode === modelData.value
                accentColor: page.accentColor
                implicitHeight: 100
                onClicked: {
                    page.preferences.layoutMode = modelData.value;
                    page.preferences.sync();
                }
            }
        }
    }
    Text {
        text: "Automatic follows the usable display size, including rotation. Override it to keep a layout. Phone and Tablet keep touch navigation; Desktop uses the normal Hyprland layout. Existing windows stay in place. Desktop and wide tablets show a workspace strip in the status bar."
        color: Theme.textMuted
        font.pixelSize: 13
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    Text {
        text: "KEYBOARD"
        color: page.accentColor
        font {
            pixelSize: 11
            bold: true
            letterSpacing: 2
        }
    }
    Text {
        text: "Super + 1…5 · switch workspace\nSuper + Shift + 1…5 · move window to workspace\nSuper + Q · confirm window close\nSuper + Tab · next window\nSuper + F · maximize · Super + Shift + F · fullscreen\nSuper + Return · terminal · Super + Shift + E · confirm session exit"
        color: Theme.subtitleText
        font.pixelSize: 13
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    Text {
        text: "APPEARANCE"
        color: page.accentColor
        font {
            pixelSize: 11
            bold: true
            letterSpacing: 2
        }
    }
    Text {
        text: page.themeBusy ? "Applying theme…" : "Theme · " + page.themeLabel(page.currentTheme)
        color: Theme.textSecondary
        font.pixelSize: 14
    }
    Text {
        text: "THEMES"
        color: page.accentColor
        font { pixelSize: 11; bold: true; letterSpacing: 2 }
    }
    Text {
        text: "Choose a palette. Tessa applies it to glass surfaces, icons, widgets, wallpaper tint, and controls."
        color: Theme.textMuted
        font.pixelSize: 13
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    GridLayout {
        columns: width >= 560 ? 3 : 2
        columnSpacing: 10
        rowSpacing: 10
        Layout.fillWidth: true
        Repeater {
            model: page.themes
            delegate: TouchButton {
                id: themeButton
                required property var modelData
                text: page.themeLabel(modelData.name)
                enabled: !page.themeBusy
                Accessible.name: "Theme " + page.themeLabel(modelData.name)
                Accessible.description: modelData.mode + " palette, accent " + modelData.accent + (selected ? ", selected" : "")
                Accessible.role: Accessible.RadioButton
                Accessible.checked: selected
                selected: page.currentTheme === modelData.name
                accentColor: modelData.accent
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                // Every card is the same size: a 16:9 thumbnail over a name strip.
                readonly property int labelHeight: 36
                readonly property int inset: 6
                Layout.preferredHeight: Math.min(Math.round(width * 9 / 16), 120) + labelHeight
                // The theme's preview.png when it ships one; otherwise a mock built from its palette.
                readonly property bool hasPreview: modelData.preview !== undefined && modelData.preview.length > 0 && previewImage.status !== Image.Error
                contentItem: Text {
                    text: page.themeLabel(themeButton.modelData.name)
                    color: themeButton.modelData.foreground
                    font.pixelSize: 15
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignBottom
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: Theme.radius("tile", 12, height)
                    color: themeButton.modelData.background
                    border.width: themeButton.selected ? Theme.borderWidth(3) : Theme.borderWidth(1)
                    border.color: themeButton.selected ? themeButton.modelData.accent : Theme.selection
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: themeButton.labelHeight
                        color: Qt.alpha(themeButton.modelData.background, 0.86)
                    }
                    Icon {
                        visible: themeButton.selected
                        anchors { top: parent.top; right: parent.right; margins: 10 }
                        symbol: "check"
                        size: 22
                        color: themeButton.modelData.accent
                    }
                    Item {
                        anchors.fill: parent
                        anchors.margins: themeButton.inset
                        anchors.bottomMargin: themeButton.labelHeight
                        clip: true
                        Image {
                            id: previewImage
                            anchors.fill: parent
                            visible: themeButton.hasPreview
                            source: themeButton.modelData.preview ? "file://" + themeButton.modelData.preview : ""
                            sourceSize.width: 480
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        // Palette mock: status bar, a window with accent text and a dock.
                        Item {
                            id: mock
                            anchors.fill: parent
                            visible: !themeButton.hasPreview
                            readonly property color ink: themeButton.modelData.foreground
                            readonly property color accent: themeButton.modelData.accent
                            Rectangle {
                                id: mockBar
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: Math.max(4, Math.round(parent.height * 0.1))
                                radius: height / 2
                                color: Qt.alpha(mock.ink, 0.14)
                            }
                            Rectangle {
                                id: mockWindow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: mockBar.bottom
                                anchors.bottom: mockDock.top
                                anchors.margins: Math.round(parent.height * 0.08)
                                radius: Theme.radius("tile", 4, height)
                                color: Qt.alpha(mock.ink, 0.08)
                                border.width: Theme.borderWidth(1)
                                border.color: Qt.alpha(mock.accent, 0.6)
                                Column {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(parent.height * 0.14)
                                    spacing: Math.max(2, Math.round(parent.height * 0.1))
                                    Repeater {
                                        model: [0.55, 0.8, 0.4]
                                        delegate: Rectangle {
                                            required property real modelData
                                            required property int index
                                            width: parent.width * modelData
                                            height: Math.max(2, Math.round(mockWindow.height * 0.1))
                                            radius: height / 2
                                            color: index === 0 ? mock.accent : Qt.alpha(mock.ink, 0.45)
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                id: mockDock
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: parent.width * 0.5
                                height: Math.max(4, Math.round(parent.height * 0.12))
                                radius: height / 2
                                color: Qt.alpha(mock.ink, 0.14)
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.height * 0.6
                                    height: width
                                    radius: height / 2
                                    color: mock.accent
                                }
                            }
                        }
                    }
                }
                onClicked: page.themeRequested(modelData.name)
            }
        }
    }
    Text {
        visible: page.themeError.length > 0
        text: page.themeError
        color: Theme.errorText
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    Text {
        text: "Bar opacity · " + Math.round(page.preferences.barOpacity * 100) + "%"
        color: Theme.textSecondary
        font.pixelSize: 14
    }
    LevelSlider {
        from: 0.1
        to: 1
        value: page.preferences.barOpacity
        Layout.fillWidth: true
        Layout.minimumHeight: 56
        focusPolicy: Qt.NoFocus
        accentColor: page.accentColor
        Accessible.name: "Bar opacity"
        onMoved: page.preferences.barOpacity = value
    }
    Text {
        text: "Wallpaper shade · " + Math.round(page.preferences.wallpaperDim * 100) + "%"
        color: Theme.textSecondary
        font.pixelSize: 14
    }
    LevelSlider {
        from: 0
        to: 0.75
        value: page.preferences.wallpaperDim
        Layout.fillWidth: true
        Layout.minimumHeight: 56
        focusPolicy: Qt.NoFocus
        accentColor: page.accentColor
        Accessible.name: "Wallpaper shade"
        onMoved: page.preferences.wallpaperDim = value
    }
    Text {
        text: "NAVIGATION"
        color: page.accentColor
        font {
            pixelSize: 11
            bold: true
            letterSpacing: 2
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: [
                {
                    label: "Gestures",
                    value: "gestures"
                },
                {
                    label: "Buttons",
                    value: "buttons"
                }
            ]
            delegate: TouchButton {
                required property var modelData
                text: modelData.label
                selected: (page.preferences.navigation === "buttons" ? "buttons" : "gestures") === modelData.value
                accentColor: page.accentColor
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Accessible.name: "Navigation " + modelData.label + (selected ? ", selected" : "")
                onClicked: {
                    page.preferences.navigation = modelData.value;
                    page.preferences.sync();
                }
            }
        }
    }
    Text {
        text: "Phone and Tablet. Gestures: swipe up from the bottom edge for Home, swipe up and hold for Recents, swipe in from the left or right edge for Back. Buttons puts Back, Home and Recents in the dock."
        color: Theme.textMuted
        font.pixelSize: 12
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    TouchButton {
        text: page.preferences.showLabels ? "Navigation labels · On" : "Navigation labels · Off"
        selected: page.preferences.showLabels
        accentColor: page.accentColor
        Layout.fillWidth: true
        onClicked: {
            page.preferences.showLabels = !page.preferences.showLabels;
            page.preferences.sync();
        }
    }
    TouchButton {
        text: page.preferences.use24Hour ? "Clock · 24 hour" : "Clock · 12 hour"
        Layout.fillWidth: true
        onClicked: {
            page.preferences.use24Hour = !page.preferences.use24Hour;
            page.preferences.sync();
        }
    }
    Text {
        text: "MOTION"
        color: page.accentColor
        font {
            pixelSize: 11
            bold: true
            letterSpacing: 2
        }
    }
    TouchButton {
        text: page.preferences.reducedMotion ? "Reduced motion · On" : "Reduced motion · Off"
        selected: page.preferences.reducedMotion
        accentColor: page.accentColor
        Layout.fillWidth: true
        onClicked: {
            page.preferences.reducedMotion = !page.preferences.reducedMotion;
            page.preferences.sync();
        }
    }
    RowLayout {
        Layout.fillWidth: true
        BrandMark {
            id: motionPreview
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            playOnStart: false
            reducedMotion: page.preferences.reducedMotion
        }
        TouchButton {
            text: "Replay logo"
            enabled: !page.preferences.reducedMotion
            Layout.fillWidth: true
            onClicked: {
                previewBrand.replay();
                motionPreview.replay();
                page.replayRequested();
            }
        }
    }
    TouchButton { text: "Sounds & ringtones"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: page.soundsRequested() }
    TouchButton { text: "SIM & cellular"; Layout.fillWidth: true; focusPolicy: Qt.StrongFocus; onClicked: page.cellularRequested() }
    Text {
        text: "ALERTS"
        color: page.accentColor
        font {
            pixelSize: 11
            bold: true
            letterSpacing: 2
        }
    }
    TouchButton {
        text: page.preferences.doNotDisturb ? "Notification pop-ups muted" : "Notification pop-ups shown"
        selected: page.preferences.doNotDisturb
        accentColor: page.accentColor
        Layout.fillWidth: true
        Accessible.name: page.preferences.doNotDisturb ? "Notification pop-ups muted, button" : "Notification pop-ups shown, button"
        onClicked: {
            page.preferences.doNotDisturb = !page.preferences.doNotDisturb;
            page.preferences.sync();
        }
    }
    Text {
        text: "Muted notifications still collect in the alert center until dismissed. Nothing persists across sessions."
        color: Theme.textMuted
        font.pixelSize: 12
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    Text { text: "WINDOW WHEEL"; color: page.accentColor; Layout.fillWidth: true }
    Repeater {
        model: [{label: "Bottom slider", value: "bottom"}, {label: "Left edge wheel", value: "left"}, {label: "Right edge wheel", value: "right"}]
        delegate: TouchButton {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.label
            selected: page.preferences.wheelStyle === modelData.value
            onClicked: page.preferences.wheelStyle = modelData.value
        }
    }
    TouchButton {
        text: "Try Window Tape"
        Layout.fillWidth: true
        onClicked: page.tapeRequested()
    }
    Text {
        text: "Preview: new apps open side by side in a separate scrolling workspace. Drag the illuminated wheel to browse. Super+T returns here; use workspace controls to leave."
        color: Theme.textMuted
        font.pixelSize: 12
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    Text {
        text: "DESKTOP"
        color: page.accentColor
        font {
            pixelSize: 11
            bold: true
            letterSpacing: 2
        }
    }
    Text {
        text: "ROTATION"
        color: page.accentColor
        font {
            pixelSize: 11
            bold: true
            letterSpacing: 2
        }
    }
    RotationControl {
        Layout.fillWidth: true
        accentColor: page.accentColor
    }
    Text {
        text: "SYSTEM"
        color: page.accentColor
        font {
            pixelSize: 11
            bold: true
            letterSpacing: 2
        }
    }
    TouchButton {
        text: "Sound & connections"
        Layout.fillWidth: true
        onClicked: page.controlsRequested()
    }
    TouchButton {
        text: "Session…"
        Layout.fillWidth: true
        onClicked: page.endSessionRequested()
    }
    Text {
        text: "Tessa 0.1 · Running on Tessarchy"
        color: Theme.textMuted
        font.pixelSize: 12
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
}
