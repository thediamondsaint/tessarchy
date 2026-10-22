pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: widgets
    property string mode: "desktop"
    property date now: new Date()
    property var weather: ({})
    property var player: null
    property bool batteryPresent: false
    property real batteryPercent: 0
    property color accentColor: Theme.accent
    signal openPage(string page)
    signal refreshWeather
    signal mediaAction(string action)
    Accessible.name: widgets.mode === "desktop" ? "Desktop widgets" : "Touch widgets"

    readonly property int columns: mode === "phone" ? 1 : width >= 920 ? 4 : 2
    readonly property real gap: 12
    readonly property real cardWidth: Math.max(180, (width - gap * (columns - 1)) / columns)
    implicitHeight: Math.min(flow.implicitHeight, mode === "phone" ? 400 : 184)
    clip: true

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: widgets.now = new Date()
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: flow.implicitHeight
        clip: true
        interactive: widgets.mode !== "desktop"
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 1800
        ScrollBar.vertical: ScrollBar {
            visible: widgets.mode !== "desktop" && scroller.contentHeight > scroller.height
            policy: ScrollBar.AsNeeded
        }

        Flow {
            id: flow
            width: scroller.width
            spacing: widgets.gap
            Repeater {
                model: ["calendar", "weather", "media", "battery"]
                delegate: Item {
                    id: widget
                    required property string modelData
                    width: widgets.cardWidth
                    height: modelData === "media" ? 184 : 164

                    DesktopWidgetCard {
                        objectName: "desktopWidgetCard-" + widget.modelData
                        anchors.fill: parent
                        title: widget.modelData === "calendar" ? "Today" : widget.modelData === "weather" ? "Weather" : widget.modelData === "media" ? "Media" : "Battery"
                        subtitle: widget.modelData === "calendar" ? Qt.formatDate(widgets.now, "dddd, MMMM d") : widget.modelData === "weather" ? (widgets.weather.ok ? (widgets.weather.description || "Current conditions") : "Tap to refresh") : widget.modelData === "media" ? (widgets.player ? (widgets.player.identity || "Now playing") : "No player connected") : (widgets.batteryPresent ? "Power status" : "Battery unavailable")
                        symbol: widget.modelData === "calendar" ? "calendar" : widget.modelData === "weather" ? (widgets.weather.icon || "weather-cloud") : widget.modelData === "media" ? "music" : "battery"
                        accentColor: widgets.accentColor
                        subtle: widgets.mode === "desktop"
                        interactive: widget.modelData === "weather"
                        onClicked: if (widget.modelData === "weather") widgets.refreshWeather()

                        Loader {
                            active: widget.modelData === "calendar"
                            visible: active
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceComponent: ColumnLayout {
                                width: parent.width
                                height: parent.height
                                spacing: 0
                                Text {
                                    text: Qt.formatDate(widgets.now, "d")
                                    color: Theme.text
                                    font.pixelSize: 52
                                    font.weight: Font.Light
                                }
                                Text {
                                    text: Qt.formatDate(widgets.now, "MMMM yyyy")
                                    color: widgets.accentColor
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }
                        }

                        Loader {
                            active: widget.modelData === "weather"
                            visible: active
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceComponent: ColumnLayout {
                                width: parent.width
                                height: parent.height
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    Icon {
                                        symbol: widgets.weather.icon || "weather-cloud"
                                        size: 42
                                        color: widgets.accentColor
                                        Layout.preferredWidth: 42
                                        Layout.preferredHeight: 42
                                    }
                                    Text {
                                        text: widgets.weather.ok ? Math.round(widgets.weather.temperature || 0) + (widgets.weather.unit || "") : "—"
                                        color: Theme.text
                                        font.pixelSize: 30
                                        font.weight: Font.Light
                                        Layout.fillWidth: true
                                    }
                                }
                                Text {
                                    text: widgets.weather.ok ? (widgets.weather.description || "Current conditions") : (widgets.weather.error || "Weather unavailable")
                                    color: Theme.textSecondary
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Item { Layout.fillHeight: true }
                                Text {
                                    text: widgets.weather.stale ? "Last observation · tap to refresh" : "Tap to refresh"
                                    color: Theme.textMuted
                                    font.pixelSize: 11
                                }
                            }
                        }

                        Loader {
                            active: widget.modelData === "media"
                            visible: active
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceComponent: ColumnLayout {
                                width: parent.width
                                height: parent.height
                                spacing: 4
                                Text {
                                    text: widgets.player ? (widgets.player.trackTitle || "Unknown track") : "Nothing playing"
                                    color: Theme.text
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: widgets.player ? (widgets.player.trackArtist || "Unknown artist") : "Start playback to see controls"
                                    color: Theme.textSecondary
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Item { Layout.fillHeight: true }
                                RowLayout {
                                    visible: !!widgets.player
                                    Layout.fillWidth: true
                                    GlassIconButton { symbol: "media-previous"; text: "Previous"; Accessible.name: "Previous track"; enabled: !!widgets.player && widgets.player.canGoPrevious; onClicked: widgets.mediaAction("previous") }
                                    GlassIconButton { symbol: widgets.player && widgets.player.isPlaying ? "media-pause" : "media-play"; text: "Play"; Accessible.name: widgets.player && widgets.player.isPlaying ? "Pause" : "Play"; enabled: !!widgets.player && widgets.player.canTogglePlaying; onClicked: widgets.mediaAction("toggle") }
                                    GlassIconButton { symbol: "media-next"; text: "Next"; Accessible.name: "Next track"; enabled: !!widgets.player && widgets.player.canGoNext; onClicked: widgets.mediaAction("next") }
                                }
                            }
                        }

                        Loader {
                            active: widget.modelData === "battery"
                            visible: active
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceComponent: ColumnLayout {
                                width: parent.width
                                height: parent.height
                                spacing: 8
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: widgets.batteryPresent ? Math.round(widgets.batteryPercent * 100) + "%" : "—"
                                        color: Theme.text
                                        font.pixelSize: 30
                                        font.weight: Font.Light
                                        Layout.fillWidth: true
                                    }
                                    Icon { symbol: "battery"; size: 30; color: widgets.accentColor }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 8
                                    radius: Theme.radius("progress", 4, height)
                                    color: Qt.alpha(Theme.text, 0.10)
                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1, widgets.batteryPercent))
                                        height: parent.height
                                        radius: parent.radius
                                        color: widgets.accentColor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
