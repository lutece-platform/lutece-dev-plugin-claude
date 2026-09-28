#!/usr/bin/env bash
# legacy-admin-jsp.sh — the admin JSPs of a project that drive a JspBean which is not a @Controller.
#
# Usage: legacy-admin-jsp.sh [project_dir]
#
# Prints one line per such JSP: the JSP, the bean class, the bean source and the kind, tab-separated, relative to the
# project. The bean is read from an EL call (${ xxxJspBean.… }) or a <jsp:useBean class="….XxxJspBean">. The kind is
# "legacy" for a bean that is not a @Controller, "direct" for a @Controller the JSP calls outside processController (a
# method that is no @View, run without the MVC dispatch). A bean extending PortletJspBean, directly or through a local
# base class, is left alone, and so is a JSP that calls processController. v8 dispatches admin views and actions through
# processController on one JSP per controller, and the automatic CSRF filter covers those actions only.
set -uo pipefail
cd "${1:-.}" || exit 1
[ -d webapp/jsp/admin ] && [ -d src/java ] || exit 0

# Prints the first JspBean class a JSP drives, or nothing.
bean_class() {
    { grep -oE '\$\{ *[a-z][A-Za-z0-9_]*JspBean\.' "$1" | sed -E 's/\$\{ *//; s/\.$//' | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }'
      grep -oE '<jsp:useBean[^>]*class *= *"[A-Za-z0-9_.]*JspBean"' "$1" | sed -E 's/.*[".]([A-Za-z0-9_]+JspBean)"$/\1/'; } | head -1
}

# Prints portlet or controller when the class of this source, or a local base class, is a PortletJspBean or a
# @Controller, and fails otherwise.
dispatched() {
    local src="$1" parent _
    for _ in 1 2 3 4 5; do
        grep -qE '^[^/*]*\bextends +PortletJspBean\b' "$src" && { echo portlet; return 0; }
        grep -qE '^[[:space:]]*@Controller\b' "$src" && { echo controller; return 0; }
        parent=$(grep -oE 'class +[A-Za-z0-9_]+(<[^>]*>)? +extends +[A-Za-z0-9_]+' "$src" | head -1 | sed -E 's/.* extends +//')
        [ -n "$parent" ] || return 1
        src=$(grep -rlE "class +$parent\b" src/java --include="*.java" 2>/dev/null | head -1)
        [ -n "$src" ] || return 1
    done
    return 1
}

grep -rlE '\$\{ *[a-z][A-Za-z0-9_]*JspBean\.|<jsp:useBean[^>]*JspBean"' webapp/jsp/admin --include="*.jsp" 2>/dev/null | sort | while read -r jsp; do
    grep -q 'processController' "$jsp" && continue
    cls=$(bean_class "$jsp")
    [ -n "$cls" ] || continue
    src=$(grep -rlE "class $cls\b" src/java --include="*.java" 2>/dev/null | head -1)
    [ -n "$src" ] || continue
    case "$(dispatched "$src")" in
        portlet) ;;
        controller) printf '%s\t%s\t%s\tdirect\n' "$jsp" "$cls" "$src" ;;
        *) printf '%s\t%s\t%s\tlegacy\n' "$jsp" "$cls" "$src" ;;
    esac
done
exit 0
