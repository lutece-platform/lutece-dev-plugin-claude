#!/usr/bin/env bash
# Checks that lutece-check.sh reports a broken template as blocking (exit 1) with its parse error, and a scanner that could not run.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/webapp/WEB-INF/templates/admin/plugins/x"
echo "<@pageContainer><#if></@pageContainer>" > "$T/webapp/WEB-INF/templates/admin/plugins/x/a.html"
if ls "$HOME"/.m2*/repository/org/freemarker/freemarker/2.3.*/freemarker-2.3.*.jar >/dev/null 2>&1; then
    OUT=$(bash "$HERE/../../tools/lutece-check.sh" "$T" 2>&1); RC=$?
    if ! { [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "errors=1" && echo "$OUT" | grep -q "PARSE_ERROR"; }; then
        echo "FAIL: expected rc=1 and a parse error; got rc=$RC"; echo "$OUT"; exit 1
    fi
    echo "PASS: checkup reports a broken template as blocking"
else
    echo "SKIP: no freemarker jar in ~/.m2, the template parse case is not run (build a Lutece 8 project once)"
fi
OUT=$(LP_PYTHON= bash "$HERE/../../tools/lutece-check.sh" "$T" 2>&1); RC=$?
SCAN=$(echo "$OUT" | sed -n '/^== scan-template-design/,/^== check-i18n-keys/p')
if [ "$RC" -eq 1 ] && echo "$SCAN" | grep -q "stopped before the end" && echo "$SCAN" | grep -q "no working Python"; then
    echo "PASS: checkup reports a scanner that could not run"; exit 0
fi
echo "FAIL: expected the scanner reported as stopped without Python; got rc=$RC"; echo "$OUT"; exit 1
