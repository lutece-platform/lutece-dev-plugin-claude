#!/bin/bash
# Empties the application's caches (FreeMarker templates included) through the back-office cache screen.
# "prime" fetches the single-use token ahead of time, so "reset" costs one short request. Logs in again only when
# the kept session is gone. Run inside the runner: bash /e2e/reset_caches.sh prime|reset
B=${E2E_BASE:-http://localhost:9090/lutece}
J=/tmp/.lpe2e-admin.cookies
T=/tmp/.lpe2e-reset.token
token() { grep -o 'name="token"[^>]*value="[^"]*"' | head -1 | sed 's/.*value="//;s/"$//'; }
caches() { curl -s -b $J -c $J "$B/jsp/admin/system/ManageCaches.jsp" | token; }
fetch() {
  t=$(caches)
  if [ -z "$t" ]; then
    lt=$(curl -s -c $J "$B/jsp/admin/AdminLogin.jsp" | token)
    curl -s -o /dev/null -b $J -c $J --data-urlencode "token=$lt" -d access_code=admin -d password=adminadmin "$B/jsp/admin/DoAdminLogin.jsp"
    t=$(caches)
  fi
  [ -n "$t" ] || { echo "RESET_FAILED no cache screen"; exit 1; }
}
reset() {
  curl -s -o /dev/null -w '%{redirect_url}' -b $J -c $J --data-urlencode "token=$1" "$B/jsp/admin/system/DoResetCaches.jsp"
}
if [ "$1" = prime ]; then
  fetch; echo "$t" > $T; echo "PRIMED"; exit 0
fi
t=$(cat $T 2>/dev/null); rm -f $T
if [ -z "$t" ] || [[ "$(reset "$t")" != *ManageCaches* ]]; then
  fetch
  [[ "$(reset "$t")" == *ManageCaches* ]] || { echo "RESET_FAILED"; exit 1; }
fi
echo "RESET_OK"
