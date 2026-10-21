"""Split workspace rules survive reload and are removed on close."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SplitPolicy(unittest.TestCase):
    def test_pair_gap_reload_ratio_and_close(self):
        if not shutil.which('lua'):
            self.skipTest('Lua interpreter unavailable')
        with tempfile.TemporaryDirectory() as home:
            config = Path(home) / 'tessarchy'
            config.mkdir()
            (config / 'shell.ini').write_text('[Shell]\nlayoutMode=tablet\n')
            script = r'''local callbacks, actions, windows, rules = {}, {}, {}, {}
local mon = {width=800,height=1280,scale=1,transform=0}
local function win(id)
  local w = {address=id,mapped=true,floating=false,fullscreen=1,tags={},monitor=mon,
    workspace={id=1},at={x=0,y=0},size={x=800,y=576}}
  windows[id]=w; return w
end
local function get(sel)
  if type(sel)=="table" then return sel end
  return windows[(sel or ""):gsub("^address:", "")]
end
local active, next_ws = nil, 7
local function op(kind) return function(a) a=a or {}; a.kind=kind; return a end end
local function run(a)
  actions[#actions+1]=a
  local w=get(a.window)
  if a.kind=="tag" then
    local tag=a.tag:sub(2)
    for i=#w.tags,1,-1 do if w.tags[i]==tag then table.remove(w.tags,i) end end
    if a.tag:sub(1,1)=="+" then w.tags[#w.tags+1]=tag end
  elseif a.kind=="fullscreen" then w.fullscreen=a.action=="set" and 1 or 0
  elseif a.kind=="move" then
    w.workspace={id=a.workspace=="emptynm" and next_ws or tonumber(a.workspace)}
    if a.workspace=="emptynm" then next_ws=next_ws+1 end
  elseif a.kind=="focus" then active=w end
end
hl={monitor=function() end,config=function() end,bind=function() end,layer_rule=function() end,
  workspace_rule=function(spec)
    local r={spec=spec,on=false}; rules[spec.workspace]=r
    return {set_enabled=function(_,on) r.on=on end}
  end,
  on=function(name,cb) callbacks[name]=cb end,dispatch=run,get_window=get,
  get_windows=function() local result={} for _,w in pairs(windows) do result[#result+1]=w end return result end,
  get_active_workspace=function() return active and active.workspace end,
  get_active_window=function() return active end,
  dsp={exec_cmd=function() end,exit=function() end,focus=op("focus"),
    layout=function(msg) return {kind="layout",msg=msg} end,
    window={fullscreen=op("fullscreen"),resize=op("resize"),center=op("center"),
      tag=op("tag"),move=op("move"),float=op("float"),close=op("close"),
      cycle_next=op("cycle"),drag=op("drag")}}}
local a,b=win("0xa"),win("0xb")
dofile(arg[1])
tessarchy.split("address:0xa","address:0xb")
assert(a.tags[1]=="split" and b.tags[1]=="split" and a.workspace.id==7 and b.workspace.id==7)
assert(rules["7"].on and rules["7"].spec.gaps_in==24 and rules["7"].spec.no_rounding)
b.at={x=0,y=672}
local before=#actions; tessarchy.ratio(0.25)
assert(#actions==before+1 and actions[#actions].y==264,"ratio centers the gap")
-- A config reload re-creates rules from surviving window tags.
rules={}; dofile(arg[1])
assert(rules["7"].on and rules["7"].spec.gaps_in==24,"gap lost on reload")
actions={}; callbacks["window.active"](a)
assert(#actions==0,"split window was maximized")
callbacks["window.close"](b)
assert(#a.tags==0 and a.fullscreen==1 and not rules["7"].on,"close cleanup")
'''
            result = subprocess.run(['lua', '-', str(ROOT / 'session/hyprland.lua')], input=script,
                                    text=True, capture_output=True,
                                    env=dict(os.environ, XDG_CONFIG_HOME=home, HOME=home))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
