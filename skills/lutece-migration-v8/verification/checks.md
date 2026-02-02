# Migration Verification Checks

Single source of truth for all migration grep checks. Consumed by:
- `scripts/verify-migration.sh` (implements all checks)
- Phase 6 (runs the script)
- `lutece-v8-reviewer` agent (references for compliance audit)

Each check has: ID, category, pattern, search path, severity, and description.

---

## POM Dependencies

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| PM01 | `org\.springframework` | `pom.xml` | FAIL | Spring dependencies must be removed |
| PM02 | `net\.sf\.ehcache` | `pom.xml` | FAIL | EhCache dependencies must be removed |
| PM03 | `com\.sun\.mail` | `pom.xml` | FAIL | javax.mail dependency must be removed |
| PM04 | `org\.glassfish\.jersey` | `pom.xml` | FAIL | Jersey dependencies must be removed |
| PM05 | `net\.sf\.json-lib` | `pom.xml` | WARN | Use Jackson instead |
| PM06 | Parent `<version>` != `8.0.0-SNAPSHOT` | `pom.xml` | FAIL | Parent version must be `8.0.0-SNAPSHOT` |
| PM07 | `<springVersion>` | `pom.xml` | FAIL | springVersion property must be removed |

---

## javax Residues

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| JX01 | `javax\.servlet` | `src/` | FAIL | Must be `jakarta.servlet` |
| JX02 | `javax\.validation` | `src/` | FAIL | Must be `jakarta.validation` |
| JX03 | `javax\.annotation\.PostConstruct\|javax\.annotation\.PreDestroy` | `src/` | FAIL | Must be `jakarta.annotation.*` |
| JX04 | `javax\.inject` | `src/` | FAIL | Must be `jakarta.inject` |
| JX05 | `javax\.enterprise` | `src/` | FAIL | Must be `jakarta.enterprise` |
| JX06 | `javax\.ws\.rs` | `src/` | FAIL | Must be `jakarta.ws.rs` |
| JX07 | `javax\.xml\.bind` | `src/` | FAIL | Must be `jakarta.xml.bind` |
| JX08 | `javax\.transaction\.Transactional\|import javax\.transaction\.[^x]` | `src/` | FAIL | Must be `jakarta.transaction` (excludes `javax.transaction.xa` which is JDK) |

**Exclusions** (do NOT flag): `javax.cache`, `javax.xml.transform`, `javax.xml.parsers`, `javax.xml.xpath`, `javax.crypto`, `javax.net`, `javax.sql`, `javax.naming`, `javax.management`, `javax.imageio`, `javax.swing`, `javax.transaction.xa`

---

## Spring Residues

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| SP01 | `SpringContextService` | `src/` | FAIL | Must use CDI lookup or @Inject |
| SP02 | `org\.springframework` | `src/` | FAIL | No Spring imports allowed |
| SP03 | `_context\.xml` | `webapp/` | FAIL | Spring context files must be deleted |
| SP04 | `@Autowired` | `src/` | FAIL | Must be `@Inject` |
| SP05 | `implements.*InitializingBean` | `src/` | FAIL | Must use `@PostConstruct` |
| SP06 | `@Component(` | `src/` | FAIL | `@Component("name")` must be `@ApplicationScoped @Named("name")` |
| SP07 | `@Service(` | `src/` | FAIL | `@Service("name")` must be `@ApplicationScoped @Named("name")` |
| SP08 | `@Repository(` | `src/` | FAIL | `@Repository("name")` must be `@ApplicationScoped @Named("name")` |

**Note:** `replace-spring-simple.sh` handles bare `@Component`, `@Service`, `@Repository` (without parameters). SP06-SP08 catch the **named** variants that the script misses.

---

## Event Residues

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| EV01 | `ResourceEventManager` | `src/` | FAIL | Use CDI events with TypeQualifier |
| EV02 | `EventRessourceListener` | `src/` | FAIL | Use @Observes @Type(EventAction.*) |
| EV03 | `LuteceUserEventManager` | `src/` | FAIL | Use @Observes LuteceUserEvent |
| EV04 | `QueryListenersService` | `src/` | FAIL | Use @Observes QueryEvent |
| EV05 | `AbstractEventManager` | `src/` | FAIL | Use CDI events |

---

## Cache Residues

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| CA01 | `net\.sf\.ehcache` | `src/` | FAIL | EhCache removed, use JCache |
| CA02 | `putInCache\|getFromCache\|removeKey` | `src/` | FAIL | Use put/get/remove |
| CA03 | `extends AbstractCacheableService[^<]` | `src/` | FAIL | Must be parameterized `<K, V>` |
| CA04 | `extends AbstractCacheableService` without `isCacheAvailable` in same file | `src/` | WARN | Override put/get/remove with isCacheEnable+isCacheAvailable guards (core delegates to _cache without null check) |

---

