#!/usr/bin/env bash
# Checks that dep-digest.py follows the content of a site's Lutece dependencies in the local repository: a jar rebuilt
# with the same name and the same date changes the digest, the artefact under test and a jar the repository does not
# hold do not count.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
D="$HERE/../../skills/lutece-e2e/tools/dep-digest.py"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0
export M2_REPO="$T/m2"
dep="$M2_REPO/fr/paris/lutece/plugins/plugin-dep/1.0.1-SNAPSHOT"
own="$M2_REPO/fr/paris/lutece/plugins/module-own/1.0.0-SNAPSHOT"
mkdir -p "$dep" "$own" "$T/site/WEB-INF/lib"
printf 'v1' > "$dep/plugin-dep-1.0.1-SNAPSHOT.jar"; printf 'w1' > "$dep/plugin-dep-1.0.1-SNAPSHOT-webapp.zip"
printf 'o1' > "$own/module-own-1.0.0-SNAPSHOT.jar"
for j in plugin-dep-1.0.1-SNAPSHOT.jar module-own-1.0.0-SNAPSHOT.jar commons-lang3-3.17.0.jar; do printf x > "$T/site/WEB-INF/lib/$j"; done
digest() { python3 "$D" "$T/site" module-own; }
a=$(digest)
printf 'o2' > "$own/module-own-1.0.0-SNAPSHOT.jar"
[ "$(digest)" = "$a" ] || { echo "FAIL: the artefact under test changes the digest"; fails=$((fails + 1)); }
touch -r "$dep/plugin-dep-1.0.1-SNAPSHOT.jar" "$T/date"; printf 'v2' > "$dep/plugin-dep-1.0.1-SNAPSHOT.jar"; touch -r "$T/date" "$dep/plugin-dep-1.0.1-SNAPSHOT.jar"
b=$(digest)
[ "$b" != "$a" ] || { echo "FAIL: a dependency rebuilt with the same date does not change the digest"; fails=$((fails + 1)); }
printf 'w2' > "$dep/plugin-dep-1.0.1-SNAPSHOT-webapp.zip"
[ "$(digest)" != "$b" ] || { echo "FAIL: a dependency's webapp zip does not change the digest"; fails=$((fails + 1)); }
[ "$fails" -eq 0 ] && { echo "PASS: dep-digest follows the content of the site's Lutece dependencies (jar and webapp zip, whatever their date), not the artefact under test"; exit 0; }
exit 1
