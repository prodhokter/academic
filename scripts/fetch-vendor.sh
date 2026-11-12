#!/usr/bin/env bash
# Clone the third-party skill repositories listed in vendor.ini and write
# vendor/.manifest.json mapping skill name -> absolute path.
set -euo pipefail

kit_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vendor_dir="${1:-$kit_root/vendor}"
ini="$kit_root/vendor.ini"
manifest="$vendor_dir/.manifest.json"

[ -f "$ini" ] || { echo "vendor.ini not found: $ini" >&2; exit 1; }
command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
mkdir -p "$vendor_dir"

python_bin="$(command -v python3 || command -v python)"

"$python_bin" - "$ini" "$vendor_dir" "$manifest" <<'PY'
import configparser, json, os, subprocess, sys
from pathlib import Path

ini, vendor_dir, manifest = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
cp = configparser.ConfigParser()
cp.read(ini, encoding="utf-8")

skills = {}
for name in cp.sections():
    repo = cp[name].get("repo", "").strip()
    commit = cp[name].get("commit", "").strip()
    spec = cp[name].get("skills", "").strip()
    dest = vendor_dir / name
    if not repo:
        continue
    if not (dest / ".git").exists():
        print(f"fetching {name} ...", flush=True)
        subprocess.run(["git", "clone", "--quiet", repo, str(dest)], check=True)
    if commit:
        head = subprocess.run(["git", "-C", str(dest), "rev-parse", "HEAD"],
                              capture_output=True, text=True).stdout.strip()
        if head != commit:
            subprocess.run(["git", "-C", str(dest), "fetch", "--quiet", "origin", commit])
            subprocess.run(["git", "-C", str(dest), "checkout", "--quiet", commit])
    if not spec:
        continue
    for entry in [e.strip() for e in spec.split(",") if e.strip()]:
        if entry.endswith("/*"):
            base = dest / entry[:-2]
            found = [p for p in base.iterdir() if p.is_dir() and (p / "SKILL.md").exists()] if base.is_dir() else []
        elif entry == ".":
            found = [dest] if (dest / "SKILL.md").exists() else []
        else:
            p = dest / entry
            found = [p] if (p / "SKILL.md").exists() else []
        for skill in found:
            skills.setdefault(skill.name, str(skill.resolve()))

manifest.write_text(json.dumps({"skills": skills}, indent=2), encoding="utf-8")
print(f"vendor ready: {len(skills)} skills")
PY
