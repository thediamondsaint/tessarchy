pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: wizard
    required property var themes
    required property string currentTheme
    required property string accentChoice
    signal themeRequested(string name)
    signal accentRequested(string color)
    signal finished
    property int step: 0
    color: Qt.alpha(Theme.background, 0.97)
    z: 10000

    function finish() {
        completeProcess.running = true;
        wizard.finished();
    }
    Process {
        id: completeProcess
        command: ["tessarchy-first-run", "complete"]
    }
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        Image {
            anchors.fill: parent
            source: "../artwork/aurora-fold.png"
            fillMode: Image.PreserveAspectCrop
            opacity: 0.18
            asynchronous: true
        }
    }
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 720)
        height: Math.min(parent.height - 32, 780)
        spacing: 18
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 74
            Layout.preferredHeight: 74
            radius: Theme.radius("card", 24, width)
            color: Qt.alpha(Theme.accent, 0.18)
            border.color: Qt.alpha(Theme.accent, 0.64)
            border.width: 1
            Image { anchors.fill: parent; anchors.margins: 12; source: "../artwork/tessarchy-mark.svg"; fillMode: Image.PreserveAspectFit }
        }
        Text {
            Layout.fillWidth: true
            text: ["Welcome to Tessarchy", "Choose your Tessa theme", "Pick an accent color", "You’re all set"][wizard.step]
            color: Theme.text
            font.pixelSize: Math.min(parent.width * 0.075, 34)
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            text: ["Tessa is ready. Make your space feel like yours.", "Choose a complete palette. You can change it later in Settings.", "Choose the highlight used across Tessa’s controls.", "Your desktop is ready. Open Settings any time to personalize Tessarchy further."][wizard.step]
            color: Theme.textSecondary
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: wizard.step
            Item {}
            Flickable {
                clip: true
                contentHeight: themeGrid.implicitHeight
                GridLayout {
                    id: themeGrid
                    width: parent.width
                    columns: width >= 560 ? 3 : 2
                    columnSpacing: 12
                    rowSpacing: 12
                    Repeater {
                        model: wizard.themes
                        delegate: Button {
                            id: themeCard
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.minimumWidth: 120
                            Layout.preferredWidth: Math.max(120, (themeGrid.width - themeGrid.columnSpacing * (themeGrid.columns - 1)) / themeGrid.columns)
                            Layout.preferredHeight: 112
                            Accessible.name: "Choose " + modelData.name + " theme"
                            background: Rectangle {
                    radius: Theme.radius("button", 18, width)
                                color: themeCard.modelData.background
                                border.width: wizard.currentTheme === themeCard.modelData.name ? 3 : 1
                                border.color: wizard.currentTheme === themeCard.modelData.name ? themeCard.modelData.accent : Qt.alpha(themeCard.modelData.foreground, 0.25)
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    visible: themeCard.modelData.preview !== undefined && themeCard.modelData.preview.length > 0
                                    source: visible ? "file://" + themeCard.modelData.preview : ""
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }
                            contentItem: Column {
                                spacing: 7
                                Text { width: parent.width; text: themeCard.modelData.name === "tessera" ? "Tessa Night" : themeCard.modelData.name === "tessera-light" ? "Tessa Light" : themeCard.modelData.name; color: themeCard.modelData.foreground; font.pixelSize: 16; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 56; height: 6; radius: Theme.radius("progress", 3, height); color: themeCard.modelData.accent }
                            }
                            onClicked: wizard.themeRequested(modelData.name)
                        }
                    }
                }
            }
            Flow {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 14
                Repeater {
                    model: Theme.accentChoices
                    delegate: Button {
                        id: accentButton
                        required property string modelData
                        width: 64; height: 64
                        Accessible.name: "Accent " + modelData
                        background: Rectangle {
                            radius: Theme.radius("button", 22, width)
                            color: accentButton.modelData
                            border.width: wizard.accentChoice.toLowerCase() === accentButton.modelData ? 4 : 1
                            border.color: wizard.accentChoice.toLowerCase() === accentButton.modelData ? Theme.text : Qt.alpha(Theme.text, 0.45)
                        }
                        onClicked: wizard.accentRequested(modelData)
                    }
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, 380)
                    height: 168
                    radius: Theme.radius("card", 24, width)
                    color: Theme.glass
                    border.color: Qt.alpha(Theme.accent, 0.45)
                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Tessa"; color: Theme.accent; font.pixelSize: 35; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Your colors are ready."; color: Theme.text; font.pixelSize: 17 }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Button {
                visible: wizard.step > 0 && wizard.step < 3
                text: "Back"
                Layout.preferredWidth: 112
                Layout.preferredHeight: 54
                background: Rectangle { radius: Theme.radius("button", 18, width); color: Theme.glass; border.color: Theme.glassBorder }
                contentItem: Text { text: "Back"; color: Theme.text; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: wizard.step--
            }
            Item { Layout.fillWidth: true }
            Text { text: (wizard.step + 1) + " / 4"; color: Theme.textMuted; font.pixelSize: 13 }
            Item { Layout.fillWidth: true }
            Button {
                id: continueButton
                text: wizard.step === 3 ? "Start using Tessa" : wizard.step === 0 ? "Get started" : "Continue"
                Layout.preferredWidth: 190
                Layout.preferredHeight: 54
                onClicked: wizard.step === 3 ? wizard.finish() : wizard.step++
                background: Rectangle { radius: Theme.radius("button", 18, width); color: Theme.accent }
                contentItem: Text { text: continueButton.text; color: Theme.darkBackground; font.pixelSize: 15; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }
}
