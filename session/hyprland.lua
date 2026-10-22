-- Tessarchy defaults: Hyprland 0.56.x Lua API.
-- This is loaded explicitly, never over the user's Hyprland config.
local session = debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]+$")
local data = os.getenv("TESSARCHY_DATA_DIR") or session:match("^(.*)/session$")
TessarchyWindows = dofile(session .. "/window-controls.lua")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
-- Theme surface values; window borders stay off unless a theme sets a width.
local surface = { window_rounding = 18, blur_enabled = true, blur_size = 4, blur_passes = 2, window_border = 0 }
local surface_max = { window_border = 4 }
local border_colors = {}
local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local surface_file = io.open(state .. "/tessarchy/theme/surface.lua", "r")
if surface_file then
    surface_file:close()
    local ok, values = pcall(dofile, state .. "/tessarchy/theme/surface.lua")
    if ok and type(values) == "table" then
        for key, default in pairs(surface) do
            local value = values[key]
            if type(value) == type(default) and (type(value) ~= "number" or
               (value >= 0 and value <= (surface_max[key] or 32))) then surface[key] = value end
        end
        for _, key in ipairs({ "window_border_active", "window_border_inactive" }) do
            local value = values[key]
            if type(value) == "string" and value:match("^rgb%(%x%x%x%x%x%x%)$") then border_colors[key] = value end
        end
    end
end
local general = { gaps_in = 0, gaps_out = 0, border_size = surface.window_border, layout = "dwindle",
                  -- Let windows be resized by dragging an edge or corner, with a
                  -- finger-sized grab area (borders are invisible unless themed).
                  resize_on_border = true, extend_border_grab_area = 24 }
local group = nil
if border_colors.window_border_active and border_colors.window_border_inactive then
    general.col = { active_border = border_colors.window_border_active,
                    inactive_border = border_colors.window_border_inactive }
    group = { col = { border_active = border_colors.window_border_active,
                      border_inactive = border_colors.window_border_inactive } }
end
hl.config({
    general = general,
    group = group,
    decoration = { rounding = surface.window_rounding, blur = { enabled = surface.blur_enabled, size = surface.blur_size, passes = surface.blur_passes }, shadow = { enabled = false } },
    animations = { enabled = false },
    input = { kb_layout = "us", follow_mouse = 0 },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true,
             force_default_wallpaper = 0,
             key_press_enables_dpms = true, mouse_move_enables_dpms = true },
})
-- Frost only Tessera glass surfaces; leave applications unchanged.
hl.layer_rule({ match = { namespace = "tessera(-status|-start)?" }, blur = surface.blur_enabled, ignore_alpha = 0.01 })
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
-- Title bars are desktop chrome. Phone and tablet apps fill the screen with no
-- decorations, so the plugin is loaded only for the desktop layout.
local function desktop_layout(monitor)
    return monitor ~= nil and shell_mode(monitor) == "desktop"
end
local startMonitor = hl.get_active_monitor and hl.get_active_monitor() or nil
if not startMonitor and hl.get_monitors then
    local monitors = hl.get_monitors()
    startMonitor = monitors and monitors[1] or nil
end
local bars = data .. "/plugins/hyprbars.so"
local barsFile = io.open(bars, "r")
if barsFile and desktop_layout(startMonitor) then
    barsFile:close()
    hl.plugin.load(bars)
    TessarchyWindows.configure_bars()
elseif barsFile then
    barsFile:close()
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
-- Phone windows retain full preview dimensions when another app becomes active.
local function phone_window(window)
    for _, tag in ipairs(type(window.tags) == "table" and window.tags or {}) do
        if tag == "tessarchy-phone" then return true end
    end
    return false
end
local function maximize_if_mobile(window)
    if not window or window.fullscreen ~= 0 or not window.monitor then return end
    if window.floating and not phone_window(window) then return end
    if shell_mode(window.monitor) == "phone" then
        local monitor = window.monitor
        local width, height = monitor.width / monitor.scale, monitor.height / monitor.scale
        if monitor.transform % 2 == 1 then width, height = height, width end
        local reserved = type(monitor.reserved) == "table" and monitor.reserved or {}
        local left, top = reserved.left or 0, reserved.top or 0
        width = math.max(1, math.floor(width - left - (reserved.right or 0)))
        height = math.max(1, math.floor(height - top - (reserved.bottom or 0)))
        if not window.floating then
            hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+tessarchy-phone" }))
            hl.dispatch(hl.dsp.window.float({ window = window, action = "set" }))
        end
        hl.dispatch(hl.dsp.window.resize({ window = window, x = width, y = height }))
        hl.dispatch(hl.dsp.window.move({ window = window, x = (monitor.x or 0) + left, y = (monitor.y or 0) + top }))
    elseif not window.floating and shell_mode(window.monitor) == "tablet" then
        hl.dispatch(hl.dsp.window.fullscreen({ window = window, mode = "maximized", action = "set" }))
    end
