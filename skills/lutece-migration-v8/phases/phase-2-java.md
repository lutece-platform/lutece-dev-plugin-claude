# Phase 2: Java Migration (Mega-Phase)

This phase handles ALL Java source code migration. It combines mechanical (script-based) and intelligent (Claude-based) work in an optimized sequence.

**Read pattern files on demand** — only when the step needs them. Do not load all patterns upfront.

**Reference-First:** Before writing ANY new class (Producer, Service, EventListener, Cache, etc.), search `~/.lutece-references/` for an existing implementation of the same pattern. The reference takes priority over pattern documentation. See the "Reference-First Rule" in `SKILL.md`.

---

## Step 1 — Mechanical replacements (SCRIPTS)

Run these three scripts in sequence:

```bash
# 1. javax → jakarta imports
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/replace-imports.sh"

# 2. Mechanical Spring → CDI annotations
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/replace-spring-simple.sh"

# 3. Check what remains
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/verify-migration.sh"
```

Read the verify output. The scripts handled the mechanical work. Everything still FAIL needs Claude.

---

## Step 2 — Context XML → beans.xml

**Read:** `patterns/cdi-patterns.md` section "Context XML → beans.xml"

1. Read every `*_context.xml` file. Catalog every `<bean>` definition (id, class, scope, properties, constructor-args)
2. Delete all `*_context.xml` files
3. Create `src/main/resources/META-INF/beans.xml`:

```xml
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0" bean-discovery-mode="annotated">
</beans>
```

---

## Step 3 — CDI scope annotations

**Read:** `patterns/cdi-patterns.md` section "CDI Scopes"

For each Java class identified by the scanner (Phase 0):

| Class type | Annotation | Rule |
|-----------|------------|------|
| DAO impl class | `@ApplicationScoped` | Always |
| Service class | `@ApplicationScoped` | Always |
| JspBean (stateful) | `@SessionScoped @Named` | Has pagination/working object fields |
| JspBean (stateless) | `@RequestScoped @Named` | No session state fields |
| XPage (stateful) | `@SessionScoped @Named("plugin.xpage.name")` | Has session state |
| XPage (stateless) | `@RequestScoped @Named("plugin.xpage.name")` | No session state |
| EntryType | `@ApplicationScoped @Named("plugin.entryTypeName")` | Match old context XML bean name |
| Prototype bean | `@Dependent @Named("beanName")` | Spring `scope="prototype"` |

**Also:**
- Remove `final` keyword from any class getting a CDI scope annotation
- Remove private constructors used for singleton enforcement
- Remove static `_instance` / `_singleton` fields

---

## Step 4 — SpringContextService replacement

**Read:** `patterns/cdi-patterns.md` section "SpringContextService Replacement"

For each remaining `SpringContextService` call (from scan):

| Calling context | Replacement |
|----------------|-------------|
| CDI-managed class | `@Inject` field (preferred) |
| Home/static class | `CDI.current().select(Type.class).get()` |
| Named bean lookup | `CDI.current().select(Type.class, NamedLiteral.of("name")).get()` |
| getBeansOfType() | `CDI.current().select(Type.class)` → `Instance<Type>` |

**CRITICAL:** Before replacing, check if the bean's type/interface exists in `~/.lutece-references/`. The v8 API may have changed (new constructors, removed methods, class renamed).

---

## Step 5 — CDI Producers

**Read:** `patterns/cdi-patterns.md` section "CDI Producers"

For each complex Spring XML bean that had constructor args, property values, or list configurations:

1. **FIRST check the v8 source** in `~/.lutece-references/`. If the class is now `@ApplicationScoped` in v8, no Producer needed — just `@Inject` it
2. If a Producer is needed, create it with proper `@Produces @Named @ApplicationScoped`
3. Use `@ConfigProperty` for property values that should come from `.properties` files
4. **If the Spring bean had `<constructor-arg ref="..."/>` or `<property ref="..."/>`** (references to other named beans): read the "Producers referencing other named CDI beans" pattern. Use `@ConfigProperty` for bean names + `CdiHelper.getReference()` for resolution. NEVER hardcode `@Inject @Named` with literal bean names in the producer.
5. **If creating a FileStoreServiceProvider producer:** also add `@Named` to the custom `IFileRBACService` implementation, and replace `FileService.getFileStoreServiceProvider(name)` with `@Inject @Named` in consumers. See the filegenerator reference implementation.

