#!/usr/bin/env bash
# Checks source-key.py: stable across touch, build output, bench artifacts and the project's own jar; changed by a
# source edit and a bench scenario edit; of the local repository, only the copies of the jars the bench site carries
# count: another artefact, or another version of a carried one, installed or downloaded leaves the key.
set -u
. "$(dirname "$0")/../../tools/python.sh"
K="$(cd "$(dirname "$0")" && pwd)/../../skills/lutece-e2e/tools/source-key.py"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }
P="$T/p"; M="$T/m2"; export M2_REPO="$M" LUTECEPOWERS_E2E_HOME="$T/home"; unset LPE2E_SITE
L="$M/fr/paris/lutece"
mkdir -p "$P/src/java" "$P/e2e/scenarios" "$P/e2e/artifacts" "$P/target" "$L/plugins/plugin-demo/1.0" "$L/plugins/library-x/1.0" \
         "$L/lutece-core/8.0.2-SNAPSHOT"
printf '<project><parent><artifactId>lutece-global-pom</artifactId></parent><artifactId>plugin-demo</artifactId></project>\n' > "$P/pom.xml"
printf 'E2E_TARGET=plugin\nE2E_NAME="demo-e2e"\n' > "$P/e2e/e2e.conf"
echo 'class A {}' > "$P/src/java/A.java"; echo 'id: a' > "$P/e2e/scenarios/a.yaml"
echo 1 > "$L/plugins/plugin-demo/1.0/plugin-demo-1.0.jar"; echo 1 > "$L/plugins/library-x/1.0/library-x-1.0.jar"
echo 1 > "$L/lutece-core/8.0.2-SNAPSHOT/lutece-core-8.0.2-SNAPSHOT.jar"
k0=$(python3 "$K" "$P")
touch "$P/src/java/A.java"; echo x > "$P/target/B.class"; echo x > "$P/e2e/artifacts/summary.md"
check "touch, build output and artifacts leave the key" '[ "$(python3 "$K" "$P")" = "$k0" ]'
echo 'class A { }' > "$P/src/java/A.java"; k1=$(python3 "$K" "$P")
check "a source edit changes the key" '[ "$k1" != "$k0" ]'
echo 'id: b' > "$P/e2e/scenarios/a.yaml"; k2=$(python3 "$K" "$P")
check "a scenario edit changes the key" '[ "$k2" != "$k1" ]'
echo 2 > "$L/plugins/library-x/1.0/library-x-1.0.jar"
check "without an assembled site the local repository leaves the key" '[ "$(python3 "$K" "$P")" = "$k2" ]'
S="$T/home/benches/demo-e2e/site/WEB-INF/lib"; mkdir -p "$S"
for j in library-x-1.0.jar lutece-core-8.0.2-SNAPSHOT.jar plugin-demo-1.0.jar commons-io-2.22.0.jar; do echo x > "$S/$j"; done
k3=$(python3 "$K" "$P")
check "the bench site's Lutece jars enter the key" '[ "$k3" != "$k2" ]'
echo 22 > "$L/plugins/plugin-demo/1.0/plugin-demo-1.0.jar"
check "the project's own jar reinstalled leaves the key" '[ "$(python3 "$K" "$P")" = "$k3" ]'
mkdir -p "$L/lutece-core/7.1.10-SNAPSHOT" "$L/plugins/plugin-other/2.0"
echo 7 > "$L/lutece-core/7.1.10-SNAPSHOT/lutece-core-7.1.10-SNAPSHOT.jar"
check "another version of a carried artefact downloaded leaves the key" '[ "$(python3 "$K" "$P")" = "$k3" ]'
echo 1 > "$L/plugins/plugin-other/2.0/plugin-other-2.0.jar"
check "a Lutece artefact the site does not carry installed leaves the key" '[ "$(python3 "$K" "$P")" = "$k3" ]'
touch -r "$L/lutece-core/8.0.2-SNAPSHOT/lutece-core-8.0.2-SNAPSHOT.jar" "$T/date"
echo 9 > "$L/lutece-core/8.0.2-SNAPSHOT/lutece-core-8.0.2-SNAPSHOT.jar"; touch -r "$T/date" "$L/lutece-core/8.0.2-SNAPSHOT/lutece-core-8.0.2-SNAPSHOT.jar"
k4=$(python3 "$K" "$P")
check "a jar the site carries rebuilt with the same date changes the key" '[ "$k4" != "$k3" ]'
check "LPE2E_SITE names the same site as e2e.conf" '[ "$(LPE2E_SITE="$T/home/benches/demo-e2e/site" python3 "$K" "$P")" = "$k4" ]'
if [ $fail = 0 ]; then echo "PASS: source key ignores what builds and benches produce, follows sources, scenarios and the jars the bench site carries"; else exit 1; fi
