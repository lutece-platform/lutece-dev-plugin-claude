#!/usr/bin/env bash
# Checks a fresh bench: init-e2e.sh writes the project's configuration only (no bench code copied), and gen-site.sh,
# run from the skill on that configuration, writes the site pom and plugins.dat into its build directory (whose
# WEB-INF/plugins does not exist yet), stops there with --pom-only, and goes on to the assembly otherwise. Maven is a
# stub; every Lutece version is pinned, so nothing is read from the network.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SKILL="$HERE/../../skills/lutece-e2e"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
P="$T/plugin-demo"
mkdir -p "$P/webapp/WEB-INF/plugins" "$T/bin"
printf '<project><groupId>fr.paris.lutece.plugins</groupId><artifactId>plugin-demo</artifactId><version>1.0.0</version><packaging>lutece-plugin</packaging></project>\n' > "$P/pom.xml"
echo "<plug-in><name>demo</name></plug-in>" > "$P/webapp/WEB-INF/plugins/demo.xml"
cat > "$T/bin/mvn" <<'MVN'
#!/usr/bin/env bash
case "$*" in
  *project.groupId*) printf fr.paris.lutece.plugins;;
  *project.artifactId*) printf plugin-demo;;
  *project.version*) printf 1.0.0;;
  *project.packaging*) printf lutece-plugin;;
esac
exit 0
MVN
chmod +x "$T/bin/mvn"
bash "$SKILL/scripts/init-e2e.sh" "$P" > "$T/init.log" 2>&1 || { cat "$T/init.log"; exit 1; }
B="$T/build"
DAT="$B/webapp/WEB-INF/plugins/plugins.dat"
fail=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }
check "init-e2e.sh writes the configuration and no bench code" "[ -f '$P/e2e/e2e.conf' ] && [ ! -e '$P/e2e/run.sh' ] && [ ! -e '$P/e2e/tools' ] && [ ! -e '$P/e2e/tests' ]"
check "e2e/ is ignored by the project's git" "! [ -d '$P/.git' ] || grep -qx 'e2e/' '$P/.gitignore'"
PIN=(E2E_SITE_POM_VERSION=8.0.9 E2E_CORE_VERSION=8.0.9-SNAPSHOT E2E_LIQUIBASE_VERSION=2.0.9-SNAPSHOT E2E_MYLUTECE_VERSION=5.0.9-SNAPSHOT E2E_MYLUTECE_DATABASE_VERSION=7.0.9-SNAPSHOT)
OUT=$(cd "$P" && env "${PIN[@]}" E2E_DIR="$P/e2e" E2E_SITE_BUILD="$B" MVN="$T/bin/mvn" bash "$SKILL/tools/gen-site.sh" --pom-only 2>&1)
check "gen-site.sh writes plugins.dat in a build directory that had no WEB-INF/plugins" "[ -f '$DAT' ]"
check "plugins.dat enables the plugin under test and mylutece" "grep -qx 'demo.installed=1' '$DAT' && grep -qx 'mylutece.installed=1' '$DAT'"
check "the site pom carries the pinned versions" "grep -q '8.0.9-SNAPSHOT' '$B/pom.xml' && grep -q '<artifactId>plugin-mylutece</artifactId><version>5.0.9-SNAPSHOT' '$B/pom.xml'"
check "the site pom has the pinned lutece-site-pom parent and no placeholder left" "grep -q '<version>8.0.9</version>' '$B/pom.xml' && ! grep -q '@@' '$B/pom.xml'"
check "--pom-only stops before the assembly" "! echo \"\$OUT\" | grep -q 'assemble the site'"
OUT=$(cd "$P" && env "${PIN[@]}" E2E_DIR="$P/e2e" E2E_SITE_BUILD="$B" MVN="$T/bin/mvn" bash "$SKILL/tools/gen-site.sh" --no-install 2>&1)
check "without --pom-only gen-site.sh goes on to the assembly" "echo \"\$OUT\" | grep -q 'assemble the site'"
[ $fail -eq 0 ] || { echo "$OUT"; exit 1; }