end
-- Lua exposes compositor goal geometry, not client buffers/acknowledgements.
-- Floating XDG commits clamp that geometry to declared client minimum sizes.
-- Observe it while an OSK is mapped; never repeatedly request an impossible size.
local dialog_lifts, lift_poll_pending = {}, false
local function keyboard_top(monitor)
    if not hl.get_layers then return nil end
    local top
    for _, layer in ipairs(hl.get_layers()) do
        if layer.mapped and layer.monitor == monitor
           and (layer.namespace == "osk" or layer.namespace == "squeekboard")
           and layer.y and layer.h and layer.h > 0 then
            local y = (monitor.y or 0) + layer.y
            top = top and math.min(top, y) or y
        end
    end
    return top
end
local function restore_dialog(state)
    local window, at = state.window, state.window.at
    if state.applied and not state.manual and at
       and at.x == state.applied.x and at.y == state.applied.y then
        local monitor, size = window.monitor, window.size
        local width, height = monitor.width / monitor.scale, monitor.height / monitor.scale
        if monitor.transform % 2 == 1 then width, height = height, width end
        local reserved = monitor.reserved or {}
        local left = (monitor.x or 0) + (reserved.left or 0)
        local top = (monitor.y or 0) + (reserved.top or 0)
        -- Restore valid prior placement; keep upper content reachable after
        -- output changes or a config reload which cannot recover older state.
        local x = math.max(left, math.min(state.base.x, (monitor.x or 0) + width - (reserved.right or 0) - size.x))
        local y = math.max(top, math.min(state.base.y, (monitor.y or 0) + height - (reserved.bottom or 0) - size.y))
        hl.dispatch(hl.dsp.window.move({ window = window, x = x, y = y }))
    end
end
local poll_dialog_lifts
local function queue_lift_poll()
    if lift_poll_pending or not hl.timer or not next(dialog_lifts) then return end
    lift_poll_pending = true
    hl.timer(function()
        lift_poll_pending = false
        poll_dialog_lifts()
    end, { timeout = 150, type = "oneshot" })
end
poll_dialog_lifts = function()
    for address, state in pairs(dialog_lifts) do
        local window = state.window
        if window.address ~= address or window.mapped == false or window.monitor ~= state.monitor
           or not window.floating or window.fullscreen ~= 0 then
            dialog_lifts[address] = nil
        else
            local top, at, size = keyboard_top(window.monitor), window.at, window.size
            local previous = state.applied or state.observed_at
            if at and size and previous
               and (at.x ~= previous.x or at.y ~= previous.y) then
                -- Native minimum-size corrections preserve the window centre.
                local previous_size = state.last_size or size
                local dx, dy = (previous_size.x - size.x) / 2, (previous_size.y - size.y) / 2
                if math.abs(at.x - previous.x - dx) > 1
                   or math.abs(at.y - previous.y - dy) > 1 then
                    state.manual = true
                elseif state.applied then
                    state.applied = { x = at.x, y = at.y }
                end
            end
            if not top or shell_mode(window.monitor) == "desktop" then
                restore_dialog(state)
                dialog_lifts[address] = nil
            elseif at and size and size.y then
                if not state.manual then
                    local reserved = window.monitor.reserved or {}
                    local work_top = (window.monitor.y or 0) + (reserved.top or 0)
                    local y = math.min(state.base.y, top - size.y)
                    if size.y > top - work_top or state.applied then
                        if at.y ~= y then
                            hl.dispatch(hl.dsp.window.move({ window = window, x = at.x, y = y }))
                        end
                        state.applied = { x = at.x, y = y }
                    end
                end
                state.last_size = { x = size.x, y = size.y }
                state.observed_at = { x = at.x, y = at.y }
            end
        end
    end
    queue_lift_poll()
