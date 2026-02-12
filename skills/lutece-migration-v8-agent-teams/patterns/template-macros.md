# Freemarker Macros — Lutece v8 Quick Reference

> Full macro source: `~/.lutece-references/lutece-core/webapp/WEB-INF/templates/admin/themes/tabler/`

## Layout Macros

### @pageContainer / @pageColumn / @pageHeader
```html
<@pageContainer>
    <@pageColumn>
        <@pageHeader title="#i18n{myplugin.manage.pageTitle}" description="#i18n{myplugin.manage.description}" />
        <!-- content here -->
    </@pageColumn>
</@pageContainer>
```

## Data Display

### @table
```html
<@table>
    <tr>
        <th>#i18n{myplugin.column.name}</th>
        <th>#i18n{portal.util.labelActions}</th>
    </tr>
    <#list items_list as item>
    <tr>
        <td>${item.name!}</td>
        <td>
            <@aButton href="jsp/admin/plugins/myplugin/ManageItems.jsp?view=modifyItem&id=${item.id}" title="#i18n{portal.util.labelModify}" color="primary" size="sm" iconClass="ti ti-pencil" />
            <@aButton href="jsp/admin/plugins/myplugin/ManageItems.jsp?action=confirmRemoveItem&id=${item.id}" title="#i18n{portal.util.labelDelete}" color="danger" size="sm" iconClass="ti ti-trash" />
        </td>
    </tr>
    </#list>
</@table>
```

### @alert
```html
<@alert type="info">#i18n{myplugin.message.info}</@alert>
<@alert type="warning">#i18n{myplugin.message.warning}</@alert>
<@alert type="danger">#i18n{myplugin.message.error}</@alert>
<@alert type="success">#i18n{myplugin.message.success}</@alert>
```

## Form Macros

### @tform
```html
<@tform action="jsp/admin/plugins/myplugin/ManageItems.jsp" method="post">
    <@formGroup labelKey="#i18n{myplugin.label.name}" required=true>
        <@input type="text" name="name" id="name" value="${item.name!}" required=true />
    </@formGroup>
    <@formGroup labelKey="#i18n{myplugin.label.description}">
        <@input type="textarea" name="description" id="description" value="${item.description!}" rows=5 />
    </@formGroup>
    <@formGroup labelKey="#i18n{myplugin.label.category}">
        <@select name="category" id="category" items=categories_list itemValue="id" itemLabel="name" selectedValue="${item.category!}" />
    </@formGroup>
    <@formGroup labelKey="#i18n{myplugin.label.active}">
        <@checkBox name="active" id="active" checked=(item.active!false) />
    </@formGroup>
    <@button type="submit" color="primary" labelKey="#i18n{portal.util.labelValidate}" />
    <@aButton href="jsp/admin/plugins/myplugin/ManageItems.jsp" color="default" labelKey="#i18n{portal.util.labelCancel}" />
</@tform>
```

### @input types
- `text`, `textarea`, `password`, `email`, `number`, `date`, `hidden`, `url`, `tel`
- `richtext` (WYSIWYG editor)

### @radioButton
```html
<@radioButton name="status" id="status_active" value="1" label="#i18n{myplugin.label.active}" checked=(item.status == 1) />
<@radioButton name="status" id="status_inactive" value="0" label="#i18n{myplugin.label.inactive}" checked=(item.status == 0) />
```

## Button Macros

### @button (submit/reset)
```html
<@button type="submit" color="primary" labelKey="#i18n{portal.util.labelValidate}" />
<@button type="submit" color="primary" iconClass="ti ti-device-floppy" labelKey="#i18n{portal.util.labelSave}" />
```

### @aButton (link styled as button)
```html
<@aButton href="..." color="primary" size="sm" iconClass="ti ti-pencil" title="#i18n{portal.util.labelModify}" />
<@aButton href="..." color="danger" size="sm" iconClass="ti ti-trash" title="#i18n{portal.util.labelDelete}" />
<@aButton href="..." color="success" iconClass="ti ti-plus" labelKey="#i18n{portal.util.labelAdd}" />
```

