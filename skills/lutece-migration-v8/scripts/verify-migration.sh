#!/bin/bash
# verify-migration.sh — Run all migration verification checks
# Usage: bash verify-migration.sh [project_root]
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

# ─── Helper functions ────────────────────────────────────

check_grep() {
    local id="$1"
    local category="$2"
    local pattern="$3"
    local path="$4"
    local severity="$5"
    local description="$6"

    TOTAL=$((TOTAL + 1))

    if [ ! -d "$path" ]; then
        echo -e "  ${GREEN}PASS${NC} [$id] $description (path $path not found)"
        PASS=$((PASS + 1))
        return
    fi

    local matches
    matches=$(grep -rn "$pattern" "$path" --include="*.java" --include="*.xml" --include="*.html" --include="*.jsp" 2>/dev/null) || true
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

check_file_exists() {
    local id="$1"
    local filepath="$2"
    local severity="$3"
    local description="$4"

    TOTAL=$((TOTAL + 1))

    if [ -f "$filepath" ]; then
        echo -e "  ${GREEN}PASS${NC} [$id] $description"
        PASS=$((PASS + 1))
    elif [ "$severity" = "FAIL" ]; then
        echo -e "  ${RED}FAIL${NC} [$id] $description (file not found: $filepath)"
        FAIL=$((FAIL + 1))
    else
        echo -e "  ${YELLOW}WARN${NC} [$id] $description (file not found: $filepath)"
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

# emit_result — shared logic for custom checks
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

echo "=== MIGRATION VERIFICATION REPORT ==="
echo "Project: $(pwd)"
echo ""

# ─── POM ─────────────────────────────────────────────────
echo "CATEGORY: POM dependencies"
check_pom "PM01" 'org\.springframework' "FAIL" "Spring dependencies in pom.xml"
check_pom "PM02" 'net\.sf\.ehcache' "FAIL" "EhCache dependencies in pom.xml"
check_pom "PM03" 'com\.sun\.mail' "FAIL" "javax.mail dependency in pom.xml"
check_pom "PM04" 'org\.glassfish\.jersey' "FAIL" "Jersey dependencies in pom.xml"
check_pom "PM05" 'net\.sf\.json-lib' "WARN" "json-lib in pom.xml (use Jackson)"
check_pom "PM07" '<springVersion>' "FAIL" "springVersion property in pom.xml"

# PM06: parent version must be 8.0.0-SNAPSHOT (inverted check)
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

# ─── javax Residues ───────────────────────────────────────
echo "CATEGORY: javax residues"
check_grep "JX01" "javax" 'javax\.servlet' "src/" "FAIL" "javax.servlet → jakarta.servlet"
check_grep "JX02" "javax" 'javax\.validation' "src/" "FAIL" "javax.validation → jakarta.validation"
check_grep "JX03" "javax" 'javax\.annotation\.PostConstruct\|javax\.annotation\.PreDestroy' "src/" "FAIL" "javax.annotation.PostConstruct/PreDestroy → jakarta"
check_grep "JX04" "javax" 'javax\.inject' "src/" "FAIL" "javax.inject → jakarta.inject"
check_grep "JX05" "javax" 'javax\.enterprise' "src/" "FAIL" "javax.enterprise → jakarta.enterprise"
check_grep "JX06" "javax" 'javax\.ws\.rs' "src/" "FAIL" "javax.ws.rs → jakarta.ws.rs"
check_grep "JX07" "javax" 'javax\.xml\.bind' "src/" "FAIL" "javax.xml.bind → jakarta.xml.bind"
check_grep "JX08" "javax" 'javax\.transaction\.Transactional\|import javax\.transaction\.[^x]' "src/" "FAIL" "javax.transaction → jakarta.transaction"
echo ""

# ─── Spring Residues ──────────────────────────────────────
echo "CATEGORY: Spring residues"
check_grep "SP01" "spring" 'SpringContextService' "src/" "FAIL" "SpringContextService → CDI"
check_grep "SP02" "spring" 'org\.springframework' "src/" "FAIL" "Spring imports"
check_grep "SP03" "spring" '_context\.xml' "webapp/" "FAIL" "Spring context XML files"
check_grep "SP04" "spring" '@Autowired' "src/" "FAIL" "@Autowired → @Inject"
check_grep "SP05" "spring" 'implements.*InitializingBean' "src/" "FAIL" "InitializingBean → @PostConstruct"

# SP06-SP08: Named Spring annotations not handled by replace-spring-simple.sh
check_grep "SP06" "spring" '@Component(' "src/" "FAIL" "@Component(\"name\") → @ApplicationScoped @Named(\"name\")"
check_grep "SP07" "spring" '@Service(' "src/" "FAIL" "@Service(\"name\") → @ApplicationScoped @Named(\"name\")"
check_grep "SP08" "spring" '@Repository(' "src/" "FAIL" "@Repository(\"name\") → @ApplicationScoped @Named(\"name\")"
echo ""

# ─── Event Residues ───────────────────────────────────────
echo "CATEGORY: Event residues"
check_grep "EV01" "events" 'ResourceEventManager' "src/" "FAIL" "ResourceEventManager → CDI events"
check_grep "EV02" "events" 'EventRessourceListener' "src/" "FAIL" "EventRessourceListener → @Observes"
check_grep "EV03" "events" 'LuteceUserEventManager' "src/" "FAIL" "LuteceUserEventManager → CDI events"
check_grep "EV04" "events" 'QueryListenersService' "src/" "FAIL" "QueryListenersService → CDI events"
check_grep "EV05" "events" 'AbstractEventManager' "src/" "FAIL" "AbstractEventManager → CDI events"
echo ""

# ─── Cache Residues ───────────────────────────────────────
echo "CATEGORY: Cache residues"
check_grep "CA01" "cache" 'net\.sf\.ehcache' "src/" "FAIL" "EhCache → JCache"
check_grep "CA02" "cache" 'putInCache\|getFromCache\|removeKey' "src/" "FAIL" "Deprecated cache methods"
check_grep "CA03" "cache" 'extends AbstractCacheableService[^<]' "src/" "FAIL" "Raw AbstractCacheableService (needs type params)"

# CA04: AbstractCacheableService without isCacheAvailable guard
CA04_MATCHES=""
if [ -d "src/" ]; then
    CA04_MATCHES=$(grep -rln 'extends AbstractCacheableService' src/ --include="*.java" 2>/dev/null | while read -r f; do
        if ! grep -q 'isCacheAvailable' "$f" 2>/dev/null; then
            echo "$f: extends AbstractCacheableService without isCacheAvailable guard"
        fi
    done) || CA04_MATCHES=""
fi
emit_result "CA04" "WARN" "CacheService missing isCacheAvailable guard" "$CA04_MATCHES"
echo ""

# ─── Deprecated API ───────────────────────────────────────
echo "CATEGORY: Deprecated API"
check_grep "DP01" "deprecated" \
    'SecurityTokenService\.getInstance\|FileService\.getInstance\|WorkflowService\.getInstance\|FileImageService\.getInstance\|FileImagePublicService\.getInstance\|AccessControlService\.getInstance\|AttributeService\.getInstance\|AttributeFieldService\.getInstance\|AttributeTypeService\.getInstance\|PortletService\.getInstance\|AccessLogService\.getInstance\|RegularExpressionService\.getInstance\|EditorBbcodeService\.getInstance\|ProgressManagerService\.getInstance\|DashboardService\.getInstance\|AdminDashboardService\.getInstance\|FilterService\.getInstance\|ServletService\.getInstance\|LuteceUserCacheService\.getInstance' \
    "src/" "FAIL" "Deprecated getInstance() calls"
check_grep "DP02" "deprecated" 'FileImagePublicService\.init\|FileImageService\.init' "src/" "FAIL" "Deprecated init() calls (auto-registered in v8)"
check_grep "DP03" "deprecated" 'getModel( )' "src/" "FAIL" "MANDATORY: getModel() → @Inject Models (asMap() is unmodifiable)"
echo ""

# ─── DAO ──────────────────────────────────────────────────
echo "CATEGORY: DAO"
check_grep "DA01" "dao" 'daoUtil\.free( )' "src/" "WARN" "daoUtil.free() → try-with-resources"
echo ""

# ─── CDI Patterns ────────────────────────────────────────
echo "CATEGORY: CDI patterns"
check_grep "CD02" "cdi" 'new CaptchaSecurityService()' "src/" "FAIL" "new CaptchaSecurityService() → @Inject @Named(BeanUtils.BEAN_CAPTCHA_SERVICE)"
check_grep "CD03" "cdi" 'CompletableFuture\.runAsync' "src/" "WARN" "CompletableFuture.runAsync → @Asynchronous"
check_grep "CD04" "cdi" 'org\.apache\.commons\.fileupload' "src/" "FAIL" "commons.fileupload.FileItem → MultipartItem"

# CD01: static _instance/_singleton on CDI-managed classes
CD01_MATCHES=""
if [ -d "src/" ]; then
    CD01_MATCHES=$(grep -rn 'private static.*_instance\|private static.*_singleton' src/ --include="*.java" 2>/dev/null | while read -r line; do
        FILE=$(echo "$line" | cut -d: -f1)
        if grep -q '@ApplicationScoped\|@RequestScoped\|@SessionScoped\|@Dependent' "$FILE" 2>/dev/null; then
            echo "$line"
        fi
    done) || CD01_MATCHES=""
fi
emit_result "CD01" "WARN" "Static _instance/_singleton on CDI-managed classes" "$CD01_MATCHES"
echo ""

# ─── Web / Config ─────────────────────────────────────────
echo "CATEGORY: Web / Config"
check_grep "WB01" "web" 'java\.sun\.com/xml/ns/javaee' "webapp/" "FAIL" "Old Java EE namespace → Jakarta EE"
check_grep "WB02" "web" '<application-class>' "webapp/WEB-INF/plugins/" "FAIL" "application-class → CDI auto-discovery"
check_grep "WB03" "web" 'ContextLoaderListener' "webapp/" "FAIL" "Spring ContextLoaderListener in web.xml"

# WB04: min-core-version not set to 8.0.0
WB04_MATCHES=""
if [ -d "webapp/WEB-INF/plugins/" ]; then
    WB04_MATCHES=$(grep -rn '<min-core-version>' webapp/WEB-INF/plugins/ --include="*.xml" 2>/dev/null | grep -v '8\.0\.0') || WB04_MATCHES=""
fi
emit_result "WB04" "WARN" "min-core-version not set to 8.0.0" "$WB04_MATCHES"
echo ""

# ─── JSP ──────────────────────────────────────────────────
echo "CATEGORY: JSP"
check_grep "JS01" "jsp" 'jsp:useBean' "webapp/" "FAIL" "jsp:useBean → CDI-managed beans"

# JS02: Check for scriptlets but exclude directives (<%@) and comments (<%--)
JS02_MATCHES=""
if [ -d "webapp/" ]; then
    JS02_MATCHES=$(grep -rn '<%[^@-]' webapp/ --include="*.jsp" 2>/dev/null) || JS02_MATCHES=""
fi
emit_result "JS02" "WARN" "Old JSP scriptlets → EL expressions" "$JS02_MATCHES"
echo ""

# ─── Templates ────────────────────────────────────────────
echo "CATEGORY: Templates"
check_grep "TM01" "templates" 'class="panel' "webapp/WEB-INF/templates/admin/" "WARN" "Old Bootstrap panels → v8 macros"
check_grep "TM02" "templates" 'jQuery\|\$(' "webapp/WEB-INF/templates/" "WARN" "jQuery → vanilla JS"

# TM03: Old upload macro names (not yet renamed to BO variants)
TM03_MATCHES=""
if [ -d "webapp/WEB-INF/templates/" ]; then
    TM03_MATCHES=$(grep -rn '<@addFileInput \|<@addUploadedFilesBox\|<@addFileInputAndfilesBox' webapp/WEB-INF/templates/ --include="*.html" 2>/dev/null \
        | grep -v 'addFileBOInput\|addBOUploadedFilesBox\|addFileBOInputAndfilesBox') || TM03_MATCHES=""
fi
emit_result "TM03" "WARN" "Old upload macros → BO variants (addFileBOInput, etc.)" "$TM03_MATCHES"

# TM04: Unsafe access to errors/infos/warnings without null-safety operator (!)
# These model variables are NOT pre-initialized in v8 — only exist after addError()/addInfo()/addWarning()
TM04_MATCHES=""
if [ -d "webapp/WEB-INF/templates/" ]; then
    TM04_MATCHES=$(grep -rn 'errors?size\|errors?has_content\|infos?size\|infos?has_content\|warnings?size\|warnings?has_content' webapp/WEB-INF/templates/ --include="*.html" 2>/dev/null \
        | grep -v '(errors!)\|(infos!)\|(warnings!)') || TM04_MATCHES=""
fi
emit_result "TM04" "FAIL" "Unsafe errors/infos/warnings access → use (errors!)?size, (infos!)?size, (warnings!)?size" "$TM04_MATCHES"
echo ""

# ─── Logging ──────────────────────────────────────────────
echo "CATEGORY: Logging"
check_grep "LG01" "logging" 'AppLogService\.\(info\|error\|debug\|warn\).*+ ' "src/" "WARN" "String concat in logging → parameterized {}"
echo ""

# ─── Tests (JUnit 4 → 5) ────────────────────────────────
echo "CATEGORY: Tests (JUnit 4 → 5)"
check_grep "TS01" "tests" 'import org\.junit\.Test\b' "src/" "FAIL" "JUnit 4 @Test → org.junit.jupiter.api.Test"
check_grep "TS02" "tests" 'import org\.junit\.Before\b\|import org\.junit\.After\b' "src/" "FAIL" "JUnit 4 @Before/@After → @BeforeEach/@AfterEach"
check_grep "TS03" "tests" 'import org\.junit\.Assert' "src/" "FAIL" "JUnit 4 Assert → org.junit.jupiter.api.Assertions"
check_grep "TS04" "tests" 'MokeHttpServletRequest' "src/" "FAIL" "MokeHttpServletRequest → MockHttpServletRequest"
check_grep "TS05" "tests" 'import org\.junit\.BeforeClass\|import org\.junit\.AfterClass' "src/" "FAIL" "JUnit 4 @BeforeClass/@AfterClass → @BeforeAll/@AfterAll"
echo ""

# ─── Structure ────────────────────────────────────────────
echo "CATEGORY: Structure"
check_file_exists "ST01" "src/main/resources/META-INF/beans.xml" "FAIL" "beans.xml exists"

# ST02: Check for final on CDI-managed classes
ST02_MATCHES=""
if [ -d "src/" ]; then
    ST02_MATCHES=$(grep -rn 'public final class' src/ --include="*.java" 2>/dev/null | while read -r line; do
        FILE=$(echo "$line" | cut -d: -f1)
        if grep -q '@ApplicationScoped\|@RequestScoped\|@SessionScoped\|@Dependent' "$FILE" 2>/dev/null; then
            echo "$line"
        fi
    done) || ST02_MATCHES=""
fi
emit_result "ST02" "WARN" "No final keyword on CDI-managed classes" "$ST02_MATCHES"

# ST03: DAO classes without @ApplicationScoped
ST03_MATCHES=""
if [ -d "src/" ]; then
    ST03_MATCHES=$(grep -rln 'class.*DAO\b' src/ --include="*.java" 2>/dev/null | while read -r f; do
        # Skip interfaces
        if grep -q 'public interface\|protected interface' "$f" 2>/dev/null; then
            continue
        fi
        # Flag if no CDI scope annotation
        if ! grep -q '@ApplicationScoped\|@RequestScoped\|@SessionScoped\|@Dependent' "$f" 2>/dev/null; then
            echo "$f: DAO class without CDI scope annotation"
        fi
    done) || ST03_MATCHES=""
fi
emit_result "ST03" "WARN" "DAO classes without @ApplicationScoped" "$ST03_MATCHES"
echo ""

# ─── Summary ──────────────────────────────────────────────
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
