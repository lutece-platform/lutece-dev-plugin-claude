#!/usr/bin/env bash
# Checks the e2e bench's source digest (tools/src-digest.sh) and that the rebuild decision uses it: a source edited
# with an older date than the last build, or another checkout of the same artefact, must rebuild; untouched sources
# and a target/ folder must not.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
E2E="$HERE/../../skills/lutece-e2e"
D="$E2E/tools/src-digest.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mk() {
  mkdir -p "$1/src/java/x" "$1/webapp/WEB-INF/templates"
  echo '<project/>' > "$1/pom.xml"
  echo 'class A {}' > "$1/src/java/x/A.java"
  echo '<p/>' > "$1/webapp/WEB-INF/templates/a.html"
}
mk "$T/develop"; mk "$T/branch"
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }
d0=$(bash "$D" "$T/branch")
mkdir -p "$T/branch/target"; echo x > "$T/branch/target/out.jar"
check "a target/ folder does not change the digest" "$(bash "$D" "$T/branch")" "$d0"
check "another checkout of the same sources has another digest" "$([ "$(bash "$D" "$T/develop")" != "$d0" ] && echo differs)" "differs"
echo 'class A { int b; }' > "$T/branch/src/java/x/A.java"; touch -d '2000-01-01' "$T/branch/src/java/x/A.java"
check "a source edited with an older date changes the digest" "$([ "$(bash "$D" "$T/branch")" != "$d0" ] && echo differs)" "differs"
mkdir -p "$T/nowebapp/src"; echo '<project/>' > "$T/nowebapp/pom.xml"
check "an artefact without webapp/ still has a digest" "$(bash "$D" "$T/nowebapp" >/dev/null 2>&1 && echo ok)" "ok"
grep -q 'stamp.src' "$E2E/run.sh" && grep -q 'src-digest.sh" "$E2E_SRC" >' "$E2E/run.sh"
check "the bench records the digest at build and compares it before reusing a build" "$?" "0"
exit $fail
