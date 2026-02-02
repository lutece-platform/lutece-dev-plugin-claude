# Phase 5: Test Migration (JUnit 4 → JUnit 5)

---

## Step 1 — Test dependency

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

## Step 5 — Mock class renames

| v7 | v8 |
|----|-----|
| `MokeHttpServletRequest` | `MockHttpServletRequest` |
| `request.addMokeHeader(name, value)` | `request.addHeader(name, value)` |

---

## Step 6 — CDI Test Extension (if needed)

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

## Verification

Grep check:
```bash
grep -rn "org\.junit\.Test\b" src/test/
```
→ must return nothing (only `org.junit.jupiter`)

Do NOT run `mvn clean install` yet — that happens in Phase 6.

Mark task as completed when grep checks pass.
