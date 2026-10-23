-- Minimized workspace names retain the return workspace across config reloads.
local controls = {}
local prefix = "special:tessarchy-minimized-"

function controls.minimize()
    local window = hl.get_active_window()
    if not window or not window.workspace or window.workspace.name:match("^special:") then return false end
    local workspace = window.workspace.name:gsub(".", function(char) return string.format("%02x", char:byte()) end)
    local mode = window.fullscreen or 0
    if mode ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({ window = window, mode = mode == 1 and "maximized" or "fullscreen", action = "unset" }))
    end
    hl.dispatch(hl.dsp.window.move({ window = window, workspace = prefix .. mode .. "-" .. workspace, follow = false }))
    return true
end

function controls.activate(selector)
    local window = hl.get_window(selector)
    if not window or not window.workspace then return false end
    local mode, encoded = window.workspace.name:match("^special:tessarchy%-minimized%-(%d)%-([0-9a-f]+)$")
    if mode and #encoded % 2 == 0 then
        local name = encoded:gsub("..", function(byte) return string.char(tonumber(byte, 16)) end)
        local workspace = name:match("^[1-9]%d*$") and tonumber(name) or "name:" .. name
        hl.dispatch(hl.dsp.window.move({ window = window, workspace = workspace, follow = false }))
        if mode == "1" or mode == "2" then
            hl.dispatch(hl.dsp.window.fullscreen({ window = window, mode = mode == "1" and "maximized" or "fullscreen", action = "set" }))
        end
    end
    hl.dispatch(hl.dsp.focus({ window = window }))
    if window.workspace.name == "tessarchy-tape" and not window.floating then
        hl.dispatch(hl.dsp.layout("fit_into_view"))
    end
    if window.floating then
        hl.dispatch(hl.dsp.window.alter_zorder({ window = window, mode = "top" }))
    end
    return true
end

function controls.configure_bars()
    if not hl.plugin or not hl.plugin.hyprbars then return end
    hl.config({ plugin = { hyprbars = {
        bar_height = 48, bar_color = "rgb(102730)", ["col.text"] = "rgb(d0f3e9)",
        bar_text_size = 14, bar_text_align = "left", bar_padding = 12,
        bar_button_padding = 0, bar_part_of_window = true, bar_blur = false,
        on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({mode="maximized",action="toggle"})']],
    } } })
    for _, button in ipairs({
        { icon = "×", action = "tessera-shell ipc call actions closeWindow" },
        { icon = "□", action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({mode="maximized",action="toggle"})']] },
        { icon = "−", action = [[hyprctl eval 'TessarchyWindows.minimize()']] },
    }) do
        hl.plugin.hyprbars.add_button({ bg_color = "rgba(00000000)", fg_color = "rgb(d0f3e9)",
            size = 48, icon = button.icon, action = button.action })
    end
end

return controls
