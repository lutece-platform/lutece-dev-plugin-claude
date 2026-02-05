# Phase 4: UI Migration (JSP + Templates + JavaScript)

---

## Step 1 — JSP migration

All JSP files must be migrated from scriptlet-based (`<jsp:useBean>` + `<% %>`) to EL-based (`${ }`) syntax using CDI bean names.

### Bean name resolution

The CDI bean name is the **camelCase** of the class name (or the `@Named` value if specified):
- `AdminWorkgroupJspBean` → `adminWorkgroupJspBean`
- `TemporaryFilesJspBean` → `temporaryFilesJspBean`

### Pattern 1: View JSP (displays a page)

```jsp
<%-- BEFORE (v7) --%>
<%@ page errorPage="../../ErrorPage.jsp" %>
<jsp:useBean id="myPluginJspBean" scope="session"
    class="fr.paris.lutece.plugins.myplugin.web.MyPluginJspBean" />
<jsp:include page="../../AdminHeader.jsp" />
<% myPluginJspBean.init( request, right ); %>
<%= myPluginJspBean.getManageItems( request ) %>
<%@ include file="../../AdminFooter.jsp" %>

<%-- AFTER (v8) --%>
<%@ page errorPage="../../ErrorPage.jsp" %>
<jsp:include page="../../AdminHeader.jsp" />

<%@page import="fr.paris.lutece.plugins.myplugin.web.MyPluginJspBean"%>

${ myPluginJspBean.init( pageContext.request, MyPluginJspBean.RIGHT_MANAGE ) }
${ myPluginJspBean.getManageItems( pageContext.request ) }

<%@ include file="../../AdminFooter.jsp" %>
```

### Pattern 2: Action JSP (Do — executes an action and redirects)

```jsp
<%-- BEFORE (v7) --%>
<%@ page errorPage="../../ErrorPage.jsp" %>
<jsp:useBean id="myPluginJspBean" scope="session"
    class="fr.paris.lutece.plugins.myplugin.web.MyPluginJspBean" />
<% response.sendRedirect( myPluginJspBean.doCreateItem( request ) ); %>

<%-- AFTER (v8) --%>
<%@ page errorPage="../../ErrorPage.jsp" %>

<%@page import="fr.paris.lutece.plugins.myplugin.web.MyPluginJspBean"%>

${ myPluginJspBean.init( pageContext.request, MyPluginJspBean.RIGHT_MANAGE ) }
${ pageContext.response.sendRedirect( myPluginJspBean.doCreateItem( pageContext.request ) ) }
```

### Pattern 3: ProcessController JSP (legacy controller dispatch)

```jsp
<%-- BEFORE (v7) --%>
<%@ page errorPage="../../ErrorPage.jsp" %>
<jsp:useBean id="myPluginJspBean" scope="session"
    class="fr.paris.lutece.plugins.myplugin.web.MyPluginJspBean" />
<jsp:include page="../../AdminHeader.jsp" />
<% String strContent = myPluginJspBean.processController( request, response ); %>
<%= strContent %>
<%@ include file="../../AdminFooter.jsp" %>

<%-- AFTER (v8) --%>
<%@ page errorPage="../../ErrorPage.jsp" %>
<jsp:include page="../../AdminHeader.jsp" />

${ pageContext.setAttribute( 'strContent', myPluginJspBean.processController( pageContext.request, pageContext.response ) ) }
${ pageContext.getAttribute( 'strContent' ) }

<%@ include file="../../AdminFooter.jsp" %>
```

### Pattern 4: Action JSP with response handling (download, etc.)

```jsp
<%-- AFTER (v8) --%>
<%@ page errorPage="../../ErrorPage.jsp" %>

<%@page import="fr.paris.lutece.plugins.myplugin.web.MyPluginJspBean"%>

${ myPluginJspBean.init( pageContext.request, MyPluginJspBean.VIEW_FILES ) }
${ myPluginJspBean.doDownloadFile( pageContext.request, pageContext.response ) }
```

### JSP migration rules

