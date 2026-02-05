#!/bin/bash
# replace-templates-bo.sh — Replace FO macros with BO variants in admin templates
# Usage: bash replace-templates-bo.sh [project_root]
# Only applies to webapp/WEB-INF/templates/admin/

set -euo pipefail

PROJECT_ROOT="${1:-.}"
ADMIN_TEMPLATES="$PROJECT_ROOT/webapp/WEB-INF/templates/admin"

if [ ! -d "$ADMIN_TEMPLATES" ]; then
    echo "INFO: No admin templates directory found at $ADMIN_TEMPLATES"
    exit 0
fi

echo "=== Admin Templates: FO → BO Macro Replacement ==="
echo "Target: $ADMIN_TEMPLATES"
echo ""

TOTAL=0

replace_and_count() {
    local pattern="$1"
    local replacement="$2"
    local label="$3"
    local count
    count=$({ grep -rl "$pattern" "$ADMIN_TEMPLATES" --include="*.html" 2>/dev/null || true; } | wc -l)
    if [ "$count" -gt 0 ]; then
        find "$ADMIN_TEMPLATES" -name "*.html" -exec sed -i "s/$pattern/$replacement/g" {} +
        echo "  $label: $count files"
        TOTAL=$((TOTAL + count))
    fi
}

# --- JS Files macro ---
replace_and_count \
    '<@addRequiredJsFiles' \
    '<@addRequiredBOJsFiles' \
    '@addRequiredJsFiles → @addRequiredBOJsFiles'

# --- File Input macro ---
replace_and_count \
    '<@addFileInput ' \
    '<@addFileBOInput ' \
    '@addFileInput → @addFileBOInput'

# --- Uploaded Files Box macro ---
replace_and_count \
    '<@addUploadedFilesBox' \
    '<@addBOUploadedFilesBox' \
    '@addUploadedFilesBox → @addBOUploadedFilesBox'

# --- File Input And Files Box macro ---
replace_and_count \
    '<@addFileInputAndfilesBox' \
    '<@addFileBOInputAndfilesBox' \
    '@addFileInputAndfilesBox → @addFileBOInputAndfilesBox'

echo ""
echo "=== RESULT ==="
echo "Files modified: $TOTAL"
