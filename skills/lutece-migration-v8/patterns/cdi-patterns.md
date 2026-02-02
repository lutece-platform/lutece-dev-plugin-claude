# CDI Migration Patterns (v7 -> v8)

Single source of truth for all Spring-to-CDI, scope, injection, and related migration patterns.
Phases reference this file on demand. This is a pattern catalog, not a step-by-step guide.

> **Reference-First Principle:** This file is a static guide. Before applying ANY pattern below, **search `~/.lutece-references/` for an existing v8 implementation** of the same pattern (Grep for the class/interface/annotation). If a reference exists, reproduce its structure exactly — it is the living truth and takes priority over this document.

## 1. Context XML -> beans.xml

### Remove Spring Context XML

Delete all `*_context.xml` files (e.g., `webapp/WEB-INF/conf/plugins/myPlugin_context.xml`).
Before deleting, **catalog every bean** defined in these files -- each one must be migrated.

### Add CDI beans.xml

Create `src/main/resources/META-INF/beans.xml`:
```xml
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0" bean-discovery-mode="annotated">
</beans>
```

## 2. CDI Scopes

### DAO and Service classes

Every DAO and Service class must get `@ApplicationScoped`:
```java
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class MyDAO implements IMyDAO { ... }

@ApplicationScoped
public class MyService { ... }
```

- If adding a CDI scope annotation (`@ApplicationScoped`, `@SessionScoped`, etc.), remove `final` keyword from class (CDI cannot proxy final classes). Do NOT remove `final` from classes that are not CDI-managed
- Remove private constructors used for singleton enforcement
- Remove static `_instance` / `_singleton` fields
- `getInstance()` methods are `@Deprecated(since = "8.0", forRemoval = true)` in lutece-core. **Ask the user** whether to remove each `getInstance()` or keep it temporarily:
  - **Remove** (preferred): delete the method, update all callers to use `@Inject` (CDI-managed beans) or `CDI.current().select()` (static contexts like Home classes)
  - **Keep temporarily**: if external non-CDI callers depend on it, mark it `@Deprecated(since = "8.0", forRemoval = true)` and convert the body to `return CDI.current().select(MyService.class).get();`

### JspBean classes (scope selection rules)

Inspect the JspBean's **instance fields**. If it stores per-user state across requests, use `@SessionScoped`. Otherwise, use `@RequestScoped`.

**`@SessionScoped`** -- bean has session state fields (pagination, working objects, filters, multi-step context, breadcrumb):
```java
@SessionScoped
@Named
@Controller(controllerJsp = "ManageMyPlugin.jsp", ...)
public class MyPluginJspBean extends MVCAdminJspBean {
    private int _nItemsPerPage;
    private String _strCurrentPageIndex;
    private MyEntity _entity;
}
```

**`@RequestScoped`** -- bean is stateless (no session instance fields):
```java
@RequestScoped
@Named
@Controller(controllerJsp = "Manage.jsp", ..., securityTokenEnabled = true)
public class MyJspBean extends MVCAdminJspBean {
    // No session-state instance fields
}
```

### XPage classes

**XPage with session state -> `@SessionScoped`:**
```java
// BEFORE (v7)
@Controller( xpageName = "myXPage", pageTitleI18nKey = "...", pagePathI18nKey = "..." )
public class MyXPage extends MVCApplication {
    private static MyService _service = SpringContextService.getBean( MyService.BEAN_NAME );
    private ICaptchaSecurityService _captchaSecurityService = new CaptchaSecurityService();
}

// AFTER (v8)
@SessionScoped
@Named( "myplugin.xpage.myXPage" )
@Controller( xpageName = "myXPage", pageTitleI18nKey = "...", pagePathI18nKey = "...", securityTokenEnabled=false )
public class MyXPage extends MVCApplication {
    @Inject
    private MyService _service;
    @Inject
    @Named(BeanUtils.BEAN_CAPTCHA_SERVICE)
    private Instance<ICaptchaService> _captchaService;
    @Inject
    private SecurityTokenService _securityTokenService;
}
```

