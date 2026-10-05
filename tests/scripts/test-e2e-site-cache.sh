#!/usr/bin/env bash
# Checks the key of the e2e bench's cached site (server/server.py, site_key): a cache hit only repackages the artefact
# and lays its jar and webapp files over the cached site, so the key must change whenever that would leave the site
# stale: an SQL script of the artefact moved, added or edited (the assembly copies them to WEB-INF/classes/sql, which a
# hit never refreshes), or a webapp file removed or moved (an overlay never deletes). Editing a webapp file in place
# keeps the key: the overlay carries it.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SERVER="$HERE/../../skills/lutece-e2e/server"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/build/webapp/WEB-INF/plugins" "$T/src/src/sql/plugins/foo/plugin" "$T/src/webapp/WEB-INF/templates/admin/plugins/foo"
echo '<project/>' > "$T/build/pom.xml"
echo 'foo=1' > "$T/build/webapp/WEB-INF/plugins/plugins.dat"
echo '-- liquibase formatted sql' > "$T/src/src/sql/plugins/foo/plugin/create_db_foo.sql"
echo '<p>a</p>' > "$T/src/webapp/WEB-INF/templates/admin/plugins/foo/manage.html"
key() {
  (cd "$SERVER" && python3 - "$T" <<'PY'
import pathlib, sys, types
import server
t = pathlib.Path(sys.argv[1])
print(server.site_key(types.SimpleNamespace(build=t / "build", src=t / "src")))
PY
  )
}
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }
k0=$(key)
echo '<p>b</p>' > "$T/src/webapp/WEB-INF/templates/admin/plugins/foo/manage.html"
check "a webapp file edited in place keeps the cached site" "$(key)" "$k0"
echo 'CREATE TABLE foo ( id INT );' >> "$T/src/src/sql/plugins/foo/plugin/create_db_foo.sql"
k1=$(key)
check "an edited SQL script rebuilds the cached site" "$([ "$k1" != "$k0" ] && echo changed)" "changed"
mkdir -p "$T/src/src/sql/plugins/foo/modules/bar/plugin"
mv "$T/src/src/sql/plugins/foo/plugin/create_db_foo.sql" "$T/src/src/sql/plugins/foo/modules/bar/plugin/"
k2=$(key)
check "a moved SQL script rebuilds the cached site" "$([ "$k2" != "$k1" ] && echo changed)" "changed"
rm "$T/src/webapp/WEB-INF/templates/admin/plugins/foo/manage.html"
check "a removed webapp file rebuilds the cached site" "$([ "$(key)" != "$k2" ] && echo changed)" "changed"
exit $fail
