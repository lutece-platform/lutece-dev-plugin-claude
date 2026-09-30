#!/usr/bin/env bash
# site-bench-war.sh — the war an e2e bench runs for a site: the assembled site plus the configuration probe.
#
#   site-bench-war.sh <assembled_site_dir> <out.war>
#
# Copies the assembled site, adds site-config-dump.jsp at its root with a random token, and writes the war. Prints the
# token: `curl "<base>/site-config-dump.jsp?token=<token>"` then prints the configuration the running site resolves,
# for `site_check.py config <assembled_site_dir> --against <dump> --env <container env>`. The probe is only in this war.
set -euo pipefail
SRC="${1:-}"; WAR="${2:-}"
[ -d "$SRC/WEB-INF" ] && [ -n "$WAR" ] || { sed -n '2,9p' "$0" >&2; exit 2; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
TOKEN=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
cp -a "$SRC/." "$TMP/"
sed "s/@@TOKEN@@/$TOKEN/" "$(dirname "$0")/site-config-dump.jsp" > "$TMP/site-config-dump.jsp"
mkdir -p "$(dirname "$WAR")"
WAR="$(cd "$(dirname "$WAR")" && pwd)/$(basename "$WAR")"
rm -f "$WAR"
(cd "$TMP" && jar -cf "$WAR.tmp" .) && mv "$WAR.tmp" "$WAR"
echo "$TOKEN"
