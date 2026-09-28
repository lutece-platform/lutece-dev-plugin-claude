#!/usr/bin/env bash
# Checks source-key.py: stable across touch, build output, bench artifacts and the project's own jar; changed by a
# source edit, a bench scenario edit and another Lutece artefact reinstalled; once a site is assembled, only by the
# Lutece artefacts that site carries.
set -u
K="$(cd "$(dirname "$0")" && pwd)/../../skills/lutece-e2e/tools/source-key.py"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }
P="$T/p"; M="$T/m2"; export M2_REPO="$M"
mkdir -p "$P/src/java" "$P/e2e/scenarios" "$P/e2e/artifacts" "$P/target" "$P/e2e/harness/site7" "$M/fr/paris/lutece/plugins/plugin-demo/1.0" "$M/fr/paris/lutece/plugins/library-x/1.0"
printf '<project><parent><artifactId>lutece-global-pom</artifactId></parent><artifactId>plugin-demo</artifactId></project>\n' > "$P/pom.xml"
echo 'class A {}' > "$P/src/java/A.java"; echo 'id: a' > "$P/e2e/scenarios/a.yaml"
echo 1 > "$M/fr/paris/lutece/plugins/plugin-demo/1.0/plugin-demo-1.0.jar"; echo 1 > "$M/fr/paris/lutece/plugins/library-x/1.0/library-x-1.0.jar"
k0=$(python3 "$K" "$P")
touch "$P/src/java/A.java"; echo x > "$P/target/B.class"; echo x > "$P/e2e/artifacts/summary.md"; echo x > "$P/e2e/harness/site7/pom.xml"
check "touch, build output, artifacts and generated v7 site leave the key" '[ "$(python3 "$K" "$P")" = "$k0" ]'
echo 22 > "$M/fr/paris/lutece/plugins/plugin-demo/1.0/plugin-demo-1.0.jar"
check "the project's own jar reinstalled leaves the key" '[ "$(python3 "$K" "$P")" = "$k0" ]'
echo 'class A { }' > "$P/src/java/A.java"; k1=$(python3 "$K" "$P")
check "a source edit changes the key" '[ "$k1" != "$k0" ]'
echo 'id: b' > "$P/e2e/scenarios/a.yaml"; k2=$(python3 "$K" "$P")
check "a scenario edit changes the key" '[ "$k2" != "$k1" ]'
echo 333 > "$M/fr/paris/lutece/plugins/library-x/1.0/library-x-1.0.jar"
check "another Lutece artefact reinstalled changes the key" '[ "$(python3 "$K" "$P")" != "$k2" ]'
mkdir -p "$P/e2e/harness/site/target/s/WEB-INF/lib" "$M/fr/paris/lutece/plugins/plugin-other/2.0"
echo x > "$P/e2e/harness/site/target/s/WEB-INF/lib/library-x-1.0.jar"; k3=$(python3 "$K" "$P")
echo 1 > "$M/fr/paris/lutece/plugins/plugin-other/2.0/plugin-other-2.0.jar"
check "a Lutece artefact the assembled site does not carry leaves the key" '[ "$(python3 "$K" "$P")" = "$k3" ]'
echo 4444 > "$M/fr/paris/lutece/plugins/library-x/1.0/library-x-1.0.jar"
check "a Lutece artefact the assembled site carries changes the key" '[ "$(python3 "$K" "$P")" != "$k3" ]'
if [ $fail = 0 ]; then echo "PASS: source key ignores what builds and benches produce, follows sources, scenarios and dependencies"; else exit 1; fi