**XPage without session state -> `@RequestScoped`:**
```java
@RequestScoped
@Named( "myplugin.xpage.myOtherXPage" )
@Controller( xpageName = "myOtherXPage", ... )
public class MyOtherXPage extends MVCApplication { ... }
```

Key XPage migration rules:
1. Add `@SessionScoped` or `@RequestScoped` (choose based on whether the XPage maintains state)
2. Add `@Named("pluginName.xpage.xpageName")` to identify the bean
3. Replace all `SpringContextService.getBean()` with `@Inject`
4. Replace `SecurityTokenService.getInstance()` with `@Inject private SecurityTokenService`
5. Replace `WorkflowService.getInstance()` with `@Inject private WorkflowService`
6. Replace `new CaptchaSecurityService()` with `@Inject @Named(BeanUtils.BEAN_CAPTCHA_SERVICE) Instance<ICaptchaService>`
7. Replace static upload handler access with `@Inject`

### EntryType classes (GenericAttributes-based plugins)

EntryType classes (extending `AbstractEntryType*`) need:
1. `@ApplicationScoped`
2. `@Named("pluginName.entryTypeName")` matching the bean name from the old context XML
3. Anonymization types injected via `@Inject` method with `@Named` parameters
4. Upload handler injected via `@Inject` instead of static access

```java
@ApplicationScoped
@Named( "myplugin.entryTypeText" )
public class EntryTypeText extends AbstractEntryTypeText {
    @Inject
    private MyAsynchronousUploadHandler _uploadHandler;

    @Inject
    public void addAnonymizationTypes(
        @Named("genericattributes.entryIdAnonymizationType") IEntryAnonymizationType entryId,
        @Named("genericattributes.entryCodeAnonymizationType") IEntryAnonymizationType entryCode,
        // ... other anonymization types
    ) {
        setAnonymizationTypes( List.of( entryId, entryCode, ... ) );
    }

    @Override
    public AbstractGenAttUploadHandler getAsynchronousUploadHandler() {
        return _uploadHandler;
    }
}
```

### Prototype beans -> @Dependent

Spring `scope="prototype"` beans become CDI `@Dependent`:
```java
// v7 Spring XML: <bean id="myBean" class="..." scope="prototype" />
// v8:
@Dependent
@Named("myBean")
public class MyBean { ... }
```

## 3. SpringContextService Replacement

| v7 Pattern | v8 Pattern |
|-----------|-----------|
| `SpringContextService.getBean("beanId")` | `CDI.current().select(InterfaceType.class).get()` |
| `SpringContextService.getBean("namedBean")` | `CDI.current().select(Type.class, NamedLiteral.of("namedBean")).get()` |
| `SpringContextService.getBeansOfType(Type.class)` | `CDI.current().select(Type.class)` (returns `Instance<Type>`) |
| `SpringContextService.getBeansOfType(Type.class)` in loop | `CDI.current().select(Type.class).forEach(...)` |

## 4. Static DAO in Home Classes

If the Home class becomes CDI-managed (annotated with a CDI scope), remove `final` keyword (CDI cannot proxy final classes). Do NOT remove `final` from Home classes that remain plain utility classes without CDI annotations.

```java
// BEFORE
public final class MyHome {
    private static IMyDAO _dao = SpringContextService.getBean("myDAO");
}

// AFTER
public class MyHome {
    private static IMyDAO _dao = CDI.current().select(IMyDAO.class).get();
}
```

## 5. CDI Injection

### Field injection (@Inject)

For CDI-managed beans (classes annotated with `@ApplicationScoped`), prefer `@Inject` over `CDI.current().select()`:
```java
@Inject
private IMyDAO _dao;

@Inject
@Named("namedBean")
private IMyService _service;
```

### Instance<T> for optional/multiple beans (MANDATORY for optional services)

Use `Instance<T>` whenever the service may or may not be deployed (e.g., a plugin may not be installed). **Always check `isResolvable()` before calling `get()`.**

