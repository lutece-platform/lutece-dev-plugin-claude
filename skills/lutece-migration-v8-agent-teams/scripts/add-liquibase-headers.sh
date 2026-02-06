#!/bin/bash
# add-liquibase-headers.sh — Add Liquibase headers to all SQL files
# Usage: bash add-liquibase-headers.sh [project_root] [plugin_name]

set -euo pipefail

PROJECT_ROOT="${1:-.}"
PLUGIN_NAME="${2:-unknown}"

if [ "$PLUGIN_NAME" = "unknown" ]; then
    if [ -f "$PROJECT_ROOT/pom.xml" ]; then
        PLUGIN_NAME=$(grep -m1 '<artifactId>' "$PROJECT_ROOT/pom.xml" | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/\1/' | tr -d ' ')
    fi
fi

echo "=== Liquibase Header Insertion ==="
echo "Project: $PROJECT_ROOT"
echo "Plugin: $PLUGIN_NAME"
echo ""

TOTAL=0

{ find "$PROJECT_ROOT/src" -name "*.sql" 2>/dev/null || true; } | sort | while read -r file; do
    [ -z "$file" ] && continue
    if head -1 "$file" | grep -q 'liquibase formatted sql'; then
        echo "  SKIP: $file (header exists)"
        continue
    fi

    SCRIPT_NAME=$(basename "$file")
    sed -i "1i\\-- liquibase formatted sql\\n-- changeset ${PLUGIN_NAME}:${SCRIPT_NAME}\\n-- preconditions onFail:MARK_RAN onError:WARN\\n" "$file"

    echo "  ADDED: $file"
    TOTAL=$((TOTAL + 1))
done

echo ""
echo "=== RESULT ==="
echo "Files modified: $TOTAL"
