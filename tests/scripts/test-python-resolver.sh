#!/usr/bin/env bash
# Checks python.sh and py.sh: the Windows Store alias, a too old Python and a missing Python are handled, and a real script runs.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
S="$HERE/../../tools"
REAL=$(command -v python3)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }
stub() { printf '#!/bin/sh\necho "Python was not found; run without arguments to install from the Microsoft Store" >&2\nexit 49\n' > "$1"; chmod +x "$1"; }

STORE="$T/store"; mkdir -p "$STORE"; stub "$STORE/python3"; ln -s "$REAL" "$STORE/python"
check "store alias skipped, python used" '[ "$(env -u LP_PYTHON PATH="$STORE:$PATH" bash "$S/py.sh" -c "print(6*7)")" = 42 ]'
check "sourced python3 runs the fallback" '[ "$(env -u LP_PYTHON PATH="$STORE:$PATH" bash -c ". \"$S/python.sh\"; python3 -c \"print(1)\"")" = 1 ]'

OLD="$T/old"; mkdir -p "$OLD"; printf '#!/bin/sh\necho /usr/bin/python3.6; exit 3\n' > "$OLD/python3"; chmod +x "$OLD/python3"; ln -s "$REAL" "$OLD/python"
check "python older than 3.9 skipped" '[ "$(env -u LP_PYTHON PATH="$OLD:$PATH" bash "$S/py.sh" -c "print(2)")" = 2 ]'

NONE="$T/none"; mkdir -p "$NONE"; stub "$NONE/python3"; stub "$NONE/python"; stub "$NONE/py"
out=$(env -u LP_PYTHON PATH="$NONE:$PATH" bash "$S/py.sh" -c "print(3)" 2>&1); rc=$?
check "no Python: exit 127" '[ "$rc" = 127 ]'
check "no Python: says what to do" 'echo "$out" | grep -q "python.org (not the Microsoft Store)"'
check "no Python: verify-migration stops instead of passing" '(cd "$T" && env -u LP_PYTHON PATH="$NONE:$PATH" bash "$S/verify-migration.sh" . >/dev/null 2>&1); [ $? = 2 ]'
check "LUTECEPOWERS_PYTHON forces the interpreter" '[ "$(env -u LP_PYTHON PATH="$NONE:$PATH" LUTECEPOWERS_PYTHON="$REAL" bash "$S/py.sh" -c "print(4)")" = 4 ]'

P="$T/project"; mkdir -p "$P/webapp/WEB-INF/conf/plugins" "$P/src/java/x"
echo '<beans/>' > "$P/webapp/WEB-INF/conf/plugins/demo_context.xml"
normal=$(cd "$P" && env -u LP_PYTHON bash "$S/verify-migration.sh" . 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^\s+(PASS|FAIL|WARN) ' | sort)
store=$(cd "$P" && env -u LP_PYTHON PATH="$STORE:$PATH" bash "$S/verify-migration.sh" . 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^\s+(PASS|FAIL|WARN) ' | sort)
check "verify-migration gives the same report behind the store alias" '[ -n "$normal" ] && [ "$normal" = "$store" ]'
check "verify-migration still finds the context file behind the store alias" 'echo "$store" | grep -q "FAIL \[SP03\]"'
if [ $fail = 0 ]; then echo "PASS: python.sh skips the Store alias and old Pythons, explains a missing one, scripts run behind it"; else exit 1; fi
