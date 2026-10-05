#!/usr/bin/env bash
# Checks how the e2e bench forces the latest Lutece versions over a site's BOM (server/server.py): force_versions
# declares them in the project dependencies, never in dependencyManagement or a profile; held_back reads the
# artefacts the enforcer's upper-bound rule reports as held back by the BOM; any other failure of mvn validate stops
# the build; the Maven type of a forced artefact follows its kind.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SERVER="$HERE/../../skills/lutece-e2e/server"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
cat > "$T/pom.site" <<'XML'
<project>
    <dependencyManagement>
        <dependencies>
            <dependency><groupId>fr.paris.lutece.starters</groupId><artifactId>lutece-bom</artifactId><version>8.0.0-SNAPSHOT</version><type>pom</type><scope>import</scope></dependency>
        </dependencies>
    </dependencyManagement>
    <dependencies>
        <dependency><groupId>fr.paris.lutece.plugins</groupId><artifactId>plugin-html</artifactId><type>lutece-plugin</type></dependency>
    </dependencies>
    <profiles>
        <profile><id>local</id><dependencies><dependency><groupId>x</groupId><artifactId>y</artifactId></dependency></dependencies></profile>
    </profiles>
</project>
XML
cat > "$T/mvn-bounds" <<'SH'
#!/bin/sh
cat <<'OUT'
[ERROR] Require upper bound dependencies error for fr.paris.lutece.tools:library-sql-utils:2.0.1. Paths to dependency are:
[ERROR]     +-fr.paris.lutece.tools:library-sql-utils:2.0.1 (managed) <-- fr.paris.lutece.tools:library-sql-utils:2.0.1
[ERROR]     +-fr.paris.lutece.tools:library-sql-utils:2.0.1 (managed) <-- fr.paris.lutece.tools:library-sql-utils:[2.1.0-SNAPSHOT,)
[ERROR]     +-org.other:lib:1.0 (managed) <-- org.other:lib:2.0
[ERROR] Rule 0: org.apache.maven.enforcer.rules.dependency.RequireUpperBoundDeps failed with message:
OUT
exit 1
SH
printf '#!/bin/sh\necho "[ERROR] Non-resolvable parent POM"\nexit 1\n' > "$T/mvn-broken"
printf '#!/bin/sh\necho "[INFO] BUILD SUCCESS"\n' > "$T/mvn-clean"
chmod +x "$T"/mvn-*
run() {
  (cd "$SERVER" && M2_REPO="$T/m2" python3 - "$T" "$@" <<'PY'
import pathlib, re, sys
sys.argv = [sys.argv[0]] + sys.argv[1:]
import server
t = pathlib.Path(sys.argv[1])
what = sys.argv[2]
if what == "force":
    server.force_versions(t / "pom.xml", {"fr.paris.lutece:lutece-core": ("8.0.2-SNAPSHOT", "b"), "fr.paris.lutece.tools:library-sql-utils": ("2.1.0-SNAPSHOT", "b")})
    text = (t / "pom.xml").read_text()
    managed = re.search(r"<dependencyManagement>.*?</dependencyManagement>", text, re.S).group(0)
    profiles = re.search(r"<profiles>.*?</profiles>", text, re.S).group(0)
    project = re.sub(r"<(dependencyManagement|profiles)>.*?</\1>", "", text, flags=re.S)
    print("core-in-project" if "<artifactId>lutece-core</artifactId><version>8.0.2-SNAPSHOT</version><type>lutece-core</type>" in project else "core-missing",
          "lib-jar" if "<artifactId>library-sql-utils</artifactId><version>2.1.0-SNAPSHOT</version><type>jar</type>" in project else "lib-missing",
          "managed-untouched" if "lutece-core" not in managed and "lutece-core" not in profiles else "managed-touched")
else:
    import os
    os.environ["MVN"] = str(t / what)
    try:
        print(",".join(server.held_back(t, "local")) or "none")
    except SystemExit as e:
        print("stopped" if "failed for another reason" in str(e) else "other: %s" % e)
PY
  )
}
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 (expected $3, got $2)"; fail=1; fi; }
check "forced versions go in the project dependencies, typed, never in dependencyManagement or a profile" "$(run force)" "core-in-project lib-jar managed-untouched"
check "held back: the Lutece artefacts the upper-bound rule reports, a satisfied bound and a non-Lutece one left out" "$(run mvn-bounds)" "fr.paris.lutece.tools:library-sql-utils"
check "another failure of mvn validate stops the build" "$(run mvn-broken)" "stopped"
check "nothing held back on a clean validation" "$(run mvn-clean)" "none"
exit $fail
