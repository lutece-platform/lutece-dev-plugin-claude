#!/usr/bin/env bash
# Runs the test scripts AGENTS.md lists, or the share of them one CI job owns, and prints the log of each failure.
# Usage: ci-tests.sh [shard] [shards]    (0 1 runs them all)
# CI_JOBS=n runs n tests at a time (default: half the cores), the slowest known first; CI_JOBS=1 runs them one by one.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARD=${1:-0}
SHARDS=${2:-1}
JOBS=${CI_JOBS:-$(( $(nproc 2>/dev/null || echo 2) / 2 ))}
[ "$JOBS" -ge 1 ] || JOBS=1
TIMES="${XDG_CACHE_HOME:-$HOME/.cache}/lutecepowers/ci-times"
LOGS=$(mktemp -d)
export LOGS
cd "$ROOT" || exit 2
mkdir -p "$(dirname "$TIMES")"; touch "$TIMES"

# Runs one test script, prints PASS or FAIL with its duration, keeps its log and its duration for the next ordering.
one() {
  local t=$1 n s
  n=$(basename "$t" .sh); s=$SECONDS
  if bash "$t" > "$LOGS/$n.log" 2>&1; then echo "PASS $n ($((SECONDS - s))s)"; else echo "FAIL $n ($((SECONDS - s))s)"; : > "$LOGS/$n.failed"; fi
  echo "$n $((SECONDS - s))" > "$LOGS/$n.time"
}
export -f one

i=0
mine=()
while read -r t; do
  [ $((i % SHARDS)) -eq "$SHARD" ] && mine+=("$t")
  i=$((i + 1))
done < <(sed -n 's/^bash \(tests\/[^ ]*\.sh\)$/\1/p' AGENTS.md)

for t in "${mine[@]}"; do
  printf '%s %s\n' "$(awk -v n="$(basename "$t" .sh)" '$1 == n {print $2}' "$TIMES" | tail -1 | grep . || echo 0)" "$t"
done | sort -rn | cut -d' ' -f2 | xargs -P "$JOBS" -I{} bash -c 'one "$@"' _ {}

failed=0
for f in "$LOGS"/*.failed; do
  [ -e "$f" ] || continue
  n=$(basename "$f" .failed); echo "::group::$n"; cat "$LOGS/$n.log"; echo "::endgroup::"; failed=1
done
cat "$LOGS"/*.time "$TIMES" 2>/dev/null | awk '!seen[$1]++' > "$TIMES.tmp" && mv "$TIMES.tmp" "$TIMES"
exit $failed
