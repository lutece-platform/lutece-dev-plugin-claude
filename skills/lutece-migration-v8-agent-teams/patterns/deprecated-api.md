# Deprecated API Replacement Patterns (v7 → v8)

Single source of truth for replacing deprecated `getInstance()` and other deprecated API calls.

> **Reference-First Principle:** Before replacing any deprecated API, **search `~/.lutece-references/` for how the replacement is used in practice** (e.g., `Grep "@Inject" ~/.lutece-references/ --glob "*Service.java"`). Reproduce the reference structure exactly.

## 1. Deprecated getInstance() Methods

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

## 2. Replacement in CDI-Managed Classes

For classes with a CDI scope annotation (`@ApplicationScoped`, `@RequestScoped`, `@SessionScoped`, `@Dependent`), add an `@Inject` field and replace all `getInstance()` calls.

**Before:**
```java
@RequestScoped
public class MyXPage extends MVCApplication {
    @Action(ACTION_CREATE)
    public XPage doCreate(HttpServletRequest request) throws AccessDeniedException {
        if (!SecurityTokenService.getInstance().validate(request, ACTION_CREATE)) {
            throw new AccessDeniedException("Invalid token");
        }
        model.put(SecurityTokenService.MARK_TOKEN,
            SecurityTokenService.getInstance().getToken(request, ACTION_CREATE));
    }
}
```

**After:**
```java
@RequestScoped
public class MyXPage extends MVCApplication {
    @Inject
    private ISecurityTokenService _securityTokenService;

    @Action(ACTION_CREATE)
    public XPage doCreate(HttpServletRequest request) throws AccessDeniedException {
        if (!_securityTokenService.validate(request, ACTION_CREATE)) {
            throw new AccessDeniedException("Invalid token");
        }
        model.put(SecurityTokenService.MARK_TOKEN,
            _securityTokenService.getToken(request, ACTION_CREATE));
    }
}
```

**Rules:**
- Use the **interface type** when one exists (e.g., `ISecurityTokenService`, `IEditorBbcodeService`)
- Use the **concrete class** when no interface exists (e.g., `FileService`, `WorkflowService`)
- Keep the static import of the class for **constants** (`SecurityTokenService.MARK_TOKEN`, `SecurityTokenService.PARAMETER_TOKEN`, `FileService.PARAMETER_RESOURCE_ID`, etc.)
- Field naming: `_securityTokenService`, `_fileService`, `_workflowService`, etc.

## 3. Replacement in Static Contexts

In Home classes or static utility methods where `@Inject` is not available, replace with direct CDI lookup.

**Before:**
```java
public class MyHome {
    public static void doSomething(HttpServletRequest request) {
        WorkflowService.getInstance().doProcess(...);
    }
}
```

**After:**
```java
public class MyHome {
    public static void doSomething(HttpServletRequest request) {
        CDI.current().select(WorkflowService.class).get().doProcess(...);
    }
}
```

## 4. Plugin.init() Cleanup

Plugin classes (`extends PluginDefaultImplementation`) often contain deprecated calls in `init()` that were needed in v7 for early bean initialization. In v8, CDI manages bean lifecycle -- these calls are redundant.

| Pattern | Why unnecessary in v8 |
|---------|----------------------|
| `CDI.current().select(MyCacheService.class).get()` | `@ApplicationScoped` + `@PostConstruct` handles initialization |
| `FileImagePublicService.init()` | Service has `@Observes @Initialized(ApplicationScoped.class)` in core |
| `FileImageService.init()` | Same as above |
| `MyService.getInstance().register()` | Registration should use `@PostConstruct` or `@Observes @Initialized(ApplicationScoped.class)` |

**Before:**
```java
public final class MyPlugin extends PluginDefaultImplementation {
    @Override
    public void init() {
        CDI.current().select(MyCacheService.class).get();
        FileImagePublicService.init();
    }
}
```

**After:**
```java
public final class MyPlugin extends PluginDefaultImplementation {
    public static final String PLUGIN_NAME = "myplugin";
}
```

If the `init()` method becomes empty, remove the override entirely.

## 5. getModel() → Models Injection (MANDATORY)

**This migration is MANDATORY, not optional.** `getModel()` is deprecated and will cause runtime errors if mixed with `Models`. In Lutece 8, `Models.asMap()` returns an **unmodifiable map** — any code that calls `put()` on it will throw `UnsupportedOperationException` at runtime.

