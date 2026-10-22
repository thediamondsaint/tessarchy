#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/view/WLSurface.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/render/pass/SurfacePassElement.hpp>
#include <hyprland/src/render/ElementRenderer.hpp>
#include <hyprland/src/protocols/XDGShell.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/managers/SeatManager.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <lua.hpp>
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>
#include "touch-probe.hpp"

// PRIVATE PROOF ONLY: never loaded by Tessarchy's session, image or package.
// The harness enables this guard, disables damage tracking, and uses an isolated
// runtime/config/bus/seat. Do not load into a user's compositor.
namespace {
HANDLE owner = nullptr;
std::string targetClass;
std::vector<CFunctionHook*> hooks;
CFunctionHook *texHook, *uvHook, *pickHook, *localHook, *touchHook, *windowHook;
uint64_t draws = 0, picks = 0, locals = 0, touches = 0;
using Geo = Desktop::View::IGeometric;

struct Fit {
    Vector2D origin;
    double scale;
    Vector2D inverse(const Vector2D& global) const { return origin + (global - origin) / scale; }
};

std::optional<Fit> fitFor(PHLWINDOW window) {
    if (targetClass.empty() || !window || !window->m_isMapped || window->m_isX11 ||
        window->m_class != targetClass || !window->m_xdgSurface)
        return std::nullopt;
    const auto geometry = window->m_xdgSurface->m_current.geometry;
    const auto available = window->size(Geo::GEOMETRIC_CURRENT);
    const auto origin = window->position(Geo::GEOMETRIC_CURRENT);
    if (geometry.width <= 0 || geometry.height <= 0 || available.x <= 0 || available.y <= 0)
        return std::nullopt;
    const double scale = std::min({1.0, available.x / geometry.width, available.y / geometry.height});
    if (!std::isfinite(scale) || scale <= 0 || scale >= 1)
        return std::nullopt;
    return Fit{origin, scale};
}

using TexFn = CBox (*)(CSurfacePassElement*);
CBox fittedTex(CSurfacePassElement* element) {
    const auto fit = fitFor(element->m_data.pWindow);
    const auto original = reinterpret_cast<TexFn>(texHook->m_original);
    if (!fit || !element->m_data.surface || !element->m_data.pMonitor)
        return original(element);
    auto& data = element->m_data;
    const double width = data.w, height = data.h;
    const bool squish = data.squishOversized;
    // Compute/cache the native texture rectangle, not the allocated/clipped one.
    // getTexBox's cache remains native; map its returned copy exactly once.
    if (data.mainSurface) {
        data.w = data.surface->m_current.size.x;
        data.h = data.surface->m_current.size.y;
    }
    data.squishOversized = false;
    CBox box = original(element);
    data.w = width;
    data.h = height;
    data.squishOversized = squish;
    // getTexBox returns monitor-local LOGICAL coordinates (not pixels).
    const auto anchor = fit->origin - data.pMonitor->m_position;
    box.x = anchor.x + (box.x - anchor.x) * fit->scale;
    box.y = anchor.y + (box.y - anchor.y) * fit->scale;
    box.width *= fit->scale;
    box.height *= fit->scale;
    ++draws;
    return box;
}

using UvFn = void (*)(Render::IElementRenderer*, PHLWINDOW, SP<CWLSurfaceResource>, PHLMONITOR,
                     bool, const Vector2D&, const Vector2D&, bool);
void fittedUv(Render::IElementRenderer* renderer, PHLWINDOW window, SP<CWLSurfaceResource> surface,
              PHLMONITOR monitor, bool main, const Vector2D& projected, const Vector2D& unscaled,
              bool misaligned) {
    // Preserve the protocol viewport source, but skip the compositor's
    // window/projection size-ratio crop: our texture box already performs fitting.
    // Do not mutate the incoming shared-pointer parameter. Optimized Hyprland
    // caller cleanup retains its original control block across this call; resetting
    // the parameter would decrement that block twice and destroy a live window.
    const bool fitted = fitFor(window).has_value();
    const PHLWINDOW uvWindow = fitted ? PHLWINDOW{} : window;
    reinterpret_cast<UvFn>(uvHook->m_original)(renderer, uvWindow, surface, monitor,
        fitted ? false : main, projected, unscaled, fitted ? false : misaligned);
}

using WindowFn = PHLWINDOW (*)(const Desktop::CViewHitTester*, const Vector2D&, uint16_t, PHLWINDOW);
PHLWINDOW fittedWindow(const Desktop::CViewHitTester* hit, const Vector2D& global, uint16_t properties,
                       PHLWINDOW ignoreWindow) {
    const auto window = reinterpret_cast<WindowFn>(windowHook->m_original)(hit, global, properties, ignoreWindow);
    if (const auto fit = fitFor(window)) {
        const auto position = fit->inverse(global) - fit->origin;
        const auto geometry = window->m_xdgSurface->m_current.geometry;
        // Reject letterboxing before InputManager can fall back to the root surface.
        if (position.x < 0 || position.y < 0 || position.x >= geometry.width || position.y >= geometry.height)
            return nullptr;
    }
    return window;
}

using PickFn = SP<CWLSurfaceResource> (*)(const Desktop::CViewHitTester*, const Vector2D&, PHLWINDOW, Vector2D&);
SP<CWLSurfaceResource> fittedPick(const Desktop::CViewHitTester* hit, const Vector2D& global,
                                PHLWINDOW window, Vector2D& local) {
    Vector2D native = global;
    if (const auto fit = fitFor(window)) {
        native = fit->inverse(global);
        ++picks;
    }
    return reinterpret_cast<PickFn>(pickHook->m_original)(hit, native, window, local);
}

using LocalFn = Vector2D (*)(const Desktop::CViewHitTester*, const Vector2D&, PHLWINDOW, SP<CWLSurfaceResource>);
Vector2D fittedLocal(const Desktop::CViewHitTester* hit, const Vector2D& global, PHLWINDOW window,
                     SP<CWLSurfaceResource> surface) {
    Vector2D native = global;
    if (const auto fit = fitFor(window)) {
        native = fit->inverse(global);
        ++locals;
    }
    return reinterpret_cast<LocalFn>(localHook->m_original)(hit, native, window, surface);
}

using TouchFn = void (*)(CSeatManager*, uint32_t, int32_t, const Vector2D&);
void fittedTouch(CSeatManager* seat, uint32_t time, int32_t id, const Vector2D& upstreamLocal) {
    Vector2D local = upstreamLocal;
    const auto window = g_pInputManager->m_touchData.touchFocusWindow.lock();
    const auto surface = g_pInputManager->m_touchData.touchFocusSurface.lock();
    if (mapTouchMotion && fitFor(window) && surface) {
        // Touch.cpp normally subtracts a constant origin after touch-down. A
        // scale needs an inverse affine mapping on EVERY motion. Re-use the
        // surface-specific picker rather than dividing already-local coordinates.
        local = Desktop::viewState()->hitTest().surfaceLocalAt(
            g_pInputManager->m_touchData.lastTouchPos, window, surface);
        ++touches;
    }
    reinterpret_cast<TouchFn>(touchHook->m_original)(seat, time, id, local);
}

CFunctionHook* install(const std::string& name, const std::string& prefix, void* callback) {
    std::vector<void*> matches;
    for (const auto& function : HyprlandAPI::findFunctionsByName(owner, name))
        if (function.demangled.starts_with(prefix))
            matches.push_back(function.address);
    if (matches.size() != 1)
        throw std::runtime_error("native-fit: expected one exact source symbol for " + prefix);
    auto hook = HyprlandAPI::createFunctionHook(owner, matches.front(), callback);
    if (!hook || !hook->hook())
        throw std::runtime_error("native-fit: could not install " + prefix);
    hooks.push_back(hook);
    return hook;
}

int selectTarget(lua_State* lua) {
    size_t size = 0;
    const char* value = luaL_checklstring(lua, 1, &size);
    if (size > 256)
        return luaL_error(lua, "app_id exceeds 256 bytes");
    targetClass.assign(value, size); // empty string disables; no built-in app list
    return 0;
}

int status(lua_State* lua) {
    lua_newtable(lua);
    for (auto [key, value] : {std::pair{"draws", draws}, {"picks", picks}, {"locals", locals}, {"touches", touches}}) {
        lua_pushinteger(lua, value);
        lua_setfield(lua, -2, key);
    }
    lua_pushlstring(lua, targetClass.data(), targetClass.size());
    lua_setfield(lua, -2, "target");
    return 1;
}
} // namespace

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }
APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    const char* guard = std::getenv("TESSARCHY_FIT_PROTOTYPE");
    if (!guard || std::string_view(guard) != "1")
        throw std::runtime_error("native-fit is isolated-harness-only; refusing live load");
    if (std::string_view(__hyprland_api_get_hash()) != __hyprland_api_get_client_hash())
        throw std::runtime_error("native-fit requires exactly matching compositor headers");
    owner = handle;
    try {
        texHook = install("getTexBox", "CSurfacePassElement::getTexBox(", reinterpret_cast<void*>(fittedTex));
        uvHook = install("calculateUVForSurface", "Render::IElementRenderer::calculateUVForSurface(", reinterpret_cast<void*>(fittedUv));
        windowHook = install("windowAt", "Desktop::CViewHitTester::windowAt(", reinterpret_cast<void*>(fittedWindow));
        pickHook = install("windowSurfaceAt", "Desktop::CViewHitTester::windowSurfaceAt(", reinterpret_cast<void*>(fittedPick));
        localHook = install("surfaceLocalAt", "Desktop::CViewHitTester::surfaceLocalAt(", reinterpret_cast<void*>(fittedLocal));
        touchHook = install("sendTouchMotion", "CSeatManager::sendTouchMotion(", reinterpret_cast<void*>(fittedTouch));
        if (!HyprlandAPI::addLuaFunction(handle, "tessarchy_fit", "target", selectTarget) ||
            !HyprlandAPI::addLuaFunction(handle, "tessarchy_fit", "status", status) ||
            !HyprlandAPI::addLuaFunction(handle, "tessarchy_fit", "touch", touchProbe))
            throw std::runtime_error("native-fit: failed to register probe controls");
    } catch (...) {
        for (auto it = hooks.rbegin(); it != hooks.rend(); ++it)
            (*it)->unhook();
        hooks.clear();
        throw;
    }
    return {"tessarchy-native-fit-probe", "Isolated native-window render/input feasibility probe", "Tessarchy", "0.0.1"};
}
APICALL EXPORT void PLUGIN_EXIT() {
    stopProbeTouch();
    targetClass.clear();
    for (auto it = hooks.rbegin(); it != hooks.rend(); ++it)
        (*it)->unhook();
    // The module's globals may survive dlclose/reload. Hyprland owns/deletes
    // hook objects; retaining their pointers would unhook freed objects next exit.
    hooks.clear();
    texHook = uvHook = pickHook = localHook = touchHook = nullptr;
    owner = nullptr;
}
