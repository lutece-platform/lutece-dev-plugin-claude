#!/usr/bin/env bash
# Checks the visual review after `run.sh compare`: the results and captures moved to artifacts/v8/ are found, and the
# review list points at the capture where it lies.
set -u
. "$(dirname "$0")/../../tools/python.sh"
E="$(cd "$(dirname "$0")" && pwd)/../../skills/lutece-e2e"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }
mkdir -p "$T/tools" "$T/tests" "$T/artifacts/v8/results" "$T/artifacts/v8/shots"
cp "$E/tools/review.py" "$T/tools/"; cp "$E/tests/lutece.py" "$T/tests/"
printf 'x' > "$T/artifacts/v8/shots/plugins_demo_ManageThings.jpg"
echo '{"suite": "screens", "id": "s1", "url": "http://x/jsp/admin/plugins/demo/ManageThings.jsp", "kind": "admin", "screenshot": "shots/plugins_demo_ManageThings.jpg"}' > "$T/artifacts/v8/results/screens.jsonl"
printf 'z' > "$T/artifacts/v8/shots/fail_csrf_get_1.jpg"
echo '{"suite": "scenarios", "id": "test_scenario[x-negative.csrf_get]", "url": "http://x/jsp/admin/plugins/demo/ManageThings.jsp?action=remove", "kind": "screen", "screenshot": "shots/fail_csrf_get_1.jpg", "status": "passed", "core_defect": "GET runs the action | step 1"}' >> "$T/artifacts/v8/results/screens.jsonl"
(cd "$T" && python3 tools/review.py todo >/dev/null 2>&1)
check "the failure capture of a core defect scenario is not a review group" '! grep -q fail_csrf_get "$T/artifacts/review-todo.md"'
OUT=$(cd "$T" && python3 tools/review.py check 2>&1); RC=$?
check "the review finds the screens of artifacts/v8 (rc 7, not 'aucun écran')" '[ $RC = 7 ] && ! printf "%s" "$OUT" | grep -q "aucun écran"'
check "the review list points at v8/shots" 'grep -q "v8/shots/plugins_demo_ManageThings.jpg" "$T/artifacts/review-todo.md"'
shots=$(grep -o 'shots: [0-9a-f]*' "$T/artifacts/review-todo.md" | head -1)
printf 'key: other-sources\n%s\n- [x] G001 ok\n' "$shots" > "$T/artifacts/review.md"
(cd "$T" && python3 tools/review.py check >/dev/null 2>&1); RC2=$?
check "a review stays valid on other sources while its captures are the same" '[ -n "$shots" ] && [ $RC2 = 0 ]'
printf 'y' > "$T/artifacts/v8/shots/plugins_demo_ManageThings.jpg"
(cd "$T" && python3 tools/review.py check >/dev/null 2>&1); RC3=$?
check "a changed capture invalidates it" '[ $RC3 = 7 ]'
(cd "$T" && python3 tools/review.py todo >/dev/null 2>&1)
check "the review list names the group whose capture changed since the review" 'grep -q "capture changée depuis la dernière revue" "$T/artifacts/review-todo.md"'
if [ $fail = 0 ]; then echo "PASS: visual review reads the v8 leg of a comparison, stays valid while its captures are unchanged"; else echo "$OUT"; exit 1; fi
