# One run at a time per bench: two runs share the same containers, database and artifacts and corrupt each other.

# Takes the bench lock <e2e dir>/.run.lock for this process, or exits 2 when a live run holds it.
# A child of the holder (E2E_LOCK_OWNER set to the holder's pid) runs under the holder's lock.
e2e_lock() {
  local dir="$1/.run.lock" pid
  if [ -n "${E2E_LOCK_OWNER:-}" ] && [ "$(cat "$dir/pid" 2>/dev/null)" = "$E2E_LOCK_OWNER" ]; then
    return 0
  fi
  mkdir -p "$1"
  if ! mkdir "$dir" 2>/dev/null; then
    pid=$(cat "$dir/pid" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "bench busy: another run holds $dir (pid $pid, started $(cat "$dir/started" 2>/dev/null)): $(cat "$dir/cmd" 2>/dev/null)" >&2
      echo "wait for it to end, or stop it; never start a second run on the same bench" >&2
      exit 2
    fi
    rm -rf "$dir"
    mkdir "$dir" || { echo "cannot take the bench lock $dir" >&2; exit 2; }
  fi
  echo "$$" > "$dir/pid"; date '+%F %T' > "$dir/started"; echo "${E2E_LOCK_CMD:-$0 $*}" > "$dir/cmd"
  export E2E_LOCK_OWNER=$$
  trap 'rm -rf "'"$dir"'"' EXIT
}
