#!/bin/bash
# scan-site.sh — Scan a Lutece site project and output a structured migration inventory
# Usage: bash scan-site.sh [project_root]
# Output: Structured text report for Claude to consume

set -euo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

if [ ! -f "pom.xml" ]; then
    echo "ERROR: No pom.xml found in $PROJECT_ROOT"
    exit 1
fi

# ============================================================
echo "=== SITE INFO ==="
# ============================================================

# Verify this is a site project
if grep -q '<packaging>lutece-site</packaging>\|<type>lutece-site</type>' pom.xml 2>/dev/null; then
    echo "type: lutece-site"
else
    echo "type: UNKNOWN (expected lutece-site packaging)"
    echo "WARNING: This may not be a Lutece site project"
fi

# Extract artifact info
ARTIFACT=$(grep -m1 '<artifactId>' pom.xml | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/\1/' | tr -d ' ')
VERSION=$(grep -m1 '<version>' pom.xml | sed 's/.*<version>\(.*\)<\/version>.*/\1/' | tr -d ' ')
PARENT_VERSION=$(sed -n '/<parent>/,/<\/parent>/p' pom.xml | grep '<version>' | head -1 | sed 's/.*<version>\(.*\)<\/version>.*/\1/' | tr -d ' ')
PARENT_ARTIFACT=$(sed -n '/<parent>/,/<\/parent>/p' pom.xml | grep '<artifactId>' | head -1 | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/\1/' | tr -d ' ')

echo "artifact: $ARTIFACT"
echo "version: $VERSION"
echo "parent_artifact: $PARENT_ARTIFACT"
echo "parent_version: $PARENT_VERSION"

# Check if already V8
if echo "$PARENT_VERSION" | grep -q '8\.0\.0'; then
    echo "STATUS: Already V8 (parent version contains 8.0.0)"
fi

# Check for starters
STARTERS=$(grep -o 'fr\.paris\.lutece\.starters.*</groupId>' pom.xml 2>/dev/null | wc -l || echo "0")
if [ "$STARTERS" -gt 0 ]; then
    echo "starters_detected: yes"
    grep -B1 -A3 'fr\.paris\.lutece\.starters' pom.xml | grep '<artifactId>' | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/  starter: \1/' | tr -d ' '
else
    echo "starters_detected: no"
fi

# Check for BOM
if grep -q 'lutece-bom' pom.xml 2>/dev/null; then
    echo "bom_detected: yes"
else
    echo "bom_detected: no"
fi

# ============================================================
echo ""
echo "=== LUTECE DEPENDENCIES ==="
# ============================================================

# Extract all Lutece dependencies with their details
python3 -c "
import xml.etree.ElementTree as ET
import re

tree = ET.parse('pom.xml')
root = tree.getroot()
ns = {'m': 'http://maven.apache.org/POM/4.0.0'}

# Try with namespace first, then without
deps = root.findall('.//m:dependency', ns)
if not deps:
    deps = root.findall('.//dependency')

for dep in deps:
    gid = dep.find('m:groupId', ns) if dep.find('m:groupId', ns) is not None else dep.find('groupId')
    aid = dep.find('m:artifactId', ns) if dep.find('m:artifactId', ns) is not None else dep.find('artifactId')
    ver = dep.find('m:version', ns) if dep.find('m:version', ns) is not None else dep.find('version')
    typ = dep.find('m:type', ns) if dep.find('m:type', ns) is not None else dep.find('type')

    if gid is not None and 'fr.paris.lutece' in (gid.text or ''):
        g = gid.text if gid is not None else '?'
        a = aid.text if aid is not None else '?'
        v = ver.text if ver is not None else '?'
        t = typ.text if typ is not None else 'jar'
        print(f'  {a} | version={v} | type={t} | groupId={g}')
" 2>/dev/null || {
    # Fallback: simple grep-based extraction
    echo "(Python parsing failed, using grep fallback)"
    grep -B2 -A3 'fr\.paris\.lutece' pom.xml | grep -E '<artifactId>|<version>|<type>' | sed 's/^[ \t]*/  /'
}

# ============================================================
echo ""
echo "=== LIBERTY CONFIG (V8) ==="
# ============================================================

LIBERTY_DIR="src/main/liberty/config"
if [ -d "$LIBERTY_DIR" ]; then
    echo "liberty_config: FOUND"
    for f in server.xml server.env bootstrap.properties jvm.options; do
        if [ -f "$LIBERTY_DIR/$f" ]; then
            echo "  $LIBERTY_DIR/$f [FOUND]"
        else
            echo "  $LIBERTY_DIR/$f [MISSING]"
        fi
    done
else
    echo "liberty_config: NOT FOUND (needs to be created for V8)"
fi

# ============================================================
echo ""
echo "=== OVERRIDE CONFIG ==="
# ============================================================

OVERRIDE_DIR="webapp/WEB-INF/conf/override"
if [ -d "$OVERRIDE_DIR" ]; then
    echo "override_config: FOUND"
    find "$OVERRIDE_DIR" -name "*.properties" 2>/dev/null | while read -r f; do
        echo "  $f"
    done
else
    echo "override_config: NOT FOUND"
fi

# ============================================================
echo ""
echo "=== CONFIG FILES ==="
# ============================================================

# db.properties
if [ -f "src/conf/default/WEB-INF/conf/db.properties" ]; then
    echo "  src/conf/default/WEB-INF/conf/db.properties [FOUND]"
    # Check JDBC driver
    DRIVER=$(grep 'portal.poolservice.lutece.driver' "src/conf/default/WEB-INF/conf/db.properties" 2>/dev/null | head -1) || true
    if [ -n "$DRIVER" ]; then
        echo "    $DRIVER"
        if echo "$DRIVER" | grep -q 'com.mysql.jdbc.Driver'; then
            echo "    WARNING: Old MySQL driver, should be com.mysql.cj.jdbc.Driver"
        fi
    fi
else
    echo "  src/conf/default/WEB-INF/conf/db.properties [NOT FOUND]"
fi

# web.xml
find . -name "web.xml" -not -path "./.git/*" -not -path "*/target/*" 2>/dev/null | sort | while read -r file; do
    FLAGS=""
    grep -q 'java\.sun\.com/xml/ns/javaee' "$file" 2>/dev/null && FLAGS="$FLAGS old-namespace"
    grep -q 'ContextLoaderListener' "$file" 2>/dev/null && FLAGS="$FLAGS spring-listener"
    grep -q 'jakarta\.ee' "$file" 2>/dev/null && FLAGS="$FLAGS jakarta-ok"
    echo "  $file ${FLAGS:+[${FLAGS# }]}"
done

# Spring context XML
CONTEXT_COUNT=0
find . -name "*_context.xml" -not -path "./.git/*" -not -path "*/target/*" 2>/dev/null | sort | while read -r file; do
    echo "  $file [SPRING-CONTEXT — must delete]"
    CONTEXT_COUNT=$((CONTEXT_COUNT + 1))
done
if [ "$CONTEXT_COUNT" -eq 0 ] 2>/dev/null; then
    find . -name "*_context.xml" -not -path "./.git/*" -not -path "*/target/*" 2>/dev/null | grep -q . || echo "  (no Spring context XML files)"
fi

# Properties files
find . -name "*.properties" -not -path "./.git/*" -not -path "*/target/*" 2>/dev/null | sort | while read -r file; do
    echo "  $file"
done

# ============================================================
echo ""
echo "=== TEMPLATES ==="
# ============================================================

echo "--- Skin templates ---"
{ find webapp/WEB-INF/templates/skin/ -name "*.html" 2>/dev/null || true
  find src/ -path "*/templates/skin/*.html" 2>/dev/null || true; } | sort -u | while read -r file; do
    [ -z "$file" ] && continue
    FLAGS=""
    grep -q 'jQuery\|\$(' "$file" 2>/dev/null && FLAGS="$FLAGS jquery"
    grep -q 'class="panel\|class="btn-default\|data-toggle=' "$file" 2>/dev/null && FLAGS="$FLAGS bootstrap3/4"
    grep -q '<@cTpl>' "$file" 2>/dev/null && FLAGS="$FLAGS v8wrap"
    grep -q 'datepicker\|DataTable\|select2\|autocomplete' "$file" 2>/dev/null && FLAGS="$FLAGS jquery-plugins"
    echo "  $file ${FLAGS:+[${FLAGS# }]}"
done
if ! { find webapp/WEB-INF/templates/skin/ -name "*.html" 2>/dev/null || true
       find src/ -path "*/templates/skin/*.html" 2>/dev/null || true; } | grep -q .; then
    echo "  (none)"
fi

echo "--- Admin templates (if customized) ---"
{ find webapp/WEB-INF/templates/admin/ -name "*.html" 2>/dev/null || true; } | sort | while read -r file; do
    [ -z "$file" ] && continue
    FLAGS=""
    grep -q 'jQuery\|\$(' "$file" 2>/dev/null && FLAGS="$FLAGS jquery"
    grep -q 'class="panel' "$file" 2>/dev/null && FLAGS="$FLAGS bootstrap3"
    grep -q '@pageContainer\|@tform\|@table' "$file" 2>/dev/null && FLAGS="$FLAGS v8macros"
    echo "  $file ${FLAGS:+[${FLAGS# }]}"
done
if ! { find webapp/WEB-INF/templates/admin/ -name "*.html" 2>/dev/null || true; } | grep -q .; then
    echo "  (none)"
fi

# ============================================================
echo ""
echo "=== JAVASCRIPT FILES ==="
# ============================================================

find webapp/ -name "*.js" -not -path "*/target/*" 2>/dev/null | sort | while read -r file; do
    FLAGS=""
    grep -q 'jQuery\|\$(' "$file" 2>/dev/null && FLAGS="$FLAGS jquery"
    grep -q '\.ajax\|\.get\|\.post' "$file" 2>/dev/null && FLAGS="$FLAGS ajax"
    grep -q 'datepicker\|DataTable\|select2' "$file" 2>/dev/null && FLAGS="$FLAGS plugins"
    echo "  $file ${FLAGS:+[${FLAGS# }]}"
done
if ! find webapp/ -name "*.js" -not -path "*/target/*" 2>/dev/null | grep -q .; then
    echo "  (none)"
fi

# ============================================================
echo ""
echo "=== SQL FILES ==="
# ============================================================

find . -name "*.sql" -not -path "./.git/*" -not -path "*/target/*" 2>/dev/null | sort | while read -r file; do
    HAS_HEADER="no"
    head -1 "$file" 2>/dev/null | grep -q 'liquibase formatted sql' && HAS_HEADER="yes"
    echo "  $file [liquibase_header=$HAS_HEADER]"
done
if ! find . -name "*.sql" -not -path "./.git/*" -not -path "*/target/*" 2>/dev/null | grep -q .; then
    echo "  (none)"
fi

# ============================================================
echo ""
echo "=== SUMMARY ==="
# ============================================================

LUTECE_DEPS=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('pom.xml')
root = tree.getroot()
ns = {'m': 'http://maven.apache.org/POM/4.0.0'}
deps = root.findall('.//m:dependency', ns)
if not deps:
    deps = root.findall('.//dependency')
count = 0
for dep in deps:
    gid = dep.find('m:groupId', ns) if dep.find('m:groupId', ns) is not None else dep.find('groupId')
    if gid is not None and 'fr.paris.lutece' in (gid.text or ''):
        count += 1
print(count)
" 2>/dev/null || grep -c 'fr\.paris\.lutece' pom.xml 2>/dev/null || echo "0")

SKIN_TEMPLATES=$({ find webapp/WEB-INF/templates/skin/ -name "*.html" 2>/dev/null || true
                    find src/ -path "*/templates/skin/*.html" 2>/dev/null || true; } | sort -u | wc -l)
ADMIN_TEMPLATES=$({ find webapp/WEB-INF/templates/admin/ -name "*.html" 2>/dev/null || true; } | wc -l)
JS_FILES=$(find webapp/ -name "*.js" -not -path "*/target/*" 2>/dev/null | wc -l)
SQL_FILES=$(find . -name "*.sql" -not -path "./.git/*" -not -path "*/target/*" 2>/dev/null | wc -l)
CONTEXT_FILES=$(find . -name "*_context.xml" -not -path "./.git/*" -not -path "*/target/*" 2>/dev/null | wc -l)

JQUERY_TEMPLATES=$({ find webapp/WEB-INF/templates/ -name "*.html" 2>/dev/null || true; } | while read -r f; do
    [ -z "$f" ] && continue
    grep -lq 'jQuery\|\$(' "$f" 2>/dev/null && echo "$f"
done | wc -l)

JQUERY_JS=$(find webapp/ -name "*.js" -not -path "*/target/*" 2>/dev/null | while read -r f; do
    grep -lq 'jQuery\|\$(' "$f" 2>/dev/null && echo "$f"
done | wc -l)

echo "lutece_dependencies: $LUTECE_DEPS"
echo "skin_templates: $SKIN_TEMPLATES"
echo "admin_templates: $ADMIN_TEMPLATES"
echo "js_files: $JS_FILES"
echo "sql_files: $SQL_FILES"
echo "spring_context_files: $CONTEXT_FILES"
echo "templates_with_jquery: $JQUERY_TEMPLATES"
echo "js_files_with_jquery: $JQUERY_JS"

# Additional V8 checks
HAS_LIBERTY=$( [ -d "src/main/liberty/config" ] && echo "yes" || echo "no" )
HAS_STARTERS=$(grep -q 'fr\.paris\.lutece\.starters' pom.xml 2>/dev/null && echo "yes" || echo "no")
HAS_BOM=$(grep -q 'lutece-bom' pom.xml 2>/dev/null && echo "yes" || echo "no")
IS_V8_PARENT=$(echo "$PARENT_VERSION" | grep -q '8\.0\.0' && echo "yes" || echo "no")

echo "liberty_config: $HAS_LIBERTY"
echo "uses_starters: $HAS_STARTERS"
echo "uses_bom: $HAS_BOM"
echo "is_v8_parent: $IS_V8_PARENT"

# Migration scope
TOTAL_ISSUES=$((JQUERY_TEMPLATES + JQUERY_JS + CONTEXT_FILES))
echo ""
echo "=== MIGRATION SCOPE ==="

# Determine site type
if [ "$IS_V8_PARENT" = "yes" ] && [ "$HAS_LIBERTY" = "yes" ] && [ "$HAS_STARTERS" = "yes" ]; then
    echo "site_type: V8_PACK_STARTER (already V8 with starter pattern)"
    echo "scope: NONE (site is already V8)"
elif [ "$IS_V8_PARENT" = "yes" ]; then
    echo "site_type: V8_CLASSIC (already V8 but may need config updates)"
    echo "scope: MINIMAL (verify config only)"
elif [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo "site_type: V7_MINIMAL"
    echo "scope: MINIMAL (POM + config only, no jQuery or Spring context to migrate)"
    echo "recommendation: Consider converting to V8 pack starter pattern"
elif [ "$TOTAL_ISSUES" -lt 10 ]; then
    echo "site_type: V7_SMALL"
    echo "scope: SMALL (< 10 files with jQuery/Spring)"
elif [ "$TOTAL_ISSUES" -lt 50 ]; then
    echo "site_type: V7_MEDIUM"
    echo "scope: MEDIUM (10-50 files to migrate)"
else
    echo "site_type: V7_LARGE"
    echo "scope: LARGE (50+ files — consider parallel Task agents for templates)"
fi
echo "total_migration_points: $TOTAL_ISSUES"
