# Tessa shell themes

The system theme uses an unmodified Omarchy `colors.toml` as its palette. To
customize the shell *look* as well as its palette, optionally place a separate
`[tessera]` table in `shell.toml` alongside `colors.toml`. We keep this file
separate so stock Omarchy themes work without alterations; the theme launcher
appends it to the **staged** palette, read atomically by the shell. Never edit
the staged file: `tessarchy-theme set NAME` regenerates it.

Example `~/.config/tessarchy/themes/my-theme/shell.toml`:

```toml
[tessera]
glass = "#501c2c43"
glass_border = "#504d687d"
start_header_top = "#8c294d9e"
```

Qt uses `#AARRGGBB`: the first byte is opacity (`00` transparent, `ff`
opaque). All keys are optional. Without `shell.toml`, `Theme.qml` derives every
semantic colour from the palette, including translucent glass in light mode.
Changing themes resets absent overrides; no old theme's tint leaks into the next.

| Tokens in `shell.toml` | Purpose |
|---|---|
| `glass`, `glass_border`, `glass_strong`, `switcher_glass`, `bar_tint` | Controls/inputs, panel border, expanded panel/drawer, switcher, taskbar/Start menu tint (`barOpacity` preference still controls bar/Start opacity) |
| `danger_surface` | Destructive button fill |
| `start_header_top`, `start_header_bottom`, `start_header_text` | Start menu gradient and heading |
| `tile_glass`, `tile_selected`, `tile_pressed`, `tile_border`, `tile_icon_glass`, `tile_icon_border`, `tile_text` | Start menu tiles and icon wells |
| `switcher_card`, `switcher_button`, `switcher_button_border` | Window previews/actions |
| `tray_glass`, `tray_border`, `task_idle`, `task_border`, `task_bevel`, `task_pressed_bevel` | XP-style taskbar tray/buttons |
| `start_button_text`, `start_button_border`, `start_button_selected_border` | Start button contrast and edge |
| `input_text`, `input_placeholder`, `input_selection`, `input_border` | Glass text fields |
| `panel_text`, `panel_muted_text` | Status/quick settings text |
| `item_text`, `detail_text`, `subtitle_text`, `hint_text`, `caption_text`, `error_text` | Mobile page text: list items, body/detail lines, secondary lines, help and empty states, message metadata, errors |
| `message_incoming` | Incoming SMS bubble (outgoing follows `accent`) |
| `notification_card`, `notification_card_pressed`, `urgent_text`, `urgent_border` | Notification cards and popups, urgent label and edge |
| `lock_scrim`, `lock_muted_text`, `pin_dot`, `pin_dot_border`, `pin_key`, `pin_key_pressed`, `pin_key_border` | Sign-in screen over its artwork |

Accent-dependent selected/pressed variants live in the Theme singleton and
follow the active `accent`. `themes/tessera/shell.toml` captures upstream's
existing blue/mint glass values; the unlayered light theme uses palette-derived
tints rather than retaining dark blue. Spacing remains component geometry.

## Surface shape

Add an optional `[surface]` table in the same `shell.toml`; this keeps both
Tessa-only colour and shape data out of Omarchy's `colors.toml`. Values are
passive data, never QML or theme-supplied Lua. For example:

```toml
[surface]
radius_card = 4
radius_tile = 4
radius_field = 4
radius_button = 4
border_width = 2
window_rounding = 4
blur_enabled = false
blur_size = 4
blur_passes = 2
window_border = 2
window_border_active = "#ff8800"
window_border_inactive = "#3388ff"
```

| Key | Scope | Default when absent |
|---|---|---|
| `radius_card`, `radius_tile`, `radius_field`, `radius_button` | Existing cards/panels, tiles/chips, fields, buttons | Each component's original radius (not a shared number) |
| `border_width` | Shell surface borders | Each component's original width (usually 1 px, slider handle 3 px) |
| `window_rounding` | Hyprland decoration | 18 |
| `blur_enabled`, `blur_size`, `blur_passes` | Hyprland window blur and Tessa layer blur | `true`, 4, 2 |
| `window_border` | Hyprland window border width, also used for grouped windows | 0 (no border) |
| `window_border_active`, `window_border_inactive` | Focused and unfocused window border colour, also the group border colours | Palette `accent` and `selection` |

Radii and widths are numeric, nonnegative pixels. An overridden radius is capped
at half that surface's height; border width is capped at 4 px. Compositor values
are strictly checked: rounding 0–32, size 1–16, passes 1–4, and an unquoted
boolean for blur. `window_border` is a whole number; widths above 4 clamp to 4.
Border colours are quoted `"#RRGGBB"`. Invalid values fall back to the
defaults. Window borders stay off unless a theme sets `window_border`, so
themes without it look exactly as before. Missing keys retain
exactly the original appearance; changing themes clears old overrides. The
renderer writes a generated, allowlisted `theme/surface.lua` fragment under
`$XDG_STATE_HOME/tessarchy/`, and `tessarchy-theme set` reloads the running
Hyprland session to apply compositor changes. Without a session, changes take
effect at the next launch. The shell reads the appended `[surface]` table live.

## Omarchy theme extras

Omarchy theme directories also ship files Tessarchy reads as data:

- `preview.png`: the Settings theme picker shows it as the button thumbnail
  above the theme name. Themes without one get a same-sized thumbnail drawn
  from their palette (bar, window with accent, dock).
- `icons.theme`: one icon theme name (for example `Yaru-purple`). It is used
  only when it is a plain name (letters, digits, `.`, `_`, `-`, up to 64
  characters) and an `index.theme` for it exists under `$XDG_DATA_HOME/icons`,
  `~/.icons` or `$XDG_DATA_DIRS/*/icons`. `tessarchy-theme set` then writes
  it to `org.gnome.desktop.interface icon-theme` through `gsettings` (read by
  GTK 3/4 apps) and records it in the staged `theme/icons`. A missing,
  invalid or uninstalled name leaves the current icon theme unchanged; so
  does switching to a theme without `icons.theme`. Omarchy's Yaru icon
  themes are not in the Arch repositories; install them separately.

Tessarchy deliberately ignores `hyprland.lua` (theme-supplied Lua for border
and shadow colours; use the `[surface]` border keys instead), `chromium.theme`
(applying it needs root-owned browser policy files), and other app configs.
Themes remain data: no file from a theme directory is executed or sourced.

Shell QML holds no colour literals outside `Theme.qml`;
`test_shell_colors_live_in_theme_tokens` enforces this and requires every token to
be loadable and pinned in `themes/tessera/shell.toml`. The greeter runs as the
`greeter` account before any user theme is readable, so it loads the bundled
Tessa theme; `login-preview.qml` previews the sign-in screen under the active
staged theme.
