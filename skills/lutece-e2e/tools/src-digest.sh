#!/usr/bin/env bash
# Prints the digest of an artefact's sources: its folder and the content of src/, webapp/ and pom.xml. The bench
# rebuilds when it differs from the one recorded at the last build: file dates cannot tell, since two checkouts of one
# artefact (a develop worktree and a branch) share the same bench, and a checkout keeps older dates than that build.
#
#   src-digest.sh <artefact folder>
set -euo pipefail
src=$(cd "$1" && pwd -P)
cd "$src"
parts=(); for p in src webapp pom.xml; do [ -e "$p" ] && parts+=("$p"); done
{
  printf '%s\n' "$src"
  [ ${#parts[@]} -eq 0 ] || find "${parts[@]}" -type f -not -path '*/target/*' -print0 | LC_ALL=C sort -z | xargs -0 -r sha1sum
} | sha1sum | cut -d' ' -f1
