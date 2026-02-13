#!/bin/bash
# extract-java-flows.sh — Mechanical extraction of Java flow data
# Usage: bash extract-java-flows.sh [project_root]
# Output: JSON to stdout (pipe to .review/java-flows-raw.json)
# This gives the Java Mapper teammate a head start — AI is needed for full constant resolution

set -uo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

json_escape() {
    printf '%s' "$1" | tr -d '\r' | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' '
}

# ─── Bean Classes ────────────────────────────────────────

echo '{"beans": ['
FIRST=true

while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Only JspBeans and XPages
    grep -q 'MVCAdminJspBean\|MVCApplication' "$file" 2>/dev/null || continue

    $FIRST || echo ","
    FIRST=false

    CLASS_NAME=$(grep -oP 'public class (\w+)' "$file" 2>/dev/null | head -1 | sed 's/public class //' || true)

    # @Named value
    NAMED=$(grep -oP '@Named\(\s*"([^"]+)"' "$file" 2>/dev/null | head -1 | sed 's/@Named( "//; s/"//' || true)

    # CDI Scope
    SCOPE="none"
    grep -q '@SessionScoped' "$file" 2>/dev/null && SCOPE="SessionScoped"
    grep -q '@RequestScoped' "$file" 2>/dev/null && SCOPE="RequestScoped"
    grep -q '@ApplicationScoped' "$file" 2>/dev/null && SCOPE="ApplicationScoped"

    # Type
    BEAN_TYPE="unknown"
    grep -q 'MVCAdminJspBean' "$file" 2>/dev/null && BEAN_TYPE="jspbean"
    grep -q 'MVCApplication' "$file" 2>/dev/null && BEAN_TYPE="xpage"

    # RIGHT constants
    RIGHTS=$(grep -oP 'static final String (RIGHT_\w+)\s*=\s*"([^"]*)"' "$file" 2>/dev/null \
        | sed 's/static final String //; s/ = /:/; s/"//g' || true)

    # MARK constants (model keys)
    MARKS=$(grep -oP 'static final String (MARK_\w+)\s*=\s*"([^"]*)"' "$file" 2>/dev/null \
        | sed 's/static final String //; s/ = /:/; s/"//g' || true)

    # VIEW constants
    VIEWS=$(grep -oP 'static final String (VIEW_\w+)\s*=\s*"([^"]*)"' "$file" 2>/dev/null \
        | sed 's/static final String //; s/ = /:/; s/"//g' || true)

    # ACTION constants
    ACTIONS=$(grep -oP 'static final String (ACTION_\w+)\s*=\s*"([^"]*)"' "$file" 2>/dev/null \
        | sed 's/static final String //; s/ = /:/; s/"//g' || true)

    # TEMPLATE constants
    TEMPLATES=$(grep -oP 'static final String (TEMPLATE_\w+)\s*=\s*"([^"]*)"' "$file" 2>/dev/null \
        | sed 's/static final String //; s/ = /:/; s/"//g' || true)

    # model.put calls (line numbers)
    MODEL_PUTS=$(grep -n 'model\.put\|\.put(' "$file" 2>/dev/null \
        | grep -v '//' \
        | head -50 || true)
    MODEL_PUT_COUNT=$(echo "$MODEL_PUTS" | grep -c '.' 2>/dev/null || echo 0)

    # @View annotated methods
    VIEW_METHODS=$(grep -n '@View' "$file" 2>/dev/null | head -20 || true)

    # @Action annotated methods
    ACTION_METHODS=$(grep -n '@Action' "$file" 2>/dev/null | head -20 || true)

    # Service field injections
    SERVICE_FIELDS=$(grep -oP '(?:@Inject\s+)?(?:private|protected)\s+\w+Service\w*\s+_\w+' "$file" 2>/dev/null \
        | sed 's/.*private //; s/.*protected //' || true)

    # request.getParameter calls
    PARAMS=$(grep -oP 'request\.getParameter\(\s*"([^"]*)"' "$file" 2>/dev/null \
        | sed 's/request.getParameter( "//; s/"//' \
        | sort -u || true)

    mk_kv_array() {
        local arr="["
        local first=true
        while IFS= read -r item; do
            [ -z "$item" ] && continue
            local key=$(echo "$item" | cut -d: -f1)
            local val=$(echo "$item" | cut -d: -f2-)
            $first || arr="$arr,"
            first=false
            arr="$arr{\"constant\":\"$key\",\"value\":\"$val\"}"
        done <<< "$1"
        echo "$arr]"
    }

    mk_str_array() {
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

    echo -n "  {\"path\":\"$file\""
    echo -n ",\"className\":\"$CLASS_NAME\""
    echo -n ",\"type\":\"$BEAN_TYPE\""
    echo -n ",\"namedValue\":\"$NAMED\""
    echo -n ",\"scope\":\"$SCOPE\""
    echo -n ",\"rights\":$(mk_kv_array "$RIGHTS")"
    echo -n ",\"marks\":$(mk_kv_array "$MARKS")"
    echo -n ",\"viewConstants\":$(mk_kv_array "$VIEWS")"
    echo -n ",\"actionConstants\":$(mk_kv_array "$ACTIONS")"
    echo -n ",\"templateConstants\":$(mk_kv_array "$TEMPLATES")"
    echo -n ",\"modelPutCount\":$MODEL_PUT_COUNT"
    echo -n ",\"viewMethodCount\":$(echo "$VIEW_METHODS" | grep -c '.' 2>/dev/null || echo 0)"
    echo -n ",\"actionMethodCount\":$(echo "$ACTION_METHODS" | grep -c '.' 2>/dev/null || echo 0)"
    echo -n ",\"serviceFields\":$(mk_str_array "$SERVICE_FIELDS")"
    echo -n ",\"requestParameters\":$(mk_str_array "$PARAMS")"
    echo -n "}"
done < <(find src/ -name "*.java" -not -path '*/test/*' 2>/dev/null | sort)

echo ""
echo '],'

# ─── Service Methods ────────────────────────────────────

echo '"services": ['
FIRST=true

while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Only service classes (not interfaces)
    grep -q 'class.*Service\b' "$file" 2>/dev/null || continue
    grep -q 'public interface' "$file" 2>/dev/null && continue

    $FIRST || echo ","
    FIRST=false

    CLASS_NAME=$(grep -oP 'public class (\w+)' "$file" 2>/dev/null | head -1 | sed 's/public class //' || true)

    # Public method signatures
    METHODS=$(grep -n 'public ' "$file" 2>/dev/null \
        | grep -v 'class\|static final\|interface' \
        | head -30 || true)

    echo -n "  {\"path\":\"$file\""
    echo -n ",\"className\":\"$CLASS_NAME\""
    echo -n ",\"publicMethodCount\":$(echo "$METHODS" | grep -c '.' 2>/dev/null || echo 0)"
    echo -n "}"
done < <(find src/ -name "*Service.java" -not -path '*/test/*' 2>/dev/null | sort)

echo ""
echo '],'

# ─── DAO SQL Extraction ─────────────────────────────────

echo '"daos": ['
FIRST=true

while IFS= read -r file; do
    [ -z "$file" ] && continue
    grep -q 'class.*DAO\b' "$file" 2>/dev/null || continue
    grep -q 'public interface' "$file" 2>/dev/null && continue

    $FIRST || echo ","
    FIRST=false

    CLASS_NAME=$(grep -oP 'public class (\w+)' "$file" 2>/dev/null | head -1 | sed 's/public class //' || true)

    # Extract SQL strings
    SQL_COUNT=$(grep -c 'SQL_QUERY_\|"SELECT\|"INSERT\|"UPDATE\|"DELETE' "$file" 2>/dev/null || echo 0)

    # Table names from SQL
    TABLES=$(grep -oP '(?:FROM|INTO|UPDATE|JOIN)\s+(\w+)' "$file" 2>/dev/null \
        | sed 's/FROM //; s/INTO //; s/UPDATE //; s/JOIN //' \
        | sort -u || true)

    echo -n "  {\"path\":\"$file\""
    echo -n ",\"className\":\"$CLASS_NAME\""
    echo -n ",\"sqlQueryCount\":$SQL_COUNT"
    echo -n ",\"tables\":[$(echo "$TABLES" | while IFS= read -r t; do [ -n "$t" ] && printf '"%s",' "$t"; done | sed 's/,$//')]"
    echo -n "}"
done < <(find src/ -name "*DAO.java" -not -path '*/test/*' 2>/dev/null | sort)

echo ""
echo ']}'
