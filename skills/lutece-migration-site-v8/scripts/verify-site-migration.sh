#!/bin/bash
# verify-site-migration.sh — Run all site migration verification checks
# Usage: bash verify-site-migration.sh [project_root]
# Implements checks defined in verification/checks.md
# Exit code: 0 if all PASS, 1 if any FAIL

set -uo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0
WARN=0
TOTAL=0

# Colors (if terminal supports them)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- Helper functions ---

check_grep() {
    local id="$1"
    local category="$2"
    local pattern="$3"
    local path="$4"
    local severity="$5"
    local description="$6"

    TOTAL=$((TOTAL + 1))

    if [ ! -d "$path" ] && [ ! -f "$path" ]; then
        echo -e "  ${GREEN}PASS${NC} [$id] $description (path $path not found)"
        PASS=$((PASS + 1))
        return
    fi

    local matches
    matches=$(grep -rn "$pattern" "$path" --include="*.xml" --include="*.html" --include="*.js" --include="*.properties" --include="*.jsp" 2>/dev/null) || true
    local count=0
    if [ -n "$matches" ]; then
        count=$(echo "$matches" | wc -l)
    fi

    if [ "$count" -eq 0 ]; then
        echo -e "  ${GREEN}PASS${NC} [$id] $description"
        PASS=$((PASS + 1))
    elif [ "$severity" = "FAIL" ]; then
        echo -e "  ${RED}FAIL${NC} [$id] $description ($count matches)"
        echo "$matches" | head -20 | sed 's/^/    /'
        [ "$count" -gt 20 ] && echo "    ... and $((count - 20)) more"
        FAIL=$((FAIL + 1))
    else
        echo -e "  ${YELLOW}WARN${NC} [$id] $description ($count matches)"
        echo "$matches" | head -20 | sed 's/^/    /'
        [ "$count" -gt 20 ] && echo "    ... and $((count - 20)) more"
        WARN=$((WARN + 1))
    fi
}

check_pom() {
    local id="$1"
    local pattern="$2"
    local severity="$3"
    local description="$4"

    TOTAL=$((TOTAL + 1))

    if [ ! -f "pom.xml" ]; then
        echo -e "  ${GREEN}PASS${NC} [$id] $description (no pom.xml)"
        PASS=$((PASS + 1))
        return
    fi

    local matches
    matches=$(grep -n "$pattern" pom.xml 2>/dev/null) || true
    local count=0
    if [ -n "$matches" ]; then
        count=$(echo "$matches" | wc -l)
    fi

    if [ "$count" -eq 0 ]; then
        echo -e "  ${GREEN}PASS${NC} [$id] $description"
        PASS=$((PASS + 1))
    elif [ "$severity" = "FAIL" ]; then
        echo -e "  ${RED}FAIL${NC} [$id] $description ($count matches)"
        echo "$matches" | head -10 | sed 's/^/    /'
        FAIL=$((FAIL + 1))
    else
        echo -e "  ${YELLOW}WARN${NC} [$id] $description ($count matches)"
        echo "$matches" | head -10 | sed 's/^/    /'
        WARN=$((WARN + 1))
    fi
}

emit_result() {
    local id="$1"
    local severity="$2"
    local description="$3"
    local matches="$4"

    local count=0
    if [ -n "$matches" ]; then
        count=$(echo "$matches" | wc -l)
    fi

    TOTAL=$((TOTAL + 1))

    if [ "$count" -eq 0 ]; then
        echo -e "  ${GREEN}PASS${NC} [$id] $description"
        PASS=$((PASS + 1))
    elif [ "$severity" = "FAIL" ]; then
        echo -e "  ${RED}FAIL${NC} [$id] $description ($count matches)"
        echo "$matches" | head -20 | sed 's/^/    /'
        [ "$count" -gt 20 ] && echo "    ... and $((count - 20)) more"
        FAIL=$((FAIL + 1))
    else
        echo -e "  ${YELLOW}WARN${NC} [$id] $description ($count matches)"
        echo "$matches" | head -20 | sed 's/^/    /'
        [ "$count" -gt 20 ] && echo "    ... and $((count - 20)) more"
        WARN=$((WARN + 1))
    fi
}

echo "=== SITE MIGRATION VERIFICATION REPORT ==="
echo "Project: $(pwd)"
echo ""

# --- POM ---
echo "CATEGORY: POM dependencies"
check_pom "PM01" 'org\.springframework' "FAIL" "Spring dependencies in pom.xml"
check_pom "PM02" 'net\.sf\.ehcache' "FAIL" "EhCache dependencies in pom.xml"
check_pom "PM03" 'com\.sun\.mail' "FAIL" "javax.mail dependency in pom.xml"
check_pom "PM04" 'org\.glassfish\.jersey' "FAIL" "Jersey dependencies in pom.xml"
check_pom "PM05" 'net\.sf\.json-lib' "WARN" "json-lib in pom.xml (use Jackson)"
check_pom "PM07" '<springVersion>' "FAIL" "springVersion property in pom.xml"

