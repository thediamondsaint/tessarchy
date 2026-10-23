pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: panel
    property color accentColor: Theme.accent
    property var status: ({})
    signal openRequested
    signal loginRequested
    signal refreshRequested

    readonly property bool connected: !!(status.usage && status.usage.connected)
    readonly property var windows: connected && status.usage.windows ? status.usage.windows : []
    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        width: parent.width
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: Theme.radius("button", 20, height)
                color: Qt.alpha(panel.accentColor, 0.16)
                border.width: 1
                border.color: Qt.alpha(panel.accentColor, 0.45)
                Image { anchors.centerIn: parent; source: "../icons/chatgpt.svg"; sourceSize: Qt.size(28, 28) }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "ChatGPT"; color: Theme.text; font.pixelSize: 20; font.bold: true }
                Text {
                    text: panel.connected ? (panel.status.usage.plan || "Account connected") : (panel.status.message || "Checking connection…")
                    color: panel.connected ? panel.accentColor : Theme.textSecondary
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            GlassIconButton {
                symbol: "return"
                text: "Open ChatGPT"
                Accessible.name: "Open ChatGPT"
                onClicked: panel.openRequested()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(panel.accentColor, 0.18)
        }

        ColumnLayout {
            visible: panel.connected && panel.windows.length > 0
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: panel.windows
                delegate: ColumnLayout {
                    id: delegate
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: delegate.modelData.label || "Usage"; color: Theme.text; font.pixelSize: 13; Layout.fillWidth: true }
                        Text { text: Math.round(delegate.modelData.usedPercent) + "%"; color: panel.accentColor; font.pixelSize: 13; font.bold: true }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 8
                        radius: Theme.radius("progress", 4, height)
                        color: Qt.alpha(Theme.text, 0.10)
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, (delegate.modelData.usedPercent || 0) / 100))
                            height: parent.height
                            radius: parent.radius
                            color: panel.accentColor
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: panel.status.usage.dailyTokens != null ? panel.status.usage.dailyTokens.toLocaleString(Qt.locale(), 'f', 0) + " tokens today" : "Usage details"; color: Theme.textSecondary; font.pixelSize: 12; Layout.fillWidth: true }
                GlassIconButton { symbol: "return"; text: "Refresh usage"; Accessible.name: "Refresh usage"; onClicked: panel.refreshRequested() }
            }
        }

        ColumnLayout {
            visible: !panel.connected
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: panel.status.installed ? "Sign in to unlock account usage, Codex, and local project access." : "Install the official ChatGPT app to use the Tessa shortcut."
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                GlassIconButton { symbol: "return"; text: "Open ChatGPT"; Accessible.name: "Open ChatGPT"; onClicked: panel.openRequested() }
                GlassIconButton { visible: panel.status.installed; symbol: "settings"; text: "Sign in"; Accessible.name: "Sign in to ChatGPT"; onClicked: panel.loginRequested() }
            }
        }
    }
}
