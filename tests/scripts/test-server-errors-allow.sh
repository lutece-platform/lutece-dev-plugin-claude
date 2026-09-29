#!/usr/bin/env bash
# Checks the run's server-error gate (metrics.py): an allowlist pattern matched on the stack of an entry, not only its
# first line, and a scenario's server_log_allow, both clear the entry; an error nothing allows stays unexpected.
set -u
. "$(dirname "$0")/../../tools/python.sh"
E="$(cd "$(dirname "$0")" && pwd)/../../skills/lutece-e2e"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/tools" "$T/tests" "$T/scenarios" "$T/harness" "$T/artifacts/logs"
cp "$E/tools/metrics.py" "$T/tools/"; cp "$E/tests/lutece.py" "$T/tests/"
echo '{"surface": {"package": "fr.paris.lutece.plugins.demo"}}' > "$T/artifacts/inventory.json"
printf 'Refused on purpose by the negative scenarios\nInvalid security token for action: removeDemo\n' > "$T/harness/server-errors-allow.txt"
printf 'scenarios:\n  - id: x\n    server_log_allow:\n      - "DemoProvokedException"\n    steps: []\n' > "$T/scenarios/demo.yaml"
{
  printf '[9/26/26, 22:17:24:431 UTC] 0000006a lutece.security   E A servlet exception occurred\n'
  printf 'jakarta.servlet.ServletException: Invalid security token for action: removeDemo\n\tat fr.paris.lutece.plugins.demo.web.DemoJspBean.x(DemoJspBean.java:1)\n'
  printf '[9/26/26, 22:17:25:431 UTC] 0000006a lutece.app   E Demo failure\n'
  printf 'fr.paris.lutece.plugins.demo.DemoProvokedException: on purpose\n\tat fr.paris.lutece.plugins.demo.web.DemoJspBean.y(DemoJspBean.java:2)\n'
  printf '[9/26/26, 22:17:26:431 UTC] 0000006a lutece.app   E Real failure\n'
  printf 'java.lang.NullPointerException\n\tat fr.paris.lutece.plugins.demo.web.DemoJspBean.z(DemoJspBean.java:3)\n'
} > "$T/artifacts/logs/messages.log"
OUT=$(cd "$T" && python3 -c "import sys; sys.path[:0] = ['tools', 'tests']; import metrics; r = metrics.server_errors(); print(r['unexpected_total'], [u['msg'] for u in r['unexpected']])")
[ "$OUT" = "1 ['Real failure']" ] && { echo "PASS: the server-error gate reads the whole entry and the scenarios' server_log_allow"; exit 0; }
echo "FAIL: server errors: $OUT"; exit 1
