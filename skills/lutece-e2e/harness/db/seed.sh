#!/bin/sh
# Prepares the bench's database once the application created its schema: the post-init (the bench's own
# e2e/harness/db/post-init.sql when it has one, else the generic one), the front-office account when mylutece is in
# the site, then every seed-*.sql of the bench, in name order. The generic harness ships no seed: the reference rows
# and the synthetic volume are written for the artefact under test (its own tables, its own row counts). E2E_VOLUME
# sizes them and is exposed to the SQL as @users/@groups/@roles/@lists/@pages so a generated seed can scale itself;
# see reference/seed-volume-example.sql. The generic scripts are in /db, the bench's in /e2e-db.
set -eu
DBN=${E2E_DB_NAME:-lutece}
case "${E2E_VOLUME:-none}" in
  large) USERS=100000; NGROUPS=500; ROLES=300; LISTS=500; PAGES=3000 ;;
  small) USERS=2000;   NGROUPS=50;  ROLES=30;  LISTS=50;  PAGES=200 ;;
  *)     USERS=0;      NGROUPS=0;   ROLES=0;   LISTS=0;   PAGES=0 ;;
esac
db() { mariadb -h db -ulutece -plutece "$DBN" "$@"; }
run() {
  db -e "SET @users=$USERS, @groups=$NGROUPS, @roles=$ROLES, @lists=$LISTS, @pages=$PAGES; SOURCE $1;"
}
if [ -f /e2e-db/post-init.sql ]; then db < /e2e-db/post-init.sql; else db < /db/post-init.sql; fi
# The bench's front-office account, when the mylutece database module is part of the site (E2E_MYLUTECE, gen-site.sh).
if db -N -e "SELECT 1 FROM mylutece_database_user LIMIT 0" >/dev/null 2>&1; then
  echo ">> mylutece account test/testtest (post-init-mylutece.sql)"
  db < /db/post-init-mylutece.sql
fi
found=0
# seed7-*.sql: rows only the v7 schema needs (a portlet's XSL style, a column the v8 dropped), applied on the v7
# database of lpe2e upgrade only.
for f in $(ls /e2e-db/seed-*.sql 2>/dev/null | sort) $( [ "${E2E_VERSION:-v8}" = v7 ] && ls /e2e-db/seed7-*.sql 2>/dev/null | sort ); do
  [ -f "$f" ] || continue
  found=1
  echo ">> seed $f (volume ${E2E_VOLUME:-none})"
  run "$f"
done
[ "$found" = 1 ] || echo ">> no e2e/harness/db/seed-*.sql in this bench: database left as the application created it"