1. **Remove** all `<jsp:useBean>` tags — beans are CDI-managed
2. **Add** `<%@page import="...JspBean"%>` to reference class constants (RIGHT_xxx, VIEW_xxx)
3. **Replace** `request` → `pageContext.request`, `response` → `pageContext.response`
4. **Replace** scriptlets `<% %>` and expressions `<%= %>` with EL `${ }`
5. **Add** `init()` call with the right constant before any bean method call
6. **Keep** `errorPage`, `AdminHeader.jsp` include, and `AdminFooter.jsp` include unchanged

---

## Step 2 — Admin (back-office) templates

**Reference (MANDATORY):** Before modifying any template, read the macro definitions:
- `~/.lutece-references/lutece-core/webapp/WEB-INF/templates/admin/themes/tabler/`

Every admin template (`templates/admin/**/*.html`) MUST be rewritten to use v8 Freemarker macros. Do NOT keep raw Bootstrap 3/4 HTML.

### Layout structure (MANDATORY)

Every admin page MUST use: `@pageContainer` > `@pageColumn` > `@pageHeader`.

### List page pattern

```html
<@pageContainer>
    <@pageColumn>
        <@pageHeader title='#i18n{myplugin.manage_items.pageTitle}'>
            <@aButton href='jsp/admin/plugins/myplugin/ManageItems.jsp?view=createItem' buttonIcon='plus' title='#i18n{myplugin.manage_items.buttonAdd}' color='primary' />
        </@pageHeader>
        <#if item_list?size gt 0>
            <@table>
                <tr>
                    <th>#i18n{myplugin.model.entity.item.attribute.name}</th>
                    <th>#i18n{portal.util.labelActions}</th>
                </tr>
                <#list item_list as item>
                <tr>
                    <td>${item.name!}</td>
                    <td>
                        <@aButton href='jsp/admin/plugins/myplugin/ManageItems.jsp?view=modifyItem&id=${item.id}' buttonIcon='edit' title='#i18n{portal.util.labelModify}' />
                        <@aButton href='jsp/admin/plugins/myplugin/ManageItems.jsp?action=confirmRemoveItem&id=${item.id}' buttonIcon='trash' color='danger' title='#i18n{portal.util.labelDelete}' />
                    </td>
                </tr>
                </#list>
            </@table>
        <#else>
            <@alert color='info'>#i18n{myplugin.manage_items.noData}</@alert>
        </#if>
    </@pageColumn>
</@pageContainer>
```

### Form page pattern

```html
<@pageContainer>
    <@pageColumn>
        <@pageHeader title='#i18n{myplugin.create_item.pageTitle}'>
            <@aButton href='jsp/admin/plugins/myplugin/ManageItems.jsp?view=manageItems' buttonIcon='arrow-left' title='#i18n{portal.util.labelBack}' />
        </@pageHeader>
        <@tform method='post' name='create_item' action='jsp/admin/plugins/myplugin/ManageItems.jsp' boxed=true>
            <@input type='hidden' name='action' value='createItem' />
            <@formGroup labelFor='title' labelKey='#i18n{myplugin.model.entity.item.attribute.title}' mandatory=true rows=2>
                <@input type='text' name='title' id='title' value='${item.title!}' />
            </@formGroup>
            <@formGroup labelFor='description' labelKey='#i18n{myplugin.model.entity.item.attribute.description}' rows=2>
                <@input type='textarea' name='description' id='description'>${item.description!}</@input>
            </@formGroup>
            <@formGroup labelFor='active' labelKey='#i18n{myplugin.model.entity.item.attribute.active}' rows=2>
                <@checkBox orientation='switch' labelKey='#i18n{myplugin.model.entity.item.attribute.active}' name='active' id='active' value='true' checked=item.active!false />
            </@formGroup>
            <@formGroup rows=2>
                <@button type='submit' buttonIcon='check' title='#i18n{portal.util.labelValidate}' color='primary' />
                <@aButton href='jsp/admin/plugins/myplugin/ManageItems.jsp?view=manageItems' buttonIcon='times' title='#i18n{portal.util.labelCancel}' />
            </@formGroup>
        </@tform>
    </@pageColumn>
</@pageContainer>
```