## Deprecated API

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| DP01 | `SecurityTokenService\.getInstance\|FileService\.getInstance\|WorkflowService\.getInstance\|FileImageService\.getInstance\|FileImagePublicService\.getInstance\|AccessControlService\.getInstance\|AttributeService\.getInstance\|AttributeFieldService\.getInstance\|AttributeTypeService\.getInstance\|PortletService\.getInstance\|AccessLogService\.getInstance\|RegularExpressionService\.getInstance\|EditorBbcodeService\.getInstance\|ProgressManagerService\.getInstance\|DashboardService\.getInstance\|AdminDashboardService\.getInstance\|FilterService\.getInstance\|ServletService\.getInstance\|LuteceUserCacheService\.getInstance` | `src/` | FAIL | Use @Inject or CDI.current().select() |
| DP02 | `FileImagePublicService\.init\|FileImageService\.init` | `src/` | FAIL | Auto-registered in v8 |
| DP03 | `getModel( )` | `src/` | FAIL | MANDATORY: Use @Inject Models. asMap() is unmodifiable — helper methods accepting Map<String, Object> must accept Models instead |

---

## DAO

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| DA01 | `daoUtil\.free( )` | `src/` | WARN | Use try-with-resources |

---

## CDI Patterns

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| CD01 | `private static.*_instance\|private static.*_singleton` on CDI-managed classes | `src/` | WARN | Remove singleton fields on CDI beans |
| CD02 | `new CaptchaSecurityService()` | `src/` | FAIL | Use `@Inject @Named(BeanUtils.BEAN_CAPTCHA_SERVICE) Instance<ICaptchaService>` |
| CD03 | `CompletableFuture\.runAsync` | `src/` | WARN | Use `@Asynchronous` |
| CD04 | `org\.apache\.commons\.fileupload` | `src/` | FAIL | `FileItem` must be `MultipartItem` |

**Note:** CD01 is a cross-file check: only flags `_instance`/`_singleton` fields in files that also contain a CDI scope annotation (`@ApplicationScoped`, `@RequestScoped`, `@SessionScoped`, `@Dependent`).

---

## Web / Config

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| WB01 | `java\.sun\.com/xml/ns/javaee` | `webapp/` | FAIL | Must be `jakarta.ee/xml/ns/jakartaee` |
| WB02 | `<application-class>` | `webapp/WEB-INF/plugins/` | FAIL | XPages auto-discovered via CDI |
| WB03 | `ContextLoaderListener` | `webapp/` | FAIL | Spring listener must be removed from web.xml |
| WB04 | `<min-core-version>` not containing `8.0.0` | `webapp/WEB-INF/plugins/` | WARN | Should be `8.0.0` |

---

## JSP

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| JS01 | `jsp:useBean` | `webapp/` | FAIL | Beans are CDI-managed |
| JS02 | `<%[^@-]` (scriptlets, excluding `<%@` directives and `<%--` comments) | `webapp/` | WARN | Use EL `${ }` instead of scriptlets |

---

## Templates

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| TM01 | `class="panel` | `webapp/WEB-INF/templates/admin/` | WARN | Use v8 Freemarker macros |
| TM02 | `jQuery\|\$(` | `webapp/WEB-INF/templates/` | WARN | No jQuery, use vanilla JS |
| TM03 | `<@addFileInput \|<@addUploadedFilesBox\|<@addFileInputAndfilesBox` (excluding BO variants) | `webapp/WEB-INF/templates/` | WARN | Use v8 upload macros: `addFileBOInput`, `addBOUploadedFilesBox`, `addFileBOInputAndfilesBox` |
| TM04 | `errors?size\|errors?has_content\|infos?size\|infos?has_content\|warnings?size\|warnings?has_content` (without `!` null-safety) | `webapp/WEB-INF/templates/` | FAIL | MANDATORY: Use `(errors!)?size`, `(infos!)?size`, `(warnings!)?size`. These variables are NOT pre-initialized in v8 — accessing without `!` causes 500 error |

---

## Logging

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| LG01 | `AppLogService\.\(info\|error\|debug\|warn\).*+ ` | `src/` | WARN | Use parameterized logging `{}` |

---

## Tests (JUnit 4 to 5)

| ID | Pattern | Path | Severity | Description |
|----|---------|------|----------|-------------|
| TS01 | `import org\.junit\.Test\b` | `src/` | FAIL | Must be `org.junit.jupiter.api.Test` |
| TS02 | `import org\.junit\.Before\b\|import org\.junit\.After\b` | `src/` | FAIL | Must be `@BeforeEach` / `@AfterEach` |
| TS03 | `import org\.junit\.Assert` | `src/` | FAIL | Must be `org.junit.jupiter.api.Assertions` |
| TS04 | `MokeHttpServletRequest` | `src/` | FAIL | Renamed to `MockHttpServletRequest` in v8 |
| TS05 | `import org\.junit\.BeforeClass\|import org\.junit\.AfterClass` | `src/` | FAIL | Must be `@BeforeAll` / `@AfterAll` |

---

## Structure

| ID | Check | Severity | Description |
|----|-------|----------|-------------|
| ST01 | `src/main/resources/META-INF/beans.xml` exists | FAIL | Required for CDI bean discovery |
| ST02 | No `final` on CDI-managed classes | WARN | CDI cannot proxy final classes |
| ST03 | All DAO classes have `@ApplicationScoped` | WARN | Required for CDI discovery |

**Note:** ST02 and ST03 are cross-file checks. ST02 only flags `public final class` in files containing a CDI scope annotation. ST03 only flags concrete classes (skips interfaces).

---

## Summary

- **Total checks**: 58
- **FAIL severity**: 44 (will break compilation or runtime)
- **WARN severity**: 14 (best practice, should fix)