```java
// Optional service — plugin may not be installed
@Inject
@Named(BeanUtils.BEAN_CAPTCHA_SERVICE)
private Instance<ICaptchaService> _captchaService;

// Usage: ALWAYS check isResolvable() before get()
if ( _captchaService.isResolvable() )
{
    String strHtml = _captchaService.get().getHtmlCode();
    boolean bValid = _captchaService.get().validate( request );
}

// Multiple implementations — iterate all
@Inject
private Instance<IMyProvider> _providers;

for ( IMyProvider provider : _providers )
{
    provider.process();
}

// Check availability in @PostConstruct (like WorkflowService does)
@Inject
@Named("workflow.workflowProvider")
private Instance<IWorkflowProvider> _provider;

@PostConstruct
void init()
{
    _bServiceAvailable = _provider != null && _provider.isResolvable();
}
```

**Key `Instance<T>` methods:**
| Method | Purpose |
|--------|---------|
| `isResolvable()` | Exactly one bean matches — safe to call `get()` |
| `isUnsatisfied()` | No bean matches — the service is not deployed |
| `isAmbiguous()` | Multiple beans match — needs qualifier to disambiguate |
| `get()` | Returns the resolved bean instance (call only after `isResolvable()`) |
| `stream()` | Iterate all matching implementations |

### Constructor injection (workflow tasks/components)

For workflow task components, use constructor injection:
```java
@ApplicationScoped
@Named("myModule.myTaskComponent")
public class MyTaskComponent extends NoFormTaskComponent {
    @Inject
    public MyTaskComponent(
        @Named("myModule.taskType") ITaskType taskType,
        @Named("myModule.taskConfigService") ITaskConfigService configService
    ) {
        setTaskType(taskType);
        setTaskConfigService(configService);
    }
}
```

## 6. CDI Producers

### Simple producers (scalar properties only)

When a Spring XML bean had **scalar property values** (strings, numbers), create a Producer class.

**CRITICAL: Check the v8 API first.** Before writing a Producer, read the **v8 source** of the class being instantiated in `~/.lutece-references/`. The class constructors and setters may have changed in v8 (e.g., constructor args removed because the class is now CDI-managed with `@Inject`). If the v8 class is `@ApplicationScoped`, you probably don't need a Producer at all -- just `@Inject` it directly.

```java
// v7 XML: <bean id="x" class="Y"><property name="p" value="v"/></bean>
// v8:
@ApplicationScoped
public class YProducer {
    @Produces @Named("x") @ApplicationScoped
    public Y produce() {
        Y y = new Y();
        y.setP("v");
        return y;
    }
}
```

### Producers with @ConfigProperty

When Spring XML beans had property values, create a Producer that reads from `.properties` via `@ConfigProperty`:

```java
@ApplicationScoped
public class MyProducer {
    @Produces
    @ApplicationScoped
    @Named("myplugin.myBeanName")
    public MyType produce(
        @ConfigProperty(name = "myplugin.myBean.propertyA") String propA,
        @ConfigProperty(name = "myplugin.myBean.propertyB") String propB
    ) {
        return new MyType(propA, propB);
    }
}
```

The corresponding `.properties` file must contain the values:
```properties
myplugin.myBean.propertyA=valueA
myplugin.myBean.propertyB=valueB
```

### Producers referencing other named CDI beans (bean refs)

**CRITICAL PATTERN.** When a Spring XML bean's constructor-args or properties reference **other named beans** (`<constructor-arg ref="otherBean" />`), you MUST:
1. Make the bean names **configurable** via `@ConfigProperty` in the `.properties` file
2. Resolve them at runtime via `CdiHelper.getReference()` — **NEVER** use `@Inject @Named` with hardcoded bean names in the producer

