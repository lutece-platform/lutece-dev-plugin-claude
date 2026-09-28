#!/bin/bash
# restore-line-endings.sh — Restore the line endings a file had before the migration.
# Usage: bash restore-line-endings.sh [project_root]
#
# An editor that saves in the other convention rewrites every line of the file: the diff then shows the whole
# file and the migration is invisible in it, so the review cannot happen. This restores the endings HEAD has,
# on every changed file whose endings moved (verify-migration.sh, check LE01), and leaves the content alone.

set -uo pipefail
cd "${1:-.}" || exit 1
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git work tree"; exit 2; }

# Same rule as LE01: the file counts as converted when the style of HEAD (CRLF or LF) differs from the work tree's,
# a mixed work tree included, whatever else changed in it. The content is left alone, only the endings move.
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
git diff HEAD --name-only --diff-filter=M > "$TMP/files"

# Prints the line-ending style of stdin: CRLF, LF, CR, mixed or none.
line_endings() {
    python3 -c 'import sys
d = sys.stdin.buffer.read()
crlf = d.count(b"\r\n"); cr = d.count(b"\r") - crlf; lf = d.count(b"\n") - crlf
kinds = [k for k, n in (("CRLF", crlf), ("CR", cr), ("LF", lf)) if n]
print(kinds[0] if len(kinds) == 1 else ("mixed" if kinds else "none"))'
}

N=0
while read -r f; do
    [ -f "$f" ] || continue
    head_le=$(git show "HEAD:$f" 2>/dev/null | head -c 20000 | line_endings)
    work_le=$(head -c 20000 "$f" | line_endings)
    { [ "$head_le" = "$work_le" ] || [ "$work_le" = "none" ]; } && continue
    if [ "$head_le" = "CRLF" ]; then
        perl -pi -e 's/\r?\n/\r\n/' "$f"; N=$((N+1)); echo "  $work_le -> CRLF  $f"
    elif [ "$head_le" = "LF" ]; then
        perl -pi -e 's/\r\n/\n/' "$f"; N=$((N+1)); echo "  $work_le -> LF  $f"
    fi
done < "$TMP/files"
echo "$N file(s) restored — run verify-migration.sh again, LE01 must pass"
