.pragma library

const TARGET = 48;
const GAP = 8;
const EDGE = 24;

function numeric(value) {
    return typeof value === "number" && isFinite(value);
}

function placement(mode, width, height, monitorId, rectangles, statusHeight) {
    if ((mode !== "phone" && mode !== "tablet") || !numeric(width) || !numeric(height)
            || !numeric(monitorId) || monitorId < 0 || !Array.isArray(rectangles)
            || !numeric(statusHeight) || width < TARGET + 2 * EDGE || height <= 0)
        return null;
    const candidates = rectangles.filter(r => r && r.monitor === monitorId
        && [r.x, r.y, r.w, r.h].every(numeric) && r.w > 0 && r.h > 0
        && r.x >= 0 && r.y >= 0 && r.x < width && r.y < height);
    if (candidates.length === 0) return null;
    // Stay above every mapped keyboard on this output, not only the last one.
    candidates.sort((a, b) => a.y - b.y);
    const keyboard = candidates[0];
    const y = keyboard.y - TARGET - GAP;
    if (y < statusHeight + GAP) return null;
    const x = Math.max(EDGE, Math.min(width - TARGET - EDGE,
                                    keyboard.x + keyboard.w - TARGET - GAP));
    return { x: Math.floor(x), y: Math.floor(y), width: TARGET, height: TARGET };
}

function query() {
    // Numeric records only: no monitor/window names need quoting or execution.
    return 'local r = {}; for _, l in ipairs(hl.get_layers({namespace="osk"})) do '
        + 'local m = l.monitor; if l.mapped and m and l.w > 0 and l.h > 0 then '
        + 'table.insert(r, string.format(\'{"monitor":%d,"x":%d,"y":%d,"w":%d,"h":%d}\', '
        + 'm.id, l.x, l.y, l.w, l.h)); end; end; print("[" .. table.concat(r, ",") .. "]")';
}
