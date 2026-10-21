.pragma library

const categories = [
    { id: "Internet", keys: ["Network", "WebBrowser", "Email"] },
    { id: "Office", keys: ["Office"] },
    { id: "Development", keys: ["Development"] },
    { id: "Graphics", keys: ["Graphics"] },
    { id: "Audio & Video", keys: ["AudioVideo", "Audio", "Video"] },
    { id: "Games", keys: ["Game"] },
    { id: "Education", keys: ["Education", "Science"] },
    { id: "Settings", keys: ["Settings"] },
    { id: "System", keys: ["System"] },
    { id: "Utilities", keys: ["Utility"] },
    { id: "Other", keys: [] }
];

// Quickshell owns discovery, desktop-ID precedence and Hidden/NoDisplay filtering.
function applications(entries) {
    return entries.filter(entry => entry && !entry.noDisplay && entry.id && entry.name
        && entry.command && entry.command.length > 0).slice().sort((a, b) =>
            String(a.name).localeCompare(String(b.name)) || String(a.id).localeCompare(String(b.id)));
}

function category(entry) {
    const keys = entry.categories || [];
    for (const group of categories) {
        if (group.keys.some(key => keys.indexOf(key) !== -1)) return group.id;
    }
    return "Other";
}

function menuRows(entries) {
    const groups = {};
    for (const entry of applications(entries)) {
        const label = category(entry);
        if (!groups[label]) groups[label] = [];
        groups[label].push(entry);
    }
    const rows = [];
    for (const group of categories) {
        const apps = groups[group.id];
        if (!apps) continue;
        rows.push({ key: "category:" + group.id, heading: true, appId: "", name: group.id, icon: "" });
        for (const entry of apps) {
            rows.push({ key: "app:" + entry.id, heading: false, appId: String(entry.id),
                name: String(entry.name), icon: String(entry.icon || "") });
        }
    }
    return rows;
}

// Move stable IDs and change only affected roles so unchanged tiles retain focus.
function syncRows(model, rows) {
    let changed = false;
    const wanted = {};
    for (const row of rows) wanted[row.key] = true;
    for (let i = model.count - 1; i >= 0; --i) {
        if (!wanted[model.get(i).key]) { model.remove(i); changed = true; }
    }
    for (let i = 0; i < rows.length; ++i) {
        const row = rows[i];
        let found = i;
        while (found < model.count && model.get(found).key !== row.key) ++found;
        if (found === model.count) { model.insert(i, row); changed = true; }
        else {
            if (found !== i) { model.move(found, i, 1); changed = true; }
            for (const role of ["heading", "appId", "name", "icon"]) {
                if (model.get(i)[role] !== row[role]) {
                    model.setProperty(i, role, row[role]);
                    changed = true;
                }
            }
        }
    }
    return changed;
}
