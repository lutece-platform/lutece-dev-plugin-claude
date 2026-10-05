#!/usr/bin/env bash
# Writes the e2e configuration of a Lutece project from this skill: e2e/e2e.conf, the scenario skeletons, the
# fixtures, the bench's own files (harness/app.env, harness/server-errors-allow.txt, harness/db/, harness/site/webapp/).
# The bench code is not copied: it stays in lutecepowers and runs through lpe2e on the machine's shared e2e server.
#
#   init-e2e.sh <project-dir> [--target plugin|site] [--name <bench-name>]
#
# Idempotent: never touches an existing e2e.conf, scenario, seed or bench file; e2e/ is added to the project's
# .gitignore (the bench is local, never committed with the project).
set -euo pipefail
SKILL="$(cd "$(dirname "$0")/.." && pwd)"
DIR=""; TARGET=""; NAME=""
while [ $# -gt 0 ]; do case "$1" in
  --target) TARGET="$2"; shift 2;;
  --name) NAME="$2"; shift 2;;
  -*) echo "unknown option $1" >&2; exit 2;;
  *) DIR="$1"; shift;;
esac; done
[ -n "$DIR" ] && [ -f "$DIR/pom.xml" ] || { echo "usage: init-e2e.sh <project-dir with pom.xml> [--target plugin|site] [--name <bench-name>]" >&2; exit 2; }
DIR=$(cd "$DIR" && pwd)
PACKAGING=$(grep -oE "<packaging>[^<]+" "$DIR/pom.xml" | head -1 | sed 's/<packaging>//')
if [ -z "$TARGET" ]; then
  case "$PACKAGING" in
    lutece-plugin|lutece-module|lutece-library) TARGET=plugin;;
    lutece-core) TARGET=core;;
    lutece-site) TARGET=site;;
    *) echo "cannot infer the target from packaging '$PACKAGING', pass --target" >&2; exit 2;;
  esac
fi
[ "$TARGET" != core ] || echo "warning: E2E_TARGET=$TARGET is not supported: lpe2e refuses it" >&2
ARTIFACT=$(grep -oE "<artifactId>[^<]+" "$DIR/pom.xml" | sed -n 2p | sed 's/<artifactId>//')
[ -n "$ARTIFACT" ] || ARTIFACT=$(basename "$DIR")
NAME=${NAME:-"lutece-${ARTIFACT#plugin-}-e2e"}
E2E="$DIR/e2e"
mkdir -p "$E2E"/{harness/db,harness/site/webapp,scenarios,fixtures,baselines/aria,artifacts}
. "$SKILL/tools/lock.sh"
E2E_LOCK_CMD="init-e2e.sh" e2e_lock "$E2E"
[ -f "$E2E/e2e.conf" ] && CONF_KEPT=1
[ -f "$E2E/e2e.conf" ] || sed -e "s/@@TARGET@@/$TARGET/" -e "s/@@NAME@@/$NAME/" "$SKILL/templates/e2e.conf.tpl" > "$E2E/e2e.conf"
[ -f "$E2E/harness/app.env" ] || cp "$SKILL/harness/app.env" "$E2E/harness/app.env"
[ -f "$E2E/harness/server-errors-allow.txt" ] || cp "$SKILL/harness/server-errors-allow.txt" "$E2E/harness/server-errors-allow.txt"
if [ -z "$(ls -A "$E2E/scenarios" 2>/dev/null)" ]; then
  # Copied as .example on purpose: the runner collects scenarios/*.yaml, and an untouched example is a red test
  # that says nothing. Write the bench's own file beside it, then delete this one.
  cp "$SKILL/templates/scenarios-example.yaml" "$E2E/scenarios/${ARTIFACT#plugin-}.yaml.example"
  cp "$SKILL/templates/scenarios-negative-example.yaml" "$E2E/scenarios/${ARTIFACT#plugin-}-negative.yaml.example"
  cp "$SKILL/templates/screens.yaml" "$E2E/scenarios/screens.yaml"
  printf '# Inventory elements the bench cannot reach, each with a written reason (read by tools/coverage.py).\nexclusions: []\n' > "$E2E/scenarios/coverage-exclusions.yaml"
fi
cp -n "$SKILL/templates/fixtures/"* "$E2E/fixtures/" 2>/dev/null || true
[ -f "$E2E/README.md" ] || sed "s/@@NAME@@/$ARTIFACT/g" "$SKILL/templates/README.md.tpl" > "$E2E/README.md"
# The bench is a local tool, never committed with the plugin: ignore the whole folder at the project root
# (idempotent; a .gitignore that does not end with a newline would glue the entry to its last line). Same for
# java.io.tmpdir/: the unit tests of a v8 project create it at the project root.
if [ -d "$DIR/.git" ] || git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  [ -s "$DIR/.gitignore" ] && [ -n "$(tail -c1 "$DIR/.gitignore")" ] && echo >> "$DIR/.gitignore"
  for entry in "e2e/" "java.io.tmpdir/"; do
    grep -qxF "$entry" "$DIR/.gitignore" 2>/dev/null || echo "$entry" >> "$DIR/.gitignore"
  done
fi
if [ -n "${CONF_KEPT:-}" ]; then
  echo "e2e configuration kept in $E2E (bench $(sed -n 's/^E2E_NAME=//p' "$E2E/e2e.conf"))"
else
  echo "e2e configuration written in $E2E (target=$TARGET, bench=$NAME)"
fi
echo "next: edit e2e/e2e.conf (plugins to assemble, plugins to enable), then run the bench: $SKILL/lpe2e (from the project)"