# PM06: parent version must be 8.0.0-SNAPSHOT
TOTAL=$((TOTAL + 1))
if [ -f "pom.xml" ]; then
    PARENT_VER=$(sed -n '/<parent>/,/<\/parent>/p' pom.xml | grep '<version>' | head -1 | sed 's/.*<version>\(.*\)<\/version>.*/\1/' | tr -d ' ')
    if [ "$PARENT_VER" = "8.0.0-SNAPSHOT" ]; then
        echo -e "  ${GREEN}PASS${NC} [PM06] Parent version is 8.0.0-SNAPSHOT"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} [PM06] Parent version is '$PARENT_VER' (must be 8.0.0-SNAPSHOT)"
        FAIL=$((FAIL + 1))
    fi
else
    echo -e "  ${GREEN}PASS${NC} [PM06] Parent version check (no pom.xml)"
    PASS=$((PASS + 1))
fi
echo ""

# --- Spring residues ---
echo "CATEGORY: Spring residues"
SP03_MATCHES=""
if [ -d "webapp/" ]; then
    SP03_MATCHES=$(find webapp/ -name "*_context.xml" 2>/dev/null | while read -r f; do
        echo "$f: Spring context XML file must be deleted"
    done) || SP03_MATCHES=""
fi
emit_result "SP03" "FAIL" "Spring context XML files" "$SP03_MATCHES"

check_grep "WB03" "web" 'ContextLoaderListener' "webapp/" "FAIL" "Spring ContextLoaderListener in web.xml"
echo ""

# --- Web / Config ---
echo "CATEGORY: Web / Config"
check_grep "WB01" "web" 'java\.sun\.com/xml/ns/javaee' "webapp/" "FAIL" "Old Java EE namespace → Jakarta EE"

# WB05: Old MySQL JDBC driver
WB05_MATCHES=""
DB_PROPS=$(find . -name "db.properties" -not -path "*/target/*" 2>/dev/null | head -1)
if [ -n "$DB_PROPS" ]; then
    WB05_MATCHES=$(grep -n 'com\.mysql\.jdbc\.Driver' "$DB_PROPS" 2>/dev/null) || WB05_MATCHES=""
fi
emit_result "WB05" "WARN" "Old MySQL driver (use com.mysql.cj.jdbc.Driver)" "$WB05_MATCHES"
echo ""

# --- Templates ---
echo "CATEGORY: Templates"

# TM01: Bootstrap 3/4 panels
check_grep "TM01" "templates" 'class="panel' "webapp/WEB-INF/templates/" "WARN" "Old Bootstrap panels → BS5 cards"

# TM02: jQuery in templates
check_grep "TM02" "templates" 'jQuery\|\$(' "webapp/WEB-INF/templates/" "FAIL" "jQuery in templates → vanilla JS"

# TM03: jQuery in JS files
check_grep "TM03" "templates" 'jQuery\|\$(' "webapp/js/" "FAIL" "jQuery in JS files → vanilla JS"

# TM04: Bootstrap 3/4 data attributes
check_grep "TM04" "templates" 'data-toggle=\|data-target=\|data-dismiss=' "webapp/WEB-INF/templates/" "WARN" "BS3/4 data attributes → data-bs-* (BS5)"

# TM05: jQuery script includes
check_grep "TM05" "templates" 'jquery\.min\.js\|jquery\.js\|jquery-[0-9]' "webapp/WEB-INF/templates/" "FAIL" "jQuery script includes must be removed"

# TM06: jQuery plugins in templates
check_grep "TM06" "templates" 'datepicker\|\.DataTable\|select2\|\.autocomplete' "webapp/WEB-INF/templates/" "WARN" "jQuery plugins → vanilla alternatives"

# TM07: Skin template missing <@cTpl> wrapper
TM07_MATCHES=""
if [ -d "webapp/WEB-INF/templates/skin/" ]; then
    TM07_MATCHES=$(find webapp/WEB-INF/templates/skin/ -name "*.html" 2>/dev/null | while read -r f; do
        if ! grep -q '<@cTpl>' "$f" 2>/dev/null; then
            echo "$f: Skin template missing <@cTpl> wrapper"
        fi
    done) || TM07_MATCHES=""
fi
emit_result "TM07" "WARN" "Skin templates missing <@cTpl> wrapper" "$TM07_MATCHES"
echo ""

# --- SQL ---
echo "CATEGORY: SQL"
SQ01_MATCHES=""
SQL_COUNT=0
find . -name "*.sql" -not -path "./.git/*" -not -path "*/target/*" 2>/dev/null | while read -r f; do
    SQL_COUNT=$((SQL_COUNT + 1))
    if ! head -1 "$f" 2>/dev/null | grep -q 'liquibase formatted sql'; then
        echo "$f: Missing Liquibase header"
    fi
done > /tmp/sq01_matches_$$ 2>/dev/null || true
SQ01_MATCHES=$(cat /tmp/sq01_matches_$$ 2>/dev/null) || SQ01_MATCHES=""
rm -f /tmp/sq01_matches_$$
emit_result "SQ01" "WARN" "SQL files missing Liquibase header" "$SQ01_MATCHES"
echo ""

# --- Summary ---
echo "=========================================="
echo "TOTAL: $TOTAL checks"
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "RESULT: MIGRATION INCOMPLETE — $FAIL check(s) failed"
    exit 1
else
    echo ""
    echo "RESULT: ALL CRITICAL CHECKS PASSED"
    if [ "$WARN" -gt 0 ]; then
        echo "  ($WARN warning(s) — recommended to fix)"
    fi
    exit 0
fi
