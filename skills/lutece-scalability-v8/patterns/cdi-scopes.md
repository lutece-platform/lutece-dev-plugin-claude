# Pattern — CDI scopes & end of static singletons

> Ref: core LUT‑28726 (23 services), LUT‑32353 (cluster-safe RSAKeyPair), LUT‑30894/30896 ; forms LUT‑32088/32425/32038. A mutable `static` lives in ONE JVM only → diverges across nodes.

## Anti-pattern
```java
public final class XService {
    private static XService _instance = new XService();   // mutable JVM-local state
    public static XService getInstance() { return _instance; }
    private final Map<...> _cache = new HashMap<>();      // diverges across instances
}
// or worse: init too early at class load
private static final FormService S = CDI.current().select(FormService.class).get();
```

## Target pattern
**Stateless service/DAO → `@ApplicationScoped`** ; init in `@PostConstruct` (never the constructor).
```java
@ApplicationScoped
public class XService {
    @Inject private IXDao _dao;          // injection, no static
    @PostConstruct void init() { ... }   // thread-safe init
}
```
**Remove `getInstance()` entirely** — no `@Deprecated` bridge (house rule: never deprecate). Migrate every caller:
- in a CDI bean → `@Inject` the service;
- in a non-CDI context (Home facade, object created with `new`, static util) → `CDI.current().select(XService.class).get()` or `CdiHelper.getBean(XService.class)`, resolved lazily (not in a static field initializer).
**Proxyability** (LUT‑30894): a normal-scoped bean injected elsewhere must be **non-`final`** + have a **non-private no-arg ctor** (alongside the `@Inject` ctor).

**Optional / multi-implementation dependency** (LUT‑30896, EntryServiceManager): `@Inject @Any Instance<I>` + `isResolvable()`/`stream()` collected in `@PostConstruct` — never a direct `@Named IService` of an optional plugin.

**Non-CDI object serialised into the session** (created with `new`, e.g. a display tree): dependencies as **`transient` + lazy getter** `if(_x==null) _x=CDI.current().select(...).get()` — never `static final = CDI.current()...`.

**Value genuinely shared across nodes** (keys, secrets): move it to the **database** with an **atomic** write `insertDataValueIfAbsent` (relies on the PK; tolerate `false` = another node won) — **never** `setDataValue`/upsert (overwrite race).

## Scope → usage
| Component | Scope |
|---|---|
| Stateless business service, DAO, producer | `@ApplicationScoped` |
| BO JspBean with state | `@SessionScoped @Named` (+ `Serializable`) |
| Stateless BO JspBean, FO XPage | `@RequestScoped @Named` |
| Home (facade) | non-bean, `static`, DAO resolved once via CDI (no mutable state) |

## Rules
- DO: explicit scope; **stateless** services, shared state in DB; `@PostConstruct` for init; inject (reserve `CDI.current()` for Home/non-CDI objects).
- DON'T: mutable `static`; static `CDI.current()` init in a field; mutable business state in an `@ApplicationScoped`; `final` bean or `@Inject`-only ctor.
