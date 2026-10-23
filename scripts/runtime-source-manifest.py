#!/usr/bin/env python3
"""Create the content manifest shared by the shell and session packages."""
import argparse
import hashlib
import json
from pathlib import Path


PAYLOADS = ("shell", "session", "themes")


def create_manifest(root: Path, commit: str) -> dict:
    files = []
    for name in PAYLOADS:
        base = root / name
        if not base.is_dir() or base.is_symlink():
            raise ValueError(f"required runtime source directory is missing: {name}")
        for path in sorted(base.rglob("*")):
            if path.is_dir():
                continue
            if path.is_symlink() or not path.is_file():
                raise ValueError(f"runtime source must contain regular files only: {path}")
            relative = path.relative_to(root).as_posix()
            if "__pycache__" in path.parts or path.suffix in {".pyc", ".pyo"}:
                continue
            files.append({
                "path": relative,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "executable": bool(path.stat().st_mode & 0o111),
            })
    files.sort(key=lambda entry: entry["path"])
    return {"schema": 1, "commit": commit, "files": files}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    manifest = create_manifest(args.root, args.commit)
    args.output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"runtime source manifest: {len(manifest['files'])} files at {args.commit}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
