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
    property color accentColor: Theme.accent
    property var bluetoothAdapter: null
    property bool bluetoothExpanded: false
    property var mediaPlayer: null
    property bool audioBackendAvailable: false
    property bool audioExpanded: false
    property var audioSink: null
    readonly property bool audioAvailable: !!(audioSink && audioSink.ready && audioSink.audio)
    signal cellularRequested
    signal screenshotRequested
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
                color: Theme.text
                font { pixelSize: 34; weight: Font.Light; letterSpacing: -1 }
            }
            Text { text: Qt.formatDateTime(sheet.date, "dddd, MMMM d"); color: Theme.textMuted; font.pixelSize: 12 }
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
        text: "SIM & cellular"
        Layout.fillWidth: true
        focusPolicy: Qt.StrongFocus
        onClicked: sheet.cellularRequested()
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
        color: Theme.textMuted
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
        color: Theme.danger; font.pixelSize: 12; wrapMode: Text.WordWrap
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
        color: Theme.textMuted; font.pixelSize: 11
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
        sourceComponent: Component { AudioPanel { accentColor: sheet.accentColor } }
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
        visible: brightness.available || nightLight.available
        text: "Display"; color: Theme.textMuted; font.pixelSize: 12
    }
    BrightnessControl { id: brightness; Layout.fillWidth: true; accentColor: sheet.accentColor }
    NightLightToggle {
        id: nightLight
        Layout.fillWidth: true
        accentColor: sheet.accentColor
        nightLight: sheet.preferences.nightLight
        onToggleRequested: {
            sheet.preferences.nightLight = !sheet.preferences.nightLight;
            sheet.preferences.sync();
        }
    }
    PowerPanel { Layout.fillWidth: true; accentColor: sheet.accentColor }
    Text {
        text: "Airplane mode switches all detected radios"
        color: Theme.textMuted; font.pixelSize: 10
        Layout.alignment: Qt.AlignHCenter
    }
}
