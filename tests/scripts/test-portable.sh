#!/usr/bin/env bash
# Checks portable.sh (version sort, reverse, GNU guard) and scan-project.sh on a native query without named parameters.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
S="$HERE/../../tools"
. "$S/portable.sh"
. "$S/python.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }

check "version sort puts 8.0.10 after 8.0.9" '[ "$(printf "8.0.10\n7.0.5\n8.0.9\n" | lp_version_sort | tr "\n" " ")" = "7.0.5 8.0.9 8.0.10 " ]'
check "version sort reads the version inside a path" '[ "$(printf "/m2/f/2.3.9/f-2.3.9.jar\n/m2/f/2.3.34/f-2.3.34.jar\n" | lp_version_sort | tail -1)" = "/m2/f/2.3.34/f-2.3.34.jar" ]'
check "version sort keeps the floor first when equal" '[ "$(printf "8.0.2\n8.0.2\n" | lp_version_sort | head -1)" = "8.0.2" ]'
check "reverse survives a reader that stops early under pipefail" '(set -o pipefail; seq 1 200000 | lp_reverse | head -1 >/dev/null)'
check "reverse prints the last line first" '[ "$(printf "a\nb\nc\n" | lp_reverse | tr "\n" " ")" = "c b a " ]'

printf '#!/bin/sh\n[ "$1" = --version ] && { echo "sed: illegal option" >&2; exit 1; }\nexec /usr/bin/sed "$@"\n' > "$T/sed"; chmod +x "$T/sed"
mkdir -p "$T/p"
out=$(cd "$T/p" && PATH="$T:$PATH" bash "$S/scan-project.sh" . 2>&1 >/dev/null); rc=$?
check "BSD sed: the scan stops" '[ "$rc" = 2 ]'
check "BSD sed: it says what to install" 'echo "$out" | grep -q "brew install gnu-sed grep"'
check "GNU sed: the guard lets it run" '(cd "$T/p" && bash "$S/scan-project.sh" . >/dev/null 2>&1; [ $? != 2 ])'

P="$T/plugin"; mkdir -p "$P/src/java/x"
printf '<project>\n    <parent>\n        <artifactId>lutece-global-pom</artifactId>\n        <version>8.0.2</version>\n    </parent>\n    <artifactId>plugin-demo</artifactId>\n    <version>1.0.0</version>\n</project>\n' > "$P/pom.xml"
printf 'class A { void f( ) { em.createNativeQuery( "select 1" ); } }\n' > "$P/src/java/x/A.java"
check "scan survives a native query without named parameters" '[ "$(cd "$P" && bash "$S/scan-project.sh" . 2>/dev/null | python3 -c "import json, sys; print(json.load(sys.stdin)[\"summary\"][\"persistence\"][\"namedNativeParams\"])")" = 0 ]'
printf 'class B { void g( ) { em.createNativeQuery( "select * from t where id = :id" ); } }\n' > "$P/src/java/x/B.java"
check "scan still counts a named parameter" '[ "$(cd "$P" && bash "$S/scan-project.sh" . 2>/dev/null | python3 -c "import json, sys; print(json.load(sys.stdin)[\"summary\"][\"persistence\"][\"namedNativeParams\"])")" = 1 ]'
if [ $fail = 0 ]; then echo "PASS: portable.sh sorts versions and reverses like GNU, stops on BSD sed, scan survives native queries"; else exit 1; fi
