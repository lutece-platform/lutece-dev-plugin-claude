#!/usr/bin/env bash
# Bumps or checks the plugin version across every manifest declared in .version-bump.json.
# Usage: bump-version.sh <X.Y.Z> | --check

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tools/python.sh"

# Writes the given version, if any, into every declared manifest, then prints every declared version; fails on drift.
versions() {
  python3 - "$ROOT" "$1" <<'PY'
import json, os, re, sys
root, new = sys.argv[1], sys.argv[2]
files = json.load(open(os.path.join(root, ".version-bump.json"), encoding="utf-8"))["files"]
keys = lambda field: [k for k in field.split(".") if k]
if new:
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.]+)?", new):
        sys.exit("expected X.Y.Z, got '%s'" % new)
    for entry in files:
        path = os.path.join(root, entry["path"])
        data = json.load(open(path, encoding="utf-8"))
        *parents, last = keys(entry["field"])
        node = data
        for k in parents:
            node = node[k]
        node[last] = new
        with open(path, "w", encoding="utf-8", newline="\n") as out:
            out.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
        print("  %s -> %s" % (entry["path"], new))
found = []
for entry in files:
    node = json.load(open(os.path.join(root, entry["path"]), encoding="utf-8"))
    for k in keys(entry["field"]):
        node = node[k]
    print("  %-40s %s" % (entry["path"], node))
    found.append(node)
if len(set(found)) == 1:
    print("All manifests at %s" % found[0])
else:
    print("DRIFT: versions differ")
    sys.exit(1)
PY
}

case "${1:-}" in
  --check) versions "" ;;
  ""|-h|--help) echo "Usage: bump-version.sh <X.Y.Z> | --check" ;;
  *) versions "$1" ;;
esac
