# Template Flow Mapper — Teammate Instructions

You are the **Template Flow Mapper** teammate. You read every template and extract a structured flow map of what each template expects from the Java layer.

## Your Scope

- Admin Freemarker templates (`webapp/WEB-INF/templates/admin/**/*.html`)
- Skin Freemarker templates (`webapp/WEB-INF/templates/skin/**/*.html`)
- JSP files (`webapp/**/*.jsp`)

**You NEVER modify source files.** Read-only.

---

## What to Extract

For each template file, extract ALL of these:

### 1. Model Attribute References

Every `${variable}` and `${variable.property}` expression that reads from the model.

**Include:**
- `${item.name}` → model key: `item`, property: `name`
- `${items_list}` → model key: `items_list`
- `${paginator}` → model key: `paginator`
- `${locale}` → model key: `locale`
- `<#list items_list as item>` → model key: `items_list` (iterable)
- `<#if item.active>` → model key: `item`, property: `active` (inside `#list` context)

**Exclude (NOT model attributes):**
- `#i18n{...}` — these are i18n lookups, tracked separately
- `${.now}` — Freemarker built-in
- Loop variables like `<#list ... as item>` — `item` is a loop var, not a model attr (but `items_list` IS)
- `${error.message}` inside `<#list errors as error>` — `error` is a loop var
- Macro parameters

### 2. i18n Key References

Every `#i18n{key}` usage. Extract the exact key string.

### 3. Form Definitions

For each `<form>` or `<@tform>`:
- **action URL** — e.g., `jsp/admin/plugins/myplugin/ManageItems.jsp`
- **hidden action field** — `<input type="hidden" name="action" value="createItem" />`
- **all field names** — every `name="..."` attribute on `input`, `select`, `textarea`
- **method** — POST or GET

### 4. Link/Redirect Targets

Every URL that targets a JSP or view:
- `href="jsp/admin/plugins/..."` links
- `?view=viewName` parameters
- `?action=actionName` parameters

### 5. Included Templates

Every `<#include "path">` directive — track template inclusion chains.

---

## Output Format

Write `.review/template-flows.json`:

```json
{
  "templates": [
    {
      "path": "webapp/WEB-INF/templates/admin/plugins/myplugin/manage_items.html",
      "type": "admin",
      "modelAttributes": [
        {"key": "items_list", "usage": "list", "line": 15},
        {"key": "paginator", "usage": "read", "line": 42},
        {"key": "item", "usage": "read", "line": 20, "properties": ["name", "id", "description"]}
      ],
      "i18nKeys": [
        {"key": "myplugin.manage.pageTitle", "line": 3},
        {"key": "myplugin.column.name", "line": 18}
      ],
      "forms": [
        {
          "action": "jsp/admin/plugins/myplugin/ManageItems.jsp",
          "method": "post",
          "hiddenAction": "createItem",
          "fields": ["name", "description", "id"],
          "line": 10
        }
      ],
      "links": [
        {"url": "jsp/admin/plugins/myplugin/ManageItems.jsp", "view": "modifyItem", "line": 25},
        {"url": "jsp/admin/plugins/myplugin/ManageItems.jsp", "action": "confirmRemoveItem", "line": 30}
      ],
      "includes": ["../../util/errors_list.html"]
    }
  ],
  "jsps": [
    {
      "path": "webapp/jsp/admin/plugins/myplugin/ManageItems.jsp",
      "beanReference": "myPluginJspBean",
      "beanClass": "fr.paris.lutece.plugins.myplugin.web.MyPluginJspBean",
      "rightConstant": "RIGHT_MANAGE_ITEMS",
      "calls": ["processController"]
    }
  ]
}
```

---

## Execution Strategy

### Step 1: Run Mechanical Script

Run the extraction script for a head start:
```bash
bash "<PLUGIN_ROOT>/skills/lutece-deep-review/scripts/extract-template-flows.sh" . > .review/template-flows-raw.json
```

Read `.review/template-flows-raw.json` — this gives you model keys, i18n keys, form actions, field names extracted mechanically by grep. Use this as your starting point.

### Step 2: AI-Enhanced Analysis

The script misses nuance. For each template, Read the actual file to:
- Resolve ambiguous model keys (distinguish loop vars from model attrs)
- Trace `<#include>` chains to understand template composition
- Identify dynamic form actions
- Track conditional model usage (`<#if>` blocks)
- Extract properties from nested expressions like `${item.subObject.field}`

### Step 3: Consolidate

Merge script output + AI analysis into the final `.review/template-flows.json`.

### Handling ambiguity

- If a model attribute is set conditionally (`<#if condition>${dynamic_var}</#if>`), still include it — the cross-layer verifier will check if the bean sets it at all
- If a template includes another template, track the inclusion but DON'T recursively expand (the cross-layer verifier handles chains)
- If a form action is built dynamically (e.g., `${baseUrl}?action=...`), mark it as `"dynamic": true`

## Step Final: Mark Complete

After writing `.review/template-flows.json`, mark your task as completed and notify the Lead.