---

## Step 6 — Events migration (if applicable)

**Read:** `patterns/events-patterns.md`

Only if the scanner detected event listeners or ResourceEventManager usage:

1. **Listener side**: Replace `EventRessourceListener` → `@Observes @Type(EventAction.*)` methods
2. **Firing side**: Replace `ResourceEventManager.fireXxx()` → `CDI.current().getBeanManager().getEvent().select(ResourceEvent.class, new TypeQualifier(action)).fire(event)`
3. **Plugin.init()**: Remove all `ResourceEventManager.register()` calls
4. **Other event managers**: LuteceUserEventManager, QueryListenersService → CDI @Observes

---

## Step 7 — Cache migration (if applicable)

**Read:** `patterns/cache-patterns.md`

Only if the scanner detected cache services:

1. Replace `EhCache 2.x` API with JCache
2. Parameterize `AbstractCacheableService<K, V>`
3. Replace `initCache()` → `initCache(CACHE_NAME, K.class, V.class)`
4. Replace deprecated methods: `putInCache→put`, `getFromCache→get`, `removeKey→remove`
5. Add `@ApplicationScoped` + `@PostConstruct`
6. Replace `EventRessourceListener` with CDI `@Observes` on cache service

---

## Step 8 — REST migration (if applicable)

**Read:** `patterns/cdi-patterns.md` section "REST API"

Only if the scanner detected REST endpoints:

1. Replace Jersey `ResourceConfig` → standard `@ApplicationPath` Application
2. Remove Jersey dependencies (handled in Phase 1 POM)
3. Add `@Provider` on exception mappers
4. Replace servlet auth filters → JAX-RS `ContainerRequestFilter`

---

## Step 9 — Deprecated API cleanup

**Read:** `patterns/deprecated-api.md`

1. Replace all `getInstance()` calls from lutece-core (see table in pattern file)
   - CDI-managed class → `@Inject` field
   - Static context → `CDI.current().select(Type.class).get()`
2. Clean up `Plugin.init()` — remove unnecessary CDI eagerness, FileImagePublicService.init(), etc.
3. **MANDATORY:** Replace `getModel()` → `@Inject Models` (in JspBeans and XPages). Also update ALL helper methods that accept `Map<String, Object>` model and call `put()` on it — change them to accept `Models`. `asMap()` returns an unmodifiable map.
4. Replace `new CaptchaSecurityService()` → `@Inject @Named(BeanUtils.BEAN_CAPTCHA_SERVICE) Instance<ICaptchaService>` + `isResolvable()` check before `get()`
5. Replace `LocalizedPaginator` manual pagination → `@Inject @Pager IPager` + `populateModels()`. Remove `_nItemsPerPage`, `_strCurrentPageIndex` fields.
6. Parameterized logging: replace string concat with `{}` placeholders
7. Remove unused imports

---

## Step 10 — DAOUtil try-with-resources

For every `daoUtil.free()` call detected by the scanner:

```java
// BEFORE
DAOUtil daoUtil = new DAOUtil( SQL_QUERY, plugin );
daoUtil.setInt( 1, id );
daoUtil.executeUpdate( );
daoUtil.free( );

// AFTER
try ( DAOUtil daoUtil = new DAOUtil( SQL_QUERY, plugin ) )
{
    daoUtil.setInt( 1, id );
    daoUtil.executeUpdate( );
}
```

---

## Parallelism for large projects

If the Phase 0 scanner reported `scope: LARGE` (100+ migration points), use `Task` agents to handle independent packages in parallel:

- **Agent A**: `src/java/.../business/` — DAOs, Home classes (scope annotations + CDI lookup)
- **Agent B**: `src/java/.../service/` — Services, Cache services (scope annotations + events + cache)
- **Agent C**: `src/java/.../web/` — JspBeans, XPages (scope annotations + @Inject + Models)

Each agent reads the relevant pattern files independently. Files in different packages have no cross-references within the same layer.

---

## Verification

Run the verification script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/verify-migration.sh"
```

All Java-related checks (JX01-JX07, SP01-SP03, EV01-EV05, CA01-CA03, DP01-DP03, DA01) must PASS or be accepted WARN.

If any FAIL → fix the issue → re-run verification → repeat until clean.

Mark task as completed ONLY when verification passes.
