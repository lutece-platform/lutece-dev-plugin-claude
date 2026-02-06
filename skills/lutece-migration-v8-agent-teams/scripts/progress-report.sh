#!/bin/bash
# progress-report.sh — Display migration progress from .migration/ state files
# Usage: bash progress-report.sh [project_root]

set -euo pipefail

PROJECT_ROOT="${1:-.}"
MIGRATION_DIR="$PROJECT_ROOT/.migration"

if [ ! -d "$MIGRATION_DIR" ]; then
    echo "No .migration/ directory found. Migration not started."
    exit 0
fi

echo "=== Migration Progress Report ==="
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ─── Scan info ───────────────────────────────────────────

if [ -f "$MIGRATION_DIR/scan.json" ] && command -v jq &>/dev/null; then
    echo "--- Project ---"
    jq -r '"  \(.project.artifact) v\(.project.version) (\(.project.type))"' "$MIGRATION_DIR/scan.json" 2>/dev/null || true
    jq -r '"  Scope: \(.summary.scope) (\(.summary.totalMigrationPoints) migration points)"' "$MIGRATION_DIR/scan.json" 2>/dev/null || true
    echo ""
fi

# ─── Task files status ──────────────────────────────────

echo "--- Task Assignments ---"
for taskfile in "$MIGRATION_DIR"/tasks-*.json; do
    [ ! -f "$taskfile" ] && continue
    BASENAME=$(basename "$taskfile" .json)
    TEAMMATE=$(jq -r '.teammate // "unknown"' "$taskfile" 2>/dev/null || echo "unknown")
    if jq -e '.files' "$taskfile" &>/dev/null; then
        COUNT=$(jq '.files | length' "$taskfile" 2>/dev/null || echo "0")
        echo "  $BASENAME ($TEAMMATE): $COUNT files"
    elif jq -e '.tasks' "$taskfile" &>/dev/null; then
        COUNT=$(jq '.tasks | keys | length' "$taskfile" 2>/dev/null || echo "0")
        echo "  $BASENAME ($TEAMMATE): $COUNT task groups"
    else
        echo "  $BASENAME ($TEAMMATE)"
    fi
done
echo ""

# ─── Context beans status ────────────────────────────────

if [ -f "$MIGRATION_DIR/context-beans.json" ]; then
    BEAN_COUNT=$(jq '.beans | length' "$MIGRATION_DIR/context-beans.json" 2>/dev/null || echo "0")
    PRODUCER_COUNT=$(jq '[.beans[] | select(.needsProducer == true)] | length' "$MIGRATION_DIR/context-beans.json" 2>/dev/null || echo "0")
    echo "--- Context Beans ---"
    echo "  Total beans: $BEAN_COUNT"
    echo "  Need producers: $PRODUCER_COUNT"
    echo ""
fi

# ─── Latest verification ────────────────────────────────

if [ -f "$MIGRATION_DIR/verify-latest.json" ] && command -v jq &>/dev/null; then
    echo "--- Last Verification ---"
    jq -r '"  Checks: \(.total) total | PASS: \(.pass) | FAIL: \(.fail) | WARN: \(.warn)"' "$MIGRATION_DIR/verify-latest.json" 2>/dev/null || true

    # Show failed checks
    FAILS=$(jq -r '[.checks[] | select(.status == "FAIL")] | length' "$MIGRATION_DIR/verify-latest.json" 2>/dev/null || echo "0")
    if [ "$FAILS" -gt 0 ]; then
        echo "  Failed checks:"
        jq -r '.checks[] | select(.status == "FAIL") | "    [\(.id)] \(.description) (\(.count) matches)"' "$MIGRATION_DIR/verify-latest.json" 2>/dev/null || true
    fi
    echo ""
fi

echo "=================================="
