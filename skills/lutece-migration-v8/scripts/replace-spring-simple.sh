#!/bin/bash
# replace-spring-simple.sh — Mechanical Spring→CDI annotation/import replacements
# Usage: bash replace-spring-simple.sh [project_root]
# Only handles exact 1:1 replacements. Does NOT touch SpringContextService calls.

set -euo pipefail

PROJECT_ROOT="${1:-.}"
SRC_DIR="$PROJECT_ROOT/src"

if [ ! -d "$SRC_DIR" ]; then
    echo "ERROR: No src/ directory found in $PROJECT_ROOT"
    exit 1
fi

echo "=== Mechanical Spring → CDI Replacements ==="
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
        find "$SRC_DIR" -name "*.java" -exec sed -i "s|$pattern|$replacement|g" {} +
        echo "  $label: $count files"
        TOTAL=$((TOTAL + count))
    fi
}

# --- Import: @Autowired → @Inject ---
replace_and_count \
    'import org\.springframework\.beans\.factory\.annotation\.Autowired;' \
    'import jakarta.inject.Inject;' \
    '@Autowired import → @Inject import'

# --- Annotation: @Autowired → @Inject ---
replace_and_count \
    '@Autowired' \
    '@Inject' \
    '@Autowired → @Inject'

# --- Import: Spring @Component → CDI @ApplicationScoped ---
replace_and_count \
    'import org\.springframework\.stereotype\.Component;' \
    'import jakarta.enterprise.context.ApplicationScoped;' \
    '@Component import → @ApplicationScoped import'

# --- Annotation: @Component → @ApplicationScoped ---
# Only replace standalone @Component, not @Component("name")
COUNT=$({ grep -rln '@Component$\|@Component[[:space:]]' "$SRC_DIR" --include="*.java" 2>/dev/null || true; } | wc -l)
if [ "$COUNT" -gt 0 ]; then
    find "$SRC_DIR" -name "*.java" -exec sed -i 's/@Component$/@ApplicationScoped/g' {} +
    find "$SRC_DIR" -name "*.java" -exec sed -i 's/@Component[[:space:]]/@ApplicationScoped /g' {} +
    echo "  @Component → @ApplicationScoped: $COUNT files"
    TOTAL=$((TOTAL + COUNT))
fi

# --- Import: Spring @Transactional → Jakarta @Transactional ---
replace_and_count \
    'import org\.springframework\.transaction\.annotation\.Transactional;' \
    'import jakarta.transaction.Transactional;' \
    'Spring @Transactional import → Jakarta'

# --- Import: Spring @Service → CDI @ApplicationScoped ---
replace_and_count \
    'import org\.springframework\.stereotype\.Service;' \
    'import jakarta.enterprise.context.ApplicationScoped;' \
    '@Service import → @ApplicationScoped import'

# --- Annotation: @Service → @ApplicationScoped ---
COUNT=$({ grep -rln '@Service$\|@Service[[:space:]]' "$SRC_DIR" --include="*.java" 2>/dev/null || true; } | wc -l)
if [ "$COUNT" -gt 0 ]; then
    find "$SRC_DIR" -name "*.java" -exec sed -i 's/@Service$/@ApplicationScoped/g' {} +
    find "$SRC_DIR" -name "*.java" -exec sed -i 's/@Service[[:space:]]/@ApplicationScoped /g' {} +
    echo "  @Service → @ApplicationScoped: $COUNT files"
    TOTAL=$((TOTAL + COUNT))
fi

# --- Import: Spring @Repository → CDI @ApplicationScoped ---
replace_and_count \
    'import org\.springframework\.stereotype\.Repository;' \
    'import jakarta.enterprise.context.ApplicationScoped;' \
    '@Repository import → @ApplicationScoped import'

# --- Annotation: @Repository → @ApplicationScoped ---
COUNT=$({ grep -rln '@Repository$\|@Repository[[:space:]]' "$SRC_DIR" --include="*.java" 2>/dev/null || true; } | wc -l)
if [ "$COUNT" -gt 0 ]; then
    find "$SRC_DIR" -name "*.java" -exec sed -i 's/@Repository$/@ApplicationScoped/g' {} +
    find "$SRC_DIR" -name "*.java" -exec sed -i 's/@Repository[[:space:]]/@ApplicationScoped /g' {} +
    echo "  @Repository → @ApplicationScoped: $COUNT files"
    TOTAL=$((TOTAL + COUNT))
fi

# --- Import: Spring InitializingBean → remove (replaced by @PostConstruct) ---
COUNT=$({ grep -rln 'import org\.springframework\.beans\.factory\.InitializingBean;' "$SRC_DIR" --include="*.java" 2>/dev/null || true; } | wc -l)
if [ "$COUNT" -gt 0 ]; then
    find "$SRC_DIR" -name "*.java" -exec sed -i '/import org\.springframework\.beans\.factory\.InitializingBean;/d' {} +
    echo "  Removed InitializingBean import: $COUNT files"
    TOTAL=$((TOTAL + COUNT))
fi

# --- Transactional annotation: remove bean manager reference ---
COUNT=$({ grep -rln '@Transactional( *"[^"]*" *)' "$SRC_DIR" --include="*.java" 2>/dev/null || true; } | wc -l)
if [ "$COUNT" -gt 0 ]; then
    find "$SRC_DIR" -name "*.java" -exec sed -i 's/@Transactional( *"[^"]*" *)/@Transactional/g' {} +
    echo "  @Transactional("beanManager") → @Transactional: $COUNT files"
    TOTAL=$((TOTAL + COUNT))
fi

echo ""
echo "=== RESULT ==="
echo "Files modified: $TOTAL"
echo ""

# Report remaining Spring references for manual handling
REMAINING=$({ grep -rn 'org\.springframework' "$SRC_DIR" --include="*.java" 2>/dev/null || true; } | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo "=== REMAINING SPRING REFERENCES (need manual review) ==="
    grep -rn 'org\.springframework' "$SRC_DIR" --include="*.java" 2>/dev/null | head -30
    echo ""
    echo "Total remaining: $REMAINING"
fi

SPRING_CTX=$({ grep -rn 'SpringContextService' "$SRC_DIR" --include="*.java" 2>/dev/null || true; } | wc -l)
if [ "$SPRING_CTX" -gt 0 ]; then
    echo ""
    echo "=== SpringContextService CALLS (need intelligent replacement) ==="
    grep -rn 'SpringContextService' "$SRC_DIR" --include="*.java" 2>/dev/null | head -30
    echo ""
    echo "Total: $SPRING_CTX"
fi
