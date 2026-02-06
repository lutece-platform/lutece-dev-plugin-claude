# MVC Patterns — Lutece v8

## 1. @RequestParam

Binds query parameters directly to method parameters.

### Before (v7)
```java
String strName = request.getParameter("name");
int nPage = Integer.parseInt(request.getParameter("page"));
```

### After (v8)
```java
@View(VIEW_LIST)
public String getList(@RequestParam(value = "page", defaultValue = "1") int nPage,
                      @RequestParam(value = "query", defaultValue = "") String strQuery) {
    // parameters auto-bound
}
```

## 2. @RequestHeader / @CookieValue

```java
@View(VIEW_LIST)
public String getList(@RequestHeader(value = "Accept-Language") String strLang,
                      @CookieValue(value = "sessionId", defaultValue = "") String strSession) {
}
```

## 3. @ModelAttribute

Auto-binds request parameters to a Java bean.

```java
@Action(ACTION_CREATE)
public String doCreate(@ModelAttribute MyItem item, BindingResult result) {
    if (result.hasErrors()) {
        // handle binding errors
    }
    MyItemHome.create(item);
    return redirectView(request, VIEW_LIST);
}
```

## 4. @Validated + BindingResult

Bean validation with groups.

```java
@Action(ACTION_CREATE)
public String doCreate(@Validated({ValidationGroups.Creation.class}) @ModelAttribute MyItem item,
                       BindingResult result) {
    if (result.hasErrors()) {
        result.getAllErrors().forEach(e -> addError(e.getDefaultMessage()));
        return redirectView(request, VIEW_CREATE);
    }
    // ...
}
```

## 5. @ResponseBody

Return JSON/XML directly from a method (no template rendering).

```java
@Action("getData")
@ResponseBody
public List<MyItem> getData(@RequestParam("page") int nPage) {
    return MyItemHome.getItemsList(nPage, ITEMS_PER_PAGE);
}
```

Used for AJAX pagination with `paginationAjax` macro.

## 6. @RequestBody

Bind HTTP body (JSON/XML) to a Java object.

```java
@Action(ACTION_API_CREATE)
public String doApiCreate(@RequestBody MyItem item) {
    MyItemHome.create(item);
    return redirectView(request, VIEW_LIST);
}
```

## 7. CSRF Auto-Filter

In v8, CSRF protection is automatic via `SecurityTokenFilterSite` / `SecurityTokenFilterAdmin`.

### What to remove
- `SecurityTokenService.MARK_TOKEN` in model.put() calls
- `getSecurityTokenService().getToken()` in model
- Manual token validation in simple @Action methods

### What happens automatically
- Token generated on `@View` (GET request)
- Token validated on `@Action` (POST request)
- Requires using `getModel()` or `@Inject Models` (token attached there)

### Confirmation pages (special case)
For actions that need a confirmation dialog before executing:

```java
// The confirmation action references the actual action that needs the token
@Action(value = ACTION_CONFIRM_REMOVE, securityTokenAction = ACTION_REMOVE)
public String getConfirmRemove(HttpServletRequest request) {
    // Show confirmation page — token is generated for ACTION_REMOVE
    return redirect(request, getConfirmUrl(request));
}

@Action(ACTION_REMOVE)
public String doRemove(HttpServletRequest request) {
    // Token is automatically validated
    MyItemHome.remove(nId);
    return redirectView(request, VIEW_LIST);
}
```

### Disabling CSRF for specific actions
```java
@Action(value = ACTION_AJAX_UPDATE, securityTokenDisabled = true)
public String doAjaxUpdate(HttpServletRequest request) {
    // No CSRF check — use only for safe operations
}
```

## 8. MultipartItem for File Upload

See `fileupload-patterns.md` for complete migration guide.

## 9. paginationAjax

JavaScript-driven pagination without page reload.

### Template
```html
<@table id="myTable" items=items_list paginationAjax=true>
    <@columns headers=["#i18n{...}", "#i18n{...}"]>
        <@column>${item.name}</@column>
        <@column>${item.description}</@column>
    </@columns>
</@table>
```

### Controller
```java
@Action("getData")
@ResponseBody
public List<MyItem> getData(@RequestParam("page") int nPage,
                            @RequestParam("itemsPerPage") int nItemsPerPage) {
    return MyItemHome.getItemsList(nPage, nItemsPerPage);
}
```

### JavaScript API
```javascript
window.LutecePaginationAjax.myTable  // Access the pagination instance
```
