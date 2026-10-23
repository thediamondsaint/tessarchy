pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell
import "components"

ShellRoot {
    // Preview under the active theme staged by tessarchy-theme.
    ThemeLoader {
        palettePath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/tessarchy/theme/colors.toml"
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Window {
        visible: true
        visibility: Window.FullScreen
        width: 400; height: 800
        title: "Tessarchy sign-in preview"
        PinScreen {
            anchors.fill: parent
            available: true
            message: "Preview · sign-in disabled"
            date: clock.date
            onSubmitted: pin => { clear(); }
        }
    }
}
