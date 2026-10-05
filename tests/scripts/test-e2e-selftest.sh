#!/usr/bin/env bash
# Checks the pure parts of lpe2e selftest (server/server.py): the target is the first template a front-office XPage
# cites (a list one first), else the TEMPLATE_MANAGE template of the first manage JspBean, none without either; the
# template bug is a FreeMarker directive left open; the Java bug throws at the start of the method's body, never at a
# call; a source broken then restored is the same bytes (CRLF line endings, Latin-1); a step is judged on the failures
# new against the baseline.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SERVER="$HERE/../../skills/lutece-e2e/server"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
W=webapp/WEB-INF/templates
mkdir -p "$T/fo/src/java/a/web" "$T/fo/$W/skin/plugins/a" "$T/fo/$W/admin/plugins/a" \
         "$T/bo/src/java/a/web" "$T/bo/$W/admin/plugins/a" "$T/none/src/java/a"
cat > "$T/fo/src/java/a/web/AApp.java" <<'JAVA'
class AApp {
    private static final String T1 = "skin/plugins/a/page.html";
    private static final String T2 = "skin/plugins/a/a_list.html";
    public XPage getPage( HttpServletRequest request, int nMode, Plugin plugin ) throws SiteMessageException
    {
        return null;
    }
}
JAVA
cat > "$T/fo/src/java/a/web/AJspBean.java" <<'JAVA'
class AJspBean {
    private static final String TEMPLATE_MANAGE_A = "admin/plugins/a/manage_a.html";
    public String getManageA( HttpServletRequest request ) { return null; }
}
JAVA
touch "$T/fo/$W/skin/plugins/a/page.html" "$T/fo/$W/skin/plugins/a/a_list.html" "$T/fo/$W/admin/plugins/a/manage_a.html"
cat > "$T/bo/src/java/a/web/BJspBean.java" <<'JAVA'
class BJspBean {
    private static final String TEMPLATE_MANAGE_B = "admin/plugins/a/manage_b.html";
    public String getCreateB( HttpServletRequest request ) { return getManageB( request ); }
    public String getManageB( HttpServletRequest request )
    {
        return null;
    }
}
JAVA
touch "$T/bo/$W/admin/plugins/a/manage_b.html"
echo 'class C {}' > "$T/none/src/java/a/C.java"
run() {
  (cd "$SERVER" && python3 - "$T" "$1" <<'PY'
import pathlib, sys
import server
t, what = pathlib.Path(sys.argv[1]), sys.argv[2]
if what in ("fo", "bo", "none"):
    found = server.selftest_target(t / what)
    print("none" if found is None else "%s %s %s" % (found[0].name, found[1], found[2].relative_to(t / what)))
elif what == "template":
    print(repr(server.break_template("<p>x</p>\n")))
elif what == "java":
    java = server.break_java((t / "bo/src/java/a/web/BJspBean.java").read_text(), "getManageB")
    print([l.strip() for l in java.splitlines() if "e2e selftest" in l])
elif what == "bytes":
    f = t / "crlf.html"
    before = "<p>\u00e9t\u00e9</p>\r\n<#-- x -->\r\n".encode("latin-1")
    f.write_bytes(before)
    text = server.source(f)
    server.write_source(f, server.break_template(text))
    broken = f.read_bytes()
    server.write_source(f, text)
    print("same" if f.read_bytes() == before and broken.startswith(before) else "changed")
elif what == "java-missing":
    try:
        server.break_java("class X {}", "getPage")
        print("broken")
    except SystemExit:
        print("stopped")
else:
    known = {"a", "b"}
    for step, failed, red in (("baseline", {"a", "b"}, False), ("template bug", {"a", "b", "c", "d"}, True),
                              ("template revert", {"a"}, False), ("java bug", {"b"}, True), ("java revert", {"a", "e"}, False)):
        print(server.judge(step, known, failed, red))
PY
  )
}
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 (expected $3, got $2)"; fail=1; fi; }
check "an XPage wins: its getPage and the first template it cites, a list one first" "$(run fo)" "AApp.java getPage $W/skin/plugins/a/a_list.html"
check "no XPage: the manage JspBean, its getManage method and its TEMPLATE_MANAGE template" "$(run bo)" "BJspBean.java getManageB $W/admin/plugins/a/manage_b.html"
check "neither: no target" "$(run none)" "none"
check "the template bug leaves a FreeMarker directive open" "$(run template)" "'<p>x</p>\n\n<#if broken'"
check "the Java bug throws at the start of the method's body, not at the call" "$(run java)" "['{ if ( true ) throw new RuntimeException( \"e2e selftest\" );']"
check "a source broken then restored is the same bytes, CRLF and Latin-1 kept" "$(run bytes)" "same"
check "a method the source does not declare stops the selftest" "$(run java-missing)" "stopped"
check "steps judged on the failures new against the baseline" "$(run judge)" "(True, 'SELFTEST baseline OK (0 new failure(s), expected green)')
(True, 'SELFTEST template bug OK (2 new failure(s), expected red)')
(True, 'SELFTEST template revert OK (0 new failure(s), expected green)')
(False, 'SELFTEST java bug MISSED (0 new failure(s), expected red)')
(False, 'SELFTEST java revert MISSED (1 new failure(s), expected green)')"
exit $fail
