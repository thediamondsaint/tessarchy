const releaseLink = document.querySelector('#release-link');

function useRelease(release) {
  if (!release || typeof release.html_url !== 'string') return;
  if (!release.html_url.startsWith('https://github.com/thediamondsaint/tessarchy/releases/')) return;

  const tag = typeof release.tag_name === 'string' ? release.tag_name : '';
  const title = typeof release.name === 'string' && release.name ? release.name : tag;
  releaseLink.href = release.html_url;
  releaseLink.textContent = `Get ${tag || 'the latest build'} ↓`;
  document.querySelector('#release-notes-link').href = release.html_url;
  document.querySelector('#release-note').textContent = `${title}. Download the Tessarchy netinstall, SHA-256 checksum, VM image, and install guide from the release.`;

  const assets = Array.isArray(release.assets) ? release.assets : [];
  const installer = assets.find(asset => typeof asset?.name === 'string'
    && asset.name.startsWith('tessarchy-netinstall-') && asset.name.endsWith('.iso'));
  if (typeof installer?.browser_download_url === 'string'
    && installer.browser_download_url.startsWith('https://github.com/thediamondsaint/tessarchy/releases/download/')) {
    const size = Number.isFinite(installer.size) ? ` · ${(installer.size / 1048576).toFixed(0)} MiB` : '';
    releaseLink.href = installer.browser_download_url;
    releaseLink.textContent = `Download ${tag || 'the latest'} netinstall ↓`;
    document.querySelector('#release-note').textContent = `${title}${size}. Download the netinstall ISO, checksum, VM image, and install guide from the release.`;
  }

  const disk = assets.find(asset => typeof asset?.name === 'string'
    && /^Arch-Linux-x86_64-basic-\d{8}\.\d+\.qcow2$/.test(asset.name));
  if (!disk) return;

  for (const [selector, suffix] of [
    ['#vm-image-link', ''], ['#vm-checksum-link', '.SHA256'], ['#vm-signature-link', '.sig']
  ]) {
    const asset = assets.find(item => item?.name === disk.name + suffix);
    if (typeof asset?.browser_download_url === 'string'
      && asset.browser_download_url.startsWith('https://github.com/thediamondsaint/tessarchy/releases/download/')) {
      document.querySelector(selector).href = asset.browser_download_url;
    }
  }
}

function useCommit(commit) {
  if (typeof commit?.commit?.message !== 'string' || typeof commit.html_url !== 'string') return;
  if (!commit.html_url.startsWith('https://github.com/thediamondsaint/tessarchy/commit/')) return;
  document.querySelector('#commit-link').href = commit.html_url;
  document.querySelector('#commit-message').textContent = commit.commit.message.split('\n')[0];
}

async function getJson(url) {
  const response = await fetch(url, {signal: AbortSignal.timeout(6000)});
  if (!response.ok) throw new Error(`Request failed: ${response.status}`);
  return response.json();
}

(async () => {
  try {
    const project = await getJson('project.json');
    useRelease(project.release);
    if (/^[a-f0-9]{40}$/.test(project.commit)) {
      document.querySelector('#build-stamp').textContent = `Site snapshot ${project.commit.slice(0, 7)} · Built from the Tessarchy source`;
    }
  } catch { /* Release links on the page remain available without metadata. */ }

  const [releases, commits] = await Promise.allSettled([
    getJson('https://api.github.com/repos/thediamondsaint/tessarchy/releases?per_page=100'),
    getJson('https://api.github.com/repos/thediamondsaint/tessarchy/commits?sha=main&per_page=1')
  ]);

  if (releases.status === 'fulfilled' && Array.isArray(releases.value)) {
    const current = releases.value.find(release => release && !release.draft && Array.isArray(release.assets)
      && release.assets.some(asset => typeof asset?.name === 'string'
        && (asset.name.endsWith('.iso') || asset.name.includes('.iso.part'))));
    useRelease(current);
  }
  if (commits.status === 'fulfilled' && Array.isArray(commits.value)) useCommit(commits.value[0]);
})();
