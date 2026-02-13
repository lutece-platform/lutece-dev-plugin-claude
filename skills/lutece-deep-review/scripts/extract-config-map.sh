#!/bin/bash
# extract-config-map.sh — Mechanical extraction of configuration data
# Usage: bash extract-config-map.sh [project_root]
# Output: JSON to stdout (pipe to .review/config-map-raw.json)
# Gives the Config Mapper teammate a head start

set -uo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

json_escape() {
    printf '%s' "$1" | tr -d '\r' | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' '
}

# ─── Plugin Descriptors ─────────────────────────────────

echo '{"pluginDescriptors": ['
FIRST=true

if [ -d "webapp/WEB-INF/plugins/" ]; then
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        $FIRST || echo ","
        FIRST=false

        PLUGIN_NAME=$(grep -oP '(?<=<plugin-name>)[^<]+' "$file" 2>/dev/null | head -1 | tr -d ' \r' || true)

        # Rights
        RIGHTS_JSON="["
        RFIRST=true
        while IFS= read -r right_name; do
            [ -z "$right_name" ] && continue
            right_name=$(echo "$right_name" | tr -d ' \r\t')
            $RFIRST || RIGHTS_JSON="$RIGHTS_JSON,"
            RFIRST=false
            RIGHTS_JSON="$RIGHTS_JSON\"$right_name\""
        done < <(grep -oP '(?<=name=")[^"]+' "$file" 2>/dev/null | head -20 || true)
        RIGHTS_JSON="$RIGHTS_JSON]"

        # XPage applications
        XPAGES_JSON="["
        XFIRST=true
        while IFS= read -r app_id; do
            [ -z "$app_id" ] && continue
            app_id=$(echo "$app_id" | tr -d ' \r\t')
            $XFIRST || XPAGES_JSON="$XPAGES_JSON,"
            XFIRST=false
            XPAGES_JSON="$XPAGES_JSON\"$app_id\""
        done < <(grep -oP '(?<=<application-id>)[^<]+' "$file" 2>/dev/null || true)
        XPAGES_JSON="$XPAGES_JSON]"

        # Daemons
        DAEMONS_JSON="["
        DFIRST=true
        while IFS= read -r daemon_id; do
            [ -z "$daemon_id" ] && continue
            daemon_id=$(echo "$daemon_id" | tr -d ' \r\t')
            $DFIRST || DAEMONS_JSON="$DAEMONS_JSON,"
            DFIRST=false
            DAEMONS_JSON="$DAEMONS_JSON\"$daemon_id\""
        done < <(grep -oP '(?<=<daemon-id>)[^<]+' "$file" 2>/dev/null || true)
        DAEMONS_JSON="$DAEMONS_JSON]"

        # RBAC resource types
        RBAC_JSON="["
        BFIRST=true
        while IFS= read -r rbac_key; do
            [ -z "$rbac_key" ] && continue
            rbac_key=$(echo "$rbac_key" | tr -d ' \r\t')
            $BFIRST || RBAC_JSON="$RBAC_JSON,"
            BFIRST=false
            RBAC_JSON="$RBAC_JSON\"$rbac_key\""
        done < <(grep -oP '(?<=<rbac-resource-type-key>)[^<]+' "$file" 2>/dev/null || true)
        RBAC_JSON="$RBAC_JSON]"

        echo -n "  {\"path\":\"$file\""
        echo -n ",\"pluginName\":\"${PLUGIN_NAME:-unknown}\""
        echo -n ",\"rights\":$RIGHTS_JSON"
        echo -n ",\"xpageApplications\":$XPAGES_JSON"
        echo -n ",\"daemons\":$DAEMONS_JSON"
        echo -n ",\"rbacResourceTypes\":$RBAC_JSON"
        echo -n "}"
    done < <(find webapp/WEB-INF/plugins/ -name "*.xml" 2>/dev/null | sort)
fi

echo ""
echo '],'

# ─── i18n Keys ──────────────────────────────────────────

echo '"i18nKeys": ['
FIRST=true

while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Only default locale (no _fr, _de suffix — or _en as common default)
    BASENAME=$(basename "$file" .properties)
    # Skip locale variants that aren't _en (keep base and _en)
    echo "$BASENAME" | grep -qP '_[a-z]{2}$' && ! echo "$BASENAME" | grep -q '_en$' && continue

    while IFS='=' read -r key _value; do
        [ -z "$key" ] && continue
        # Skip comments
        echo "$key" | grep -q '^#' && continue
        echo "$key" | grep -q '^\s*$' && continue
        key=$(echo "$key" | tr -d ' \r\t')
        [ -z "$key" ] && continue

        $FIRST || echo ","
        FIRST=false
        echo -n "  \"$key\""
    done < "$file"
done < <({ find src/ -name "*.properties" 2>/dev/null || true; } | sort)

echo ""
echo '],'

# ─── SQL Tables ─────────────────────────────────────────

echo '"sqlTables": ['
FIRST=true

while IFS= read -r file; do
    [ -z "$file" ] && continue

    while IFS= read -r table_line; do
        [ -z "$table_line" ] && continue
        TABLE_NAME=$(echo "$table_line" | grep -oP '(?:CREATE TABLE(?:\s+IF NOT EXISTS)?)\s+(\w+)' | sed 's/CREATE TABLE//; s/IF NOT EXISTS//; s/ //g' || true)
        [ -z "$TABLE_NAME" ] && continue

        $FIRST || echo ","
        FIRST=false

        # Extract columns from CREATE TABLE block
        COLS=$(sed -n "/CREATE TABLE.*${TABLE_NAME}/,/);/p" "$file" 2>/dev/null \
            | grep -oP '^\s+(\w+)\s+(INT|VARCHAR|LONG VARCHAR|TEXT|DATE|TIMESTAMP|SMALLINT|BIGINT|BOOLEAN|FLOAT|DOUBLE)' \
            | awk '{print $1}' \
            | sort || true)

        echo -n "  {\"table\":\"$TABLE_NAME\",\"file\":\"$file\""
        echo -n ",\"columns\":[$(echo "$COLS" | while IFS= read -r c; do [ -n "$c" ] && printf '"%s",' "$c"; done | sed 's/,$//')]"
        echo -n "}"
    done < <(grep -n 'CREATE TABLE' "$file" 2>/dev/null || true)
done < <(find src/ -name "*.sql" 2>/dev/null | sort)

echo ""
echo '],'

# ─── Config Properties ──────────────────────────────────

echo '"configProperties": ['
FIRST=true

if [ -d "webapp/WEB-INF/conf/plugins/" ]; then
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        while IFS='=' read -r key _value; do
            [ -z "$key" ] && continue
            echo "$key" | grep -q '^#' && continue
            key=$(echo "$key" | tr -d ' \r\t')
            [ -z "$key" ] && continue

            $FIRST || echo ","
            FIRST=false
            echo -n "  \"$key\""
        done < "$file"
    done < <(find webapp/WEB-INF/conf/plugins/ -name "*.properties" 2>/dev/null | sort)
fi

echo ""
echo ']}'
