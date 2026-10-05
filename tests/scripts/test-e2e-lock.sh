#!/usr/bin/env bash
# Checks the bench lock: a second run is refused while the first lives, a child of the holder runs, the lock is
# released at exit, and a lock left by a dead run is taken over. The holder's exit hook runs however it exits (a failed
# command under set -e included), before the lock is released; a child of the holder never runs it.
set -u
L="$(cd "$(dirname "$0")" && pwd)/../../skills/lutece-e2e/tools/lock.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }
touch "$T/hold"
bash -c ". '$L'; e2e_lock '$T'; while [ -f '$T/hold' ]; do sleep 0.2; done" & holder=$!
until [ -f "$T/.run.lock/pid" ]; do sleep 0.2; done
check "a second run is refused while the first lives" '! bash -c ". '"'$L'"'; e2e_lock '"'$T'"'" 2>/dev/null'
check "the refusal names the holder" 'bash -c ". '"'$L'"'; e2e_lock '"'$T'"'" 2>&1 | grep -q "bench busy"'
check "a child of the holder runs under its lock" 'E2E_LOCK_OWNER=$(cat "$T/.run.lock/pid") bash -c ". '"'$L'"'; e2e_lock '"'$T'"'"'
rm -f "$T/hold"; wait "$holder"
check "the lock is released at exit" '[ ! -d "$T/.run.lock" ]'
mkdir "$T/.run.lock"; echo 999999 > "$T/.run.lock/pid"
check "a lock left by a dead run is taken over" 'bash -c ". '"'$L'"'; e2e_lock '"'$T'"'"'
rm -rf "$T/.run.lock"
bash -c "set -euo pipefail; . '$L'; e2e_lock '$T'; e2e_on_exit() { [ -d '$T/.run.lock' ] && touch '$T/hooked'; }; false | cat; echo unreachable" >/dev/null 2>&1
check "the holder's exit hook runs on a set -e failure, the lock still held" '[ -f "$T/hooked" ]'
check "the lock is released after the hook" '[ ! -d "$T/.run.lock" ]'
rm -f "$T/hooked"; touch "$T/hold"
bash -c ". '$L'; e2e_lock '$T'; while [ -f '$T/hold' ]; do sleep 0.2; done" & holder=$!
until [ -f "$T/.run.lock/pid" ]; do sleep 0.2; done
E2E_LOCK_OWNER=$(cat "$T/.run.lock/pid") bash -c ". '$L'; e2e_lock '$T'; e2e_on_exit() { touch '$T/hooked'; }; exit 0"
check "a child of the holder leaves the hook to the holder" '[ ! -f "$T/hooked" ] && [ -d "$T/.run.lock" ]'
rm -f "$T/hold"; wait "$holder"
if [ $fail = 0 ]; then echo "PASS: bench lock refuses a second run, admits the holder's children, releases, recovers a dead lock, runs the exit hook"; else exit 1; fi
