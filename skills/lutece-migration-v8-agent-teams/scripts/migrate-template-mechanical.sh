#!/bin/bash
# migrate-template-mechanical.sh — Batch mechanical template migration
# Usage: bash migrate-template-mechanical.sh [project_root]
# Combines: BO macro renames + null-safety + namespace updates

set -euo pipefail

PROJECT_ROOT="${1:-.}"
TEMPLATES_DIR="$PROJECT_ROOT/webapp/WEB-INF/templates"
WEBAPP_DIR="$PROJECT_ROOT/webapp"

TOTAL=0

replace_and_count() {
    local dir="$1"
    local ext="$2"
    local pattern="$3"
    local replacement="$4"
    local label="$5"
    local count
    count=$({ grep -rl "$pattern" "$dir" --include="*.$ext" 2>/dev/null || true; } | wc -l)
    if [ "$count" -gt 0 ]; then
        find "$dir" -name "*.$ext" -exec sed -i "s|$pattern|$replacement|g" {} +
        echo "  $label: $count files" >&2
        TOTAL=$((TOTAL + count))
    fi
}

echo "=== Mechanical Template Migration ===" >&2

# ─── BO Macro Renames (admin templates only) ─────────────

if [ -d "$TEMPLATES_DIR/admin/" ]; then
    echo "--- Admin template BO macro renames ---" >&2
    replace_and_count "$TEMPLATES_DIR/admin" "html" '<@addRequiredJsFiles' '<@addRequiredBOJsFiles' '@addRequiredJsFiles → @addRequiredBOJsFiles'
    replace_and_count "$TEMPLATES_DIR/admin" "html" '<@addFileInput ' '<@addFileBOInput ' '@addFileInput → @addFileBOInput'
    replace_and_count "$TEMPLATES_DIR/admin" "html" '<@addUploadedFilesBox' '<@addBOUploadedFilesBox' '@addUploadedFilesBox → @addBOUploadedFilesBox'
    replace_and_count "$TEMPLATES_DIR/admin" "html" '<@addFileInputAndfilesBox' '<@addFileBOInputAndfilesBox' '@addFileInputAndfilesBox → @addFileBOInputAndfilesBox'
fi

# ─── Null-safety for errors/infos/warnings ───────────────

if [ -d "$TEMPLATES_DIR" ]; then
    echo "--- Null-safety for errors/infos/warnings ---" >&2

    # errors?size → (errors!)?size  (and has_content)
    for var in errors infos warnings; do
        # ?size pattern (not already wrapped with !)
        COUNT=$({ grep -rl "${var}?size\|${var}?has_content" "$TEMPLATES_DIR" --include="*.html" 2>/dev/null \
            | while read -r f; do grep -l "${var}?size\|${var}?has_content" "$f" | grep -v "(${var}!)" 2>/dev/null; done || true; } | sort -u | wc -l)
        if [ "$COUNT" -gt 0 ]; then
            find "$TEMPLATES_DIR" -name "*.html" -exec sed -i \
                "s/${var}?size/(${var}!)?size/g; s/${var}?has_content/(${var}!)?has_content/g" {} +
            # Fix double-wrapping: ((var!)!) → (var!)
            find "$TEMPLATES_DIR" -name "*.html" -exec sed -i \
                "s/((${var}!)!)/($var!)/g" {} +
            echo "  ${var} null-safety: $COUNT files" >&2
            TOTAL=$((TOTAL + COUNT))
        fi
    done

    # <#list errors as → <#list (errors![]) as
    for var in errors infos warnings; do
        COUNT=$({ grep -rl "<#list ${var} as\b" "$TEMPLATES_DIR" --include="*.html" 2>/dev/null || true; } | wc -l)
        if [ "$COUNT" -gt 0 ]; then
            find "$TEMPLATES_DIR" -name "*.html" -exec sed -i \
                "s/<#list ${var} as/<#list (${var}![]) as/g" {} +
            echo "  <#list ${var} null-safety: $COUNT files" >&2
            TOTAL=$((TOTAL + COUNT))
        fi
    done
fi

# ─── MVCMessage: ${error} → ${error.message} ─────────────

if [ -d "$TEMPLATES_DIR" ]; then
    echo "--- MVCMessage ${error} → ${error.message} ---" >&2
    # In <#list errors as error> blocks, ${error} must be ${error.message}
    # (errors are MVCMessage objects in v8, not plain strings)
    COUNT=$({ grep -rl '${error}' "$TEMPLATES_DIR" --include="*.html" 2>/dev/null || true; } | wc -l)
    if [ "$COUNT" -gt 0 ]; then
        # Replace ${error} with ${error.message} but NOT ${error.message} (avoid double-replace)
        find "$TEMPLATES_DIR" -name "*.html" -exec sed -i \
            's/${error}/${error.message}/g' {} +
        # Fix any double-replace: ${error.message.message} → ${error.message}
        find "$TEMPLATES_DIR" -name "*.html" -exec sed -i \
            's/${error\.message\.message}/${error.message}/g' {} +
        echo "  MVCMessage error fix: $COUNT files" >&2
        TOTAL=$((TOTAL + COUNT))
    fi
fi

# ─── web.xml namespace migration ─────────────────────────

if [ -f "$WEBAPP_DIR/WEB-INF/web.xml" ]; then
    if grep -q 'java\.sun\.com/xml/ns/javaee' "$WEBAPP_DIR/WEB-INF/web.xml" 2>/dev/null; then
        sed -i 's|java\.sun\.com/xml/ns/javaee|jakarta.ee/xml/ns/jakartaee|g' "$WEBAPP_DIR/WEB-INF/web.xml"
        sed -i 's|javaee_[0-9]\.xsd|jakartaee_10.xsd|g' "$WEBAPP_DIR/WEB-INF/web.xml"
        echo "  web.xml namespace migration: 1 file" >&2
        TOTAL=$((TOTAL + 1))
    fi
fi

echo "" >&2
echo "=== RESULT: $TOTAL files modified ===" >&2

# JSON output
cat << ENDJSON
{
  "filesModified": $TOTAL
}
ENDJSON
