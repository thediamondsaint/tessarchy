-- Tessa compositor baseline.
-- Keep Hyprland close to its defaults; the shell owns presentation and touch
-- surfaces while this file only provides the native tape bridge, theme glass,
-- wallpaper handoff, and a few explicit Tessa controls.
local session = debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]+$")
local data = os.getenv("TESSARCHY_DATA_DIR") or session:match("^(.*)/session$")
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
