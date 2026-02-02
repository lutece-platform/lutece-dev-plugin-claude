#!/bin/bash
# replace-imports.sh — Mass javax→jakarta import replacement
# Usage: bash replace-imports.sh [project_root]
# Only replaces imports that have Jakarta equivalents. Preserves JDK javax.* packages.

set -euo pipefail

PROJECT_ROOT="${1:-.}"
SRC_DIR="$PROJECT_ROOT/src"

if [ ! -d "$SRC_DIR" ]; then
    echo "ERROR: No src/ directory found in $PROJECT_ROOT"
    exit 1
fi

echo "=== javax → jakarta Import Replacement ==="
echo "Target: $SRC_DIR"
echo ""

TOTAL=0

replace_and_count() {
    local pattern="$1"
    local replacement="$2"
    local label="$3"
    local count
    count=$({ grep -rl "$pattern" "$SRC_DIR" --include="*.java" 2>/dev/null || true; } | wc -l)
    if [ "$count" -gt 0 ]; then
        find "$SRC_DIR" -name "*.java" -exec sed -i "s/$pattern/$replacement/g" {} +
        echo "  $label: $count files"
        TOTAL=$((TOTAL + count))
    fi
}

# --- Servlet ---
replace_and_count \
    'javax\.servlet' \
    'jakarta.servlet' \
    'javax.servlet → jakarta.servlet'

# --- Validation ---
replace_and_count \
    'javax\.validation' \
    'jakarta.validation' \
    'javax.validation → jakarta.validation'

# --- Annotations (PostConstruct/PreDestroy) ---
replace_and_count \
    'javax\.annotation\.PostConstruct' \
    'jakarta.annotation.PostConstruct' \
    'javax.annotation.PostConstruct → jakarta'

replace_and_count \
    'javax\.annotation\.PreDestroy' \
    'jakarta.annotation.PreDestroy' \
    'javax.annotation.PreDestroy → jakarta'

# --- Inject ---
replace_and_count \
    'javax\.inject' \
    'jakarta.inject' \
    'javax.inject → jakarta.inject'

# --- CDI (enterprise) ---
replace_and_count \
    'javax\.enterprise' \
    'jakarta.enterprise' \
    'javax.enterprise → jakarta.enterprise'

# --- JAX-RS ---
replace_and_count \
    'javax\.ws\.rs' \
    'jakarta.ws.rs' \
    'javax.ws.rs → jakarta.ws.rs'

# --- JAXB ---
replace_and_count \
    'javax\.xml\.bind' \
    'jakarta.xml.bind' \
    'javax.xml.bind → jakarta.xml.bind'

# --- Transaction ---
replace_and_count \
    'javax\.transaction' \
    'jakarta.transaction' \
    'javax.transaction → jakarta.transaction'

# --- FileItem → MultipartItem ---
FI_COUNT=$({ grep -rl 'org\.apache\.commons\.fileupload\.FileItem' "$SRC_DIR" --include="*.java" 2>/dev/null || true; } | wc -l)
if [ "$FI_COUNT" -gt 0 ]; then
    find "$SRC_DIR" -name "*.java" -exec sed -i \
        's/org\.apache\.commons\.fileupload\.FileItem/fr.paris.lutece.portal.service.upload.MultipartItem/g' {} +
    # Also fix the import statement specifically
    find "$SRC_DIR" -name "*.java" -exec sed -i \
        's/import fr\.paris\.lutece\.portal\.service\.upload\.MultipartItem;/import fr.paris.lutece.portal.service.upload.MultipartItem;/g' {} +
    echo "  FileItem → MultipartItem: $FI_COUNT files"
    TOTAL=$((TOTAL + FI_COUNT))
fi

echo ""
echo "=== RESULT ==="
echo "Files modified: $TOTAL"
echo ""

# Verify no accidental replacements of JDK javax
echo "=== SAFETY CHECK ==="
SAFE_JAVAX=$({ grep -rn 'import jakarta\.cache\|import jakarta\.xml\.transform\|import jakarta\.xml\.parsers\|import jakarta\.crypto\|import jakarta\.net\.\|import jakarta\.sql\.\|import jakarta\.naming\.' "$SRC_DIR" --include="*.java" 2>/dev/null || true; } | wc -l)
if [ "$SAFE_JAVAX" -gt 0 ]; then
    echo "WARNING: Found $SAFE_JAVAX accidental replacements of JDK javax packages!"
    grep -rn 'import jakarta\.cache\|import jakarta\.xml\.transform\|import jakarta\.xml\.parsers\|import jakarta\.crypto\|import jakarta\.net\.\|import jakarta\.sql\.\|import jakarta\.naming\.' "$SRC_DIR" --include="*.java" 2>/dev/null
    echo "These must be reverted to javax.*"
    exit 1
else
    echo "SAFE: No accidental JDK javax replacements detected"
fi