### Common v7 → v8 replacements

| v7 (raw HTML / Bootstrap 3-4) | v8 (Freemarker macro) |
|---|----|
| `<div class="panel panel-default">` | `<@box>` or `<@pageContainer>` layout |
| `<table class="table ...">` | `<@table>` |
| `<form method="post" ...>` | `<@tform method='post' ...>` |
| `<div class="form-group"><label>...<input ...>` | `<@formGroup labelFor=... labelKey=...><@input .../></@formGroup>` |
| `<input type="text" class="form-control" ...>` | `<@input type='text' .../>` |
| `<textarea class="form-control" ...>` | `<@input type='textarea' ...>` |
| `<select class="form-control" ...>` | `<@select ...>` |
| `<input type="checkbox" ...>` | `<@checkBox .../>` |
| `<button class="btn btn-primary" ...>` | `<@button type='submit' color='primary' .../>` |
| `<a class="btn btn-primary" href="...">` | `<@aButton href='...' color='primary' .../>` |
| `<div class="alert alert-info">` | `<@alert color='info'>` |

### Freemarker best practices

- **Null safety**: always use `${value!}` (with `!`) to handle null values
- **i18n**: use `#i18n{prefix.key}` — reuse existing `portal.util.*` keys
- **Icons**: use Tabler icon names in `buttonIcon` parameter (`plus`, `edit`, `trash`, `arrow-left`, `check`, `times`)
- **BS5 & Tabler Icons are already loaded** by the admin theme — do NOT add `<link>` or `<script>` for these

---

## Step 3 — Front-office (skin) templates

All skin templates (`templates/skin/**/*.html`) must be wrapped with `<@cTpl>`:

```html
<@cTpl>
  <!-- template content -->
</@cTpl>
```

Conventions:
- Use Bootstrap 5 utility classes (no Bootstrap 3/4)
- No jQuery — vanilla JS only
- No CDN — local assets only (`webapp/js/{pluginName}/`, `webapp/css/{pluginName}/`)

### MANDATORY — Null-safety for model variables (`errors`, `infos`, `warnings`)

In Lutece 8, `errors`, `infos`, and `warnings` are **only present in the model when `addError()`/`addInfo()`/`addWarning()` has been called**. They are NOT pre-initialized. Any template that accesses them without null-safety will throw a FreeMarker error (500).

**Search and fix all occurrences** in both skin and admin templates:

```html
<#-- BEFORE — crashes if errors is not in model -->
<#if errors?size gt 0>
<#list errors as error>

<#-- AFTER — null-safe -->
<#if (errors!)?size gt 0>
<#list (errors![]) as error>
```

Same applies to `infos` and `warnings`:
```html
<#if (infos!)?size gt 0>
<#if (warnings!)?size gt 0>
```

**Grep to find all unsafe usages:**
```bash
grep -rn 'errors?size\|errors?has_content\|infos?size\|infos?has_content\|warnings?size\|warnings?has_content' webapp/WEB-INF/templates/ --include="*.html" | grep -v '!'
```

---

## Step 4 — JavaScript (jQuery → vanilla JS)

Replace all jQuery usage in both admin and skin templates:

```javascript
// BEFORE (v7) — jQuery
$('#myElement').click(function() { ... });
$.ajax({ url: '...', success: function(data) { ... } });
$('.myClass').hide();

// AFTER (v8) — Vanilla JS
document.querySelector('#myElement').addEventListener('click', () => { ... });
fetch('...').then(response => response.json()).then(data => { ... });
document.querySelector('.myClass').style.display = 'none';
```

Use ES6+: `const`/`let`, arrow functions, template literals, `async`/`await`.

---

## Step 5 — Admin template macro renames (BO variants)

In **admin templates** (`templates/admin/**/*.html`), several macros must use their **BO** (Back-Office) variants:

