-- Tessarchy defaults: Hyprland 0.56.x Lua API.
-- This is loaded explicitly, never over the user's Hyprland config.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.config({
    general = { gaps_in = 0, gaps_out = 0, border_size = 0, layout = "dwindle",
                -- Let windows be resized by dragging an edge or corner, with a
                -- finger-sized grab area (borders are invisible in this theme).
                resize_on_border = true, extend_border_grab_area = 24 },
    decoration = { rounding = 18, blur = { enabled = true, size = 4, passes = 2 }, shadow = { enabled = false } },
    animations = { enabled = false },
    input = { kb_layout = "us", follow_mouse = 0 },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true,
             force_default_wallpaper = 0,
             key_press_enables_dpms = true, mouse_move_enables_dpms = true },
})
-- Frost only Tessera glass surfaces; leave applications unchanged.
hl.layer_rule({ match = { namespace = "tessera(-status|-start)?" }, blur = true, ignore_alpha = 0.01 })
-- Read the same saved mode as Tessera when a new ordinary app opens.
-- Existing windows and floating dialogs are left alone when modes change.
local function shell_mode(monitor)
    local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    local file = io.open(config .. "/tessarchy/shell.ini", "r")
    local mode, section = "auto", ""
    if file then
        for line in file:lines() do
            section = line:match("^%[([^%]]+)%]%s*$") or section
            if section == "Shell" then
                mode = line:match("^%s*layoutMode%s*=%s*(%a+)%s*$") or mode
            end
        end
        file:close()
    end
    if mode == "phone" or mode == "tablet" or mode == "desktop" then return mode end
    local width, height = monitor.width / monitor.scale, monitor.height / monitor.scale
    if monitor.transform % 2 == 1 then width, height = height, width end
    if math.min(width, height) < 600 then return "phone" end
    if width >= 1100 and height >= 650 then return "desktop" end
    return "tablet"
end
-- Desktop window style, chosen in Settings: "windowed" floats ordinary windows
-- at a conventional size, anything else leaves the dwindle tiling in place.
local function desktop_windowed()
    local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
    local file = io.open(config .. "/tessarchy/shell.ini", "r")
    local value, section = "windowed", ""
    if file then
        for line in file:lines() do
            section = line:match("^%[([^%]]+)%]%s*$") or section
            if section == "Shell" then
                value = line:match("^%s*desktopWindows%s*=%s*(%a+)%s*$") or value
            end
        end
        file:close()
    end
    return value == "windowed"
end
-- Re-maximize ordinary mobile windows when they become active.
local function is_split(window)
    local tags = window and window.tags
    if type(tags) == "string" then return tags:find("%f[%w]split%f[%W]") ~= nil end
    if type(tags) == "table" then
        for _, tag in ipairs(tags) do if tag == "split" then return true end end
    end
    return false
end
local function maximize_if_mobile(window)
    if not window or window.floating or window.fullscreen ~= 0 or not window.monitor then return end
    if is_split(window) then return end
    if shell_mode(window.monitor) ~= "desktop" then
        hl.dispatch(hl.dsp.window.fullscreen({ window = window, mode = "maximized", action = "set" }))
    end
