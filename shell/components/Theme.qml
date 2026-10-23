pragma Singleton
import QtQuick

// Omarchy palette plus optional Tessa shell.toml semantic overrides.
// Every value derives from the active palette when no shell layer is present.
QtObject {
    id: theme
    property string mode: "dark"
    property color background: "#101b30"
    property color darkBackground: "#0b1424"
    property color darkerBackground: "#040d1a"
    property color surface: "#1c2c43"
    property color selection: "#34465e"
    property color text: "#f0f5ff"
    property color textSecondary: "#d0dced"
    property color textMuted: "#8da7b9"
    property color muted: "#7a8589"
    property color accent: "#a9e8d5"
    property color danger: "#ef8a9b"
    property var shellOverrides: ({})
    function token(name, fallback) {
        return shellOverrides[name] === undefined ? fallback : shellOverrides[name];
    }
    // Preserve each control's original radius until a surface override is supplied.
    function radius(name, fallback, height) {
        const value = shellOverrides["radius_" + name];
        return value === undefined ? fallback : Math.min(value, Math.max(0, height / 2));
    }
    function borderWidth(fallback) { return token("border_width", fallback); }
    readonly property color wheelGlow: token("wheel_glow", accent)
    readonly property color glass: token("glass", Qt.alpha(surface, 0.31))
    readonly property color glassBorder: token("glass_border", Qt.alpha(selection, 0.31))
    readonly property color glassStrong: token("glass_strong", Qt.alpha(background, 0.76))
    readonly property color switcherGlass: token("switcher_glass", Qt.alpha(background, 0.70))
    readonly property color barTint: token("bar_tint", background)
    readonly property color gestureBackground: token("gesture_background", "#000000")
    readonly property color dangerSurface: token("danger_surface", Qt.alpha(danger, 0.26))
    readonly property color startHeaderTop: token("start_header_top", Qt.alpha(selection, 0.55))
    readonly property color startHeaderBottom: token("start_header_bottom", Qt.alpha(selection, 0.12))
    readonly property color startHeaderText: token("start_header_text", text)
    readonly property color tileGlass: token("tile_glass", Qt.alpha(selection, 0.42))
    readonly property color tileSelected: token("tile_selected", Qt.alpha(accent, 0.55))
    readonly property color tilePressed: token("tile_pressed", Qt.alpha(accent, 0.65))
    readonly property color tileBorder: token("tile_border", Qt.alpha(accent, 0.26))
    readonly property color tileIconGlass: token("tile_icon_glass", Qt.alpha(accent, 0.55))
    readonly property color tileIconBorder: token("tile_icon_border", Qt.alpha(accent, 0.35))
    readonly property color switcherCard: token("switcher_card", Qt.alpha(surface, 0.25))
    readonly property color switcherButton: token("switcher_button", Qt.alpha(surface, 0.21))
    readonly property color switcherButtonBorder: token("switcher_button_border", Qt.alpha(accent, 0.25))
    readonly property color trayGlass: token("tray_glass", Qt.alpha(darkerBackground, 0.20))
    readonly property color trayBorder: token("tray_border", Qt.alpha(text, 0.12))
    readonly property color taskIdle: token("task_idle", Qt.alpha(text, 0.06))
    readonly property color taskBorder: token("task_border", Qt.alpha(text, 0.16))
    readonly property color taskBevel: token("task_bevel", Qt.alpha(text, 0.12))
    readonly property color taskPressedBevel: token("task_pressed_bevel", Qt.alpha(darkerBackground, 0.30))
    readonly property color startButtonText: token("start_button_text", darkBackground)
    readonly property color startButtonBorder: token("start_button_border", Qt.alpha(text, 0.55))
    readonly property color startButtonSelectedBorder: token("start_button_selected_border", Qt.alpha(text, 0.85))
    readonly property color inputText: token("input_text", text)
    readonly property color inputPlaceholder: token("input_placeholder", textMuted)
    readonly property color inputSelection: token("input_selection", selection)
    readonly property color inputBorder: token("input_border", glassBorder)
    readonly property color panelText: token("panel_text", textSecondary)
    readonly property color panelMutedText: token("panel_muted_text", textMuted)
    readonly property color tileText: token("tile_text", text)
    // Mobile pages, notifications and the sign-in screen.
    readonly property color itemText: token("item_text", text)
    readonly property color detailText: token("detail_text", textSecondary)
    readonly property color subtitleText: token("subtitle_text", textMuted)
    readonly property color hintText: token("hint_text", textMuted)
    readonly property color captionText: token("caption_text", textMuted)
    readonly property color errorText: token("error_text", danger)
    readonly property color messageIncoming: token("message_incoming", Qt.alpha(selection, 0.50))
    readonly property color notificationCard: token("notification_card", surface)
    readonly property color notificationCardPressed: token("notification_card_pressed", selection)
    readonly property color urgentText: token("urgent_text", danger)
    readonly property color urgentBorder: token("urgent_border", Qt.alpha(danger, 0.75))
    // The sign-in screen draws over fixed dark artwork; the scrim carries contrast.
    readonly property color lockScrim: token("lock_scrim", Qt.alpha(background, 0.78))
    readonly property color lockMutedText: token("lock_muted_text", textSecondary)
    readonly property color pinDot: token("pin_dot", text)
    readonly property color pinDotBorder: token("pin_dot_border", textSecondary)
    readonly property color pinKey: token("pin_key", Qt.alpha(surface, 0.41))
    readonly property color pinKeyPressed: token("pin_key_pressed", Qt.alpha(accent, 0.31))
    readonly property color pinKeyBorder: token("pin_key_border", Qt.alpha(textMuted, 0.35))
    // Existing user setting still controls only the bar and Start menu opacity.
    function bar(opacity) { return Qt.alpha(barTint, opacity); }
    function selected(accentColor) { return Qt.alpha(accentColor, 0.18); }
    function pressed(accentColor) { return Qt.alpha(accentColor, 0.28); }
    function taskSelected(accentColor) { return Qt.alpha(accentColor, 0.26); }
    function taskDown(accentColor) { return Qt.alpha(accentColor, 0.20); }
    function taskSelectedBorder(accentColor) { return Qt.alpha(accentColor, 0.85); }
    function switcherSelectedBorder(accentColor) { return Qt.alpha(accentColor, 0.65); }

    function load(raw) {
        // Assign defaults before reading new theme: a missing key must not
        // inherit the previous theme's colour (especially after light -> dark).
        shellOverrides = ({});
        const overrides = {};
        const shapeKeys = ["radius_card", "radius_tile", "radius_field", "radius_button", "border_width"];
        const allowed = ["wheel_glow", "glass", "glass_border", "glass_strong", "switcher_glass", "bar_tint", "gesture_background", "danger_surface",
            "start_header_top", "start_header_bottom", "start_header_text", "tile_glass", "tile_selected", "tile_pressed",
            "tile_border", "tile_icon_glass", "tile_icon_border", "switcher_card", "switcher_button", "switcher_button_border",
            "tray_glass", "tray_border", "task_idle", "task_border", "task_bevel", "task_pressed_bevel",
            "start_button_text", "start_button_border", "start_button_selected_border", "input_text", "input_placeholder",
            "input_selection", "input_border", "panel_text", "panel_muted_text", "tile_text",
            "item_text", "detail_text", "subtitle_text", "hint_text", "caption_text", "error_text", "message_incoming",
            "notification_card", "notification_card_pressed", "urgent_text", "urgent_border", "lock_scrim",
            "lock_muted_text", "pin_dot", "pin_dot_border", "pin_key", "pin_key_pressed", "pin_key_border"];
        const lines = String(raw || "").split("\n");
        let section = "";
        for (let i = 0; i < lines.length; i++) {
            const heading = lines[i].trim().match(/^\[([^\]]+)\]$/);
            if (heading) { section = heading[1]; continue; }
            if (section === "surface") {
                const shape = lines[i].match(/^\s*([a-z_]+)\s*=\s*(\d+(?:\.\d+)?)\s*(?:#.*)?$/);
                if (shape && shapeKeys.indexOf(shape[1]) >= 0) {
                    const value = Number(shape[2]);
                    if (Number.isFinite(value) && value >= 0)
                        overrides[shape[1]] = shape[1] === "border_width" ? Math.min(value, 4) : value;
                }
                continue;
            }
            const match = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6,8}|light|dark)/);
            if (!match) continue;
            const value = match[2];
            if (section === "tessera") {
                if (allowed.indexOf(match[1]) >= 0 && /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(value))
                    overrides[match[1]] = value;
                continue;
            }
            switch (match[1]) {
            case "mode": mode = value; break;
            case "background": background = value; break;
            case "dark_background": darkBackground = value; break;
            case "darker_background": darkerBackground = value; break;
            case "lighter_background": surface = value; break;
            case "selection": selection = value; break;
            case "foreground": text = value; break;
            case "light_foreground": textSecondary = value; break;
            case "dark_foreground": textMuted = value; break;
            case "muted": muted = value; break;
            case "accent": accent = value; break;
            case "red": danger = value; break;
            }
        }
        shellOverrides = overrides;
    }
}
