#!/usr/bin/env bash
# Checks the cross-references of the prose: every `file.md` §N points at a file of the plugin holding a "## N." section,
# and no text points at a numbered section of a skill.
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
bad=$(cd "$R" && python3 - <<'EOF2'
import glob, os, re
files = [f for f in glob.glob("**/*.md", recursive=True) if not f.startswith(("rules-cursor/", "node_modules/"))]
by_name = {}
for f in files:
    by_name.setdefault(os.path.basename(f), []).append(f)
out = []
for f in files:
    text = open(f, errors="replace").read()
    for m in re.finditer(r"`(?:\$\{PATTERNS\}/)?([\w-]+\.md)`\s*§\s*(\d+)", text):
        name, n = m.group(1), m.group(2)
        targets = by_name.get(name, [])
        if not targets:
            out.append("%s: %s §%s, no such file" % (f, name, n))
        elif not any(re.search(r"(?m)^#{2,3} %s\." % n, open(t, errors="replace").read()) for t in targets):
            out.append("%s: %s §%s, no such section" % (f, name, n))
    for m in re.finditer(r"`/?[\w-]+`\s+skill\s+§\s*\d+|`/[\w-]+`\s*§\s*\d+", text):
        out.append("%s: %s, skills have no numbered sections" % (f, m.group(0)))
print("\n".join(out))
EOF2
)
[ -z "$bad" ] && { echo "PASS: every § reference of the prose points at an existing section"; exit 0; }
echo "$bad" | sed 's/^/FAIL: /'; exit 1
