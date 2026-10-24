# Tessarchy website

The public site introduces Tessa through Tess, shown holding a phone, tablet, and laptop against the default mint-aurora wallpaper. The device scenes are illustrative compositions; each display uses a real Tessa development capture. They do not claim physical hardware support. The Alpha 17 release section links its separate BIOS and UEFI boot evidence.

The site icon and header mark use the original tessellated T cube from `shell/artwork/tessarchy-mark.svg`.

The [Hermes terminal guide](terminal-guide.html) covers Hermes Agent profiles and its built-in Kanban workflow. It distinguishes that board from Tessarchy's separate read-only issue queue in `docs/agent-kanban.md`.

## Build and publish

The dependency-free builder writes a fresh output directory:

```sh
python3 scripts/build-site.py --output dist/website
python3 -m http.server 8765 --directory dist/website --bind 127.0.0.1
```

The builder refuses to overwrite an existing destination. It copies both pages, styling, script, canonical T cube, three Tess device scenes, and their real screen captures into the static output. It bundles public release metadata in `project.json`.

The browser refreshes public release and commit information from the GitHub API. If that request is unavailable, the built-in Alpha 17 links remain usable. The site uses no accounts, analytics, paid services, or remote fonts.

The Pages workflow rebuilds and deploys from `main`. Release files and project documentation stay in the repository and are linked from the page. Website changes do not rebuild an ISO.
