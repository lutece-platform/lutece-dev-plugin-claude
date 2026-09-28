#!/usr/bin/env bash
# lutece-check.sh — every mechanical check of a Lutece project against Lutece 8, in one pass; changes nothing.
#
#   lutece-check.sh [project_dir]      the findings of this project, per tool, with what to do
#   lutece-check.sh --explain CODE     what a check proves and how to fix what it reports
#
# Runs verify-migration.sh, scan-template-design.py, check-i18n-keys.sh and check-template-parse.sh, keeps their full
# output under <project>/target/checkup/ and prints the findings to act on (FAIL and WARN lines, INFO counted). A v7
# project to migrate and a v8 project are checked the same way. Exit 1 when a tool reports a blocking finding (a FAIL,
# an unresolved i18n key, a template that does not parse), else 0.
set -uo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
if [ "${1:-}" = --explain ]; then
    code="${2:-}"
    [ -n "$code" ] || { echo "usage: lutece-check.sh --explain CODE" >&2; exit 2; }
    grep -E "^\| $code \|" "$S/checks.md" || awk -v c="$code" '
        $0 ~ "^  " c " " { on = 1; print; next }
        on && $0 ~ /^             / { print; next }
        { on = 0 }' "$S/scan-template-design.py" | grep . || echo "no check $code in $S/checks.md nor in the template scanner"
    awk -v c="$code" '
        $0 ~ "^[[:space:]]*# " c "[:, ]" { on = 1 }
        on && $0 !~ /^[[:space:]]*#/ { on = 0 }
        on && $0 ~ /^[[:space:]]*# [A-Z][A-Z0-9]*[0-9][0-9][:, ]/ && $0 !~ "# " c "[:, ]" { on = 0 }
        on { sub(/^[[:space:]]*# ?/, ""); print }' "$S"/*.sh "$S"/*.py 2>/dev/null
    exit 0
fi
ROOT=$(cd "${1:-.}" && pwd)
. "$S/python.sh"
OUT="$ROOT/target/checkup"
mkdir -p "$OUT"
cd "$ROOT" || { echo "checkup: no such directory: $ROOT" >&2; exit 2; }
strip() { sed 's/\x1b\[[0-9;]*m//g'; }
blocking=0

# Runs one tool and keeps its colour-free output.
run() {
    local name=$1; shift
    "$@" > "$OUT/$name.txt" 2>&1
    strip < "$OUT/$name.txt" > "$OUT/$name.clean.txt"
}

run verify bash "$S/verify-migration.sh" .
run scanner python3 "$S/scan-template-design.py" . --flat
run i18n bash "$S/check-i18n-keys.sh" .
run parse bash "$S/check-template-parse.sh" .

echo "== verify-migration"
V="$OUT/verify.clean.txt"
f=$(grep -cE "^\s+FAIL \[" "$V"); w=$(grep -cE "^\s+WARN \[" "$V")
echo "   $f FAIL, $w WARN"
grep -E "^\s+(FAIL|WARN) \[" "$V" | sed 's/^ */   /' | cut -c1-160
[ "$f" -eq 0 ] || blocking=1
grep -q "^RESULT:" "$V" || { echo "   stopped before the end:"; tail -3 "$V" | sed 's/^/   /'; blocking=1; }

echo "== scan-template-design"
C="$OUT/scanner.clean.txt"
w=$(grep -c " WARN " "$C"); i=$(grep -c " INFO " "$C")
echo "   $w WARN, $i INFO"
grep " WARN " "$C" | sed 's/^/   /' | cut -c1-160
[ "$i" -eq 0 ] || grep " INFO " "$C" | awk '{print $2}' | sort | uniq -c | sort -rn | awk '{printf "   INFO %s x%s\n", $2, $1}'
grep -q "scan not performed" "$C" && { grep -A3 "scan not performed" "$C" | sed 's/^/   /'; blocking=1; }

echo "== check-i18n-keys"
I="$OUT/i18n.clean.txt"
line=$(grep "^I18NKEYS" "$I" | tail -1)
echo "   ${line:-no summary line, see $I}"
u=$(echo "$line" | grep -o "unresolved=[0-9]*" | cut -d= -f2)
[ "${u:-1}" -eq 0 ] || { grep -E "unresolved|missing" "$I" | grep -v "^I18NKEYS" | head -10 | sed 's/^/   /'; blocking=1; }

echo "== check-template-parse"
P="$OUT/parse.clean.txt"
line=$(grep "^FMPARSE" "$P" | tail -1)
echo "   ${line:-no summary line, see $P}"
e=$(echo "$line" | grep -o "errors=[0-9]*" | cut -d= -f2)
[ "${e:-1}" -eq 0 ] || { grep -v "^FMPARSE" "$P" | head -10 | sed 's/^/   /'; blocking=1; }

echo "== full outputs: $OUT/{verify,scanner,i18n,parse}.txt; a code explained: $S/lutece-check.sh --explain CODE"
exit $blocking
