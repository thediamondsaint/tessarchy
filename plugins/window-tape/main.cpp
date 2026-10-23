#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/algorithm/tiled/scrolling/ScrollingAlgorithm.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <lua.hpp>
#include <algorithm>
#include <cmath>
#include <stdexcept>

// Expose the native gesture path without layout-message refocusing on every frame.
static Layout::Tiled::CScrollingAlgorithm* activeTape() {
    const auto monitor = Desktop::focusState()->monitor();
    if (!monitor || monitor->m_activeSpecialWorkspace) return nullptr;
    const auto workspace = monitor->m_activeWorkspace;
    if (!workspace || workspace->m_name != "tessarchy-tape" || !workspace->m_space) return nullptr;
    const auto algorithm = workspace->m_space->algorithm();
    if (!algorithm) return nullptr;
    return dynamic_cast<Layout::Tiled::CScrollingAlgorithm*>(algorithm->tiledAlgo().get());
}

static int moveTape(lua_State* state) {
    const auto delta = luaL_checknumber(state, 1);
    if (!std::isfinite(delta)) return 0;
    if (const auto tape = activeTape()) tape->moveTape(std::clamp(delta, -4096.0, 4096.0));
    return 0;
}

static int settleTape(lua_State*) {
    if (const auto tape = activeTape()) {
        const auto column = tape->snapToProjectedOffset(tape->normalizedTapeOffset());
        if (column) tape->focusColumn(column);
    }
    return 0;
}

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }
APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (std::string_view(__hyprland_api_get_hash()) != __hyprland_api_get_client_hash())
        throw std::runtime_error("Window tape requires matching Hyprland build headers");
    if (!HyprlandAPI::addLuaFunction(handle, "tessarchy_tape", "move", moveTape) ||
        !HyprlandAPI::addLuaFunction(handle, "tessarchy_tape", "settle", settleTape))
        throw std::runtime_error("Could not register window tape bridge");
    return {"tessarchy-tape", "Touch bridge to Hyprland's native scrolling gestures", "Tessarchy", "0.1.0"};
}
APICALL EXPORT void PLUGIN_EXIT() {}