**WRONG — hardcoded bean names in producer (NOT configurable):**
```java
// DO NOT DO THIS — the service names are hardcoded in Java
@ApplicationScoped
public class MyProducer {
    @Inject @Named("localDatabaseFileService")
    private IFileStoreService _fileStoreService;  // WRONG: hardcoded

    @Inject @Named("defaultFileDownloadService")
    private IFileDownloadUrlService _downloadService;  // WRONG: hardcoded

    @Produces @ApplicationScoped @Named("myplugin.myProvider")
    public IFileStoreServiceProvider produce() {
        return new FileStoreServiceProvider("myProvider",
            _fileStoreService, _downloadService, _rbacService, false);
    }
}
```

**CORRECT — configurable via properties + CdiHelper:**
```java
import org.eclipse.microprofile.config.inject.ConfigProperty;
import fr.paris.lutece.portal.service.util.CdiHelper;

@ApplicationScoped
public class MyPluginFileStoreServiceProviderProducer
{
    @Produces
    @ApplicationScoped
    @Named( "myplugin.fileStoreServiceProvider" )
    public IFileStoreServiceProvider createFileStoreProvider(
            @ConfigProperty( name = "myplugin.fileStoreServiceProvider.fileStoreService" ) String fileStoreImplName,
            @ConfigProperty( name = "myplugin.fileStoreServiceProvider.rbacService" ) String rbacImplName,
            @ConfigProperty( name = "myplugin.fileStoreServiceProvider.downloadService" ) String downloadImplName )
    {
        return new FileStoreServiceProvider( "myPluginFileStoreProvider",
                CdiHelper.getReference( IFileStoreService.class, fileStoreImplName ),
                CdiHelper.getReference( IFileDownloadUrlService.class, downloadImplName ),
                CdiHelper.getReference( IFileRBACService.class, rbacImplName ),
                false );
    }
}
```

With the corresponding `.properties` file:
```properties
myplugin.fileStoreServiceProvider.fileStoreService=localDatabaseFileService
myplugin.fileStoreServiceProvider.rbacService=myplugin.myFileRBACService
myplugin.fileStoreServiceProvider.downloadService=defaultFileDownloadService
```

**Required companion changes:**

1. **Add `@Named` to the custom `IFileRBACService`** so it can be referenced by name in properties:
```java
@ApplicationScoped
@Named( "myplugin.myFileRBACService" )
public class MyPluginFileRBACService implements IFileRBACService { ... }
```

2. **Consumers: replace runtime lookup with `@Inject @Named`:**
```java
// WRONG — runtime lookup via FileService
@Inject
private FileService _fileService;
// then: _fileService.getFileStoreServiceProvider("myPluginFileStoreProvider")

// CORRECT — direct CDI injection of the produced bean
@Inject
@Named( "myplugin.fileStoreServiceProvider" )
private IFileStoreServiceProvider _fileStoreProvider;
```

**Reference implementation:** `lutece-tech-plugin-filegenerator` — see `FileGeneratorFileStoreServiceProviderProducer.java`, `TemporaryFileRBACService.java`, and `filegenerator.properties` in `~/.lutece-references/`.

### TaskType producers (workflow)

TaskType beans from Spring XML become CDI producers with `@ConfigProperty`:

```java
@ApplicationScoped
public class MyTaskTypeProducer {
    @Produces @ApplicationScoped
    @Named("myModule.taskType")
    public ITaskType produce(
        @ConfigProperty(name = "myModule.taskType.key") String key,
        @ConfigProperty(name = "myModule.taskType.titleI18nKey") String titleI18nKey,
        @ConfigProperty(name = "myModule.taskType.beanName") String beanName,
        @ConfigProperty(name = "myModule.taskType.configBeanName") String configBeanName,
        @ConfigProperty(name = "myModule.taskType.configRequired", defaultValue = "false") boolean configRequired,
        @ConfigProperty(name = "myModule.taskType.taskForAutomaticAction", defaultValue = "false") boolean taskForAutomaticAction
    ) {
        TaskType t = new TaskType();
        t.setKey(key); t.setTitleI18nKey(titleI18nKey); t.setBeanName(beanName);
        t.setConfigBeanName(configBeanName); t.setConfigRequired(configRequired);
        t.setTaskForAutomaticAction(taskForAutomaticAction);
        return t;
    }
}
```

