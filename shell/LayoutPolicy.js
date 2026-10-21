.pragma library

function automaticMode(width, height) {
    if (Math.min(width, height) < 600) return "phone";
    if (width >= 1100 && height >= 650) return "desktop";
    return "tablet";
}

function effectiveMode(choice, width, height) {
    if (["phone", "tablet", "desktop"].indexOf(choice) >= 0) return choice;
    return automaticMode(width, height);
}

function title(mode) {
    return mode.charAt(0).toUpperCase() + mode.slice(1);
}

function columns(mode, width) {
    const preferred = mode === "desktop" ? 4 : mode === "tablet" ? 3 : 2;
    return Math.max(1, Math.min(preferred, Math.floor(width / 140)));
}

function panelWidth(mode, width) {
    return mode === "phone" ? width : Math.min(Math.max(0, width - 24), mode === "desktop" ? 760 : 720);
}

// Nav/task bar geometry. Every bar dimension in shell.qml derives from these.
// row: touch row height; rowGap/columnGap: spacing between dock buttons;
// inset: frame edge to the row, equal above and below; gap: frame to the
// bottom screen edge; side: least frame-to-side-edge gap (0 spans the screen);
// padding: frame edge to the first and last button; maxWidth: widest dock.
const BAR_ROW = 48;
const BAR_ROW_GAP = 8;
const BAR_COLUMN_GAP = 4;
const BAR_MODES = {
    desktop: {inset: 4, gap: 8, side: 0, padding: 10, maxWidth: 448},
    tablet: {inset: 12, gap: 12, side: 16, padding: 16, maxWidth: 448},
    phone: {inset: 8, gap: 12, side: 16, padding: 12, maxWidth: 376}
};
// Open pages keep their own frame margins, flush with the screen bottom.
const BAR_PAGE = {top: 12, desktopTop: 8, bottom: 12};

// Desktop always shows one taskbar row; touch docks may wrap to several.
function barGeometry(mode, rows) {
    const spec = BAR_MODES[mode] || BAR_MODES.tablet;
    const count = mode === "desktop" ? 1 : Math.max(1, rows || 1);
    const rowsHeight = count * BAR_ROW + (count - 1) * BAR_ROW_GAP;
    const frameHeight = rowsHeight + 2 * spec.inset;
    return {
        row: BAR_ROW,
        rowGap: BAR_ROW_GAP,
        columnGap: BAR_COLUMN_GAP,
        rows: count,
        rowsHeight: rowsHeight,
        inset: spec.inset,
        gap: spec.gap,
        side: spec.side,
        padding: spec.padding,
        maxWidth: spec.maxWidth,
        frameHeight: frameHeight,
        // The layer surface holds the frame plus the gap below it.
        height: frameHeight + spec.gap,
        pageTop: mode === "desktop" ? BAR_PAGE.desktopTop : BAR_PAGE.top,
        pageBottom: BAR_PAGE.bottom
    };
}

// Navigation gestures for the touch layouts. Distances are logical pixels.
// edge: width of the left/right swipe strips; the bottom strip is the bar gap
// plus inset (open pages: BAR_PAGE.bottom), so it never covers a dock button.
// distance: least upward travel
// for Home/Recents; back: least inward travel for Back; hold: milliseconds
// held still at the end of a swipe up for Recents; still: movement allowed
// while holding.
const GESTURE_EDGE = 16;
const GESTURE_DISTANCE = 48;
const GESTURE_BACK_DISTANCE = 48;
const GESTURE_HOLD = 350;
const GESTURE_STILL = 12;

// Gestures replace Back/Home/Recents on Phone and Tablet unless the user
// chose buttons. Desktop keeps its taskbar.
function gestureNavigation(mode, choice) {
    return mode !== "desktop" && choice !== "buttons";
}

// Hidden touch docks reserve nothing; temporary reveals overlay the app.
function dockState(mode, hasApp, expanded, revealed, barHeight) {
    const hidden = mode !== "desktop" && hasApp && !expanded && !revealed;
    return {visible: !hidden, exclusiveZone: mode === "desktop" || !hasApp ? barHeight : 0,
            reveal: hidden};
}

// edge: "bottom", "left" or "right"; dx/dy: travel since the touch began
// (screen axes, y down); heldMs: time the finger has been still at the end.
function classifyGesture(edge, dx, dy, heldMs) {
    if (edge === "bottom") {
        const up = -dy;
        if (up < GESTURE_DISTANCE || up < Math.abs(dx)) return "none";
        return heldMs >= GESTURE_HOLD ? "recents" : "home";
    }
    const inward = edge === "left" ? dx : edge === "right" ? -dx : 0;
    if (inward < GESTURE_BACK_DISTANCE || inward < Math.abs(dy)) return "none";
    return "back";
}

