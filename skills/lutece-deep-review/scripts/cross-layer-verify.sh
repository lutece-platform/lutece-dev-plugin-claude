#!/bin/bash
# cross-layer-verify.sh — Mechanical cross-layer verification
# Usage: bash cross-layer-verify.sh [project_root]
# Output: JSON to stdout
# Performs fast, script-level cross-checks. The AI teammate does the deep analysis.

set -uo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

BUGS="["
FIRST=true
BUG_COUNT=0

add_bug() {
    local type="$1" severity="$2" file="$3" line="$4" detail="$5"
    $FIRST || BUGS="$BUGS,"
    FIRST=false
    BUG_COUNT=$((BUG_COUNT + 1))
    detail=$(printf '%s' "$detail" | sed 's/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
    BUGS="$BUGS{\"type\":\"$type\",\"severity\":\"$severity\",\"file\":\"$file\",\"line\":$line,\"detail\":\"$detail\"}"
}

# ─── F6: i18n keys used in templates but missing from properties ──

# Collect all i18n keys from properties files
ALL_PROPS_KEYS=""
while IFS= read -r file; do
    [ -z "$file" ] && continue
    ALL_PROPS_KEYS="$ALL_PROPS_KEYS
$(grep -v '^#' "$file" 2>/dev/null | grep '=' | cut -d= -f1 | tr -d ' \r\t')"
done < <({ find src/ -name "*.properties" 2>/dev/null || true; } | sort)

# Check each template's i18n references
if [ -d "webapp/WEB-INF/templates/" ]; then
    while IFS= read -r tpl; do
        [ -z "$tpl" ] && continue
        while IFS= read -r key_line; do
            [ -z "$key_line" ] && continue
            KEY=$(echo "$key_line" | grep -oP '#i18n\{([^}]+)\}' | sed 's/#i18n{//; s/}//')
            [ -z "$KEY" ] && continue
            # Skip portal.* keys (from core)
            echo "$KEY" | grep -q '^portal\.' && continue
            # Check if key exists in properties
            if ! echo "$ALL_PROPS_KEYS" | grep -qF "$KEY"; then
                LINE=$(echo "$key_line" | cut -d: -f1)
                add_bug "F6" "BUG" "$tpl" "${LINE:-0}" "i18n key '$KEY' used in template but not found in any .properties file"
            fi
        done < <(grep -n '#i18n{' "$tpl" 2>/dev/null || true)
    done < <(find webapp/WEB-INF/templates/ -name "*.html" 2>/dev/null | sort)
fi

# ─── F8: RIGHT constants in code not declared in plugin.xml ──

# Collect all right names from plugin.xml
DECLARED_RIGHTS=""
if [ -d "webapp/WEB-INF/plugins/" ]; then
    DECLARED_RIGHTS=$(grep -ohP 'name="[A-Z_]+"' webapp/WEB-INF/plugins/*.xml 2>/dev/null \
        | sed 's/name="//; s/"//' || true)
fi

# Check Java code for RIGHT_ constants
while IFS= read -r file; do
    [ -z "$file" ] && continue
    while IFS= read -r right_line; do
        [ -z "$right_line" ] && continue
        RIGHT_VALUE=$(echo "$right_line" | grep -oP '=\s*"([^"]+)"' | sed 's/= "//; s/"//')
        [ -z "$RIGHT_VALUE" ] && continue
        LINE=$(echo "$right_line" | cut -d: -f2)
        # Check if declared in plugin.xml
        if [ -n "$DECLARED_RIGHTS" ] && ! echo "$DECLARED_RIGHTS" | grep -qF "$RIGHT_VALUE"; then
            add_bug "F8" "BUG" "$file" "${LINE:-0}" "RIGHT constant '$RIGHT_VALUE' used in code but not declared in plugin.xml"
        fi
    done < <(grep -n 'RIGHT_.*=.*"' "$file" 2>/dev/null || true)
done < <(find src/ -name "*JspBean.java" -not -path '*/test/*' 2>/dev/null | sort)

# ─── F3: Hidden actions in templates vs @Action constants in beans ──

# Collect all action values from beans
ALL_ACTIONS=""
while IFS= read -r file; do
    [ -z "$file" ] && continue
    ALL_ACTIONS="$ALL_ACTIONS
$(grep -oP 'ACTION_\w+\s*=\s*"([^"]+)"' "$file" 2>/dev/null | grep -oP '"[^"]+"' | tr -d '"' || true)"
done < <(find src/ -name "*JspBean.java" -o -name "*XPage.java" 2>/dev/null | grep -v test | sort)

# Check template hidden action fields
if [ -d "webapp/WEB-INF/templates/" ]; then
    while IFS= read -r tpl; do
        [ -z "$tpl" ] && continue
        while IFS= read -r action_line; do
            [ -z "$action_line" ] && continue
            ACTION=$(echo "$action_line" | grep -oP 'value="([^"]+)"' | sed 's/value="//; s/"//')
            [ -z "$ACTION" ] && continue
            LINE=$(echo "$action_line" | cut -d: -f1)
            if [ -n "$ALL_ACTIONS" ] && ! echo "$ALL_ACTIONS" | grep -qF "$ACTION"; then
                add_bug "F3" "BUG" "$tpl" "${LINE:-0}" "Form action '$ACTION' in template but no @Action with this value found in any bean"
            fi
        done < <(grep -n 'name="action".*value="' "$tpl" 2>/dev/null || true)
    done < <(find webapp/WEB-INF/templates/ -name "*.html" 2>/dev/null | sort)
fi

# ─── F9: redirectView constants referencing non-existent views ──

# Collect all VIEW values from beans
ALL_VIEWS=""
while IFS= read -r file; do
    [ -z "$file" ] && continue
    ALL_VIEWS="$ALL_VIEWS
$(grep -oP 'VIEW_\w+' "$file" 2>/dev/null | sort -u || true)"
done < <({ find src/ -name "*JspBean.java" -o -name "*XPage.java"; } 2>/dev/null | grep -v test | sort)

# Check redirectView references
while IFS= read -r file; do
    [ -z "$file" ] && continue
    while IFS= read -r redirect_line; do
        [ -z "$redirect_line" ] && continue
        VIEW_CONST=$(echo "$redirect_line" | grep -oP 'redirectView\(\s*(VIEW_\w+)' | sed 's/redirectView( //')
        [ -z "$VIEW_CONST" ] && continue
        LINE=$(echo "$redirect_line" | cut -d: -f2)
        # Check if a @View annotation references this constant
        if ! grep -q "@View.*$VIEW_CONST\|@View.*value.*=.*$VIEW_CONST" "$file" 2>/dev/null; then
            add_bug "F9" "WARN" "$file" "${LINE:-0}" "redirectView($VIEW_CONST) but no @View method referencing this constant in same class"
        fi
    done < <(grep -n 'redirectView(' "$file" 2>/dev/null || true)
done < <({ find src/ -name "*JspBean.java" -o -name "*XPage.java"; } 2>/dev/null | grep -v test | sort)

BUGS="$BUGS]"

# ─── Output ─────────────────────────────────────────────

cat << ENDJSON
{
  "scriptBugCount": $BUG_COUNT,
  "bugs": $BUGS
}
ENDJSON