With corresponding `.properties`:
```properties
myModule.taskType.key=myTaskKey
myModule.taskType.titleI18nKey=module.workflow.mymodule.task_title
myModule.taskType.beanName=myModule.myTask
myModule.taskType.configBeanName=myModule.myTaskConfig
myModule.taskType.configRequired=true
myModule.taskType.taskForAutomaticAction=false
```

### CDI Impl Classes for abstract services

When a library provides abstract service classes (e.g., `ActionService` from `library-workflow-core`), create empty CDI implementation classes:

```java
@ApplicationScoped
@Named(ActionService.BEAN_SERVICE)
public class ActionServiceImpl extends ActionService {
    // Empty - provides CDI annotations for parent abstract class
}
```

This is needed because CDI cannot proxy abstract classes without a concrete subclass.

### Default constructor for CDI proxies

CDI-managed classes with `@Inject` constructor MUST also have a default (no-arg) constructor:

```java
@ApplicationScoped
@Named("myModule.myTaskComponent")
public class MyTaskComponent extends NoFormTaskComponent {
    MyTaskComponent() { } // Required for CDI proxy

    @Inject
    public MyTaskComponent(
        @Named("myModule.taskType") ITaskType taskType,
        @Named("myModule.configService") ITaskConfigService configService
    ) {
        setTaskType(taskType);
        setTaskConfigService(configService);
    }
}
```

## 7. Singleton Pattern Migration

```java
// v7
public final class MyService {
    private static MyService _instance;
    public static synchronized MyService getInstance() { ... }
}

// v8 -- PREFERRED: remove getInstance() entirely, use @Inject or CDI.current().select()
@ApplicationScoped
public class MyService {
    // No getInstance() -- callers use @Inject (CDI beans) or CDI.current().select(MyService.class).get() (static contexts)
}

// v8 -- TEMPORARY: keep getInstance() only if external callers depend on it
@ApplicationScoped
public class MyService {
    @Deprecated(since = "8.0", forRemoval = true)
    public static MyService getInstance() {
        return CDI.current().select(MyService.class).get();
    }
}
```

### Deprecated `getInstance()` methods in lutece-core

These methods are `@Deprecated(since = "8.0", forRemoval = true)`. Replace with `@Inject` in CDI-managed classes or `CDI.current().select()` in static contexts.

| Class | Deprecated Method | @Inject Type |
|-------|-------------------|-------------|
| `SecurityTokenService` | `getInstance()` | `ISecurityTokenService` |
| `FileService` | `getInstance()` | `FileService` |
| `FileImageService` | `getInstance()` | `FileImageService` |
| `FileImagePublicService` | `getInstance()` | `FileImagePublicService` |
| `WorkflowService` | `getInstance()` | `WorkflowService` |
| `AccessControlService` | `getInstance()` | `AccessControlService` |
| `AttributeService` | `getInstance()` | `AttributeService` |
| `AttributeFieldService` | `getInstance()` | `AttributeFieldService` |
| `AttributeTypeService` | `getInstance()` | `AttributeTypeService` |
| `PortletService` | `getInstance()` | `PortletService` |
| `AccessLogService` | `getInstance()` | `AccessLogService` |
| `RegularExpressionService` | `getInstance()` | `RegularExpressionService` |
| `EditorBbcodeService` | `getInstance()` | `IEditorBbcodeService` |
| `ProgressManagerService` | `getInstance()` | `ProgressManagerService` |
| `DashboardService` | `getInstance()` | `DashboardService` |
| `AdminDashboardService` | `getInstance()` | `AdminDashboardService` |
| `FilterService` | `getInstance()` | `FilterService` |
| `ServletService` | `getInstance()` | `ServletService` |
| `LuteceUserCacheService` | `getInstance()` | `LuteceUserCacheService` |

