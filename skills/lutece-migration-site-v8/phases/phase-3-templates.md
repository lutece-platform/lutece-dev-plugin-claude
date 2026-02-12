# Phase 3: Templates Migration (Skin + jQuery → Vanilla JS)

**Live reference (MANDATORY):** Before modifying any template, check real v8 templates:
- `~/.lutece-references/lutece-core/webapp/WEB-INF/templates/skin/`

---

## Step 1 — Inventory skin templates

List all custom skin templates in the site:
- `webapp/WEB-INF/templates/skin/**/*.html`
- Note which ones use jQuery (`$(`  or `jQuery`)
- Note which ones use Bootstrap 3/4 classes
- Note which ones use jQuery plugins (datepicker, datatables, select2, etc.)

---

## Step 2 — Skin template wrapper

All skin templates must be wrapped with the `<@cTpl>` macro:

```html
<@cTpl>
  <!-- existing template content -->
</@cTpl>
```

---

## Step 3 — jQuery → Vanilla JS

**This is the most critical step.** Analyze each template and replace all jQuery with vanilla ES6+ JS.

### Migration rules

1. **Remove jQuery script includes** — `<script src="...jquery...">` must be removed
2. **Replace all jQuery calls** — Convert to vanilla JS using ES6+ (selectors → `querySelector`/`querySelectorAll`, events → `addEventListener`, AJAX → `fetch`/`async`/`await`, etc.)
3. **Replace jQuery plugins** — Each plugin must be replaced with a vanilla JS alternative or Lutece v8 built-in component
4. **Use ES6+** — `const`/`let`, arrow functions, template literals, `async`/`await`
5. **No CDN** — All JS must be local (`webapp/js/` or core-provided)

### jQuery plugin replacements

| jQuery Plugin | v8 Replacement |
|---------------|---------------|
| jQuery UI Datepicker | HTML5 `<input type="date">` or Flatpickr (if already in core) |
| DataTables | Vanilla JS table sorting or Lutece v8 `<@table>` macro |
| Select2 | HTML5 `<datalist>` or Tom Select (vanilla) |
| jQuery Validation | HTML5 form validation (`required`, `pattern`, etc.) |
| jQuery File Upload | Lutece v8 `<@inputDropFiles>` macro |
| jQuery UI Autocomplete | Vanilla JS with `fetch()` + `<datalist>` |
| jQuery UI Dialog | HTML5 `<dialog>` element |
| jQuery UI Sortable | HTML5 Drag and Drop API |

For each jQuery plugin found:
1. Identify what it does
2. Check if Lutece v8 core provides a built-in replacement (search `~/.lutece-references/lutece-core/webapp/js/`)
3. If yes → use the core replacement
4. If no → implement in vanilla JS

---

## Step 4 — Bootstrap migration

If templates use Bootstrap 3/4 classes, migrate to Bootstrap 5:

| Bootstrap 3/4 | Bootstrap 5 |
|---------------|-------------|
| `class="panel panel-default"` | `class="card"` |
| `class="panel-heading"` | `class="card-header"` |
| `class="panel-body"` | `class="card-body"` |
| `class="btn-default"` | `class="btn-secondary"` |
| `data-toggle="..."` | `data-bs-toggle="..."` |
| `data-target="..."` | `data-bs-target="..."` |
| `data-dismiss="..."` | `data-bs-dismiss="..."` |
| `class="form-group"` | `class="mb-3"` |
| `class="form-control-label"` | `class="form-label"` |
| `class="float-left"` | `class="float-start"` |
| `class="float-right"` | `class="float-end"` |
| `class="text-left"` | `class="text-start"` |
| `class="text-right"` | `class="text-end"` |
| `class="ml-*"` / `class="mr-*"` | `class="ms-*"` / `class="me-*"` |
| `class="pl-*"` / `class="pr-*"` | `class="ps-*"` / `class="pe-*"` |

---

## Step 5 — Static assets

If the site has custom JS/CSS files:
- `webapp/js/` — Migrate jQuery code to vanilla JS
- `webapp/css/` — Update Bootstrap 3/4 overrides for BS5

---

## Step 6 — Clean up references to removed plugins

If plugins were removed during Phase 1, their templates may still be referenced.

### Detect orphan references

Search all site templates for references to removed plugins:

```
For each removed plugin:
  - Search for `<#include "*/plugins/<plugin_name>/*">`
  - Search for `<@<plugin_name>` macro calls
  - Search for `href="css/plugins/<plugin_name>/` or `src="js/plugins/<plugin_name>/`
  - Search for `page=<plugin_name>` in links
```

Common cases:
- **plugin-extend** — Templates often include `<@extendAction>`, `<@extendComment>`, or `<#include "*/extend/*">`. These must be removed or the template will fail with missing macro errors.
- **plugin-seo** — SEO meta tags in page templates reference SEO macros. Remove them.
- **Themes** — Removed theme plugins (e.g. `site-theme-wiki`) provide CSS/JS. If templates link to those files, create local copies or remove the links.

### Fix orphan references

For each orphan reference found:
1. **Remove the include/macro call** if the feature is no longer needed
2. **Replace with a local alternative** if the feature is still needed
3. **Create local CSS/JS copies** if the file was provided by the removed plugin and is still needed by remaining templates

---

## Verification

Run the verification script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-site-v8/scripts/verify-site-migration.sh"
```

Template checks (TM01, TM02, TM03, TM04) must PASS.

Mark task as completed ONLY when verification passes.
