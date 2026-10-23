pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: panel
    property var player: null
    property color accentColor: Theme.accent
    spacing: 6

    function activate(action) {
        const current = player;
        if (!current || !current.canControl) return;
        if (action === "previous" && current.canGoPrevious) current.previous();
        else if (action === "next" && current.canGoNext) current.next();
        else if (action === "toggle" && current.canTogglePlaying) current.togglePlaying();
        else if (action === "back" && current.canSeek) current.seek(-10);
        else if (action === "forward" && current.canSeek) current.seek(10);
    }

    Text {
        text: panel.player ? (panel.player.trackTitle || "Unknown track") : "No media player connected"
        textFormat: Text.PlainText
        color: Theme.text
        font.pixelSize: 14
        elide: Text.ElideRight
        Layout.fillWidth: true
    }
    Text {
        visible: !!panel.player
        text: panel.player ? ((panel.player.trackArtist || "Unknown artist") + " · " + (panel.player.identity || "Player")) : ""
        textFormat: Text.PlainText
        color: Theme.subtitleText
        font.pixelSize: 12
        elide: Text.ElideRight
        Layout.fillWidth: true
    }
    RowLayout {
        visible: !!panel.player
        Layout.fillWidth: true
        Repeater {
            model: [
                {action: "previous", icon: "media-previous", label: "Previous track", capability: "canGoPrevious"},
                {action: "toggle", icon: "media-play", label: "Play", capability: "canTogglePlaying"},
                {action: "next", icon: "media-next", label: "Next track", capability: "canGoNext"}
            ]
            delegate: NavButton {
                required property var modelData
                readonly property bool playing: modelData.action === "toggle" && !!panel.player && panel.player.isPlaying
                text: playing ? "Pause" : modelData.label
                symbol: playing ? "media-pause" : modelData.icon
                showLabel: false
                focusPolicy: Qt.TabFocus
                enabled: !!panel.player && panel.player.canControl && panel.player[modelData.capability]
                accentColor: panel.accentColor
                onClicked: panel.activate(modelData.action)
            }
        }
    }
    RowLayout {
        visible: !!panel.player
        Layout.fillWidth: true
        Repeater {
            model: [
                {action: "back", icon: "media-back", label: "Seek backward ten seconds"},
                {action: "forward", icon: "media-forward", label: "Seek forward ten seconds"}
            ]
            delegate: NavButton {
                required property var modelData
                text: modelData.label
                symbol: modelData.icon
                showLabel: false
                focusPolicy: Qt.TabFocus
                enabled: !!panel.player && panel.player.canControl && panel.player.canSeek
                accentColor: panel.accentColor
                onClicked: panel.activate(modelData.action)
            }
        }
    }
}