Rules for replacement:
- Use the **interface type** when one exists (e.g., `ISecurityTokenService`, `IEditorBbcodeService`)
- Use the **concrete class** when no interface exists (e.g., `FileService`, `WorkflowService`)
- Keep static imports of the class for **constants** (`SecurityTokenService.MARK_TOKEN`, `SecurityTokenService.PARAMETER_TOKEN`, etc.)
- Field naming: `_securityTokenService`, `_fileService`, `_workflowService`, etc.

## 8. Business Objects

### Serializable requirement

Business objects used in `@SessionScoped` beans or passed through CDI events should implement `Serializable`:

```java
public class MyBusinessObject implements Cloneable, Serializable {
    private static final long serialVersionUID = 1L;
    // ...
}
```

## 9. Transaction Annotation

```java
// BEFORE (v7)
@Transactional(MyPlugin.BEAN_TRANSACTION_MANAGER)

// AFTER (v8) - no transaction manager reference
@Transactional
```

Import change: `org.springframework.transaction.annotation.Transactional` -> `jakarta.transaction.Transactional`

## 10. DAOUtil try-with-resources

Replace manual `daoUtil.free()` with try-with-resources:

```java
// BEFORE (v7)
DAOUtil daoUtil = new DAOUtil(SQL_QUERY, plugin);
daoUtil.setInt(1, id);
daoUtil.executeUpdate();
daoUtil.free();

// AFTER (v8)
try (DAOUtil daoUtil = new DAOUtil(SQL_QUERY, plugin)) {
    daoUtil.setInt(1, id);
    daoUtil.executeUpdate();
}
```

## 11. RBAC User Cast

v8 requires explicit `(User)` cast for RBAC calls:
```java
// BEFORE (v7)
RBACService.isAuthorized(resource, permission, adminUser)

// AFTER (v8)
RBACService.isAuthorized(resource, permission, (User) adminUser)
```

## 12. Async Processing

Replace `CompletableFuture.runAsync()` with Jakarta `@Asynchronous`:

```java
// BEFORE (v7)
import java.util.concurrent.CompletableFuture;
public void generateFile(IFileGenerator generator) {
    CompletableFuture.runAsync(new MyRunnable(generator));
}

// AFTER (v8)
import jakarta.enterprise.concurrent.Asynchronous;
@Asynchronous
public void generateFile(IFileGenerator generator) {
    new MyRunnable(generator).run();
}
```

## 13. CdiHelper

Use `CdiHelper.getReference()` for programmatic CDI lookup with qualifiers in producers:

```java
CdiHelper.getReference(IMyService.class, "namedBeanName");
```

## 14. InitializingBean -> @PostConstruct

Replace Spring's `InitializingBean.afterPropertiesSet()` with Jakarta `@PostConstruct`:

```java
// BEFORE (v7)
import org.springframework.beans.factory.InitializingBean;
public class MyComponent implements InitializingBean {
    @Override
    public void afterPropertiesSet() throws Exception {
        Assert.notNull(_field, "Required");
    }
}

// AFTER (v8)
import jakarta.annotation.PostConstruct;
public class MyComponent {
    @PostConstruct
    public void afterPropertiesSet() {
        if (_field == null) throw new IllegalArgumentException("Required");
    }
}
```

Also remove `extends InitializingBean` from interfaces.

## 15. Workflow Task Signature Changes

If implementing `ITask.processTaskWithResult()`, update to the new signature:

```java
// BEFORE (v7)
boolean processTaskWithResult(int nIdResourceHistory, HttpServletRequest request, Locale locale, User user);

// AFTER (v8) - includes resource info
boolean processTaskWithResult(int nIdResource, String strResourceType, int nIdResourceHistory,
    HttpServletRequest request, Locale locale, User user);
```

Similarly for `AsynchronousSimpleTask.processAsynchronousTask()`.

## 16. Models Injection (JspBean/XPage) — MANDATORY

**This migration is MANDATORY, not optional.** `getModel()` is deprecated and will cause runtime errors if mixed with `Models`. In Lutece 8, `Models.asMap()` returns an **unmodifiable map** — any code that calls `put()` on it will throw `UnsupportedOperationException` at runtime.

