-- Use Hyprland's native tape; keep normal workspaces and existing geometry intact.
local tape = { name = "tessarchy-tape" }

function tape.contains(window)
    return window and window.workspace and window.workspace.name == tape.name
end

function tape.open_request()
    tape.pending = 0
    local current = hl.get_active_workspace()
    if current and current.name ~= tape.name then tape.previous = current.id end
    return hl.dsp.focus({ workspace = "name:" .. tape.name })
end

function tape.close_request()
    local current = hl.get_active_workspace()
    if not current or current.name ~= tape.name then return hl.dsp.no_op() end
    local previous = tape.previous and hl.get_workspace(tape.previous)
    return hl.dsp.focus({ workspace = previous and previous.id or 1 })
end

local function request(action, monitor_id, workspace_id)
    local monitor, workspace = hl.get_active_monitor(), hl.get_active_workspace()
    if not monitor or not workspace or workspace.name ~= tape.name then return nil end
    if monitor_id ~= nil and monitor.id ~= monitor_id then return nil end
    if workspace_id ~= nil and workspace.id ~= workspace_id then return nil end
    if monitor.active_special_workspace then return nil end
    if action == "begin" or action == "cancel" then
        tape.pending = 0
        return hl.dsp.no_op()
    end
    local message
    if type(action) == "number" then
        if action ~= action or math.abs(action) == math.huge then return nil end
        local delta = math.max(-4096, math.min(4096, math.floor(action + 0.5)))
        local left, right = math.huge, -math.huge
        for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
            if not window.floating and window.at and window.size then
                left = math.min(left, window.at.x)
                right = math.max(right, window.at.x + window.size.x)
            end
        end
        if left == math.huge then return nil end
        local reserved = monitor.reserved or {}
        local width = (monitor.transform % 2 == 1 and monitor.height or monitor.width) / monitor.scale
        local start = monitor.x + (reserved.left or 0)
        local finish = monitor.x + width - (reserved.right or 0)
        if delta > 0 then delta = math.min(delta, math.max(0, math.floor(start - left)))
        else delta = math.max(delta, math.min(0, math.ceil(finish - right))) end
        if delta == 0 then return nil end
        local native = hl.plugin and hl.plugin.tessarchy_tape
        if native and native.move then return function() native.move(delta) end end
        if tape.pending_workspace ~= workspace.id or tape.pending_monitor ~= monitor.id then tape.pending = 0 end
        tape.pending_workspace, tape.pending_monitor = workspace.id, monitor.id
        tape.pending = (tape.pending or 0) + delta
        if math.abs(tape.pending) < 120 then return nil end
        message = tape.pending > 0 and "focus l" or "focus r"
        tape.pending = 0
    else
        tape.pending = 0
        local native = hl.plugin and hl.plugin.tessarchy_tape
        if action == "settle" and native and native.settle then return function() native.settle() end end
        message = ({ previous = "focus l", next = "focus r", settle = "fit_into_view" })[action]
    end
    if not message then return nil end
    return hl.dsp.layout(message)
end

function tape.request(action, monitor_id, workspace_id)
    return request(action, monitor_id, workspace_id) or hl.dsp.no_op()
end

function tape.command(action, monitor_id, workspace_id)
    local dispatcher = request(action, monitor_id, workspace_id)
    if not dispatcher then return false end
    hl.dispatch(dispatcher)
    return true
end

function tape.open()
    hl.dispatch(tape.open_request())
end

function tape.close()
    hl.dispatch(tape.close_request())
end

return tape
