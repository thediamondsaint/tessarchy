-- Tessa compositor baseline.
-- Keep Hyprland close to its defaults; the shell owns presentation and touch
-- surfaces while this file only provides the native tape bridge, theme glass,
-- wallpaper handoff, and a few explicit Tessa controls.
local session = debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]+$")
local data = session:match("^(.*)/session$") or os.getenv("TESSARCHY_DATA_DIR")
TessarchyWindows = dofile(session .. "/window-controls.lua")
TessarchyTape = dofile(session .. "/window-tape.lua")

-- Optional native Hyprland scrolling bridge. The Lua tape module supplies the
-- same focus/snap fallback when the bridge is unavailable.
local tapeBridge = data .. "/plugins/tessarchy-tape.so"
local tapeFile = io.open(tapeBridge, "r")
if tapeFile then
    tapeFile:close()
    hl.plugin.load(tapeBridge)
end

-- Keep the monitor and wallpaper policy vanilla: preferred mode, automatic
-- placement, and no Hyprland-generated wallpaper under Tessa's own surface.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Theme surface values are the only compositor styling Tessa owns. They are
-- validated and staged by tessarchy-theme; user Hyprland files are untouched.
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

local general = { layout = "dwindle", border_size = surface.window_border,
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
    decoration = {
        rounding = surface.window_rounding,
        blur = { enabled = surface.blur_enabled, size = surface.blur_size, passes = surface.blur_passes },
        shadow = { enabled = false },
    },
    -- This is the only non-vanilla layout: the isolated Tessa tape workspace.
    scrolling = { column_width = 1.0, wrap_focus = false, wrap_swapcol = false, follow_focus = false },
    input = { kb_layout = "us" },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true,
             force_default_wallpaper = 0, key_press_enables_dpms = true,
             mouse_move_enables_dpms = true },
})
hl.workspace_rule({ workspace = "name:tessarchy-tape", layout = "scrolling" })
-- Only Tessa glass surfaces are blurred; application surfaces remain vanilla.
hl.layer_rule({ match = { namespace = "tessera(-status|-start|-tape)?" },
                blur = surface.blur_enabled, ignore_alpha = 0.01 })

-- Read the same output layout policy as Tessera. Only the phone and tablet
-- layouts use OSK-aware dialog placement; Desktop keeps vanilla behavior.
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
local function phone_window(window)
    for _, tag in ipairs(type(window.tags) == "table" and window.tags or {}) do
        if tag == "tessarchy-phone" then return true end
    end
    return false
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
    if not keyboard_top(monitor) then return end
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
-- Re-evaluate floating dialogs after keyboard/output changes. Keep this policy
-- scoped to the OSK and current Phone/Tablet layouts; tiled apps are untouched.
local function refit_osk_dialogs(recovering)
    if not hl.timer or not hl.get_windows then return end
    local has_eligible_dialog = false
    for _, window in ipairs(hl.get_windows()) do
        if window.monitor and window.floating and window.fullscreen == 0
           and not phone_window(window) and keyboard_top(window.monitor) then
            has_eligible_dialog = true
            break
        end
    end
    if not has_eligible_dialog then return end
    hl.timer(function()
        for _, window in ipairs(hl.get_windows()) do
            if window.monitor and keyboard_top(window.monitor) then fit_dialog(window, recovering) end
        end
    end, { timeout = 150, type = "oneshot" })
end
hl.on("window.open", fit_dialog)
hl.on("layer.opened", function() refit_osk_dialogs(false) end)
hl.on("layer.closed", function() refit_osk_dialogs(false) end)
hl.on("monitor.layout_changed", function() refit_osk_dialogs(false) end)
hl.on("config.reloaded", function() refit_osk_dialogs(true) end)

hl.on("hyprland.start", function ()
    hl.exec_cmd("tessarchy-session-services")
    hl.exec_cmd("tessera-shell")
    -- Optional; exits quietly when squeekboard is not installed.
    hl.exec_cmd("tessarchy-osk start")
    -- Blank the panel without adding a lock policy to the compositor.
    local share = os.getenv("TESSARCHY_DATA_DIR") or "/usr/share/tessarchy"
    hl.exec_cmd("hypridle -c '" .. share .. "/session/hypridle.conf'")
end)

-- Tessa controls. All touch surfaces use shell IPC; these are keyboard/mouse
-- fallbacks and do not redefine normal Hyprland workspaces or window rules.
hl.bind("SUPER + T", function() TessarchyTape.toggle() end)
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("tessera-shell ipc call apps launcher"))
hl.bind("SUPER + bracketleft", function() TessarchyTape.command("previous") end)
hl.bind("SUPER + bracketright", function() TessarchyTape.command("next") end)
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("tessera-shell"))
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("tessera-shell ipc call actions endSession"))
hl.bind("Print", hl.dsp.exec_cmd("tessera-screenshot"))

-- Hardware keys stay usable without adding a window policy.
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("tessera-brightness up"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("tessera-brightness down"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })

-- User preferences and generated display rotation remain user-owned. They are
-- loaded last so the baseline never overwrites a user's monitor choice.
local home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local preferences = home .. "/tessarchy/preferences.lua"
local f = io.open(preferences, "r")
if f then f:close(); dofile(preferences) end
local display = home .. "/tessarchy/display.lua"
local displayFile = io.open(display, "r")
if displayFile then displayFile:close(); dofile(display) end