end
-- A tablet pair occupies its own workspace; tags exempt it from mobile maximization.
local function split_windows(workspace)
    local found = {}
    for _, window in ipairs(hl.get_windows()) do
        if window.mapped and is_split(window) and window.workspace
            and (not workspace or window.workspace.id == workspace) then
            found[#found + 1] = window
        end
    end
    table.sort(found, function(a, b)
        if a.at.x ~= b.at.x then return a.at.x < b.at.x end
        return a.at.y < b.at.y
    end)
    return found
end
-- Split workspaces leave a gap the divider's width (2 x gaps_in = 48) so the
-- bar never covers app content, and square corners so edge text isn't clipped.
local split_rules = {}
local function split_layout(workspace, on)
    local key = tostring(workspace)
    if not split_rules[key] then
        if not on then return end
        split_rules[key] = hl.workspace_rule({ workspace = key, gaps_in = 24, no_rounding = true })
    end
    split_rules[key]:set_enabled(on)
end
-- A reload (tessera-rotate does one per rotation) re-runs this file and drops
-- the rules above, but window tags survive; re-apply them for live pairs.
for _, window in ipairs(split_windows()) do split_layout(window.workspace.id, true) end
local function untag(window)
    hl.dispatch(hl.dsp.window.tag({ window = "address:" .. window.address, tag = "-split" }))
    if window.workspace then split_layout(window.workspace.id, false) end
end
tessarchy = tessarchy or {}
function tessarchy.split(a, b)
    local first, second = hl.get_window(a), hl.get_window(b)
    if not first or not second or first.address == second.address then return end
    for _, window in ipairs({ first, second }) do
        if is_split(window) then
            for _, other in ipairs(split_windows(window.workspace.id)) do untag(other) end
        end
    end
    for _, sel in ipairs({ a, b }) do
        hl.dispatch(hl.dsp.window.tag({ window = sel, tag = "+split" }))
        hl.dispatch(hl.dsp.window.fullscreen({ window = sel, mode = "maximized", action = "unset" }))
        if hl.get_window(sel).floating then hl.dispatch(hl.dsp.window.float({ window = sel, action = "unset" })) end
    end
    hl.dispatch(hl.dsp.window.move({ window = a, workspace = "emptynm" }))
    local workspace = hl.get_window(a).workspace.id
    split_layout(workspace, true)
    hl.dispatch(hl.dsp.window.move({ window = b, workspace = tostring(workspace) }))
    local pair = split_windows(workspace)
    if #pair == 2 and pair[1].address ~= first.address then
        hl.dispatch(hl.dsp.focus({ window = a }))
        hl.dispatch(hl.dsp.layout("swapsplit"))
    end
    hl.dispatch(hl.dsp.focus({ window = a }))
end
function tessarchy.ratio(ratio)
    local workspace = hl.get_active_workspace()
    local pair = workspace and split_windows(workspace.id) or {}
    if #pair ~= 2 then return end
    ratio = math.max(0.2, math.min(0.8, tonumber(ratio) or 0.5))
    local first, second = pair[1], pair[2]
    local sel = "address:" .. first.address
    -- Place the gap's midpoint, not the first window's edge, at the ratio.
    if first.at.x ~= second.at.x then
        local total = second.at.x + second.size.x - first.at.x
        local gap = second.at.x - first.at.x - first.size.x
        hl.dispatch(hl.dsp.window.resize({ window = sel, x = math.floor(total * ratio - gap / 2), y = first.size.y }))
    else
        local total = second.at.y + second.size.y - first.at.y
        local gap = second.at.y - first.at.y - first.size.y
        hl.dispatch(hl.dsp.window.resize({ window = sel, x = first.size.x, y = math.floor(total * ratio - gap / 2) }))
    end
end
function tessarchy.swap()
    local workspace = hl.get_active_workspace()
    local pair = workspace and split_windows(workspace.id) or {}
    if #pair ~= 2 then return end
    hl.dispatch(hl.dsp.focus({ window = "address:" .. pair[1].address }))
    hl.dispatch(hl.dsp.layout("swapsplit"))
end
function tessarchy.unsplit()
    local workspace = hl.get_active_workspace()
    if not workspace then return end
    for _, window in ipairs(split_windows(workspace.id)) do untag(window) end
    maximize_if_mobile(hl.get_active_window())
end
local function away_from_split(window)
    if not window or window.floating or is_split(window) or not window.workspace or not window.monitor then return end
    if shell_mode(window.monitor) == "desktop" then return end
    if #split_windows(window.workspace.id) == 0 then return end
    hl.dispatch(hl.dsp.window.move({ window = "address:" .. window.address, workspace = "emptynm" }))
end
hl.on("window.close", function(window)
    if not is_split(window) or not window.workspace then return end
    for _, other in ipairs(split_windows(window.workspace.id)) do
        if other.address ~= window.address then
            untag(other)
            maximize_if_mobile(other)
        end
    end
end)
-- Request usable dimensions while respecting application minimum sizes.
local function fit_dialog(window)
    if not window or not window.floating or window.fullscreen ~= 0 or not window.monitor then return end
    local size = window.size
    if type(size) ~= "table" or not size.x or not size.y then return end
    local monitor = window.monitor
    if shell_mode(monitor) == "desktop" then return end
    local width, height = monitor.width / monitor.scale, monitor.height / monitor.scale
    if monitor.transform % 2 == 1 then width, height = height, width end
    local reserved = type(monitor.reserved) == "table" and monitor.reserved or {}
    width = math.max(1, math.floor(width - (reserved.left or 0) - (reserved.right or 0)))
    height = math.max(1, math.floor(height - (reserved.top or 0) - (reserved.bottom or 0)))
    if size.x <= width and size.y <= height then return end
    hl.dispatch(hl.dsp.window.resize({ window = window, x = math.min(size.x, width), y = math.min(size.y, height) }))
    hl.dispatch(hl.dsp.window.center({ window = window }))
end
hl.on("window.open", function(window)
    away_from_split(window)
    -- Windowed desktop: ordinary windows open floating at a conventional size
    -- and are centred, instead of joining the tile layout.
    if window and not window.floating and window.fullscreen == 0 and window.monitor
       and shell_mode(window.monitor) == "desktop" and desktop_windowed() then
        if hl.dsp.window.float then
            hl.dispatch(hl.dsp.window.float({ window = window, action = "set" }))
            local monitor = window.monitor
            local width = math.max(360, math.floor(math.min(960, monitor.width / monitor.scale - 96)))
            local height = math.max(280, math.floor(math.min(640, monitor.height / monitor.scale - 140)))
            hl.dispatch(hl.dsp.window.resize({ window = window, x = width, y = height }))
            hl.dispatch(hl.dsp.window.center({ window = window }))
        end
        return
    end
    maximize_if_mobile(window)
    fit_dialog(window)
end)
hl.on("window.active", maximize_if_mobile)
hl.on("hyprland.start", function ()
    hl.exec_cmd("tessarchy-session-services")
    hl.exec_cmd("tessera-shell")
    -- Optional; exits quietly when squeekboard is not installed.
    hl.exec_cmd("tessarchy-osk start")
    -- Blank the panel after five minutes without input; input wakes it back.
    -- hypridle honors idle inhibitors and no lock command is configured.
    local share = os.getenv("TESSARCHY_DATA_DIR") or "/usr/share/tessarchy"
    hl.exec_cmd("hypridle -c '" .. share .. "/session/hypridle.conf'")
end)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("tessera-brightness up"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("tessera-brightness down"))
-- Same card switcher for touch and keyboard. Alt release commits selection.
-- Keycodes 64/108 are left/right Alt in the configured evdev/US keymap.
-- These bindings remain available while the switcher has an exclusive layer grab.
hl.bind("ALT + Tab", hl.dsp.exec_cmd("tessera-shell ipc call switcher next"), { locked = true })
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("tessera-shell ipc call switcher previous"), { locked = true })
hl.bind("code:64", hl.dsp.exec_cmd("tessera-shell ipc call switcher accept"), { release = true, ignore_mods = true, locked = true })
hl.bind("code:108", hl.dsp.exec_cmd("tessera-shell ipc call switcher accept"), { release = true, ignore_mods = true, locked = true })
hl.bind("Print", hl.dsp.exec_cmd("tessera-screenshot"))
hl.bind("SUPER + Return", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("tessera-shell"))
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("tessera-shell ipc call actions endSession"))
-- Desktop mode: numbered workspaces, directional focus and window moving.
-- These bindings are harmless in the touch layouts and mirror the workspace
-- strip in the status bar.
for i = 1, 5 do
    local key = tostring(i)
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind("SUPER + Q", hl.dsp.exec_cmd("tessera-shell ipc call actions closeWindow"))
hl.bind("SUPER + Tab", hl.dsp.window.cycle_next())
hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
-- Volume keys mirror the Tessera controls page when PipeWire is running.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
-- Preferences are user-owned, never installed over existing files.
local home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local preferences = home .. "/tessarchy/preferences.lua"
local f = io.open(preferences, "r")
if f then f:close(); dofile(preferences) end
-- Generated display rotation; written only by tessera-rotate, loaded last.
local display = home .. "/tessarchy/display.lua"
local displayFile = io.open(display, "r")
if displayFile then displayFile:close(); dofile(display) end
