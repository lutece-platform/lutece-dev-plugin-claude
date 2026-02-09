---
description: "Lutece 8 JspBean/XPage constraints: CDI annotations, CRUD lifecycle, security tokens, pagination"
paths:
  - "**/web/**/*.java"
---

# Web Beans — Lutece 8

## JspBean (back-office admin)

- MUST have CDI scope + `@Named` + `@Controller` + extend `MVCAdminJspBean`. Without a scope annotation and `@Named`, the page will be BLANK.
- **Scope rule**: `@SessionScoped` if the bean declares instance fields storing per-user state across requests (pagination `_strCurrentPageIndex`/`_nItemsPerPage`, working objects like `_task`, filters, multi-step context). `@RequestScoped` if the bean is stateless (no session instance fields).
- Right check: `init(request, RIGHT_MANAGE_ENTITY)` in constructor or first call

## XPage (front-office site)

- `@Named("plugin.xpage.name")` + `@Controller` + extend `MVCApplication`
- Declared in plugin.xml `<applications>`

## Models — MANDATORY

- **NEVER use `getModel()`** — it is deprecated.
- **NEVER use `new HashMap<>()`** to build the model manually.
- **ALWAYS inject `Models`** via `@Inject` and use `_models.put(key, value)` then pass `_models.getModel()` to templates. Note: `_models.getModel()` and `_models.asMap()` both return an **unmodifiable** map — all `put()` calls must go through the `Models` object, never directly on the returned map.

## CRUD Lifecycle — Strict Naming

| Method | Role | Returns |
|---|---|---|
| `getManageEntities()` | List view | HTML template |
| `getCreateEntity()` | Create form | HTML template |
| `doCreateEntity()` | Create action | Redirect URL |
| `getModifyEntity()` | Edit form | HTML template |
| `doModifyEntity()` | Edit action | Redirect URL |
| `getConfirmRemoveEntity()` | Confirm dialog | AdminMessage URL |
| `doRemoveEntity()` | Delete action | Redirect URL |

## Every `do*` Method — Mandatory Order

1. CSRF token: `getSecurityTokenService().validate(request, ACTION)`
2. Populate: `populate(entity, request)`
3. Validate: `validate(entity)`
4. Business logic: `EntityHome.create(entity)`
5. Redirect: `redirectView(request, VIEW_MANAGE)`

## Every `get*` Form — Mandatory Token

```java
model.put(SecurityTokenService.MARK_TOKEN,
    getSecurityTokenService().getToken(request, ACTION));
```

## Pagination (list views)

Use `LocalizedPaginator` + `AbstractPaginator.getPageIndex()` + `AbstractPaginator.getItemsPerPage()`. Store `_strCurrentPageIndex` and `_nItemsPerPage` as session fields.
