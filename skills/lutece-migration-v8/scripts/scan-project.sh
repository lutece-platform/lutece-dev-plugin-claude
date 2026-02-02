#!/bin/bash
# scan-project.sh — Scan a Lutece project and output a structured migration inventory
# Usage: bash scan-project.sh [project_root]
# Output: Structured text report for Claude to consume

set -euo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

if [ ! -f "pom.xml" ]; then
    echo "ERROR: No pom.xml found in $PROJECT_ROOT"
    exit 1
fi

# ============================================================
echo "=== PROJECT INFO ==="
# ============================================================

# Detect project type
if grep -q '<type>lutece-plugin</type>\|<packaging>lutece-plugin</packaging>' pom.xml 2>/dev/null; then
    echo "type: plugin"
elif grep -q '<type>lutece-module</type>\|<packaging>lutece-module</packaging>' pom.xml 2>/dev/null; then
    echo "type: module"
elif grep -q '<type>lutece-library</type>\|<packaging>lutece-library</packaging>' pom.xml 2>/dev/null; then
    echo "type: library"
else
    echo "type: unknown"
fi

# Extract artifact info
ARTIFACT=$(grep -m1 '<artifactId>' pom.xml | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/\1/' | tr -d ' ')
VERSION=$(grep -m1 '<version>' pom.xml | sed 's/.*<version>\(.*\)<\/version>.*/\1/' | tr -d ' ')
PARENT_VERSION=$(sed -n '/<parent>/,/<\/parent>/p' pom.xml | grep '<version>' | head -1 | sed 's/.*<version>\(.*\)<\/version>.*/\1/' | tr -d ' ')

echo "artifact: $ARTIFACT"
echo "version: $VERSION"
echo "parent_version: $PARENT_VERSION"

# ============================================================
echo ""
echo "=== LUTECE DEPENDENCIES ==="
# ============================================================

# Extract Lutece dependencies (groupId starting with fr.paris.lutece)
grep -B2 -A2 'fr\.paris\.lutece' pom.xml | grep -E '<artifactId>|<version>|<type>' | sed 's/^[ \t]*//' || echo "(none)"

# ============================================================
echo ""
echo "=== JAVA FILES ==="
# ============================================================

JAVA_COUNT=0
find src/ -name "*.java" 2>/dev/null | sort | while read -r file; do
    JAVA_COUNT=$((JAVA_COUNT + 1))
    echo "FILE: $file"

    # Detect javax imports that need migration
    JAVAX_IMPORTS=$(grep -n 'import javax\.\(servlet\|validation\|annotation\.PostConstruct\|annotation\.PreDestroy\|inject\|enterprise\|ws\.rs\|xml\.bind\)' "$file" 2>/dev/null | head -10) || true
    if [ -n "$JAVAX_IMPORTS" ]; then
        echo "  javax_imports:"
        echo "$JAVAX_IMPORTS" | sed 's/^/    /'
    fi

    # Detect Spring imports
    SPRING_IMPORTS=$(grep -n 'import org\.springframework' "$file" 2>/dev/null | head -10) || true
    if [ -n "$SPRING_IMPORTS" ]; then
        echo "  spring_imports:"
        echo "$SPRING_IMPORTS" | sed 's/^/    /'
    fi

    # Detect SpringContextService calls
    SPRING_BEANS=$(grep -n 'SpringContextService' "$file" 2>/dev/null | head -10) || true
    if [ -n "$SPRING_BEANS" ]; then
        echo "  spring_bean_lookups:"
        echo "$SPRING_BEANS" | sed 's/^/    /'
    fi

    # Detect getInstance() calls (deprecated services)
    GET_INSTANCE=$(grep -n '\.getInstance( )' "$file" 2>/dev/null | head -10) || true
    if [ -n "$GET_INSTANCE" ]; then
        echo "  getInstance_calls:"
        echo "$GET_INSTANCE" | sed 's/^/    /'
    fi

    # Detect existing CDI annotations
    CDI_ANNOT=$(grep -n '@ApplicationScoped\|@RequestScoped\|@SessionScoped\|@Dependent\|@Inject\|@Named\|@Produces' "$file" 2>/dev/null | head -10) || true
    if [ -n "$CDI_ANNOT" ]; then
        echo "  cdi_annotations:"
        echo "$CDI_ANNOT" | sed 's/^/    /'
    fi

    # Detect implements/extends patterns
    IMPLEMENTS=$(grep -n 'implements.*EventRessourceListener\|implements.*InitializingBean\|extends.*AbstractCacheableService\|extends.*MVCApplication\|extends.*MVCAdminJspBean\|extends.*AbstractEntryType\|extends.*PluginDefaultImplementation' "$file" 2>/dev/null | head -5) || true
    if [ -n "$IMPLEMENTS" ]; then
        echo "  class_patterns:"
        echo "$IMPLEMENTS" | sed 's/^/    /'
    fi

    # Detect deprecated patterns
    DEPRECATED=$(grep -n 'daoUtil\.free( )\|ResourceEventManager\|LuteceUserEventManager\|QueryListenersService\|putInCache\|getFromCache\|removeKey\|getModel( )\|net\.sf\.ehcache\|FileImagePublicService\.init\|FileImageService\.init' "$file" 2>/dev/null | head -10) || true
    if [ -n "$DEPRECATED" ]; then
        echo "  deprecated_patterns:"
        echo "$DEPRECATED" | sed 's/^/    /'
    fi

    # Detect class type
    IS_DAO="" ; IS_SERVICE="" ; IS_JSPBEAN="" ; IS_XPAGE="" ; IS_PLUGIN=""
    grep -q 'class.*DAO\b\|implements.*IDAO\|implements.*I[A-Z].*DAO' "$file" 2>/dev/null && IS_DAO="dao"
    grep -q 'class.*Service\b' "$file" 2>/dev/null && IS_SERVICE="service"
    grep -q 'extends.*MVCAdminJspBean\|JspBean' "$file" 2>/dev/null && IS_JSPBEAN="jspbean"
    grep -q 'extends.*MVCApplication\|XPage' "$file" 2>/dev/null && IS_XPAGE="xpage"
    grep -q 'extends.*PluginDefaultImplementation' "$file" 2>/dev/null && IS_PLUGIN="plugin"

    TYPES="$IS_DAO $IS_SERVICE $IS_JSPBEAN $IS_XPAGE $IS_PLUGIN"
    TYPES=$(echo "$TYPES" | xargs)
    if [ -n "$TYPES" ]; then
        echo "  class_type: $TYPES"
    fi

    echo ""
done

# ============================================================
echo "=== CONTEXT XML FILES ==="
# ============================================================

find webapp/ -name "*_context.xml" 2>/dev/null | sort | while read -r file; do
    echo "FILE: $file"
    # Extract bean definitions
    grep -n '<bean ' "$file" 2>/dev/null | sed 's/^/  /' || true
    echo ""
done
if ! find webapp/ -name "*_context.xml" 2>/dev/null | grep -q .; then
    echo "(none)"
fi

# ============================================================
echo ""
echo "=== TEMPLATES ==="
# ============================================================

echo "--- Admin templates ---"
{ find webapp/WEB-INF/templates/admin/ -name "*.html" 2>/dev/null || true; } | sort | while read -r file; do
    [ -z "$file" ] && continue
    FLAGS=""
    grep -q 'jQuery\|\$(' "$file" 2>/dev/null && FLAGS="$FLAGS jquery"
    grep -q 'class="panel\|class="btn ' "$file" 2>/dev/null && FLAGS="$FLAGS bootstrap3"
    grep -q '@pageContainer\|@tform\|@table' "$file" 2>/dev/null && FLAGS="$FLAGS v8macros"
    echo "  $file ${FLAGS:+[${FLAGS# }]}"
done
if ! { find webapp/WEB-INF/templates/admin/ -name "*.html" 2>/dev/null || true; } | grep -q .; then
    echo "  (none)"
fi

echo "--- Skin templates ---"
{ find webapp/WEB-INF/templates/skin/ -name "*.html" 2>/dev/null || true; } | sort | while read -r file; do
    [ -z "$file" ] && continue
    FLAGS=""
    grep -q 'jQuery\|\$(' "$file" 2>/dev/null && FLAGS="$FLAGS jquery"
    grep -q '<@cTpl>' "$file" 2>/dev/null && FLAGS="$FLAGS v8wrap"
    echo "  $file ${FLAGS:+[${FLAGS# }]}"
done
if ! { find webapp/WEB-INF/templates/skin/ -name "*.html" 2>/dev/null || true; } | grep -q .; then
    echo "  (none)"
fi

# ============================================================
echo ""
echo "=== JSP FILES ==="
# ============================================================

find webapp/ -name "*.jsp" 2>/dev/null | sort | while read -r file; do
    FLAGS=""
    grep -q 'jsp:useBean' "$file" 2>/dev/null && FLAGS="$FLAGS useBean"
    grep -q '<%[^@]' "$file" 2>/dev/null && FLAGS="$FLAGS scriptlet"
    grep -q '\${ ' "$file" 2>/dev/null && FLAGS="$FLAGS EL"
    echo "  $file ${FLAGS:+[${FLAGS# }]}"
done
if ! find webapp/ -name "*.jsp" 2>/dev/null | grep -q .; then
    echo "  (none)"
fi

# ============================================================
echo ""
echo "=== SQL FILES ==="
# ============================================================

find src/ -name "*.sql" 2>/dev/null | sort | while read -r file; do
    HAS_HEADER="no"
    head -1 "$file" 2>/dev/null | grep -q 'liquibase formatted sql' && HAS_HEADER="yes"
    echo "  $file [liquibase_header=$HAS_HEADER]"
done
if ! find src/ -name "*.sql" 2>/dev/null | grep -q .; then
    echo "  (none)"
fi

# ============================================================
echo ""
echo "=== REST ENDPOINTS ==="
# ============================================================

grep -rln '@Path\|@GET\|@POST\|@PUT\|@DELETE' src/ 2>/dev/null | sort | while read -r file; do
    echo "  $file"
done
if ! grep -rln '@Path\|@GET\|@POST\|@PUT\|@DELETE' src/ 2>/dev/null | grep -q .; then
    echo "  (none)"
fi

# ============================================================
echo ""
echo "=== PROPERTIES FILES ==="
# ============================================================

find src/ webapp/ -name "*.properties" 2>/dev/null | sort | while read -r file; do
    echo "  $file"
done

# ============================================================
echo ""
echo "=== SUMMARY ==="
# ============================================================

JAVA_FILES=$(find src/ -name "*.java" 2>/dev/null | wc -l)
CONTEXT_FILES=$(find webapp/ -name "*_context.xml" 2>/dev/null | wc -l)
SPRING_LOOKUPS=$(grep -rn 'SpringContextService' src/ 2>/dev/null | wc -l)
GETINSTANCE_CALLS=$(grep -rn '\.getInstance( )' src/ 2>/dev/null | wc -l)
JAVAX_IMPORTS=$(grep -rn 'import javax\.\(servlet\|validation\|annotation\.PostConstruct\|annotation\.PreDestroy\|inject\|enterprise\|ws\.rs\|xml\.bind\)' src/ 2>/dev/null | wc -l)
EVENT_LISTENERS=$(grep -rln 'EventRessourceListener\|LuteceUserEventManager\|QueryListenersService' src/ 2>/dev/null | wc -l)
CACHE_SERVICES=$(grep -rln 'AbstractCacheableService\|net\.sf\.ehcache' src/ 2>/dev/null | wc -l)
ADMIN_TEMPLATES=$({ find webapp/WEB-INF/templates/admin/ -name "*.html" 2>/dev/null || true; } | wc -l)
SKIN_TEMPLATES=$({ find webapp/WEB-INF/templates/skin/ -name "*.html" 2>/dev/null || true; } | wc -l)
JSP_FILES=$(find webapp/ -name "*.jsp" 2>/dev/null | wc -l)
SQL_FILES=$(find src/ -name "*.sql" 2>/dev/null | wc -l)
REST_FILES=$(grep -rln '@Path\|@GET\|@POST\|@PUT\|@DELETE' src/ 2>/dev/null | wc -l)
DAO_FREE=$(grep -rn 'daoUtil\.free( )' src/ 2>/dev/null | wc -l)
DEPRECATED_CACHE=$(grep -rn 'putInCache\|getFromCache\|removeKey' src/ 2>/dev/null | wc -l)
DEPRECATED_GETMODEL=$(grep -rn 'getModel( )' src/ 2>/dev/null | wc -l)

echo "java_files: $JAVA_FILES"
echo "context_xml_files: $CONTEXT_FILES"
echo "spring_lookups: $SPRING_LOOKUPS"
echo "getInstance_calls: $GETINSTANCE_CALLS"
echo "javax_imports: $JAVAX_IMPORTS"
echo "event_listeners: $EVENT_LISTENERS"
echo "cache_services: $CACHE_SERVICES"
echo "admin_templates: $ADMIN_TEMPLATES"
echo "skin_templates: $SKIN_TEMPLATES"
echo "jsp_files: $JSP_FILES"
echo "sql_files: $SQL_FILES"
echo "rest_endpoints: $REST_FILES"
echo "dao_free_calls: $DAO_FREE"
echo "deprecated_cache_methods: $DEPRECATED_CACHE"
echo "deprecated_getModel: $DEPRECATED_GETMODEL"

# Migration scope assessment
echo ""
echo "=== MIGRATION SCOPE ==="
TOTAL_ISSUES=$((SPRING_LOOKUPS + GETINSTANCE_CALLS + JAVAX_IMPORTS + EVENT_LISTENERS + CACHE_SERVICES + DAO_FREE + DEPRECATED_CACHE + DEPRECATED_GETMODEL))
if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo "scope: ALREADY_MIGRATED (no v7 patterns detected)"
elif [ "$TOTAL_ISSUES" -lt 20 ]; then
    echo "scope: SMALL (< 20 migration points)"
elif [ "$TOTAL_ISSUES" -lt 100 ]; then
    echo "scope: MEDIUM (20-100 migration points)"
else
    echo "scope: LARGE (100+ migration points — consider parallel Task agents)"
fi
echo "total_migration_points: $TOTAL_ISSUES"
