local source = debug.getinfo(1, "S").source:sub(2)
local session = source:match("^(.*)/[^/]+$")
local runtime = session:match("^(.*)/bootstrap/session$")
assert(runtime, "Tessarchy runtime bootstrap path is invalid")

local marker = io.open(runtime .. "/active-generation", "r")
assert(marker, "Tessarchy runtime has no active generation")
local generation = marker:read("*a"):match("^([0-9a-f]+)%s*$")
marker:close()
assert(generation and #generation == 64, "Tessarchy runtime generation marker is invalid")

local config = runtime .. "/generations/" .. generation .. "/session/hyprland.lua"
local file = io.open(config, "r")
assert(file, "Tessarchy runtime compositor source is missing")
file:close()
dofile(config)
