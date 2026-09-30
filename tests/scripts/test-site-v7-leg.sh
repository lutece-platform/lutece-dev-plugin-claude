#!/usr/bin/env bash
# Checks the site mode of gen-site7.sh: the v7 leg of run.sh compare is the site's own v7 war (E2E_V7_WAR), with the
# bench's database settings laid over the site's, a war written, and the versions the v8 site resets read from its
# plugin descriptors and its core jar.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SKILL="$HERE/../../skills/lutece-e2e"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
E="$T/e2e"
mkdir -p "$E/tools" "$E/harness/site7/webapp/WEB-INF/conf" "$T/v7/WEB-INF/lib" "$T/v7/WEB-INF/plugins" "$T/v7/WEB-INF/conf"
cp "$SKILL/tools/gen-site7.sh" "$E/tools/"
cp "$HERE/../../tools/python.sh" "$E/tools/"
cp "$SKILL/harness/site7/webapp/WEB-INF/conf/db.properties" "$E/harness/site7/webapp/WEB-INF/conf/"
printf 'E2E_TARGET=site\nE2E_SRC=..\nE2E_V7_WAR=%s\n' "$T/v7" > "$E/e2e.conf"
echo "portal.url=jdbc:mysql://production-host:3306/site" > "$T/v7/WEB-INF/conf/db.properties"
echo "<plug-in><name>forms</name><version>3.1.3</version></plug-in>" > "$T/v7/WEB-INF/plugins/forms.xml"
( cd "$T" && mkdir -p j/x && printf '\xca\xfe\xba\xbe\x00\x00\x00\x37' > j/x/A.class && cd j && jar -cf "$T/v7/WEB-INF/lib/lutece-core-7.1.5.jar" x/A.class )
OUT=$(bash "$E/tools/gen-site7.sh" 2>&1); RC=$?
fail=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }
check "gen-site7.sh accepts a site target with E2E_V7_WAR" "[ $RC -eq 0 ]"
check "the v7 war is written" "[ -f '$E/harness/site7/target/lutece.war' ]"
check "the bench database settings replace the site's" "grep -q 'jdbc:mysql://db:3306/lutece' '$E/harness/site7/target/e2e-site7-site/WEB-INF/conf/db.properties' && ! grep -q production-host '$E/harness/site7/target/e2e-site7-site/WEB-INF/conf/db.properties'"
check "versions.properties names the core and the plugins of the v7 war" "grep -qx 'core=7.1.5' '$E/harness/site7/target/versions.properties' && grep -qx 'forms=3.1.3' '$E/harness/site7/target/versions.properties'"
printf 'E2E_TARGET=site\nE2E_SRC=..\n' > "$E/e2e.conf"
OUT2=$(bash "$E/tools/gen-site7.sh" 2>&1); RC2=$?
check "a site target without E2E_V7_WAR is refused with the reason" "[ $RC2 -eq 2 ] && echo \"\$OUT2\" | grep -q E2E_V7_WAR"
[ $fail -eq 0 ] || { echo "$OUT"; exit 1; }
