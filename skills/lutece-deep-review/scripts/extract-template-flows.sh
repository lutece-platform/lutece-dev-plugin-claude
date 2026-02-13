#!/bin/bash
# extract-template-flows.sh — Mechanical extraction of template flow data
# Usage: bash extract-template-flows.sh [project_root]
# Output: JSON to stdout (pipe to .review/template-flows-raw.json)
# This gives the Template Mapper teammate a head start — it still needs AI for full analysis

set -uo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

json_escape() {
    printf '%s' "$1" | tr -d '\r' | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' '
}

echo '{"templates": ['

FIRST=true

# ─── Admin + Skin Templates ─────────────────────────────
for dir in "webapp/WEB-INF/templates/admin" "webapp/WEB-INF/templates/skin"; do
    [ -d "$dir" ] || continue
    TPL_TYPE="admin"
    echo "$dir" | grep -q "skin" && TPL_TYPE="skin"

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        $FIRST || echo ","
        FIRST=false

        # Model attribute references: ${variable} and ${variable.property}
        MODEL_KEYS=$(grep -oP '\$\{([a-zA-Z_][a-zA-Z0-9_.!]*)\}' "$file" 2>/dev/null \
            | sed 's/\${//; s/}//' \
            | grep -v '^\.now' \
            | grep -v '^#i18n' \
            | sort -u || true)

        # i18n keys: #i18n{key}
        I18N_KEYS=$(grep -oP '#i18n\{([^}]+)\}' "$file" 2>/dev/null \
            | sed 's/#i18n{//; s/}//' \
            | sort -u || true)

        # Form actions
        FORM_ACTIONS=$(grep -oP '(?:action="|action='"'"')[^"'"'"']*' "$file" 2>/dev/null \
            | sed 's/action="//; s/action='"'"'//' \
            | sort -u || true)

        # Hidden action fields: name="action" value="xxx"
        HIDDEN_ACTIONS=$(grep -oP 'name="action"[^>]*value="[^"]*"' "$file" 2>/dev/null \
            | grep -oP 'value="[^"]*"' \
            | sed 's/value="//; s/"//' \
            | sort -u || true)

        # Form field names
        FIELD_NAMES=$(grep -oP 'name="[a-zA-Z_][a-zA-Z0-9_]*"' "$file" 2>/dev/null \
            | sed 's/name="//; s/"//' \
            | grep -v '^action$' \
            | grep -v '^token$' \
            | grep -v '^plugin_name$' \
            | sort -u || true)

        # Includes
        INCLUDES=$(grep -oP '<#include\s+"[^"]*"' "$file" 2>/dev/null \
            | sed 's/<#include "//; s/"//' \
            | sort -u || true)

        # View/Action links
        VIEW_LINKS=$(grep -oP 'view=[a-zA-Z_][a-zA-Z0-9_]*' "$file" 2>/dev/null \
            | sed 's/view=//' \
            | sort -u || true)
        ACTION_LINKS=$(grep -oP 'action=[a-zA-Z_][a-zA-Z0-9_]*' "$file" 2>/dev/null \
            | grep -v 'action="\|action=post\|action=get' \
            | sed 's/action=//' \
            | sort -u || true)

        # List iterations (model keys used as iterables)
        LIST_KEYS=$(grep -oP '<#list\s+\(?([a-zA-Z_][a-zA-Z0-9_]*)[!)]?\)?\s+as' "$file" 2>/dev/null \
            | grep -oP '[a-zA-Z_][a-zA-Z0-9_]*' \
            | head -1 || true)

        # Build JSON arrays
        mk_array() {
            local arr="["
            local first=true
            while IFS= read -r item; do
                [ -z "$item" ] && continue
                $first || arr="$arr,"
                first=false
                arr="$arr\"$(json_escape "$item")\""
            done <<< "$1"
            echo "$arr]"
        }

        echo -n "  {\"path\":\"$file\",\"type\":\"$TPL_TYPE\""
        echo -n ",\"modelKeys\":$(mk_array "$MODEL_KEYS")"
        echo -n ",\"i18nKeys\":$(mk_array "$I18N_KEYS")"
        echo -n ",\"formActions\":$(mk_array "$FORM_ACTIONS")"
        echo -n ",\"hiddenActions\":$(mk_array "$HIDDEN_ACTIONS")"
        echo -n ",\"fieldNames\":$(mk_array "$FIELD_NAMES")"
        echo -n ",\"includes\":$(mk_array "$INCLUDES")"
        echo -n ",\"viewLinks\":$(mk_array "$VIEW_LINKS")"
        echo -n ",\"actionLinks\":$(mk_array "$ACTION_LINKS")"
        echo -n "}"
    done < <(find "$dir" -name "*.html" 2>/dev/null | sort)
done

echo ""
echo '],'

# ─── JSP Files ───────────────────────────────────────────
echo '"jsps": ['

FIRST=true
if [ -d "webapp/" ]; then
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        $FIRST || echo ","
        FIRST=false

        # Bean reference: ${beanName.method(...)}
        BEAN_REF=$(grep -oP '\$\{([a-zA-Z_][a-zA-Z0-9_]*)\.(?:init|processController|download|getManage|getCreate|getModify|doCreate|doModify|doRemove)' "$file" 2>/dev/null \
            | head -1 \
            | sed 's/\${//; s/\..*//' || true)

        # useBean class (old pattern)
        BEAN_CLASS=$(grep -oP 'class="[^"]*"' "$file" 2>/dev/null \
            | head -1 \
            | sed 's/class="//; s/"//' || true)

        # Right constant
        RIGHT_CONST=$(grep -oP '\.\(RIGHT_[A-Z_]+\)' "$file" 2>/dev/null \
            | head -1 \
            | sed 's/\.//; s/(//; s/)//' || true)

        # Method calls
        CALLS=$(grep -oP '\$\{[a-zA-Z_]+\.(processController|download|init|getManage[A-Za-z]*|getCreate[A-Za-z]*|getModify[A-Za-z]*|doCreate[A-Za-z]*|doModify[A-Za-z]*|doRemove[A-Za-z]*)' "$file" 2>/dev/null \
            | sed 's/.*\.//' \
            | sort -u || true)

        echo -n "  {\"path\":\"$file\""
        echo -n ",\"beanReference\":\"${BEAN_REF:-}\""
        echo -n ",\"beanClass\":\"${BEAN_CLASS:-}\""
        echo -n ",\"rightConstant\":\"${RIGHT_CONST:-}\""
        echo -n ",\"calls\":[$(echo "$CALLS" | while IFS= read -r c; do [ -n "$c" ] && printf '"%s",' "$c"; done | sed 's/,$//')]"
        echo -n "}"
    done < <(find webapp/ -name "*.jsp" 2>/dev/null | sort)
fi

echo ""
echo ']}'
