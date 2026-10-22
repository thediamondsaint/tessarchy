#pragma once
#include <aquamarine/input/Input.hpp>
#include <hyprland/src/pointer/PointerManager.hpp>
#include <hyprland/src/state/MonitorState.hpp>
#include <chrono>
#include <cmath>
#include <string>
#include <string_view>
#include <lua.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>

// Compositor-local synthetic AQ source: no kernel device or parent input socket.
namespace {
class CFitProbeTouch final : public Aquamarine::ITouch {
    const std::string name = "tessarchy-fit-private-touch";
  public:
    const std::string& getName() override { return name; }
};
SP<CFitProbeTouch> probeTouch;
SP<ITouch> probeDevice;
int32_t probeContact = -1;
bool mapTouchMotion = true;

uint32_t touchTime() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

void stopProbeTouch() {
    if (!probeTouch)
        return;
    if (probeContact >= 0) {
        probeTouch->events.up.emit({touchTime(), probeContact});
        probeTouch->events.frame.emit();
    }
    probeContact = -1;
    Pointer::mgr()->detachTouch(probeDevice);
    // Keep the wrapper alive while AQ destruction removes it from InputManager.
    probeTouch.reset();
    probeDevice.reset();
    g_pInputManager->updateCapabilities();
    mapTouchMotion = true;
}

int touchProbe(lua_State* lua) {
    const std::string_view action = luaL_checkstring(lua, 1);
    auto* monitor = State::monitorState()->query().name("FIT-1").run().get();
    if (!monitor)
        return luaL_error(lua, "touch probe requires the private FIT-1 output");
    if (action == "enable") {
        if (!probeTouch) {
            probeTouch = makeShared<CFitProbeTouch>();
            g_pInputManager->newTouchDevice(probeTouch);
            probeDevice = g_pInputManager->m_touches.back();
            probeDevice->m_boundOutput = "FIT-1";
            g_pInputManager->updateCapabilities();
        }
        return 0;
    }
    if (action == "disable") {
        stopProbeTouch();
        return 0;
    }
    if (action == "motion_fix") {
        if (probeContact >= 0)
            return luaL_error(lua, "finish the contact before changing its transform");
        mapTouchMotion = lua_toboolean(lua, 2);
        return 0;
    }
    if (!probeTouch)
        return luaL_error(lua, "enable the private touch device first");
    const auto id = luaL_checkinteger(lua, 2);
    if (id < 0 || id > 65535)
        return luaL_error(lua, "invalid contact ID");
    const auto time = touchTime();
    if (action == "up") {
        if (id != probeContact)
            return luaL_error(lua, "contact ID is not active");
        probeTouch->events.up.emit({time, static_cast<int32_t>(id)});
        probeContact = -1;
    } else if (action == "down" || action == "move") {
        const Vector2D position{luaL_checknumber(lua, 3), luaL_checknumber(lua, 4)};
        if (!std::isfinite(position.x) || !std::isfinite(position.y) || position.x < 0 || position.y < 0 ||
            position.x >= monitor->m_size.x || position.y >= monitor->m_size.y)
            return luaL_error(lua, "position is outside the private output");
        if (action == "down") {
            if (probeContact >= 0)
                return luaL_error(lua, "probe supports one contact at a time");
            probeContact = id;
            probeTouch->events.down.emit({time, static_cast<int32_t>(id), position / monitor->m_size});
        } else {
            if (id != probeContact)
                return luaL_error(lua, "contact ID is not active");
            probeTouch->events.move.emit({time, static_cast<int32_t>(id), position / monitor->m_size});
        }
    } else
        return luaL_error(lua, "unknown touch probe action");
    probeTouch->events.frame.emit();
    return 0;
}
}