end
-- Request usable dimensions while respecting application minimum sizes.
local function fit_dialog(window, recovering)
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
    local address, at = window.address, window.at
    local state = address and dialog_lifts[address]
    if state and state.window == window then
        queue_lift_poll()
        -- Repeated layer events must not keep asking for an impossible resize.
        if state.manual or (state.fit_width == width and state.fit_height == height) then return end
    end
    -- Reload loses the old Lua table, but an off-screen fitting dialog still
    -- needs a way back when the keyboard hides. Do not resize it to adopt it.
    local fits = size.x <= width and size.y <= height
    local recover = recovering and fits and not state and address and at and hl.timer
                    and at.y < (monitor.y or 0) + (reserved.top or 0)
                    and not phone_window(window) and keyboard_top(monitor)
    if fits and not recover then return end
    if address and at and at.x and at.y and hl.timer and not phone_window(window)
       and keyboard_top(monitor) then
        if not state or state.window ~= window then
            state = { window = window, monitor = monitor, base = { x = at.x, y = at.y } }
            dialog_lifts[address] = state
        end
        state.fit_width, state.fit_height = width, height
        queue_lift_poll()
        if recover then
            state.applied = { x = at.x, y = at.y }
            state.last_size = { x = size.x, y = size.y }
            return
        end
    end
    hl.dispatch(hl.dsp.window.resize({ window = window, x = math.min(size.x, width), y = math.min(size.y, height) }))
    -- Preserve an existing lift while recomputing the fit for changed reservations.
    if not state or not state.applied then hl.dispatch(hl.dsp.window.center({ window = window })) end
    if state then
        local after, resized = window.at, window.size
        state.observed_at = { x = after.x, y = after.y }
        state.last_size = { x = resized.x, y = resized.y }
        if state.applied then state.applied = { x = after.x, y = after.y } end
    end
end
hl.on("window.open", function(window)
    -- Windowed desktop: ordinary windows open floating at a conventional size
    -- and are centred, instead of joining the tile layout.
    if window and not window.floating and window.fullscreen == 0 and window.monitor
       and shell_mode(window.monitor) == "desktop" and desktop_windowed() then
        if hl.dsp.window.float then
            hl.dispatch(hl.dsp.window.float({ window = window, action = "set" }))
            local monitor = window.monitor
            local width = math.max(360, math.floor(math.min(960, monitor.width / monitor.scale - 96)))
            local titleHeight = hl.plugin and hl.plugin.hyprbars and 48 or 0
            local height = math.max(280, math.floor(math.min(640, monitor.height / monitor.scale - 140 - titleHeight)))
            hl.dispatch(hl.dsp.window.resize({ window = window, x = width, y = height }))
            hl.dispatch(hl.dsp.window.center({ window = window }))
            if titleHeight > 0 then
                hl.dispatch(hl.dsp.window.move({ window = window, x = 0, y = titleHeight / 2, relative = true }))
            end
        end
        return
    end
    maximize_if_mobile(window)
    fit_dialog(window)
end)
-- Re-fit existing windows when the display size changes (rotation, dock, or a
-- manual mode switch). Windows opened at a larger resolution keep that
-- geometry otherwise: a 960px-wide window stays 960px on a 400px phone and
-- hangs off-screen.
local function refit_windows(monitor)
    for _, window in ipairs(hl.get_windows()) do
        if not monitor or window.monitor == monitor then
            if phone_window(window) then
                maximize_if_mobile(window)
            elseif window.floating then
                fit_dialog(window)
            else
                maximize_if_mobile(window)
            end
        end
    end
end
local function refit_after_layers()
    if hl.timer then hl.timer(function() refit_windows(nil) end, { timeout = 150, type = "oneshot" }) end
end
hl.on("monitor.layout_changed", function(monitor)
    refit_windows(monitor)
    refit_after_layers()
end)
hl.on("layer.opened", refit_after_layers)
hl.on("layer.closed", refit_after_layers)
-- Config reload may happen with a keyboard and dialogs already mapped.
if hl.timer and hl.get_layers then
    hl.timer(function()
        for _, window in ipairs(hl.get_windows()) do
            if window.monitor and keyboard_top(window.monitor) then fit_dialog(window, true) end
        end
    end, { timeout = 150, type = "oneshot" })
end
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
-- Keyboard icon switcher. Alt release commits selection.
-- Keycodes 64/108 are left/right Alt in the configured evdev/US keymap.
-- These bindings remain available while the switcher has an exclusive layer grab.
hl.bind("ALT + Tab", hl.dsp.exec_cmd("tessera-shell ipc call switcher next"), { locked = true })
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("tessera-shell ipc call switcher previous"), { locked = true })
hl.bind("code:64", hl.dsp.exec_cmd("tessera-shell ipc call switcher accept"), { release = true, ignore_mods = true, locked = true })
hl.bind("code:108", hl.dsp.exec_cmd("tessera-shell ipc call switcher accept"), { release = true, ignore_mods = true, locked = true })
hl.bind("Print", hl.dsp.exec_cmd("tessera-screenshot"))
hl.bind("SUPER + Return", hl.dsp.exec_cmd("tessarchy-run foot"))
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