**Before:**
```java
Map<String, Object> model = getModel( );
model.put( MARK_ITEM, item );
model.put( SecurityTokenService.MARK_TOKEN, _securityTokenService.getToken( request, ACTION ) );
XPage page = getXPage( TEMPLATE, locale, model );
```

**After:**
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
- The 2-arg `getXPage(template, locale)` / `getPage(titleProperty, template)` automatically includes a **global CSRF token** (`SecurityTokenHandler.MARK_CSRF_TOKEN`)
- **Per-action tokens** (`SecurityTokenService.MARK_TOKEN`) are different — tied to a specific action, must still be added manually
- Both tokens can coexist in the model

**Helper method signatures — MUST be updated:**
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

Every method in the class hierarchy that receives the model as `Map<String, Object>` and calls `put()` on it **must** be changed to accept `Models`. This includes abstract methods in base classes and their implementations in subclasses.

## 6. Pagination — LocalizedPaginator → @Inject @Pager IPager

Manual pagination with `LocalizedPaginator`, `_strCurrentPageIndex`, `_nItemsPerPage` instance fields is replaced by CDI-injected `IPager`. The `PaginatorHandler` (session-scoped) manages pagination state automatically.

**Before:**
```java
private int _nItemsPerPage;
private int _nDefaultItemsPerPage;
private String _strCurrentPageIndex;

public String getManageTasks( HttpServletRequest request )
{
    _strCurrentPageIndex = AbstractPaginator.getPageIndex( request, AbstractPaginator.PARAMETER_PAGE_INDEX, _strCurrentPageIndex );
    _nDefaultItemsPerPage = AppPropertiesService.getPropertyInt( PROPERTY_ITEMS_PER_PAGE, 50 );
    _nItemsPerPage = AbstractPaginator.getItemsPerPage( request, AbstractPaginator.PARAMETER_ITEMS_PER_PAGE, _nItemsPerPage, _nDefaultItemsPerPage );

    List<Task> listTasks = TaskHome.findAll();
    UrlItem url = new UrlItem( JSP_MANAGE );
    LocalizedPaginator<Task> paginator = new LocalizedPaginator<>( listTasks, _nItemsPerPage, url.getUrl(), AbstractPaginator.PARAMETER_PAGE_INDEX, _strCurrentPageIndex, getLocale() );

    _models.put( MARK_NB_ITEMS_PER_PAGE, String.valueOf( _nItemsPerPage ) );
    _models.put( MARK_PAGINATOR, paginator );
    _models.put( MARK_LIST, paginator.getPageItems() );

    return getPage( PROPERTY_PAGE_TITLE_MANAGE, TEMPLATE_MANAGE );
}
```

**After:**
```java
@Inject
@Pager( name = "taskList", listBookmark = "task_list",
        defaultItemsPerPage = "myplugin.task.itemsPerPage",
        baseUrl = "jsp/admin/plugins/myplugin/ManageTasks.jsp" )
private IPager<Task, Task> _pager;

public String getManageTasks( HttpServletRequest request )
{
    List<Task> listTasks = TaskHome.findAll();

    _pager.withListItem( listTasks )
          .populateModels( request, _models, getLocale() );

    return getPage( PROPERTY_PAGE_TITLE_MANAGE, TEMPLATE_MANAGE );
}
```

**Migration rules:**
- Remove `_nItemsPerPage`, `_nDefaultItemsPerPage`, `_strCurrentPageIndex` instance fields
- Remove manual `AbstractPaginator.getPageIndex()`/`getItemsPerPage()` calls
- Remove `UrlItem` + `LocalizedPaginator` construction
- Remove manual `_models.put( MARK_PAGINATOR, ... )` / `_models.put( MARK_NB_ITEMS_PER_PAGE, ... )` / `_models.put( MARK_LIST, ... )`
- `populateModels()` handles all of the above automatically
- The `listBookmark` attribute in `@Pager` defines the model key for the items list
- Use `withIdList()` + delegate for lazy loading (load only current page from DB)

**Template:** use the `paginationAdmin` macro from core:
```html
<@paginationAdmin paginator=paginator nb_items_per_page=nb_items_per_page />
```

## 7. Unused Import Cleanup

After replacing all deprecated calls, remove unused imports:
- `import jakarta.enterprise.inject.spi.CDI` -- only if no `CDI.current()` calls remain in the file
- `import fr.paris.lutece.portal.service.security.SecurityTokenService` -- only if no constants (`MARK_TOKEN`, `PARAMETER_TOKEN`) are still referenced
- Same logic for all other service imports that were only used for `getInstance()`
