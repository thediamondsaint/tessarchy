const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../website/app.js'), 'utf8');
const root = 'https://github.com/thediamondsaint/tessarchy/';

async function page(releases = [], commits = [], bundled = {}) {
  const nodes = new Map();
  function element() {
    return {
      events: {}, textContent: '', href: '',
      addEventListener(name, handler) { this.events[name] = handler; },
    };
  }
  const document = {
    querySelector(selector) {
      if (!nodes.has(selector)) nodes.set(selector, element());
      return nodes.get(selector);
    },
    querySelectorAll() { return []; }
  };
  document.querySelector('#release-link').href = root + 'releases/tag/fallback';
  const requests = [];
  const fetch = async url => {
    requests.push(url);
    const data = url === 'project.json' ? bundled : url.includes('/releases?') ? releases : commits;
    return {ok: true, json: async () => data};
  };
  await vm.runInNewContext(source, {document, fetch, AbortSignal, navigator: {}});
  return {nodes, requests};
}

test('release discovery reaches an ISO beyond five newer non-ISO releases and ignores drafts', async () => {
  const branding = Array.from({length: 6}, (_, i) => ({assets: [{name: 'logo-' + i + '.zip'}]}));
  const draft = {draft: true, html_url: root + 'releases/tag/draft', assets: [{name: 'draft.iso'}]};
  const iso = {html_url: root + 'releases/tag/tester', name: 'Tester', assets: [{name: 'tessarchy.iso.part001'}]};
  const result = await page([draft, ...branding, iso]);
  assert.equal(result.nodes.get('#release-link').href, iso.html_url);
  assert.ok(result.requests.some(url => url.includes('releases?per_page=100')));
  assert.ok(result.requests.some(url => url.includes('commits?sha=main&')));
});

test('invalid metadata keeps fallback links and does not prevent other updates', async () => {
  const result = await page({message: 'Invalid release response'}, [{html_url: 123}], {
    commit: 'a'.repeat(40), release: {html_url: 123}
  });
  assert.equal(result.nodes.get('#release-link').href, root + 'releases/tag/fallback');
  assert.equal(result.nodes.get('#build-stamp').textContent, 'Site snapshot aaaaaaa · Built from the Tessarchy source');
  const malformed = await page([{assets: {name: 'not-an-array'}}], {message: 'Invalid commits'});
  assert.equal(malformed.nodes.get('#release-link').href, root + 'releases/tag/fallback');
});

test('commit summaries render as literal text and untrusted destinations are ignored', async () => {
  const result = await page([{html_url: 'https://example.invalid/', assets: [{name: 'image.iso'}]}], [
    {html_url: root + 'commit/' + 'b'.repeat(40), commit: {message: '<b>Literal title</b>\nDetails'}}
  ]);
  assert.equal(result.nodes.get('#release-link').href, root + 'releases/tag/fallback');
  assert.equal(result.nodes.get('#commit-message').textContent, '<b>Literal title</b>');
});

test('release metadata updates the alpha link and signed VM image links', async () => {
  const disk = 'Arch-Linux-x86_64-basic-20261015.611680.qcow2';
  const base = root + 'releases/download/tester/';
  const release = {
    tag_name: 'v0.1.0-alpha.17', name: 'Tessarchy Alpha 17',
    html_url: root + 'releases/tag/tester',
    assets: [
      {name: 'tessarchy.iso.part001'},
      {name: disk, browser_download_url: base + disk},
      {name: disk + '.SHA256', browser_download_url: base + disk + '.SHA256'},
      {name: disk + '.sig', browser_download_url: base + disk + '.sig'}
    ]
  };
  const result = await page([release]);
  assert.equal(result.nodes.get('#release-link').textContent, 'Get v0.1.0-alpha.17 ↓');
  assert.match(result.nodes.get('#release-note').textContent, /Tessarchy Alpha 17/);
  assert.equal(result.nodes.get('#vm-image-link').href, base + disk);
  assert.equal(result.nodes.get('#vm-checksum-link').href, base + disk + '.SHA256');
  assert.equal(result.nodes.get('#vm-signature-link').href, base + disk + '.sig');
});