### Common button colors
`primary`, `secondary`, `success`, `danger`, `warning`, `info`, `default`

## Upload Macros (Back-Office)

```html
<@addFileBOInput name="file_upload" labelKey="#i18n{myplugin.label.file}" />
<@addBOUploadedFilesBox name="file_upload" />
<@inputDropFiles name="file_drop" />
```

## Front-Office Macros

```html
<@cTpl>
    <@cContainer>
        <h1>#i18n{myplugin.xpage.title}</h1>
        <!-- content -->
    </@cContainer>
</@cTpl>
```

## Pagination

### Admin (server-side)
```html
<@paginationAdmin paginator=paginator />
```

### AJAX (client-side, recommended)
```html
<@table id="myTable" items=items_list paginationAjax=true>
    <!-- columns -->
</@table>
```

## Icons

Tabler Icons: `ti ti-{name}` — https://tabler.io/icons
Common: `ti-pencil`, `ti-trash`, `ti-plus`, `ti-eye`, `ti-search`, `ti-download`, `ti-upload`, `ti-check`, `ti-x`, `ti-arrow-left`, `ti-arrow-right`

## i18n

```html
#i18n{pluginName.key.subkey}
```
Reuse portal utility keys: `portal.util.labelValidate`, `portal.util.labelCancel`, `portal.util.labelDelete`, `portal.util.labelModify`, `portal.util.labelActions`

## Null Safety (CRITICAL in v8)

```html
${value!}                      <!-- empty string if null -->
${value!"default"}             <!-- default value if null -->
<#if value??>                  <!-- null check -->
(errors!)?size                 <!-- MANDATORY for errors/infos/warnings -->
(errors!)?has_content          <!-- MANDATORY -->
<#list (errors![]) as error>   <!-- safe list iteration -->
```

## JavaScript Migration (jQuery → Vanilla ES6)

Replace jQuery with vanilla JS. Use ES6+ syntax: `const`/`let`, arrow functions, template literals, destructuring.

| jQuery | Vanilla JS |
|--------|-----------|
| `$(document).ready(fn)` | `document.addEventListener('DOMContentLoaded', fn)` |
| `$('#id')` | `document.getElementById('id')` or `document.querySelector('#id')` |
| `$('.class')` | `document.querySelectorAll('.class')` |
| `$.ajax({...})` | `fetch(url, options).then(r => r.json())` |
| `$(el).on('click', fn)` | `el.addEventListener('click', fn)` |
| `$(el).hide()` | `el.style.display = 'none'` or `el.classList.add('d-none')` |
| `$(el).show()` | `el.style.display = ''` or `el.classList.remove('d-none')` |
| `$(el).val()` | `el.value` |
| `$(el).text()` | `el.textContent` |
| `$(el).html()` | `el.innerHTML` |

**Do NOT convert** jQuery code that depends on jQuery plugins (DataTables, Select2, jQuery UI, etc.) — those still require jQuery.

## MVCMessage in templates (v8 BREAKING CHANGE)

In Lutece 8, **errors** are `MVCMessage` objects — NOT plain strings. Using `${error}` displays the object's `toString()` instead of the message text.

```html
<!-- ERRORS: MVCMessage objects — MUST use .message -->
<#if (errors!)?has_content>
    <@alert type="danger"><#list (errors![]) as error>${error.message}</#list></@alert>
</#if>

<!-- INFOS: plain strings — direct access -->
<#if (infos!)?has_content>
    <@alert type="info"><#list (infos![]) as info>${info}</#list></@alert>
</#if>

<!-- WARNINGS: plain strings — direct access -->
<#if (warnings!)?has_content>
    <@alert type="warning"><#list (warnings![]) as warning>${warning}</#list></@alert>
</#if>
```

Reference: `~/.lutece-references/lutece-core/src/java/fr/paris/lutece/portal/util/mvc/utils/MVCMessage.java`