**Before (will crash in v8):**
```java
Map<String, Object> model = getModel( );
model.put( MARK_ITEM, item );
model.put( SecurityTokenService.MARK_TOKEN, _securityTokenService.getToken( request, ACTION ) );
XPage page = getXPage( TEMPLATE, locale, model );
```

**After (use `Models` injection):**
```java
@Inject
private Models _models;

// In view method:
_models.put( MARK_ITEM, item );
_models.put( SecurityTokenService.MARK_TOKEN, _securityTokenService.getToken( request, ACTION ) );
XPage page = getXPage( TEMPLATE, locale );
```

**Rules:**
- Inject `Models` (from `fr.paris.lutece.portal.web.cdi.mvc.Models`) — it is `@RequestScoped`
- Use `_models.put(key, value)` instead of `model.put(key, value)`
- Call `getXPage(template, locale)` (2 args) instead of `getXPage(template, locale, model)` (3 args)
- For back-office: `getPage(titleProperty, template)` (2 args) instead of `getPage(titleProperty, template, model)` (3 args)
- `Models.put()` returns `this` for chaining: `_models.put(A, a).put(B, b)`

**CRITICAL — asMap() is unmodifiable:**
- `_models.asMap()` returns an **unmodifiable view** of the map — calling `put()` on it throws `UnsupportedOperationException`
- NEVER pass `_models.asMap()` to a method that writes into the map
- If a helper method needs to add entries to the model, change its signature to accept `Models` (not `Map<String, Object>`)

**Per-action token vs CSRF auto-token:**
- The 2-arg `getXPage(template, locale)` / `getPage(titleProperty, template)` automatically includes a **global CSRF token** (`SecurityTokenHandler.MARK_CSRF_TOKEN`) — this is a generic anti-CSRF measure
- **Per-action tokens** (`SecurityTokenService.MARK_TOKEN`) are **different** — they are tied to a specific action and must still be added manually: `_models.put(SecurityTokenService.MARK_TOKEN, _securityTokenService.getToken(request, ACTION))`
- Both tokens can coexist in the model; they serve different purposes

**Helper method signatures — MUST be updated:**
Every method in the class hierarchy that receives the model as `Map<String, Object>` and calls `put()` on it **must** be changed to accept `Models`. This includes abstract methods in base classes and their implementations in subclasses.

```java
// Before — WILL CRASH if passed _models.asMap()
protected void addElementsToModel( MyDTO dto, User user, Locale locale, Map<String, Object> model )
{
    model.put( MARK_USER, user );  // UnsupportedOperationException!
}

// After — accepts Models directly
protected void addElementsToModel( MyDTO dto, User user, Locale locale, Models model )
{
    model.put( MARK_USER, user );  // OK
}
```

The `Models` interface supports `put(String, Object)` and `get(String)`, so most code using `Map.put()` works unchanged after the type change.

## 17. Configuration

### @ConfigProperty in CDI beans

If the plugin uses `AppPropertiesService` for injected config in CDI beans, optionally use MicroProfile Config:

```java
@Inject
@ConfigProperty(name = "myplugin.myProperty", defaultValue = "default")
private String _myProperty;
```

**Note:** `AppPropertiesService.getProperty()` still works in v8. MicroProfile Config is optional but preferred in CDI beans.

### AppPropertiesService -> MicroProfile Config (in libraries)

For libraries that don't have CDI injection context, use `ConfigProvider.getConfig()` directly:

```java
// BEFORE (v7)
import fr.paris.lutece.portal.service.util.AppPropertiesService;
String value = AppPropertiesService.getProperty(PROPERTY_KEY);
String valueWithDefault = AppPropertiesService.getProperty(PROPERTY_KEY, "default");

// AFTER (v8)
import org.eclipse.microprofile.config.Config;
import org.eclipse.microprofile.config.ConfigProvider;
private static Config _config = ConfigProvider.getConfig();
String value = _config.getOptionalValue(PROPERTY_KEY, String.class).orElse(null);
String valueWithDefault = _config.getOptionalValue(PROPERTY_KEY, String.class).orElse("default");
```

