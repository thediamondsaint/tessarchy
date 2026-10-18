pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: sheet
    required property var radios
    required property var preferences
    required property string activeMode
    required property var date
    property bool use24Hour: true
    property color accentColor: "#a9e8d5"
    property var bluetoothAdapter: null
    property bool bluetoothExpanded: false
    property var wifiDevice: null
    property bool wifiExpanded: false
    // The status bar layer may take keyboard focus only while the password
    // prompt is visible, so typing and the on-screen keyboard reach the field.
    readonly property bool wifiPromptOpen: sheet.wifiExpanded && wifiPanel.promptOpen
    property var mediaPlayer: null
    property bool audioBackendAvailable: false
    property bool audioExpanded: false
    property var audioSink: null
    readonly property bool audioAvailable: !!(audioSink && audioSink.ready && audioSink.audio)
    signal screenshotRequested
    signal settingsRequested
    signal dismissed
    spacing: 14
    Item {
        Layout.fillWidth: true
        implicitHeight: 64
        Column {
            anchors.left: parent.left
            spacing: 4
            Text {
                text: Qt.formatDateTime(sheet.date, sheet.use24Hour ? "h:mm" : "h:mm AP")
                color: "#f0f5ff"
                font { pixelSize: 34; weight: Font.Light; letterSpacing: -1 }
            }
            Text { text: Qt.formatDateTime(sheet.date, "dddd, MMMM d"); color: "#a7bdc6"; font.pixelSize: 12 }
        }
        NavButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 48; height: 48
            text: "Settings"; symbol: "settings"; showLabel: false
            onClicked: sheet.settingsRequested()
        }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: width >= 620 ? 4 : 2
        columnSpacing: 10
        rowSpacing: 10
        Repeater {
            model: [
                {name: "airplane", title: "Airplane mode", icon: "airplane"},
                {name: "wifi", title: "Wi-Fi", icon: "wifi"},
                {name: "bluetooth", title: "Bluetooth", icon: "bluetooth"},
                {name: "cellular", title: "Cellular", icon: "cellular"}
            ]
            delegate: RadioTile {
                required property var modelData
                readonly property var radio: sheet.radios.state[modelData.name] || {available: false, enabled: false, label: "Unavailable"}
                text: modelData.title
                symbol: modelData.icon
                detail: radio.label
                selected: radio.enabled
                enabled: radio.available && !radio.hardBlocked && sheet.radios.state.canControl && !sheet.radios.busy
                accentColor: sheet.accentColor
                onClicked: sheet.radios.toggle(modelData.name)
            }
        }
    }
    TouchButton {
        text: sheet.wifiExpanded ? "Hide Wi-Fi networks" : "Wi-Fi networks"
        focusPolicy: Qt.TabFocus
        Layout.fillWidth: true
        accentColor: sheet.accentColor
        Accessible.description: "Scan, connect and disconnect Wi-Fi networks"
        onClicked: sheet.wifiExpanded = !sheet.wifiExpanded
    }
    WifiPanel {
        id: wifiPanel
        visible: sheet.wifiExpanded
        device: sheet.wifiDevice
        accentColor: sheet.accentColor
        Layout.fillWidth: true
    }
    TouchButton {
        text: sheet.bluetoothExpanded ? "Hide Bluetooth devices" : "Bluetooth devices"
        focusPolicy: Qt.TabFocus
        Layout.fillWidth: true
        accentColor: sheet.accentColor
        Accessible.description: "Show paired devices and Bluetooth radio controls"
        onClicked: sheet.bluetoothExpanded = !sheet.bluetoothExpanded
    }
    BluetoothPanel {
        visible: sheet.bluetoothExpanded
        adapter: sheet.bluetoothAdapter
        accentColor: sheet.accentColor
        Layout.fillWidth: true
    }
    Text {
        text: "Layout · " + sheet.activeMode
        color: "#a7bdc6"
        font.pixelSize: 12
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                {value: "auto", label: "Auto", icon: "auto"},
                {value: "phone", label: "Phone", icon: "phone"},
                {value: "tablet", label: "Tablet", icon: "tablet"},
                {value: "desktop", label: "Desktop", icon: "desktop"}
            ]
            delegate: NavButton {
                required property var modelData
                text: modelData.label
                symbol: modelData.icon
                implicitHeight: 56
                Layout.minimumHeight: 56
                selected: sheet.preferences.layoutMode === modelData.value
                accentColor: sheet.accentColor
                Accessible.name: modelData.value === "auto" ? "Automatic layout" : modelData.label + " layout"
                onClicked: {
                    sheet.preferences.layoutMode = modelData.value;
                    sheet.preferences.sync();
                }
            }
        }
    }
    Text {
        visible: !!sheet.radios.state.error
        Layout.fillWidth: true
        text: sheet.radios.state.error || ""
        color: "#ebbbbd"; font.pixelSize: 12; wrapMode: Text.WordWrap
    }
    RowLayout {
        Layout.fillWidth: true
        NavButton {
            text: sheet.audioAvailable && sheet.audioSink.audio.muted ? "Unmute" : "Mute"
            symbol: sheet.audioAvailable && sheet.audioSink.audio.muted ? "volume-muted" : "volume"
            showLabel: false; Layout.fillWidth: false; Layout.preferredWidth: 48
            enabled: sheet.audioAvailable
            onClicked: sheet.audioSink.audio.muted = !sheet.audioSink.audio.muted
        }
        LevelSlider {
            Layout.fillWidth: true
            from: 0; to: 1
            value: sheet.audioAvailable ? sheet.audioSink.audio.volume : 0
            enabled: sheet.audioAvailable
            accentColor: sheet.accentColor
            Accessible.name: "Output volume"
            onMoved: sheet.audioSink.audio.volume = value
        }
    }
    Text {
        text: sheet.audioAvailable ? "Volume · " + Math.round(sheet.audioSink.audio.volume * 100) + "%" : "Audio output unavailable"
        color: "#99afbe"; font.pixelSize: 11
        Layout.alignment: Qt.AlignHCenter
    }
    TouchButton {
        text: sheet.audioExpanded ? "Hide audio devices and apps" : "Audio devices and apps"
        focusPolicy: Qt.TabFocus
        enabled: sheet.audioBackendAvailable
        Layout.fillWidth: true
        accentColor: sheet.accentColor
        onClicked: sheet.audioExpanded = !sheet.audioExpanded
    }
    Loader {
        Layout.fillWidth: true
        active: sheet.visible && sheet.audioExpanded && sheet.audioBackendAvailable
        visible: active
        source: "AudioPanel.qml"
        onLoaded: item.accentColor = Qt.binding(() => sheet.accentColor)
    }
    NavButton {
        text: "Screenshot"
        symbol: "camera"
        showLabel: false
        focusPolicy: Qt.TabFocus
        Layout.fillWidth: true
        accentColor: sheet.accentColor
        onClicked: sheet.screenshotRequested()
    }
    MediaPanel {
        player: sheet.mediaPlayer
        accentColor: sheet.accentColor
        Layout.fillWidth: true
    }
    Text {
        text: "Airplane mode switches all detected radios"
        color: "#99afbe"; font.pixelSize: 10
        Layout.alignment: Qt.AlignHCenter
    }
    TouchButton {
        text: "Collapse quick controls"
        Layout.fillWidth: true
        implicitHeight: 48; Layout.minimumHeight: 48
        background: Item {}
        contentItem: Item { Rectangle { anchors.centerIn: parent; width: 40; height: 4; radius: 2; color: "#8eacb8" } }
        onClicked: sheet.dismissed()
        DragHandler {
            target: null
            xAxis.enabled: false
            onActiveTranslationChanged: { if (activeTranslation.y < -28) sheet.dismissed(); }
        }
    }
}