// An open page puts its dock row BAR_PAGE.bottom above the screen edge.
// handle: height of the handle pill's centre, in the gap below the dock frame.
function gestureEdgeSize(mode, expanded) {
    const bar = barGeometry(mode, 1);
    const bottom = expanded ? BAR_PAGE.bottom : bar.gap + bar.inset;
    return {side: GESTURE_EDGE, bottom: bottom, handle: Math.min(bar.gap, bottom) / 2};
}

// Touch docks: Phone, Messages and the optional Keyboard, plus Back, Home and
// Recents when gestures are off. Settings lives in the status bar and pull-down.
function dockLayout(mode, width, keyboard, gestures) {
    const bar = barGeometry(mode, 1);
    const navigation = gestures && mode !== "desktop" ? 0 : 3;
    const count = 2 + navigation + (keyboard && mode !== "desktop" ? 1 : 0);
    const dockWidth = Math.min(Math.max(0, width - 2 * bar.side), bar.maxWidth);
    const capacity = Math.max(1, Math.floor((dockWidth - 2 * bar.padding + bar.columnGap) / (bar.row + bar.columnGap)));
    const columns = capacity >= count ? count : Math.min(3, capacity);
    return {width: dockWidth, columns: columns, rows: Math.ceil(count / columns)};
}

// Desktop keeps numbered workspaces one tap away; landscape tablets only once
// the status bar has room beside the clock, tray and battery indicators.
function showWorkspaces(mode, width) {
    return (mode === "desktop" || mode === "tablet") && width >= 900;
}

// Workspaces 1-5 always have a slot. Higher numbered workspaces extend the
// strip. Named workspaces have negative ids and are not numbered slots.
function workspaceSlots(ids) {
    let slots = 5;
    for (let i = 0; i < ids.length; i++) {
        if (Number.isInteger(ids[i]) && ids[i] > slots) slots = Math.min(8, ids[i]);
    }
    return slots;
}

// Connected devices can disconnect; only paired devices can connect.
function btAction(connected, paired) {
    if (connected) return "disconnect";
    return paired ? "connect" : "none";
}

// Invalid battery readings are unavailable rather than a fabricated zero.
function btBatteryLabel(available, level) {
    if (!available || typeof level !== "number" || !isFinite(level)) return "";
    return " · " + Math.round(Math.max(0, Math.min(1, level)) * 100) + "%";
}

// Prefer a playing media player, then the first registered player.
function preferredPlayerIndex(playing) {
    for (let i = 0; i < playing.length; i++) if (playing[i]) return i;
    return playing.length ? 0 : -1;
}

function mediaSummary(title, artist) {
    return (title || "Unknown track") + " — " + (artist || "Unknown artist");
}

function nodeLabel(description, nickname, name) {
    for (const value of [description, nickname, name]) {
        if (value !== undefined && value !== null && String(value).trim()) return String(value).trim();
    }
    return "Unknown device";
}

function streamLabel(app, media, name) {
    const label = nodeLabel(app, media, name);
    return label === "Unknown device" ? "Unknown app" : label;
}

function playbackStream(mediaClass) {
    return mediaClass === "Stream/Output/Audio";
}

function volumePercent(value) {
    return Math.round(Math.max(0, Math.min(1, Number(value) || 0)) * 100);
}

function duration(seconds) {
    const total = Math.floor(Number(seconds) || 0);
    if (!isFinite(total) || total <= 0) return "";
    if (total < 60) return "less than a minute";
    let minutes = Math.round(total / 60);
    const hours = Math.floor(minutes / 60);
    minutes = minutes % 60;
    if (hours > 0) return hours + "h " + String(minutes).padStart(2, "0") + "m";
    return minutes + "m";
}

// Notification pop-ups dock below the status bar. Phone cards span the panel;
// larger screens right-align a bounded column.
function notificationPlacement(mode, width) {
    if (mode === "phone") return { fullWidth: true, maxWidth: Math.max(280, width - 16), topOffset: 56 };
    if (mode === "tablet") return { fullWidth: false, maxWidth: Math.min(360, width - 32), topOffset: 60 };
    return { fullWidth: false, maxWidth: Math.min(420, width - 32), topOffset: 60 };
}

// Seconds a pop-up stays on screen. Low urgency leaves sooner, normal after a
// comfortable read, and critical notifications stay until dismissed.
function notificationTimeout(urgency) {
    if (urgency === 2) return 0;
    if (urgency === 0) return 4;
    return 8;
}

// The on-screen keyboard is armed for the touch layouts only. Desktop is driven
// by a physical keyboard, and a panel there would cover the window it serves.
function oskArmed(mode) {
    return mode !== "desktop";
}
