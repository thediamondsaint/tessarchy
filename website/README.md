# Tessarchy website

The public site introduces Tess, the mascot and guide, and Tessa, the Arch-based desktop project she presents. Its visual system uses warm paper, deep green, and three original portraits of Tess presenting a phone, tablet, and desktop.

## Site artwork

`assets/tess-phone.webp`, `assets/tess-tablet.webp`, and `assets/tess-desktop.webp` are optimized campaign illustrations based on the supplied Tess portrait. Their screens are concept art, not captures of the running operating system. The page says so beside the device gallery. `assets/tess-social.jpg` is the share-card copy of the phone portrait. `assets/tess-mark.svg` is the matching small portrait mark used by the header and favicon.

## Build and publish

The dependency-free site builder writes a fresh output directory:

```sh
python3 scripts/build-site.py --output dist/website
python3 -m http.server 8765 --directory dist/website --bind 127.0.0.1
```

The builder refuses to overwrite an existing destination. It copies the page, styling, script, and the Tess portraits, social preview, and portrait mark, then bundles the public release metadata in `project.json`. It does not publish the development VM screenshots as marketing images.

The browser refreshes public release and commit information from the GitHub API. If that request is unavailable, the page’s built-in Alpha 17 release links remain usable. The site uses no accounts, analytics, paid services, or remote fonts.

The Pages workflow rebuilds and deploys from `main`. The site source is `website/`; release files and project documentation remain in the repository and are linked from the page. Changing the website does not rebuild an ISO.
