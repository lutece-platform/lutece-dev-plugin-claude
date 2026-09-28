#!/usr/bin/env bash
# Checks the verify-edit PostToolUse hook: reports a broken Lutece file with exit 2, stays silent on a clean one and
# outside a Lutece project.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT="$HERE/../.."
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }
run() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" | CLAUDE_PLUGIN_ROOT="$ROOT" bash "$ROOT/hooks/verify-edit" 2>"$T/err"; echo $?; }
mkdir -p "$T/p/src/java" "$T/q"
printf '<project><parent><artifactId>lutece-global-pom</artifactId></parent><artifactId>plugin-x</artifactId></project>\n' > "$T/p/pom.xml"
printf 'package x;\nimport javax.servlet.http.HttpServletRequest;\npublic class Bad {}\n' > "$T/p/src/java/Bad.java"
printf 'package x;\npublic class Good {}\n' > "$T/p/src/java/Good.java"
printf '<project><artifactId>other</artifactId></project>\n' > "$T/q/pom.xml"; cp "$T/p/src/java/Bad.java" "$T/q/Bad.java"
check "a broken Lutece file is handed back (exit 2)" '[ "$(run "$T/p/src/java/Bad.java")" = 2 ] && grep -q "FAIL JX01" "$T/err"'
check "a clean Lutece file is silent" '[ "$(run "$T/p/src/java/Good.java")" = 0 ] && [ ! -s "$T/err" ]'
check "a file outside a Lutece project is silent" '[ "$(run "$T/q/Bad.java")" = 0 ]'
check "a file of another kind is silent" 'echo x > "$T/p/notes.md"; [ "$(run "$T/p/notes.md")" = 0 ]'
if [ $fail = 0 ]; then echo "PASS: verify-edit hands back a broken Lutece file and stays silent otherwise"; else exit 1; fi
