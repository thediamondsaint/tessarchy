"""Check tape commands cannot move another workspace or dispatch unsafe input."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
LUA = shutil.which('lua') or shutil.which('lua5.4')


@unittest.skipUnless(LUA, 'Lua interpreter unavailable')
class WindowTape(unittest.TestCase):
    def run_lua(self, script):
        bootstrap = '''
local monitor = {id=2, x=0, width=400, height=800, scale=1, transform=0}
local tiled = {{at={x=-10000},size={x=400}},{at={x=10000},size={x=400}}}
local workspace = {id=7, name="tessarchy-tape"}
local requests = {}
local native_moves = {}
local native = {move=function(delta) table.insert(native_moves,delta) end,
                settle=function() table.insert(native_moves,"settle") end}
hl = {
 plugin={tessarchy_tape=native},
 get_active_monitor=function() return monitor end,
 get_active_workspace=function() return workspace end,
 get_workspace_windows=function() return tiled end,
 get_workspace=function(id) if id==3 then return {id=3} end end,
 dispatch=function(d) if type(d)=="function" then d() else table.insert(requests,d) end end,
 dsp={no_op=function() return "noop" end, layout=function(s) return s end, focus=function(t) return t end}
}
local tape = dofile("session/window-tape.lua")
'''
        result = subprocess.run([LUA, '-'], input=bootstrap + script, text=True,
                                cwd=ROOT, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_scope_and_special_workspace_guard(self):
        self.run_lua('''
assert(tape.command(100,2,7)); assert(native_moves[1]==100)
assert(not tape.command(100,1,7)); assert(not tape.command(100,2,8))
monitor.active_special_workspace = {}; assert(not tape.command(100,2,7))
monitor.active_special_workspace = nil
workspace.name="1"; assert(not tape.command(100)); assert(#native_moves==1)
''')

    def test_numeric_safety_and_settle_preserves_width(self):
        self.run_lua('''
assert(not tape.command(0/0)); assert(not tape.command(math.huge))
assert(not tape.command(-math.huge)); assert(not tape.command("move +100; exec x"))
assert(not tape.command(0)); assert(#requests==0)
assert(tape.command(90000)); assert(native_moves[1]==4096)
assert(tape.command(-90000)); assert(native_moves[2]==-4096)
assert(tape.command("settle")); assert(native_moves[3]=="settle")
assert(tape.command("previous")); assert(requests[1]=="focus l")
assert(tape.command("next")); assert(requests[2]=="focus r")
''')

    def test_exit_returns_to_previous_workspace_and_handles_removal(self):
        self.run_lua('''
workspace={id=3,name="3"}; tape.open()
assert(requests[1].workspace=="name:tessarchy-tape")
workspace={id=7,name="tessarchy-tape"}; tape.open()
tape.close(); assert(requests[3].workspace==3)
tape.previous=4; tape.close(); assert(requests[4].workspace==1)
workspace.name="other"; tape.close(); assert(requests[5]=="noop")
assert(tape.contains({workspace={name="tessarchy-tape"}}))
assert(not tape.contains({workspace={name="1"}}))
''')

    def test_drag_stops_at_content_edges_and_ignores_dialogs(self):
        self.run_lua('''
tiled={{at={x=-100},size={x=400}}, {at={x=300},size={x=400}},
       {floating=true,at={x=9000},size={x=400}}}
assert(tape.command(500)); assert(native_moves[1]==100)
assert(tape.command(-500)); assert(native_moves[2]==-300)
tiled={{at={x=0},size={x=400}}}
assert(not tape.command(100)); assert(not tape.command(-100)); assert(#native_moves==2)
''')

    def test_without_bridge_drag_steps_using_native_focus_commands(self):
        self.run_lua('''
hl.plugin={}
assert(not tape.command(-60)); assert(tape.command(-60)); assert(requests[1]=="focus r")
assert(tape.command("settle")); assert(requests[2]=="fit_into_view")
assert(not tape.command(60)); assert(tape.command(60)); assert(requests[3]=="focus l")
assert(not tape.command(-60)); assert(tape.command("begin")); assert(requests[4]=="noop")
assert(not tape.command(-60)); assert(tape.command("cancel")); assert(requests[5]=="noop")
assert(not tape.command(-60))
''')
