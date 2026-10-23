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
      dataset: {}, events: {}, textContent: '', href: '', alt: '',
      addEventListener(name, handler) { this.events[name] = handler; },
      setAttribute(name, value) { this[name] = value; },
      focus() { this.focused = true; },
      showModal() { this.open = true; }, close() { this.open = false; },
      querySelector() { return this.image; }
    };
  }
  const document = {
    querySelector(selector) {
      if (!nodes.has(selector)) nodes.set(selector, element());
      return nodes.get(selector);
    },
    querySelectorAll(selector) { return selector === '[data-mode]' ? tabs : shots; }
  };
  const tabs = ['phone', 'tablet', 'desktop'].map(mode =>
    Object.assign(element(), {id: 'tab-' + mode, dataset: {mode}, textContent: mode}));
  const preview = element();
  const image = document.querySelector('#layout-image');
  image.parentElement = preview;
  preview.image = image;
  const controls = document.querySelector('#layout-controls-shot');
  const shots = [preview, controls];
  document.querySelector('#release-link').href = root + 'releases/tag/fallback';
  const requests = [];
  const fetch = async url => {
    requests.push(url);
    const data = url === 'project.json' ? bundled : url.includes('/releases?') ? releases : commits;
    return {ok: true, json: async () => data};
  };
  await vm.runInNewContext(source, {document, fetch, AbortSignal, navigator: {}});
  return {nodes, tabs, shots, requests};
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
  assert.equal(result.nodes.get('#build-stamp').textContent, 'Site built from aaaaaaa');
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

test('layout keyboard navigation updates gallery image, dimensions and control caption', async () => {
  const result = await page();
  let prevented = false;
  result.tabs[0].events.keydown({key: 'End', preventDefault() { prevented = true; }});
  assert.ok(prevented);
  assert.equal(result.tabs[2]['aria-selected'], 'true');
  assert.ok(result.tabs[2].focused);
  const image = result.nodes.get('#layout-image');
  assert.equal(image.width, 1280);
  assert.equal(image.height, 800);
  result.shots[0].events.click();
  assert.match(result.nodes.get('#gallery-image').src, /desktop-home/);
  assert.equal(result.nodes.get('#gallery-image').alt, image.alt);
  result.nodes.get('#layout-controls-shot').events.click();
  assert.match(result.nodes.get('#gallery-image').src, /desktop-controls/);
  assert.match(result.nodes.get('#gallery-image').alt, /desktop layout showing/);
});
