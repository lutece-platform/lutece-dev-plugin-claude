# Cache Migration Patterns (v7 → v8)

Single source of truth for all cache migration patterns (EhCache 2.x → JCache/JSR-107).

> **Reference-First Principle:** Before writing any cache service, **search `~/.lutece-references/` for existing `AbstractCacheableService` implementations** (e.g., `Grep AbstractCacheableService ~/.lutece-references/`). Reproduce the reference structure exactly.

## 1. API Replacement

Replace EhCache 2.x API with JCache (JSR-107) or `@LuteceCache` annotation:

- `net.sf.ehcache.Cache` → `javax.cache.Cache` or `Lutece107Cache`
- `new Element(key, value)` → `cache.put(key, value)`
- `cache.get(key).getObjectValue()` → `cache.get(key)`

## 2. Cache Injection

```java
@Inject
@LuteceCache(cacheName = "myCache", keyType = String.class, valueType = MyObject.class, enable = true)
private Lutece107Cache<String, MyObject> _cache;
```

## 3. Full Cache Service Migration

**Before (v7):**
```java
public class MyCacheService extends AbstractCacheableService implements EventRessourceListener {
    @Override
    public void initCache() {
        super.initCache();
        ResourceEventManager.register(this);
    }
    public void addedResource(ResourceEvent event) { handleEvent(event); }
    public void deletedResource(ResourceEvent event) { handleEvent(event); }
    public void updatedResource(ResourceEvent event) { handleEvent(event); }
}
```

**After (v8):**
```java
import javax.cache.CacheException;

@ApplicationScoped
public class MyCacheService extends AbstractCacheableService<String, Object> {
    @PostConstruct
    public void initCache() {
        initCache(CACHE_NAME, String.class, Object.class);
    }

    // MANDATORY: override put/get/remove with defensive guards.
    // AbstractCacheableService delegates directly to _cache without null/closed checks.
    // If the cache is disabled in the datastore (default state), _cache is null → NPE.

    @Override
    public void put(String key, Object value) {
        if (isCacheEnable() && isCacheAvailable()) {
            try { super.put(key, value); }
            catch (CacheException | IllegalStateException e) {
                AppLogService.error("Cache put error for key {}", key, e);
            }
        }
    }
    @Override
    public Object get(String key) {
        if (isCacheEnable() && isCacheAvailable()) {
            try { return super.get(key); }
            catch (CacheException | IllegalStateException e) {
                AppLogService.error("Cache get error for key {}", key, e);
            }
        }
        return null;
    }
    @Override
    public boolean remove(String key) {
        if (isCacheEnable() && isCacheAvailable()) {
            try { return super.remove(key); }
            catch (CacheException | IllegalStateException e) {
                AppLogService.error("Cache remove error for key {}", key, e);
            }
        }
        return false;
    }
    private boolean isCacheAvailable() {
        return _cache != null && !_cache.isClosed();
    }

    // CDI observer replaces EventRessourceListener
    public void processEvent(@Observes MyEvent event) {
        if (isCacheEnable()) { resetCache(); }
    }
}
```

## 4. Cache Method Renames

| v7 (deprecated) | v8 |
|---|---|
| `putInCache(key, value)` | `put(key, value)` |
| `getFromCache(key)` | `get(key)` |
| `removeKey(key)` | `remove(key)` |

## 5. Cache Service Access

**NEVER add a `getInstance()` method** on the cache service — it is `@Deprecated(since = "8.0", forRemoval = true)`.

| Caller context | Pattern |
|---|---|
| CDI-managed bean (`@ApplicationScoped` service) | `@Inject private MyCacheService _cacheService;` |
| Static Home class | Direct field init: `CDI.current().select(MyCacheService.class).get()` |

```java
// Home class — static context, direct field initialization (no lazy-init getter)
public class EntityHome
{
    private static IEntityDAO _dao = CDI.current( ).select( IEntityDAO.class ).get( );
    private static MyCacheService _cacheService = CDI.current( ).select( MyCacheService.class ).get( );
    private static final Plugin _plugin = PluginService.getPlugin( "pluginname" );
}
```

## 6. AbstractCacheableService Type Parameters

Raw type `AbstractCacheableService` must be parameterized. The typed `initCache(String, Class<K>, Class<V>)` replaces the no-arg `initCache()`. Use `<String, Object>` as default when the cache stores heterogeneous values.

**Before:**
```java
@ApplicationScoped
public class MyCacheService extends AbstractCacheableService
{
    @PostConstruct
    public void init( )
    {
        initCache( );
    }
}
```

**After:**
```java
@ApplicationScoped
public class MyCacheService extends AbstractCacheableService<String, Object>
{
    @PostConstruct
    public void init( )
    {
        initCache( CACHE_NAME, String.class, Object.class );
    }
}
```

## 7. No getInstance() on Cache Services

`getInstance()` is `@Deprecated(since = "8.0", forRemoval = true)` in lutece-core. Use `@Inject` or `CDI.current().select()` instead. See section 5 for the access patterns.
