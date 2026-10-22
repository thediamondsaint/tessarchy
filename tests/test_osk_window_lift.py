"""Isolated Lua policy tests; not compositor or native client acceptance."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

HARNESS = r'''
local callbacks, actions, timers, windows, layers = {}, {}, {}, {}, {}
local function action(kind) return function(a) a = a or {}; a.kind = kind; return a end end
hl = {
    get_windows = function() return windows end,
    get_layers = function() return layers end,
    layer_rule = function() end, monitor = function() end, config = function() end,
    bind = function() end,
    on = function(name, callback) callbacks[name] = callback end,
    timer = function(fn, options) timers[#timers + 1] = fn end,
    dispatch = function(a)
        actions[#actions + 1] = a
        if a.kind == "move" then
            a.window.at = { x = a.x, y = a.y }
        elseif a.kind == "resize" then
            local old = a.window.size
            a.window.at = { x = a.window.at.x + (old.x - a.x) / 2,
                            y = a.window.at.y + (old.y - a.y) / 2 }
            a.window.size = { x = a.x, y = a.y }
        elseif a.kind == "center" then
            local m, s = a.window.monitor, a.window.size
            local w, h = m.width / m.scale, m.height / m.scale
            if m.transform % 2 == 1 then w, h = h, w end
            local r = m.reserved
            a.window.at = { x = m.x + r.left + (w - r.left - r.right - s.x) / 2,
                            y = m.y + r.top + (h - r.top - r.bottom - s.y) / 2 }
        end
    end,
    dsp = { exec_cmd = function() end, exit = function() end, focus = function() end,
        window = { fullscreen = action("fullscreen"), resize = action("resize"),
                   center = action("center"), move = action("move"),
                   close = action("close"), cycle_next = function() end, drag = function() end } }
}
local function write_mode(mode)
    local f = assert(io.open(os.getenv("XDG_CONFIG_HOME") .. "/tessarchy/shell.ini", "w"))
    f:write("[Shell]\nlayoutMode=" .. mode .. "\n"); f:close()
end
local mon = { x = 0, y = 0, width = 800, height = 600, scale = 1, transform = 0,
              reserved = { left = 0, right = 0, top = 48, bottom = 300 } }
local dialog = { address = "0x1", mapped = true, floating = true, fullscreen = 0,
                 tags = {}, monitor = mon, at = { x = 100, y = 70 }, size = { x = 500, y = 450 } }
local keyboard = { address = "0x2", mapped = true, namespace = "osk", monitor = mon,
                   x = 0, y = 300, w = 800, h = 280 }
windows = { dialog }; layers = { keyboard }
write_mode("tablet")
dofile(arg[1])
local function tick()
    local ready = timers; timers = {}
    for _, fn in ipairs(ready) do fn() end
end
local function commit_minimum(height)
    -- Mirror CWindow::commitWindow -> clampWindowSize, not a raw buffer API.
    if dialog.size.y < height then
        dialog.at.y = dialog.at.y + (dialog.size.y - height) / 2
        dialog.size.y = height
    end
end
local function moves()
    local count = 0
    for _, a in ipairs(actions) do if a.kind == "move" then count = count + 1 end end
    return count
end
'''


@unittest.skipUnless(shutil.which('lua'), 'Lua interpreter unavailable')
class OskWindowLift(unittest.TestCase):
    def run_policy(self, case):
        with tempfile.TemporaryDirectory(prefix='tessarchy-osk-fit-') as tmp:
            home = Path(tmp)
            (home / 'config/tessarchy').mkdir(parents=True)
            result = subprocess.run(
                ['lua', '-', str(ROOT / 'session/hyprland.lua')],
                input=HARNESS + case, capture_output=True, text=True, timeout=10,
                env=dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=str(home / 'config')))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_minimum_height_lifts_beneath_bar_after_resize_response(self):
        self.run_policy(r'''
callbacks["window.open"](dialog)
assert(moves() == 0, "no immediate fallback before observing post-request geometry")
tick(); tick()
assert(moves() == 0, "requested goal alone is not a rejected resize")
commit_minimum(450)
tick(); tick()
assert(dialog.at.y == -150, "minimum-height dialog bottom must clear the keyboard")
assert(dialog.at.x == 150, "vertical fallback must preserve post-centering horizontal placement")
''')

    def test_accepted_resize_does_not_lift(self):
        self.run_policy(r'''
callbacks["window.open"](dialog)
tick(); tick(); tick()
assert(moves() == 0, "a dialog that accepted resizing must not be lifted")
''')

    def test_keyboard_hide_restores_owned_position(self):
        self.run_policy(r'''
callbacks["window.open"](dialog)
commit_minimum(450)
tick(); tick(); tick()
assert(dialog.at.y == -150, "precondition: dialog was lifted")
layers = {}; keyboard.mapped = false; mon.reserved.bottom = 80
callbacks["layer.closed"](keyboard)
tick(); tick(); tick()
assert(dialog.at.x == 100 and dialog.at.y == 70, "keyboard hide restores the original position")
''')

    def test_repeated_checks_do_not_repeat_resize_or_move(self):
        self.run_policy(r'''
callbacks["window.open"](dialog); commit_minimum(450); tick()
local before = #actions
for _ = 1, 20 do tick() end
assert(#actions == before, "minimum-size rejection must not cause resize/move loops")
assert(#timers == 1, "at most one observation timer")
''')

    def test_late_minimum_and_later_minimum_growth(self):
        self.run_policy(r'''
callbacks["window.open"](dialog)
for _ = 1, 20 do tick() end
assert(moves() == 0)
commit_minimum(450); tick()
assert(dialog.at.y + dialog.size.y == keyboard.y)
commit_minimum(500); tick()
assert(dialog.at.y + dialog.size.y == keyboard.y, "late centre-preserving clamp is not a manual drag")
''')

    def test_manual_placement_before_first_observation_is_respected(self):
        self.run_policy(r'''
callbacks["window.open"](dialog); commit_minimum(450)
dialog.at = { x = 200, y = 90 }; tick(); tick()
assert(moves() == 0 and dialog.at.y == 90,
       "a drag during the first observation delay is still a manual placement")
''')

    def test_manual_placement_is_not_overwritten_on_hide(self):
        self.run_policy(r'''
callbacks["window.open"](dialog); commit_minimum(450); tick()
dialog.at = { x = 200, y = 90 }; tick()
local before = #actions
layers = {}; mon.reserved.bottom = 80
tick(); tick()
assert(dialog.at.x == 200 and dialog.at.y == 90 and #actions == before,
       "a later manual placement cancels policy ownership")
''')

    def test_monitor_origins_rotation_and_scale(self):
        for scale, transform in ((1, 0), (1.5, 0), (1, 1), (1.5, 1)):
            with self.subTest(scale=scale, transform=transform):
                self.run_policy(f'''
mon.x = -1280; mon.y = 240
mon.scale = {scale}; mon.transform = {transform}
mon.width = ({transform} == 1 and 600 or 800) * mon.scale
mon.height = ({transform} == 1 and 800 or 600) * mon.scale
dialog.at = {{ x = mon.x + 100, y = mon.y + 70 }}
callbacks["window.open"](dialog); commit_minimum(450); tick()
assert(dialog.at.y + dialog.size.y == mon.y + keyboard.y,
       "layer-local coordinates require monitor origin exactly once")
assert(dialog.at.x == mon.x + 150, "horizontal centering remains monitor-local")
layers = {{}}; mon.reserved.bottom = 80; tick()
assert(dialog.at.x == mon.x + 100 and dialog.at.y == mon.y + 70)
''')

    def test_layer_close_waits_for_unmap_and_reservation_update(self):
        self.run_policy(r'''
callbacks["window.open"](dialog); commit_minimum(450); tick()
callbacks["layer.closed"](keyboard)
assert(dialog.at.y == -150, "close event still has stale mapped/reserved state")
keyboard.mapped = false; layers = {}; mon.reserved.bottom = 80
tick(); tick()
assert(dialog.at.y == 70)
''')

    def test_keyboard_open_refits_existing_dialog(self):
        self.run_policy(r'''
layers = {}; mon.reserved.bottom = 80
callbacks["window.open"](dialog)
assert(#actions == 0)
layers = { keyboard }; mon.reserved.bottom = 300
callbacks["layer.opened"](keyboard); tick()
commit_minimum(450); tick()
assert(dialog.at.y + dialog.size.y == keyboard.y)
''')

    def test_unmapped_or_other_output_keyboard_does_not_lift(self):
        for setup in ('keyboard.mapped = false', 'keyboard.monitor = {}'):
            with self.subTest(setup=setup):
                self.run_policy(setup + r'''
callbacks["window.open"](dialog); commit_minimum(450)
tick(); tick()
assert(moves() == 0 and #timers == 0)
''')

    def test_closed_or_moved_output_window_clears_tracking(self):
        for setup in ('dialog.mapped = false', 'dialog.monitor = {}', 'dialog.address = nil'):
            with self.subTest(setup=setup):
                self.run_policy(r'''
callbacks["window.open"](dialog); commit_minimum(450)
''' + setup + r'''
tick(); tick()
assert(moves() == 0 and #timers == 0, "do not act on stale window identity/output")
''')

    def test_fullscreen_and_nonfloating_do_not_lift(self):
        for setup in ('dialog.fullscreen = 2', 'dialog.floating = false'):
            with self.subTest(setup=setup):
                self.run_policy(setup + r'''
callbacks["window.open"](dialog); tick(); tick()
assert(moves() == 0 and #timers == 0)
''')

    def test_reservation_change_refits_once_and_preserves_restore(self):
        self.run_policy(r'''
callbacks["window.open"](dialog); commit_minimum(450); tick()
keyboard.y = 250; mon.reserved.bottom = 350
callbacks["layer.opened"](keyboard); tick()
commit_minimum(450); tick(); tick()
assert(dialog.at.y + dialog.size.y == keyboard.y)
local before = #actions
for _ = 1, 10 do tick() end
assert(#actions == before)
layers = {}; mon.reserved.bottom = 80; tick()
assert(dialog.at.x == 100 and dialog.at.y == 70)
''')

    def test_smaller_output_restores_within_current_work_area(self):
        self.run_policy(r'''
callbacks["window.open"](dialog); commit_minimum(450); tick()
mon.height = 300; layers = {}; mon.reserved.bottom = 80
tick()
assert(dialog.at.y == mon.reserved.top, "do not restore off-screen after output geometry changes")
''')

    def test_no_keyboard_or_missing_query_api_is_safe(self):
        for setup in ('layers = {}', 'hl.get_layers = nil'):
            with self.subTest(setup=setup):
                self.run_policy(setup + r'''
callbacks["window.open"](dialog); commit_minimum(450); tick(); tick()
assert(moves() == 0 and #timers == 0)
''')

    def test_config_load_with_visible_keyboard_recovers_existing_dialog(self):
        self.run_policy(r'''
-- Existing dialog, including a placement left by a prior Lua config instance.
dialog.at.y = -150
tick(); commit_minimum(450); tick(); tick()
assert(dialog.at.y + dialog.size.y <= keyboard.y)
layers = {}; mon.reserved.bottom = 80; tick(); tick()
assert(dialog.at.y >= mon.reserved.top, "config reload must not leave upper content stranded")
''')

    def test_reload_recovers_offscreen_dialog_that_now_fits(self):
        self.run_policy(r'''
dialog.size.y = 100; dialog.at.y = -150
tick(); tick()
assert(dialog.at.y == -150, "reload recovery must not resize an already fitting dialog")
for _, a in ipairs(actions) do assert(a.kind ~= "resize") end
layers = {}; mon.reserved.bottom = 80
tick(); tick()
assert(dialog.at.y >= mon.reserved.top, "a fitting dialog's old lift must not survive keyboard hide")
''')

    def test_phone_dialog_uses_same_fallback(self):
        self.run_policy(r'''
write_mode("phone")
callbacks["window.open"](dialog); commit_minimum(450); tick()
assert(dialog.at.y + dialog.size.y == keyboard.y)
''')

    def test_desktop_is_unchanged(self):
        self.run_policy(r'''
write_mode("desktop")
callbacks["window.open"](dialog)
tick(); tick(); tick()
assert(#actions == 0, "Desktop policy must not change")
''')


if __name__ == '__main__':
    unittest.main()
