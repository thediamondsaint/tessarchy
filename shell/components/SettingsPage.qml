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
    property var themes: []
    property string currentTheme: ""
    property bool themeBusy: false
    property string themeError: ""
    property string accentChoice: String(Theme.accent)
    signal themeRequested(string name)
    signal accentRequested(string color)
    signal endSessionRequested
    signal controlsRequested
    signal tapeRequested
    signal replayRequested
    spacing: 14

    function themeLabel(name) {
        if (name === "tessera") return "Tessa Night";
        if (name === "tessera-light") return "Tessa Light";
        return name.split("-").map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(" ");
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 88
        radius: Theme.radius("card", 22, height)
        color: Qt.alpha(Theme.glassStrong, 0.92)
        border.width: Theme.borderWidth(1)
        border.color: Qt.alpha(page.accentColor, 0.32)
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            BrandMark {
                id: previewBrand
                Layout.preferredWidth: 58
                Layout.preferredHeight: 58
                playOnStart: false
                reducedMotion: page.preferences.reducedMotion
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "TESSA SETTINGS"
                    color: Theme.text
                    font { pixelSize: 20; bold: true; letterSpacing: 1.4 }
                }
                Text {
                    text: page.displayWidth + " × " + page.displayHeight + " · " + page.activeMode + " · tuned for touch"
                    color: Theme.textMuted
                    font.pixelSize: 13
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
            GlassIconButton {
                symbol: "close"
                reducedMotion: page.preferences.reducedMotion
                Accessible.name: "Close settings"
                onClicked: page.controlsRequested()
            }
        }
    }

    SettingsCard {
        title: "THEMES"
        subtitle: page.themeBusy ? "Applying palette…" : "Every glass surface, icon, widget, and wallpaper tint follows the selected palette."
        accentColor: page.accentColor
        Layout.fillWidth: true
        GridLayout {
            id: themeGrid
            columns: width >= 640 ? 3 : width >= 420 ? 2 : 1
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
                    readonly property int labelHeight: 34
                    readonly property int inset: 6
                    Layout.preferredHeight: Math.min(Math.round(width * 9 / 16), 120) + labelHeight
                    readonly property bool hasPreview: modelData.preview !== undefined && modelData.preview.length > 0 && previewImage.status !== Image.Error
                    contentItem: Text {
                        text: page.themeLabel(themeButton.modelData.name)
                        color: themeButton.modelData.foreground
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        radius: Theme.radius("tile", 14, height)
                        color: themeButton.modelData.background
                        border.width: themeButton.selected ? Theme.borderWidth(3) : Theme.borderWidth(1)
                        border.color: themeButton.selected ? themeButton.modelData.accent : Theme.selection
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: themeButton.labelHeight
                            color: Qt.alpha(themeButton.modelData.background, 0.88)
                        }
                        Icon {
                            visible: themeButton.selected
                            anchors { top: parent.top; right: parent.right; margins: 9 }
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
                            Item {
                                id: mock
                                anchors.fill: parent
                                visible: !themeButton.hasPreview
                                readonly property color ink: themeButton.modelData.foreground
                                readonly property color accent: themeButton.modelData.accent
                                Rectangle {
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    height: Math.max(4, Math.round(parent.height * 0.1))
                                    radius: Theme.radius("progress", 3, height)
                                    color: Qt.alpha(mock.ink, 0.14)
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(parent.height * 0.08)
                                    radius: Theme.radius("tile", 5, height)
                                    color: Qt.alpha(mock.ink, 0.08)
                                    border.width: Theme.borderWidth(1)
                                    border.color: Qt.alpha(mock.accent, 0.62)
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
                                                height: Math.max(2, Math.round(parent.height * 0.1))
                                                radius: Theme.radius("progress", 2, height)
                                                color: index === 0 ? mock.accent : Qt.alpha(mock.ink, 0.45)
                                            }
                                        }
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
            font.pixelSize: 12
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }

    SettingsCard {
        title: "ACCENT COLOR"
        subtitle: "Choose the highlight color used across Tessa."
        accentColor: page.accentColor
        Layout.fillWidth: true
        GridLayout {
            columns: width >= 520 ? 6 : 3
            columnSpacing: 8
            rowSpacing: 8
            Layout.fillWidth: true
            Repeater {
                model: Theme.accentChoices
                delegate: TouchButton {
                    id: accentButton
                    required property string modelData
                    readonly property var labels: ["Mint", "Sky", "Lavender", "Rose", "Amber", "Cloud"]
                    text: labels[index]
                    required property int index
                    Accessible.name: "Accent color " + text
                    Accessible.checked: selected
                    selected: page.accentChoice.toLowerCase() === modelData
                    accentColor: modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 48
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 56
                    background: Rectangle {
                        radius: Theme.radius("button", 12, height)
                        color: accentButton.modelData
                        border.width: accentButton.selected ? 3 : 1
                        border.color: accentButton.selected ? Theme.text : Qt.alpha(Theme.text, 0.45)
                    }
                    contentItem: Text {
                        text: accentButton.text
                        color: Theme.darkBackground
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: page.accentRequested(modelData)
                }
            }
        }
    }

    GridLayout {
        id: settingsGrid
        columns: width >= 640 ? 2 : 1
        columnSpacing: 12
        rowSpacing: 12
        Layout.fillWidth: true

        SettingsCard {
            title: "WORKSPACE"
            subtitle: "Choose the layout that matches the device in your hands."
            accentColor: page.accentColor
            Layout.fillWidth: true
            GridLayout {
                columns: width >= 420 ? 4 : 2
                columnSpacing: 8
                rowSpacing: 8
                Layout.fillWidth: true
                Repeater {
                    model: [
                        {value: "auto", label: "Automatic", icon: "auto"},
                        {value: "phone", label: "Phone", icon: "phone"},
                        {value: "tablet", label: "Tablet", icon: "tablet"},
                        {value: "desktop", label: "Desktop", icon: "desktop"}
                    ]
                    delegate: AppTile {
                        required property var modelData
                        text: modelData.label
                        symbol: modelData.icon
                        selected: page.preferences.layoutMode === modelData.value
                        accentColor: page.accentColor
                        implicitHeight: 96
                        onClicked: {
                            page.preferences.layoutMode = modelData.value;
                            page.preferences.sync();
                        }
                    }
                }
            }
        }

        SettingsCard {
            title: "NAVIGATION"
            subtitle: "T cube, edge gestures, and touch-sized controls stay available in every layout."
            accentColor: page.accentColor
            Layout.fillWidth: true
            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: [{label: "Gestures", value: "gestures"}, {label: "Buttons", value: "buttons"}]
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
            TouchButton {
                text: page.preferences.showLabels ? "Navigation labels · On" : "Navigation labels · Off"
                selected: page.preferences.showLabels
                accentColor: page.accentColor
                Layout.fillWidth: true
                onClicked: { page.preferences.showLabels = !page.preferences.showLabels; page.preferences.sync(); }
            }
        }

        SettingsCard {
            title: "APPEARANCE"
            subtitle: "Tune the glass frame without losing the active theme contrast."
            accentColor: page.accentColor
            Layout.fillWidth: true
            Text { text: "Bar opacity · " + Math.round(page.preferences.barOpacity * 100) + "%"; color: Theme.textSecondary; font.pixelSize: 13 }
            LevelSlider {
                from: 0.1; to: 1; value: page.preferences.barOpacity
                Layout.fillWidth: true; Layout.minimumHeight: 52
                accentColor: page.accentColor; Accessible.name: "Bar opacity"
                onMoved: page.preferences.barOpacity = value
            }
            Text { text: "Wallpaper shade · " + Math.round(page.preferences.wallpaperDim * 100) + "%"; color: Theme.textSecondary; font.pixelSize: 13 }
            LevelSlider {
                from: 0; to: 0.75; value: page.preferences.wallpaperDim
                Layout.fillWidth: true; Layout.minimumHeight: 52
                accentColor: page.accentColor; Accessible.name: "Wallpaper shade"
                onMoved: page.preferences.wallpaperDim = value
            }
            TouchButton {
                text: page.preferences.use24Hour ? "Clock · 24 hour" : "Clock · 12 hour"
                Layout.fillWidth: true
                onClicked: { page.preferences.use24Hour = !page.preferences.use24Hour; page.preferences.sync(); }
            }
        }

        SettingsCard {
            title: "MOTION & DISPLAY"
            subtitle: "Keep transitions calm and rotate the output without leaving Tessa."
            accentColor: page.accentColor
            Layout.fillWidth: true
            TouchButton {
                text: page.preferences.reducedMotion ? "Reduced motion · On" : "Reduced motion · Off"
                selected: page.preferences.reducedMotion
                accentColor: page.accentColor
                Layout.fillWidth: true
                onClicked: { page.preferences.reducedMotion = !page.preferences.reducedMotion; page.preferences.sync(); }
            }
            RowLayout {
                Layout.fillWidth: true
                BrandMark {
                    id: motionPreview
                    Layout.preferredWidth: 64; Layout.preferredHeight: 64
                    playOnStart: false; reducedMotion: page.preferences.reducedMotion
                }
                TouchButton {
                    text: "Replay logo"
                    enabled: !page.preferences.reducedMotion
                    Layout.fillWidth: true
                    onClicked: { previewBrand.replay(); motionPreview.replay(); page.replayRequested(); }
                }
            }
            RotationControl { Layout.fillWidth: true; accentColor: page.accentColor }
        }

        SettingsCard {
            title: "WINDOW WHEEL"
            subtitle: "Move real full-size windows with a thumb-friendly slider or edge wheel."
            accentColor: page.accentColor
            Layout.fillWidth: true
            Repeater {
                model: [{label: "Bottom slider", value: "bottom"}, {label: "Left edge wheel", value: "left"}, {label: "Right edge wheel", value: "right"}]
                delegate: TouchButton {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label
                    selected: page.preferences.wheelStyle === modelData.value
                    accentColor: page.accentColor
                    onClicked: { page.preferences.wheelStyle = modelData.value; page.preferences.sync(); }
                }
            }
            TouchButton { text: "Try Window Tape"; Layout.fillWidth: true; onClicked: page.tapeRequested() }
        }

        SettingsCard {
            title: "SYSTEM & ACCESS"
            subtitle: "The T cube keeps these actions one tap away."
            accentColor: page.accentColor
            Layout.fillWidth: true
            TouchButton { text: "Sounds & ringtones"; Layout.fillWidth: true; onClicked: page.soundsRequested() }
            TouchButton { text: "SIM & cellular"; Layout.fillWidth: true; onClicked: page.cellularRequested() }
            TouchButton { text: "Quick controls"; Layout.fillWidth: true; onClicked: page.controlsRequested() }
            TouchButton {
                text: page.preferences.doNotDisturb ? "Notification pop-ups muted" : "Notification pop-ups shown"
                selected: page.preferences.doNotDisturb
                accentColor: page.accentColor
                Layout.fillWidth: true
                Accessible.name: text
                onClicked: { page.preferences.doNotDisturb = !page.preferences.doNotDisturb; page.preferences.sync(); }
            }
            TouchButton { text: "End session…"; destructive: true; Layout.fillWidth: true; onClicked: page.endSessionRequested() }
        }
    }

    Text {
        text: "Super + Return · terminal   •   Super + Tab · apps   •   Super + F · maximize   •   Super + Shift + E · exit"
        color: Theme.textMuted
        font.pixelSize: 12
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    Text {
        text: "Tessa 0.1 · Running on Tessarchy"
        color: Theme.textMuted
        font.pixelSize: 12
        Layout.fillWidth: true
    }
}
