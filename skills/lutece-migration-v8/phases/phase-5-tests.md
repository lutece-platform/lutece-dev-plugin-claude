# Phase 5: Test Migration (JUnit 4 → JUnit 5)

---

## Step 1 — Test dependencies

Tests extending `LuteceTestCase` require `library-lutece-unit-testing`. The global-pom `8.0.0-SNAPSHOT` manages the version — just declare it in `pom.xml`:

```xml
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-lutece-unit-testing</artifactId>
    <type>jar</type>
    <scope>test</scope>
</dependency>
```

If this dependency is missing, tests will fail with `cannot find symbol: class LuteceTestCase`.

**Additional dependencies** (if needed by your tests):

```xml
<!-- Jakarta Bean Validation -->
<dependency>
    <groupId>org.hibernate.validator</groupId>
    <artifactId>hibernate-validator</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.glassfish</groupId>
    <artifactId>jakarta.el</artifactId>
    <scope>test</scope>
</dependency>
<!-- JAXB runtime -->
<dependency>
    <groupId>org.glassfish.jaxb</groupId>
    <artifactId>jaxb-runtime</artifactId>
    <scope>test</scope>
</dependency>
```

---

## Step 2 — Annotation changes

| JUnit 4 | JUnit 5 |
|---------|---------|
| `import org.junit.Test` | `import org.junit.jupiter.api.Test` |
| `import org.junit.Before` | `import org.junit.jupiter.api.BeforeEach` |
| `import org.junit.After` | `import org.junit.jupiter.api.AfterEach` |
| `@Before` | `@BeforeEach` |
| `@After` | `@AfterEach` |
| `@BeforeClass` | `@BeforeAll` |
| `@AfterClass` | `@AfterAll` |

**CRITICAL:** Every test method MUST have `@Test` from JUnit 5:
```java
import org.junit.jupiter.api.Test;

@Test
public void testSomething() { ... }
```

Verify with:
```bash
# Find test methods without @Test annotation
grep -rn "public void test" src/test/ --include="*.java" | grep -v "@Test"
```

---

## Step 3 — Assertion parameter order change

```java
// JUnit 4
assertEquals("Message", expected, actual);
// JUnit 5
assertEquals(expected, actual, "Message");
```

---

## Step 4 — Assertion style (JUnit 5)

```java
// v7: static import
import static org.junit.Assert.*;
assertTrue(condition);

// v8: use Assertions class
import org.junit.jupiter.api.Assertions;
Assertions.assertTrue(condition);
```

---

## Step 5 — Mock class renames and package migration

| v7 | v8 |
|----|-----|
| `MokeHttpServletRequest` | `MockHttpServletRequest` |
| `request.addMokeHeader(name, value)` | `request.addHeader(name, value)` |
| `org.springframework.mock.web.*` | `fr.paris.lutece.test.mocks.*` |

**Example:**
```java
// v7
import org.springframework.mock.web.MockHttpServletRequest;

// v8
import fr.paris.lutece.test.mocks.MockHttpServletRequest;
```

---

## Step 6 — SpringContextService → @Inject in tests

Replace `SpringContextService.getBean()` with `@Inject` in test classes:

**Before (v7):**
```java
public class DummyServiceTest extends LuteceTestCase
{
    private IDummyService _service = SpringContextService.getBean( "dummyPlugin.DummyService" );

    @Override
    protected void setUp() throws Exception
    {
        super.setUp();
        assertNotNull( _service );
    }

    public void testMethodA()
    {
        assertNotNull( _service.methodA() );
    }
}
```

**After (v8):**
```java
public class DummyServiceTest extends LuteceTestCase
{
    @Inject
    private IDummyService _service;

    @BeforeEach
    protected void setUp() throws Exception
    {
        super.setUp();
        assertNotNull( _service );
    }

    @Test
    public void testMethodA()
    {
        Assertions.assertNotNull( _service.methodA() );
    }
}
```

**Key changes:**
1. `SpringContextService.getBean()` → `@Inject`
2. `setUp()` → `@BeforeEach setUp()`
3. `public void testX()` → `@Test public void testX()`
4. `assertNotNull()` → `Assertions.assertNotNull()`

---

## Step 7 — CDI Test Extension (advanced)

For tests that need dynamic bean registration, create a CDI test extension:

1. Create `src/test/resources/META-INF/services/jakarta.enterprise.inject.spi.Extension` listing the test extension class

2. Implement the extension:

```java
public class MyTestExtension implements Extension {
    protected void addBeans(@Observes AfterBeanDiscovery abd, BeanManager bm) {
        abd.addBean()
            .beanClass(MockService.class)
            .name("mockBeanName")
            .addTypes(MockService.class, IService.class)
            .addQualifier(NamedLiteral.of("mockBeanName"))
            .scope(ApplicationScoped.class)
            .produceWith(obj -> new MockService());
    }
}
```

---

## Step 8 — Optional dependencies: Instance<T> vs direct @Inject

When migrating from `SpringContextService.getBean()`, a common mistake is using direct `@Inject` instead of `Instance<T>` for optional dependencies.

**Problem:**
```java
// WRONG: forces mandatory dependency — test fails if bean not in classpath
@Inject
@Named("workflowService")
private IWorkflowService _workflowService;
```

**Solution:**
```java
// CORRECT: optional dependency — can check availability at runtime
@Inject
@Named("workflowService")
private Instance<IWorkflowService> _workflowService;

// Usage:
if (_workflowService.isResolvable()) {
    _workflowService.get().doSomething();
}
```

**Detection:** Look for `@Inject` on services that are NOT declared as dependencies in `pom.xml`:
```bash
# List all @Inject @Named in test files
grep -rn "@Inject" src/test/ | grep -B1 "@Named"
```

Then cross-reference with `pom.xml` dependencies. If the injected service's artifact is not a dependency, it must use `Instance<T>`.

**Common candidates:** `IWorkflowService`, `IAccessControlService`, `IFormService`, `ISearchIndexer` — modules that are optional in many plugins.

---

## Step 9 — Running tests

Lutece tests require the exploded webapp and HSQL database. Run tests with:

```bash
mvn clean lutece:exploded antrun:run -Dlutece-test-hsql test -q 2>&1
```

This command:
1. `lutece:exploded` — builds the exploded webapp structure
2. `antrun:run -Dlutece-test-hsql` — initializes the HSQL test database
3. `test` — runs JUnit tests
4. `-q 2>&1` — quiet mode with stderr redirected to stdout

---

## Verification

Grep check:
```bash
grep -rn "org\.junit\.Test\b" src/test/
```
→ must return nothing (only `org.junit.jupiter`)

Run the test command above and verify all tests pass.

Mark task as completed when grep checks pass and tests are green.
