"""Exercise minimize/restore lifecycle without touching a running compositor."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
LUA = shutil.which('lua') or shutil.which('lua5.4')
BOOTSTRAP = '''
local windows, active, focused, raised = {}, nil, nil, nil
local fitted = {}
hl = {plugin = {}}
function hl.get_active_window() return active end
function hl.get_window(selector) return windows[selector] end
hl.dsp = {window = {}}
for _, action in ipairs({"move", "fullscreen", "alter_zorder"}) do
    hl.dsp.window[action] = function(args) return {action=action, args=args} end
end
hl.dsp.focus = function(args) return {action="focus", args=args} end
hl.dsp.layout = function(message) return {action="layout", message=message} end
function hl.dispatch(request)
    local args = request.args
    if request.action == "move" then
        assert(args.follow == false)
        local name = tostring(args.workspace):gsub("^name:", "")
        args.window.workspace = {name=name}
    elseif request.action == "fullscreen" then
        args.window.fullscreen = args.action == "unset" and 0 or (args.mode == "maximized" and 1 or 2)
    elseif request.action == "alter_zorder" then
        assert(args.mode == "top"); raised = args.window
    elseif request.action == "layout" then
        assert(request.message == "fit_into_view"); table.insert(fitted, focused)
    else focused = args.window end
end
local function window(selector, workspace, fullscreen)
    local w = {workspace={name=workspace}, fullscreen=fullscreen or 0, floating=true}
    windows[selector] = w
    return w
end
local controls = dofile("session/window-controls.lua")
'''


@unittest.skipUnless(LUA, 'Lua interpreter unavailable')
class WindowControls(unittest.TestCase):
    def run_lua(self, script):
        result = subprocess.run([LUA, '-'], input=BOOTSTRAP + script, text=True,
                                cwd=ROOT, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_multiple_minimized_windows_survive_config_reload(self):
        self.run_lua('''
local first = window("first", "1", 1)
local second = window("second", "3", 0)
active = first; assert(controls.minimize()); assert(first.fullscreen == 0)
active = second; assert(controls.minimize())
controls = dofile("session/window-controls.lua")
assert(controls.activate("first")); assert(first.workspace.name == "1")
assert(first.fullscreen == 1 and focused == first and raised == first)
assert(second.workspace.name:match("^special:"))
assert(controls.activate("second")); assert(second.workspace.name == "3")
assert(second.fullscreen == 0 and focused == second)
''')

    def test_named_workspace_roundtrip_and_closed_window(self):
        self.run_lua('''
local name = "Project \'quoted\' — 日本語"
local w = window("app", name, 2)
active = w; assert(controls.minimize())
assert(controls.activate("app"))
assert(w.workspace.name == name and w.fullscreen == 2)
windows.app = nil
assert(controls.activate("app") == false)
''')

    def test_empty_and_unrelated_special_workspaces_are_untouched(self):
        self.run_lua('''
assert(controls.minimize() == false)
local w = window("scratch", "special:other", 0)
active = w; assert(controls.minimize() == false)
assert(controls.activate("scratch"))
assert(w.workspace.name == "special:other")
controls.configure_bars()
''')

    def test_scrolling_activation_reveals_target_without_affecting_other_layouts(self):
        self.run_lua('''
local target = window("tape", "tessarchy-tape", 0)
target.floating = false
assert(controls.activate("tape")); assert(fitted[1] == target)
local normal = window("normal", "1", 0)
normal.floating = false
assert(controls.activate("normal")); assert(#fitted == 1 and focused == normal)
local dialog = window("dialog", "tessarchy-tape", 0)
assert(controls.activate("dialog")); assert(#fitted == 1 and raised == dialog)
''')
