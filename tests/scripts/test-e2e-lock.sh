#!/usr/bin/env bash
# Checks the bench lock: a second run is refused while the first lives, a child of the holder runs, the lock is
# released at exit, and a lock left by a dead run is taken over.
set -u
L="$(cd "$(dirname "$0")" && pwd)/../../skills/lutece-e2e/tools/lock.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }
bash -c ". '$L'; e2e_lock '$T'; sleep 3" & holder=$!
sleep 1
check "a second run is refused while the first lives" '! bash -c ". '"'$L'"'; e2e_lock '"'$T'"'" 2>/dev/null'
check "the refusal names the holder" 'bash -c ". '"'$L'"'; e2e_lock '"'$T'"'" 2>&1 | grep -q "bench busy"'
check "a child of the holder runs under its lock" 'E2E_LOCK_OWNER=$(cat "$T/.run.lock/pid") bash -c ". '"'$L'"'; e2e_lock '"'$T'"'"'
wait "$holder"
check "the lock is released at exit" '[ ! -d "$T/.run.lock" ]'
mkdir "$T/.run.lock"; echo 999999 > "$T/.run.lock/pid"
check "a lock left by a dead run is taken over" 'bash -c ". '"'$L'"'; e2e_lock '"'$T'"'"'
if [ $fail = 0 ]; then echo "PASS: bench lock refuses a second run, admits the holder's children, releases, recovers a dead lock"; else exit 1; fi
