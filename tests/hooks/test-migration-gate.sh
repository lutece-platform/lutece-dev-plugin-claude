#!/usr/bin/env bash
# Checks the migration-gate Stop hook: silent without marker, blocks on a red gate, never removes the marker itself.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
HOOK="$HERE/../../hooks/migration-gate"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }
G="$T/root/tools"; mkdir -p "$G" "$T/p"
gate() { printf '#!/bin/bash\nexit %s\n' "$1" > "$G/final-gate.sh"; chmod +x "$G/final-gate.sh"; }
run() { (cd "$T/p" && CLAUDE_PLUGIN_ROOT="$T/root" bash "$HOOK" </dev/null >/dev/null 2>&1); echo $?; }
gate 1
check "no marker: the turn ends" '[ "$(run)" = 0 ]'
mkdir -p "$T/p/.migration" && touch "$T/p/.migration/gate-required"
check "marker and red gate: the stop is blocked" '[ "$(run)" = 2 ]'
check "second stop within two minutes: let through" '[ "$(run)" = 0 ]'
rm -f "$T/p/.migration/.gate-ran"; gate 0
check "green gate without e2e: the turn ends" '[ "$(run)" = 0 ]'
check "green gate without e2e: the marker stays" '[ -f "$T/p/.migration/gate-required" ]'
rm -f "$T/p/.migration/.gate-ran"; gate 1
mkdir -p "$T/p/e2e/.run.lock"; sleep 30 & echo $! > "$T/p/e2e/.run.lock/pid"
check "a run holding the bench lock: the turn ends while it works" '[ "$(run)" = 0 ]'
kill %1 2>/dev/null; rm -rf "$T/p/e2e/.run.lock"
check "the lock released: a red gate blocks again" '[ "$(run)" = 2 ]'
if [ $fail = 0 ]; then echo "PASS: migration-gate blocks on red, lets the turn end while a run holds the bench lock, keeps the marker until the full gate removes it"; else exit 1; fi
