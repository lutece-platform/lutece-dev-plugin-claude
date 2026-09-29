#!/usr/bin/env bash
# Runs the test scripts AGENTS.md lists, or the share of them one CI job owns, and prints the log of each failure.
# Usage: ci-tests.sh [shard] [shards]    (0 1 runs them all)

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARD=${1:-0}
SHARDS=${2:-1}
LOGS=$(mktemp -d)
cd "$ROOT" || exit 2
failed=0
i=0
while read -r t; do
  if [ $((i % SHARDS)) -eq "$SHARD" ]; then
    n=$(basename "$t" .sh); s=$SECONDS
    if bash "$t" > "$LOGS/$n.log" 2>&1; then
      echo "PASS $n ($((SECONDS - s))s)"
    else
      echo "FAIL $n ($((SECONDS - s))s)"; echo "::group::$n"; cat "$LOGS/$n.log"; echo "::endgroup::"; failed=1
    fi
  fi
  i=$((i + 1))
done < <(sed -n 's/^bash \(tests\/[^ ]*\.sh\)$/\1/p' AGENTS.md)
exit $failed
