const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const policy = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../shell/AppPolicy.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), policy);
const plain = value => JSON.parse(JSON.stringify(value));
const entry = (id, name = id, categories = []) => ({id, name, categories, icon: '', command: ['test']});

// Model test double implements the public ListModel operations used by the policy.
function model() {
    return {
        rows: [], operations: [], get count() { return this.rows.length; },
        get(i) { return this.rows[i]; },
        insert(i, row) { this.operations.push('insert'); this.rows.splice(i, 0, {...row}); },
        remove(i) { this.operations.push('remove'); this.rows.splice(i, 1); },
        move(from, to) { this.operations.push('move'); this.rows.splice(to, 0, this.rows.splice(from, 1)[0]); },
        setProperty(i, key, value) { this.operations.push('set'); this.rows[i][key] = value; }
    };
}

test('all apps includes unknown IDs and competing browsers; does not mutate inventory', () => {
    const apps = [entry('firefox', 'Firefox'), entry('custom', 'A custom app'), entry('chromium', 'Chromium')];
    assert.deepEqual(plain(policy.applications(apps)).map(a => a.id), ['custom', 'chromium', 'firefox']);
    assert.deepEqual(apps.map(a => a.id), ['firefox', 'custom', 'chromium']);
});
test('filters hidden/unlaunchable entries and keeps distinct IDs with equal names', () => {
    const apps = [entry('b', 'Editor'), entry('a', 'Editor'), {...entry('hidden'), noDisplay: true},
        {...entry('empty'), command: []}, null, {name: 'No ID', command: ['x']}];
    assert.deepEqual(plain(policy.applications(apps)).map(a => a.id), ['a', 'b']);
});
test('groups once with deterministic category precedence, alphabetical names and Other fallback', () => {
    const rows = plain(policy.menuRows([entry('z', 'Z editor', ['Utility', 'Development']),
        entry('unknown', 'Unknown'), entry('a', 'A editor', ['Development']), entry('web', 'Browser', ['Network'])]));
    assert.deepEqual(rows.map(r => r.name), ['Internet', 'Browser', 'Development', 'A editor', 'Z editor', 'Other', 'Unknown']);
    assert.equal(rows.filter(r => !r.heading).length, 4);
});
test('unchanged refresh performs no model writes and preserves row objects', () => {
    const m = model(), apps = [entry('a', 'Alpha', ['Office']), entry('b', 'Beta')];
    policy.syncRows(m, policy.menuRows(apps));
    const original = [...m.rows];
    m.operations = [];
    assert.equal(policy.syncRows(m, policy.menuRows(apps)), false);
    assert.equal(m.operations.length, 0);
    original.forEach((row, i) => assert.equal(m.rows[i], row));
});
test('install, rename, regroup, change icon and uninstall update stable IDs without resetting model', () => {
    const m = model();
    policy.syncRows(m, policy.menuRows([entry('a', 'Alpha'), entry('b', 'Beta')]));
    const b = m.rows.find(r => r.appId === 'b');
    policy.syncRows(m, policy.menuRows([entry('b', 'A renamed', ['Office']),
        {...entry('c', 'Charlie'), icon: 'custom-icon'}]));
    assert.equal(m.rows.find(r => r.appId === 'b'), b);
    assert.equal(b.name, 'A renamed');
    assert.equal(m.rows.find(r => r.appId === 'c').icon, 'custom-icon');
    assert.equal(m.rows.some(r => r.appId === 'a'), false);
    assert.deepEqual(plain(m.rows), plain(policy.menuRows([entry('b', 'A renamed', ['Office']),
        {...entry('c', 'Charlie'), icon: 'custom-icon'}])));
    policy.syncRows(m, []);
    assert.equal(m.count, 0);
});
test('large inventory remains complete and repeated updates do not duplicate rows', () => {
    const apps = Array.from({length: 500}, (_, i) => entry('id-' + i, 'App ' + i, ['Utility']));
    const m = model();
    for (let i = 0; i < 3; i++) policy.syncRows(m, policy.menuRows(apps));
    assert.equal(m.count, 501);
    assert.equal(new Set(m.rows.map(r => r.key)).size, m.count);
});
