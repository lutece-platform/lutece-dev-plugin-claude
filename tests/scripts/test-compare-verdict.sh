#!/usr/bin/env bash
# Checks the comparison verdicts: a v7 failure on a view the v7 sources never name is "v8 seulement", not "corrigé";
# a v7 failure on a view v7 knew stays "corrigé"; the v7 and v8 names of one view (viewConfirmX, confirmX, DoX.jsp) pair.
set -u
E="$(cd "$(dirname "$0")" && pwd)/../../skills/lutece-e2e"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/tools" "$T/tests" "$T/artifacts" "$T/harness/src7/src/java/x"
cp "$E/tools/compare.py" "$T/tools/"; cp "$E/tests/lutece.py" "$T/tests/"
printf 'class XJspBean { static final String VIEW_MANAGE = "viewManage"; }\n' > "$T/harness/src7/src/java/x/XJspBean.java"
OUT=$(cd "$T" && python3 - <<'PY'
import sys
sys.path.insert(0, "tools")
import compare
ko = lambda v: {"suite": "screens", "status": "failed", "url": "http://x/jsp/admin/plugins/x/ManageX.jsp?view=" + v}
ok = {"suite": "screens", "status": "passed", "url": "http://x/jsp/admin/plugins/x/ManageX.jsp"}
print(compare.verdict(ko("viewConfirmNew"), ok), "|", compare.verdict(ko("viewManage"), ok), "|",
      len({compare.function("http://x/jsp/admin/plugins/x/" + u)[1] for u in ("ManageX.jsp?view=viewConfirmRemoveX", "ManageX.jsp?view=confirmRemoveX", "DoRemoveX.jsp")}))
PY
)
[ "$OUT" = "v8 seulement | corrigé | 1" ] && { echo "PASS: a view unknown to the v7 sources is v8 only, a known one stays corrigé, v7 and v8 names of a view pair"; exit 0; }
echo "FAIL: compare verdicts: $OUT"; exit 1
