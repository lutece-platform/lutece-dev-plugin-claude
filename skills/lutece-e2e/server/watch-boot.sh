#!/usr/bin/env bash
# Follows a Liberty container's console from a given instant and returns as soon as the outcome is known, instead of
# waiting for a health check to run out: READY on the application started, FAIL on the first line that says the start
# is lost, HANG when the console stays silent.
#   watch-boot.sh <container> [since: docker logs --since value] [quiet seconds, 60]
# Exit 0 READY, 1 FAIL (the line is printed), 2 HANG.
export LC_ALL=C
c=$1; since=${2:-$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)}; quiet=${3:-60}; start=$SECONDS
fatal='CWWKZ0002E|CWWKE0018E|Could not create the Java Virtual Machine|Error: VM option|Unrecognized VM option|LiquibaseRunner failed|Migration failed for changeset|startup failed due to previous errors|DSRA4000E|Exception in thread'
exec 3< <(exec docker logs -f --since "$since" "$c" 2>&1)
reader=$!
trap 'kill $reader 2>/dev/null' EXIT
while true; do
  if ! IFS= read -r -t "$quiet" -u 3 line; then
    [ -n "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null | grep true)" ] || { echo "FAIL $((SECONDS - start))s: the container stopped"; exit 1; }
    echo "HANG: no console line for ${quiet}s after $((SECONDS - start))s"
    exit 2
  fi
  case "$line" in
    *CWWKZ0001I*) echo "READY $((SECONDS - start))s"; exit 0 ;;
  esac
  if [[ "$line" =~ $fatal ]]; then
    echo "FAIL $((SECONDS - start))s: ${line:0:300}"
    exit 1
  fi
done