## 18. REST API Migration

### 18.1 Import Migration

Replace `javax.ws.rs.*` imports with `jakarta.ws.rs.*`.

### 18.2 Jersey -> Jakarta JAX-RS

If the plugin uses Jersey directly:
- Replace `ResourceConfig` with standard `Application` class using `@ApplicationPath`
- Remove Jersey-specific dependencies (`jersey-server`, `jersey-spring5`, `jersey-media-*`)
- Remove manual `register()` calls -- use `@Provider` auto-discovery instead
- Remove Jersey filter registrations from `plugin.xml`

```java
// BEFORE (v7) - Jersey ResourceConfig
public class MyRestConfig extends ResourceConfig {
    public MyRestConfig() {
        register(MyExceptionMapper.class);
    }
}

// AFTER (v8) - Standard JAX-RS Application
@ApplicationPath("/rest/")
public class MyRestApplication extends Application { }
```

### 18.3 REST Authentication Filter

Replace servlet-based auth filters with JAX-RS `ContainerRequestFilter`:

```java
// AFTER (v8)
@Provider
@PreMatching
@Priority(Priorities.AUTHENTICATION)
public class MyAuthFilter implements ContainerRequestFilter {
    @Inject
    private HttpServletRequest _httpRequest;

    @Inject
    @MyAuthenticatorQualifier
    private RequestAuthenticator _authenticator;

    @Override
    public void filter(ContainerRequestContext ctx) throws IOException {
        if (!_authenticator.isRequestAuthenticated(_httpRequest)) {
            ctx.abortWith(Response.status(Response.Status.UNAUTHORIZED).build());
        }
    }
}
```

### 18.4 Custom CDI Qualifier for Authenticators

```java
@Qualifier
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.FIELD, ElementType.METHOD, ElementType.PARAMETER, ElementType.TYPE})
public @interface MyAuthenticatorQualifier { }
```

### 18.5 Exception Mappers

Add `@Provider` annotation for auto-discovery (no manual registration):
```java
@Provider
public class MyExceptionMapper implements ExceptionMapper<Throwable> { ... }
```

### 18.6 REST plugin.xml changes

- Remove `<filters>` section -- JAX-RS auto-discovers via `@ApplicationPath`
- Remove Jersey init-params

## 19. Logging

Update string concatenation to parameterized logging:

```java
// BEFORE (v7)
AppLogService.info(MyClass.class.getName() + " : message " + variable);

// AFTER (v8)
AppLogService.info("{} : message {}", MyClass.class.getName(), variable);
```

## Key Imports Reference

```java
// CDI Core
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.context.RequestScoped;
import jakarta.enterprise.context.SessionScoped;
import jakarta.enterprise.context.Dependent;
import jakarta.enterprise.inject.spi.CDI;
import jakarta.enterprise.inject.Instance;
import jakarta.enterprise.inject.Produces;
import jakarta.enterprise.inject.Alternative;
import jakarta.enterprise.inject.literal.NamedLiteral;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.inject.Singleton;

// CDI Events
import jakarta.enterprise.event.Observes;
import jakarta.enterprise.event.ObservesAsync;
import jakarta.enterprise.context.Initialized;
import jakarta.annotation.Priority;
import fr.paris.lutece.portal.service.event.EventAction;
import fr.paris.lutece.portal.service.event.Type;
import fr.paris.lutece.portal.service.event.Type.TypeQualifier;
import fr.paris.lutece.portal.business.event.ResourceEvent;

// Lifecycle
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;

// Servlet
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

// REST
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.*;

// Validation
import jakarta.validation.ConstraintViolation;

// Config
import org.eclipse.microprofile.config.inject.ConfigProperty;

// Cache
import javax.cache.Cache; // NOTE: javax, NOT jakarta
```
