#!/usr/bin/env bash
# Checks the memory guard of lpe2e (run.sh mem_guard) on a stand-in /proc/meminfo: enough memory passes at once, too
# little fails with code 12 once E2E_MEM_WAIT is spent, memory coming back during the wait passes, E2E_SEARCH raises
# the default need, E2E_MIN_MEM_MB=0 skips the check.
set -u
R="$(cd "$(dirname "$0")" && pwd)/../../skills/lutece-e2e/run.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then :; else echo "FAIL: $1 (expected '$3', got '$2')"; fail=1; fi; }
sed -n '/^mem_guard() {/,/^}/p' "$R" > "$T/guard.sh"
mem() { printf 'MemTotal:       32000000 kB\nMemAvailable:   %d kB\n' $(($1 * 1024)) > "$T/meminfo"; }
guard() { env LPE2E_MEMINFO="$T/meminfo" "$@" bash -c ". '$T/guard.sh'; (mem_guard) > '$T/out' 2>&1; echo \$?"; }
mem 8000
check "enough memory passes" "$(guard E2E_MEM_WAIT=0)" 0
mem 2000
check "too little memory fails with 12" "$(guard E2E_MEM_WAIT=0)" 12
check "the failure says what is available and needed" "$(grep -c '2000 MB available, 3072 MB needed' "$T/out")" 1
mem 5000
check "a bench with search needs more" "$(guard E2E_MEM_WAIT=0 E2E_SEARCH=1)" 12
check "E2E_MIN_MEM_MB=0 skips the check" "$(guard E2E_MEM_WAIT=0 E2E_SEARCH=1 E2E_MIN_MEM_MB=0)" 0
mem 1000
s=$SECONDS
check "the wait is bounded" "$(guard E2E_MEM_WAIT=5)" 12
check "it ends within the wait" "$([ $((SECONDS - s)) -le 8 ] && echo yes)" yes
( sleep 2; mem 9000 ) &
check "memory coming back during the wait passes" "$(guard E2E_MEM_WAIT=30)" 0
wait
if [ $fail = 0 ]; then echo "PASS: lpe2e raises a bench only with the memory it needs, waits a bounded time, fails with 12"; else exit 1; fi
