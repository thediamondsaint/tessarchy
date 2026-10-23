const modes = {
  phone: {image: 'phone-home.png?v=20261019-refresh', controls: 'phone-controls.png?v=20261019-refresh', label: 'PHONE / 390 × 844', width: 390, height: 844},
  tablet: {image: 'tablet-home.png?v=20261019-refresh', controls: 'tablet-controls.png?v=20261019-refresh', label: 'TABLET / 800 × 1280', width: 800, height: 1280},
  desktop: {image: 'desktop-home.png?v=20261019-refresh', controls: 'desktop-controls.png?v=20261019-refresh', label: 'DESKTOP / 1280 × 800', width: 1280, height: 800}
};
const tabs = [...document.querySelectorAll('[data-mode]')];
function selectMode(tab) {
  tabs.forEach(item => {item.setAttribute('aria-selected', String(item === tab)); item.tabIndex = item === tab ? 0 : -1;});
  const mode = modes[tab.dataset.mode], panel = document.querySelector('#layout-preview'), image = document.querySelector('#layout-image');
  panel.className = 'layout-preview ' + tab.dataset.mode + '-mode';
  panel.setAttribute('aria-labelledby', tab.id);
  image.src = 'assets/' + mode.image;
  image.alt = tab.textContent + ' layout in the Tessarchy development VM';
  image.width = mode.width; image.height = mode.height;
  image.parentElement.dataset.image = image.src;
  document.querySelector('#layout-label').textContent = mode.label;
  const controls = document.querySelector('#layout-controls-shot');
  controls.dataset.image = 'assets/' + mode.controls;
  controls.dataset.alt = tab.textContent + ' layout showing the current pull-down controls in the development VM';
}
tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => selectMode(tab));
  tab.addEventListener('keydown', event => {
    let next;
    if (event.key === 'ArrowRight') next = tabs[(index + 1) % tabs.length];
    if (event.key === 'ArrowLeft') next = tabs[(index + tabs.length - 1) % tabs.length];
    if (event.key === 'Home') next = tabs[0];
    if (event.key === 'End') next = tabs[tabs.length - 1];
    if (next) {event.preventDefault(); selectMode(next); next.focus();}
  });
});
const gallery = document.querySelector('#gallery');
document.querySelectorAll('[data-image]').forEach(button => button.addEventListener('click', () => {
  document.querySelector('#gallery-image').src = button.dataset.image;
  document.querySelector('#gallery-image').alt = button.querySelector('img')?.alt || button.dataset.alt;
  document.querySelector('#gallery-download').href = button.dataset.image;
  gallery.showModal();
}));
document.querySelector('#gallery-close').addEventListener('click', () => gallery.close());
gallery.addEventListener('click', event => {if (event.target === gallery) gallery.close();});
document.querySelector('#share-project').addEventListener('click', async () => {
  const url = 'https://thediamondsaint.github.io/tessarchy/';
  const status = document.querySelector('#share-status');
  try {
    if (navigator.share) {
      await navigator.share({title: 'Tessarchy · Quiet Edge', text: 'A touch-first Arch Linux prototype: real VM screenshots, a tester ISO, and the roadmap to a handheld device.', url});
      status.textContent = 'Project shared.';
    } else {
      await navigator.clipboard.writeText(url);
      status.textContent = 'Project link copied. Paste it into your channel.';
    }
  } catch (error) {
    status.textContent = error.name === 'AbortError' ? 'Sharing cancelled.' : 'Copy the project address below to share it.';
  }
});
function showRelease(release) {
  if (!release || typeof release.html_url !== 'string' || !release.html_url.startsWith('https://github.com/thediamondsaint/tessarchy/releases/')) return;
  const link = document.querySelector('#release-link'); link.href = release.html_url;
  link.textContent = 'Download ' + (release.name || release.tag_name) + ' ↓';
}
function showCommit(commit) {
  if (!commit || typeof commit.commit?.message !== 'string' || typeof commit.html_url !== 'string' || !commit.html_url.startsWith('https://github.com/thediamondsaint/tessarchy/commit/')) return;
  document.querySelector('#commit-link').href = commit.html_url;
  document.querySelector('#commit-message').textContent = commit.commit.message.split('\n')[0];
}
async function readJson(url) {
  const response = await fetch(url, {signal: AbortSignal.timeout(6000)});
  if (!response.ok) throw new Error('Data unavailable');
  return response.json();
}
(async () => {
  try {
    const bundled = await readJson('project.json');
    showRelease(bundled.release);
    document.querySelector('#build-stamp').textContent = /^[a-f0-9]{40}$/.test(bundled.commit)
      ? 'Site built from ' + bundled.commit.slice(0, 7) : 'Built from a source snapshot';
  } catch { /* The built-in links remain usable offline. */ }
  // Public metadata only. No credentials, trackers, or paid services.
  const results = await Promise.allSettled([
    readJson('https://api.github.com/repos/thediamondsaint/tessarchy/releases?per_page=100'),
    readJson('https://api.github.com/repos/thediamondsaint/tessarchy/commits?sha=main&per_page=1')
  ]);
  if (results[0].status === 'fulfilled' && Array.isArray(results[0].value))
    showRelease(results[0].value.find(release => release && !release.draft && Array.isArray(release.assets)
      && release.assets.some(asset => typeof asset?.name === 'string'
        && (asset.name.endsWith('.iso') || asset.name.includes('.iso.part')))));
  if (results[1].status === 'fulfilled' && Array.isArray(results[1].value)) showCommit(results[1].value[0]);
})();
