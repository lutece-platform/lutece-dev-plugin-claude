#!/usr/bin/env bash
# Checks that a scenario result carrying core_defect is reported apart, as a core defect not handled, in summary.md
# and report.html, and that a scenario whose core defect is gone asks to drop the key.
set -u
E="$(cd "$(dirname "$0")" && pwd)/../../skills/lutece-e2e"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }
mkdir -p "$T/e2e/artifacts/results" "$T/e2e/tools" "$T/e2e/tests"
cp "$E"/tools/*.py "$T/e2e/tools/"; cp "$E/tests/lutece.py" "$T/e2e/tests/"
printf '%s\n' '{"id":"test_scenario[x_get]","suite":"scenarios","status":"passed","duration_ms":10,"scenario":"x_get","title":"GET forgery","core_defect":"core runs GET actions | step 1 sql: expected 1 got 0"}' \
  '{"id":"test_scenario[y_get]","suite":"scenarios","status":"passed","duration_ms":10,"scenario":"y_get","core_defect_fixed":"core runs GET actions"}' > "$T/e2e/artifacts/results/main.jsonl"
(cd "$T/e2e" && python3 tools/report.py >/dev/null 2>&1)
check "summary lists the core defect apart" 'grep -q "^## Défauts du core (1)" "$T/e2e/artifacts/summary.md" && grep -q "x_get" "$T/e2e/artifacts/summary.md"'
check "summary asks to drop a core_defect the core fixed" 'grep -q "y_get.*retirer \`core_defect\`" "$T/e2e/artifacts/summary.md"'
check "report.html lists it too" 'grep -q "Défauts du core, non traités" "$T/e2e/artifacts/report.html"'
if [ $fail = 0 ]; then echo "PASS: core defects are reported apart, and a fixed one asks to drop its key"; else exit 1; fi
