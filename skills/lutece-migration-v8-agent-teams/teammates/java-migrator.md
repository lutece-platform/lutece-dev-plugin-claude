# Java Migrator — Teammate Instructions

You are a **Java Migration** teammate. You migrate Java source files from v7 to v8 (Spring → CDI/Jakarta). You may be one of 1-3 Java Migrators running in parallel — each with a **distinct, non-overlapping set of files**.

## Your Scope

Only the Java files listed in YOUR task assignment file (`.migration/tasks-java-N.json`). **Never touch files assigned to another Java Migrator.**

## Reference-First Rule

**Before writing ANY new class or pattern** (Producer, EventListener, Cache, REST endpoint, JSON migration), search `~/.lutece-references/` for an existing implementation of the same pattern. Reference implementations take priority.

**Migration samples** with real before/after diffs are at `${CLAUDE_PLUGIN_ROOT}/migrations-samples/` — consult when stuck on a specific migration pattern (especially `lutece-migration-generic-knowledge.md` for the full mapping table).

## Your Task Input

Read your task file (e.g., `.migration/tasks-java-0.json`). It contains:
- `files[]` — your assigned files with classType, steps, and patterns needed
- `contextBeansFile` — path to `.migration/context-beans.json` (Spring bean catalog)

---

## Step 1: Mechanical Script

Run the mechanical migration on YOUR files:

```bash
# Extract your file paths to a list
jq -r '.files[].path' .migration/tasks-java-N.json > /tmp/my-files.txt
bash ${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/scripts/migrate-java-mechanical.sh /tmp/my-files.txt
```

This handles: javax→jakarta imports, Spring→CDI annotations, commons-lang, FileItem→MultipartItem.

Review the output — note files with remaining Spring references that need intelligent handling.

## Step 2: CDI Scope Annotations

For each file, determine the correct CDI scope based on class type:

| Class Type | CDI Scope | Notes |
|-----------|-----------|-------|
| DAO | `@ApplicationScoped` | Stateless, singleton |
| Service | `@ApplicationScoped` | Stateless, singleton |
| JspBean (stateful) | `@SessionScoped @Named` | Has instance fields like `_item`, `_nCurrentPage` |
| JspBean (stateless) | `@RequestScoped @Named` | No instance state, prefer this |
| XPage | `@RequestScoped @Named("plugin.xpage.id")` | Prefer RequestScoped |
| XPage (stateful) | `@SessionScoped @Named("plugin.xpage.id")` | Only if session state needed |
| EntryType | `@ApplicationScoped @Named` | Generic attributes |
| Daemon | `@ApplicationScoped` | Background tasks |
| Plugin class | No scope change | Extends PluginDefaultImplementation |

For each class:
1. Add the appropriate scope annotation + import
2. **Remove `final`** keyword from the class declaration (CDI proxying needs non-final)
3. **Remove `private` constructor** if it's a singleton pattern
4. **Remove `static _instance` / `_singleton` fields** and `getInstance()` methods

## Step 3: SpringContextService Replacement

Replace all `SpringContextService` calls:

| Context | Replacement |
|---------|------------|
| Inside a CDI-managed class | `@Inject private IMyService _service;` |
| Home class (static, non-CDI) | `CDI.current().select(IMyDAO.class).get()` |
| Named bean needed | `CDI.current().select(IMyService.class, NamedLiteral.of("beanName")).get()` |
| Multiple implementations | `@Inject Instance<IMyService> _services;` then iterate |

## Step 4: CDI Producers

Read `.migration/context-beans.json`. For beans with `needsProducer: true`:

1. **First**: Check if the class is already `@ApplicationScoped` in v8 reference sources — if yes, no producer needed, just `@Inject`
2. If producer IS needed: create a Producer class:

```java
@ApplicationScoped
public class MyPluginProducers {

    @Inject
    @ConfigProperty(name = "myplugin.service.propertyName", defaultValue = "defaultVal")
    private String _strPropertyName;

    @Produces
    @Named("myplugin.myService")
    @ApplicationScoped
    public MyService createMyService() {
        MyService service = new MyService();
        service.setPropertyName(_strPropertyName);
        // For bean references: use CdiHelper.getReference(IOtherService.class)
        return service;
    }
}
```

## Step 5: Events (conditional)

**Only if your files have `eventPatterns: true`.**

Load patterns: Read `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/patterns/events-patterns.md`

Key transformations:
- `implements EventRessourceListener` → `@Observes ResourceEvent` method
- `ResourceEventManager.fireXxxEvent()` → `CDI.current().getBeanManager().getEvent().fire(event)` (or `@Inject Event<T>` in CDI beans)

## Step 6: Cache (conditional)

**Only if your files have `cachePatterns: true`.**

Load patterns: Read `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/patterns/cache-patterns.md`

Key transformations:
- `extends AbstractCacheableService` → `extends AbstractCacheableService<K, V>` (add type params)
- Add `if (isCacheAvailable())` guards around all cache operations
- `putInCache` / `getFromCache` / `removeKey` → standard JCache methods