| v7 Macro | v8 Macro |
|---------|---------|
| `@addRequiredJsFiles` | `@addRequiredBOJsFiles` |
| `@addFileInput` | `@addFileBOInput` |
| `@addUploadedFilesBox` | `@addBOUploadedFilesBox` |
| `@addFileInputAndfilesBox` | `@addFileBOInputAndfilesBox` |

**Automatic replacement:**

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/replace-templates-bo.sh" .
```

This script replaces all FO macros with BO variants in `webapp/WEB-INF/templates/admin/`.

If jQuery File Upload is used, replace with Uppy:
```html
<@inputDropFiles name=fieldName handler=handler type=type>
    <#nested>
</@inputDropFiles>
```

---

## Step 6 — SuggestPOI / Address autocomplete migration (if applicable)

If the plugin uses the `address-autocomplete` module for address autocomplete (SuggestPOI), the old jQuery-based integration must be replaced with the new LuteceAutoComplete-based version.

**Reference (MANDATORY):** Read the v8 implementation in:
- `~/.lutece-references/lutece-tech-module-address-autocomplete/webapp/WEB-INF/templates/skin/plugins/address/modules/autocomplete/include/suggestPOI.html`
- `~/.lutece-references/lutece-tech-module-address-autocomplete/webapp/js/plugins/address/modules/autocomplete/suggestPOI.js`
- `~/.lutece-references/lutece-form-plugin-forms/webapp/WEB-INF/templates/skin/plugins/forms/entries/fill_entry_type_geolocation.html`

### Detect old patterns

Search templates for:
- Old JSP include: `autocomplete-js.jsp`
- jQuery autocomplete: `$.autocomplete`, `$(…).autocomplete(`, `createAutocomplete(`
- Old JSONP calls: `dataType: 'jsonp'` with address WS
- Old jQuery selectors with `#labelAutocomplete`

### Template migration (admin + skin)

```html
<!-- BEFORE (v7) — jQuery autocomplete via old JSP include -->
<script src="jsp/plugins/address/modules/autocomplete/autocomplete-js.jsp"></script>
<script>createAutocomplete('.my-address-input');</script>
<input type="text" class="my-address-input" name="address" />

<!-- AFTER (v8) — LuteceAutoComplete via FreeMarker macros -->
<#include "/skin/plugins/address/modules/autocomplete/include/suggestPOI.html" />
<@setupSuggestPOI />
<@suggestPOIInput id="address_field" name="address" currentValue="${addressValue!}" required=false cssClass="form-control" />
```

### JavaScript migration

```javascript
// BEFORE (v7) — jQuery event handling
$('#myField').on('autocompleteselect', function(event, ui) {
    var label = ui.item.label;
    var value = ui.item.value;
});

// AFTER (v8) — Vanilla JS with SuggestPOI class
var suggestPoi = new SuggestPOI('#address_field', {
    allowFreeText: false
});
document.getElementById('address_field').addEventListener(SuggestPOI.EVT_SELECT, function(event) {
    var poi = event.detail.poi;
    // poi.label, poi.id, poi.x, poi.y, poi.type
});
```

### Key differences

| v7 (jQuery) | v8 (LuteceAutoComplete) |
|---|---|
| `autocomplete-js.jsp` (scriptlet + jQuery) | `<@setupSuggestPOI />` macro (CDI bean + FreeMarker) |
| `$.autocomplete({source:…})` | `new SuggestPOI(container, options)` |
| JSONP data type | `fetch()` with JSON |
| `autocompleteselect` jQuery event | `SuggestPOI.EVT_SELECT` (`suggestpoi:select`) custom event |
| `ui.item.label` / `ui.item.value` | `event.detail.poi.label` / `.id` / `.x` / `.y` / `.type` |

### Admin templates

For admin templates, the include path differs:

```html
<#include "/admin/plugins/address/modules/autocomplete/include/suggestPOI.html" />
```

The macro usage is identical.

---

## Verification

Run the verification script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/verify-migration.sh"
```

UI checks (JS01, JS02, TM01, TM02, TM05) must PASS or be accepted WARN.

Mark task as completed ONLY when verification passes.
