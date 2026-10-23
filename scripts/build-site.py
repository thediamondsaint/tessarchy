#!/usr/bin/env python3
"""Build the dependency-free GitHub Pages site from repo assets; refuse overwrite."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SITE_ART = ("tess-mark.svg", "tess-phone.webp", "tess-tablet.webp", "tess-desktop.webp", "tess-social.jpg")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--releases", type=Path, help="Optional public GitHub releases JSON")
    args = parser.parse_args()
    output = args.output.absolute()
    if output.exists() or output.is_symlink():
        parser.error(f"Refusing existing output: {output}")
    sources = [ROOT / "website/assets" / name for name in SITE_ART]
    for path in sources:
        if not path.is_file():
            parser.error(f"Missing site artwork: {path}")
    releases = json.loads(args.releases.read_text()) if args.releases else []
    release = next((item for item in releases if not item.get("draft") and any(
        asset.get("name", "").endswith(".iso") or ".iso.part" in asset.get("name", "")
        for asset in item.get("assets", []))), None)
    commit = "source-snapshot"
    if shutil.which("git"):
        result = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                capture_output=True, text=True)
        if result.returncode == 0:
            commit = result.stdout.strip()
    output.mkdir(parents=True)
    for name in ("index.html", "style.css", "app.js"):
        source = ROOT / "website" / name
        shutil.copyfile(source, output / name)
    assets = output / "assets"
    assets.mkdir()
    for source in sources:
        shutil.copyfile(source, assets / source.name)
    (output / "project.json").write_text(json.dumps({"commit": commit, "release": release}) + "\n")
    (output / ".nojekyll").touch()
    print(f"Built {output} from {commit[:7]}")


if __name__ == "__main__":
    main()
