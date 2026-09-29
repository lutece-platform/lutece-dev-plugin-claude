#!/usr/bin/env bash
# Checks the fuzzer's shield on seeded rows: a delete form aimed at an id of the 9000s is recognised, by the screen, the
# action or a hidden field; a modify form, another id, or a token that happens to hold those digits is not.
set -u
. "$(dirname "$0")/../../tools/python.sh"
E="$(cd "$(dirname "$0")" && pwd)/../../skills/lutece-e2e"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
cp "$E/tests/test_forms.py" "$T/forms_rule.py"
OUT=$(cd "$T" && python3 - <<'PY'
import re, sys, types
lutece = types.ModuleType("lutece")
lutece.rule_re = lambda name, default: re.compile(default)
lutece.ADMIN = ("admin", "adminadmin")
lutece.load_json = lambda path, default: default
lutece.scope = lambda: (lambda u: True)
pytest = types.ModuleType("pytest")
pytest.mark = types.SimpleNamespace(parametrize=lambda *a, **k: (lambda f: f))
sys.modules.update(lutece=lutece, pytest=pytest)
from forms_rule import deletes_seeded as d
cases = [
    (d("jsp/admin/plugins/q/ConfirmRemoveEntry.jsp?entry_id=9001", "jsp/admin/plugins/q/DoRemoveEntry.jsp", "", []), True),
    (d("jsp/admin/plugins/q/ManageQ.jsp?view=manage", "jsp/admin/plugins/q/ManageQ.jsp", "removeEntry", ["9002"]), True),
    (d("jsp/admin/plugins/q/ModifyEntry.jsp?entry_id=9001", "jsp/admin/plugins/q/DoModifyEntry.jsp", "", ["9001"]), False),
    (d("jsp/admin/plugins/q/ConfirmRemoveEntry.jsp?entry_id=12", "jsp/admin/plugins/q/DoRemoveEntry.jsp", "", ["19001"]), False),
    (d("jsp/admin/plugins/q/ConfirmRemoveEntry.jsp?entry_id=12", "jsp/admin/plugins/q/DoRemoveEntry.jsp", "", ["a9123f"]), False),
]
print(" ".join("ok" if got == want else "KO%d" % i for i, (got, want) in enumerate(cases)))
PY
)
case "$OUT" in *KO*|"") echo "FAIL: seed protection $OUT"; exit 1 ;; esac
echo "PASS: the fuzzer never deletes a seeded row, and only those"