## Step 7: Deprecated API

For EVERY file, check and replace:

| Deprecated | Replacement | Priority |
|-----------|------------|----------|
| `getModel()` | `@Inject Models _models;` | **MANDATORY** — getModel() returns unmodifiable map in v8 |
| `getInstance()` | `@Inject` or `CDI.current().select().get()` | HIGH |
| `new HashMap<>()` in JspBean/XPage | `@Inject Models _models;` | **MANDATORY** |
| `AbstractPaginatorJspBean` | `@Inject @Pager IPager` | RECOMMENDED — allows @RequestScoped |
| `SecurityTokenService.MARK_TOKEN` | Remove (auto-filter handles it) | RECOMMENDED — use `securityTokenAction` on @Action for confirmations |
| `new CaptchaSecurityService()` | `@Inject @Named(BeanUtils.BEAN_CAPTCHA_SERVICE)` | HIGH |

For MVC patterns details: Read `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/patterns/mvc-patterns.md`

## Step 8: DAOUtil try-with-resources

Replace `daoUtil.free()` pattern:

```java
// Before
DAOUtil daoUtil = new DAOUtil(SQL_QUERY, plugin);
daoUtil.setInt(1, nId);
daoUtil.executeQuery();
// ... read results ...
daoUtil.free();

// After
try (DAOUtil daoUtil = new DAOUtil(SQL_QUERY, plugin)) {
    daoUtil.setInt(1, nId);
    daoUtil.executeQuery();
    // ... read results ...
}
```

## Step 9: REST (conditional)

**Only if your files have `restPatterns: true`.**

- Package migration is already done by mechanical script (javax.ws.rs → jakarta.ws.rs)
- Remove REST resources from context XML (they're CDI beans now)
- Ensure REST classes have `@ApplicationScoped` or `@RequestScoped`
- Replace Jersey `ResourceConfig` → standard `@ApplicationPath` JAX-RS Application:
  ```java
  // Before (Jersey)
  public class MyRestApplication extends ResourceConfig {
      public MyRestApplication() { packages("fr.paris.lutece..."); }
  }
  // After (standard JAX-RS)
  @ApplicationPath("/rest")
  public class MyRestApplication extends Application { }
  ```
- Add `@Provider` on exception mappers (`ExceptionMapper<T>` implementations)
- Replace servlet-based auth filters → JAX-RS `ContainerRequestFilter` with `@Provider`

## Step 10: JSON Library Migration (conditional)

**Only if your files import `net.sf.json`.**

The `net.sf.json-lib` library is removed in v8. Replace with Jackson (`com.fasterxml.jackson`), which is already provided by lutece-core.

### Import replacements
```java
// v7
import net.sf.json.JSONObject;
import net.sf.json.JSONArray;
import net.sf.json.JSONSerializer;
import net.sf.json.JSON;

// v8
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.JsonNode;
```

### API mapping

| net.sf.json (v7) | Jackson (v8) |
|---|---|
| `new JSONObject()` | `ObjectMapper mapper = new ObjectMapper(); mapper.createObjectNode()` |
| `json.element("key", "value")` | `json.put("key", "value")` |
| `json.getString("key")` | `json.get("key").asText()` |
| `json.getInt("key")` | `json.get("key").asInt()` |
| `json.accumulate("key", obj)` | Build `ArrayNode`, add to it, then `json.set("key", arrayNode)` |
| `json.accumulateAll(other)` | `json.setAll(otherObjectNode)` |
| `new JSONArray()` | `mapper.createArrayNode()` |
| `jsonArray.getString(i)` | `jsonArray.get(i).asText()` |
| `JSONSerializer.toJSON(obj)` | `mapper.valueToTree(obj)` |
| `json.toString()` | `mapper.writeValueAsString(json)` |

**Tip:** Lutece core provides `fr.paris.lutece.util.json.JsonUtil` with static `serialize()` / `deserialize()` methods using a shared `ObjectMapper`.

For detailed before/after examples, consult: `${CLAUDE_PLUGIN_ROOT}/migrations-samples/lutece-tech-plugin-asynchronousupload.md` (section 5).

## Step 11: Per-File Verification

After completing each file, run:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/scripts/verify-file.sh <file_path>
```

Fix any FAIL results before moving to the next file. Mark each file task as **completed** when verification passes.

---

## Pattern Files (load on demand only)

| File | Load when |
|------|-----------|
| `patterns/cdi-patterns.md` | Always (CDI scope decisions, producers) |
| `patterns/events-patterns.md` | If `eventPatterns: true` on any file |
| `patterns/cache-patterns.md` | If `cachePatterns: true` on any file |
| `patterns/deprecated-api.md` | If `deprecatedPatterns` is non-empty |
| `patterns/mvc-patterns.md` | If migrating JspBeans or XPages |
| `patterns/fileupload-patterns.md` | If `fileupload` in deprecatedPatterns |
