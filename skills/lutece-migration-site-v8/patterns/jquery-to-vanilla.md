# jQuery → Vanilla JS Patterns

Comprehensive reference for replacing jQuery with vanilla JavaScript (ES6+).

---

## Selectors

| jQuery | Vanilla JS |
|--------|-----------|
| `$('#id')` | `document.getElementById('id')` |
| `$('.class')` | `document.querySelectorAll('.class')` |
| `$('.class:first')` | `document.querySelector('.class')` |
| `$('div.class')` | `document.querySelectorAll('div.class')` |
| `$(this)` | `this` (in event handler) or `event.currentTarget` |
| `$el.find('.child')` | `el.querySelectorAll('.child')` |
| `$el.closest('.parent')` | `el.closest('.parent')` |
| `$el.parent()` | `el.parentElement` |
| `$el.children()` | `el.children` |
| `$el.siblings()` | `[...el.parentElement.children].filter(c => c !== el)` |
| `$el.next()` | `el.nextElementSibling` |
| `$el.prev()` | `el.previousElementSibling` |

---

## DOM Manipulation

| jQuery | Vanilla JS |
|--------|-----------|
| `$el.html()` | `el.innerHTML` |
| `$el.html('<b>text</b>')` | `el.innerHTML = '<b>text</b>'` |
| `$el.text()` | `el.textContent` |
| `$el.text('value')` | `el.textContent = 'value'` |
| `$el.val()` | `el.value` |
| `$el.val('new')` | `el.value = 'new'` |
| `$el.attr('name')` | `el.getAttribute('name')` |
| `$el.attr('name', 'val')` | `el.setAttribute('name', 'val')` |
| `$el.removeAttr('name')` | `el.removeAttribute('name')` |
| `$el.data('key')` | `el.dataset.key` |
| `$el.data('key', 'val')` | `el.dataset.key = 'val'` |
| `$el.prop('checked')` | `el.checked` |
| `$el.prop('disabled', true)` | `el.disabled = true` |

---

## CSS & Classes

| jQuery | Vanilla JS |
|--------|-----------|
| `$el.addClass('cls')` | `el.classList.add('cls')` |
| `$el.removeClass('cls')` | `el.classList.remove('cls')` |
| `$el.toggleClass('cls')` | `el.classList.toggle('cls')` |
| `$el.hasClass('cls')` | `el.classList.contains('cls')` |
| `$el.css('color')` | `getComputedStyle(el).color` |
| `$el.css('color', 'red')` | `el.style.color = 'red'` |
| `$el.css({color: 'red', fontSize: '14px'})` | `Object.assign(el.style, {color: 'red', fontSize: '14px'})` |
| `$el.show()` | `el.style.display = ''` |
| `$el.hide()` | `el.style.display = 'none'` |
| `$el.toggle()` | `el.style.display = el.style.display === 'none' ? '' : 'none'` |

---

## Events

| jQuery | Vanilla JS |
|--------|-----------|
| `$el.click(fn)` | `el.addEventListener('click', fn)` |
| `$el.on('click', fn)` | `el.addEventListener('click', fn)` |
| `$el.off('click', fn)` | `el.removeEventListener('click', fn)` |
| `$el.on('click', '.child', fn)` | `el.addEventListener('click', e => { if (e.target.matches('.child')) fn.call(e.target, e); })` |
| `$(document).ready(fn)` | `document.addEventListener('DOMContentLoaded', fn)` |
| `$el.trigger('click')` | `el.dispatchEvent(new Event('click'))` |
| `$el.trigger('custom', [data])` | `el.dispatchEvent(new CustomEvent('custom', {detail: data}))` |
| `$el.on('input change', fn)` | `['input', 'change'].forEach(e => el.addEventListener(e, fn))` |
| `event.preventDefault()` | `event.preventDefault()` (same) |
| `event.stopPropagation()` | `event.stopPropagation()` (same) |

### Event delegation pattern

```javascript
// jQuery
$('#list').on('click', '.item', function() {
    $(this).toggleClass('selected');
});

// Vanilla JS
document.getElementById('list').addEventListener('click', (e) => {
    const item = e.target.closest('.item');
    if (item) {
        item.classList.toggle('selected');
    }
});
```

---

## AJAX

### GET request

```javascript
// jQuery
$.get('/api/data', function(data) {
    console.log(data);
});

// Vanilla JS
const response = await fetch('/api/data');
const data = await response.json();
console.log(data);
```

### POST request

```javascript
// jQuery
$.post('/api/data', { name: 'test' }, function(data) {
    console.log(data);
});

// Vanilla JS
const response = await fetch('/api/data', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: 'test' })
});
const data = await response.json();
```

### POST with form data

```javascript
// jQuery
$.ajax({
    url: '/api/upload',
    type: 'POST',
    data: new FormData(document.getElementById('myForm')),
    processData: false,
    contentType: false,
    success: function(data) { ... }
});

// Vanilla JS
const response = await fetch('/api/upload', {
    method: 'POST',
    body: new FormData(document.getElementById('myForm'))
});
const data = await response.json();
```

### AJAX with error handling

```javascript
// jQuery
$.ajax({
    url: '/api/data',
    method: 'GET',
    success: function(data) { ... },
    error: function(xhr, status, error) { ... },
    complete: function() { ... }
});

// Vanilla JS
try {
    const response = await fetch('/api/data');
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    // success
} catch (error) {
    // error
} finally {
    // complete
}
```

---

## DOM Creation & Insertion

| jQuery | Vanilla JS |
|--------|-----------|
| `$('<div>')` | `document.createElement('div')` |
| `$('<div class="cls">text</div>')` | See template pattern below |
| `$el.append(child)` | `el.append(child)` |
| `$el.prepend(child)` | `el.prepend(child)` |
| `$el.before(sibling)` | `el.before(sibling)` |
| `$el.after(sibling)` | `el.after(sibling)` |
| `$el.remove()` | `el.remove()` |
| `$el.empty()` | `el.innerHTML = ''` |
| `$el.clone()` | `el.cloneNode(true)` |
| `$el.replaceWith(newEl)` | `el.replaceWith(newEl)` |

### Creating complex elements

```javascript
// jQuery
const $row = $('<tr><td>' + name + '</td><td>' + value + '</td></tr>');
$('#table tbody').append($row);

// Vanilla JS — template literal
const tbody = document.querySelector('#table tbody');
tbody.insertAdjacentHTML('beforeend',
    `<tr><td>${name}</td><td>${value}</td></tr>`
);
```

---

## Iteration

```javascript
// jQuery
$('.items').each(function(index) {
    $(this).addClass('item-' + index);
});

// Vanilla JS
document.querySelectorAll('.items').forEach((el, index) => {
    el.classList.add(`item-${index}`);
});
```

---

## Animations & Transitions

| jQuery | Vanilla JS |
|--------|-----------|
| `$el.fadeIn()` | CSS transition: `el.style.opacity = '1'` with `transition: opacity 0.3s` |
| `$el.fadeOut()` | `el.style.opacity = '0'` then `el.style.display = 'none'` after transition |
| `$el.slideDown()` | CSS: `el.style.maxHeight = el.scrollHeight + 'px'` with `transition: max-height 0.3s` |
| `$el.slideUp()` | `el.style.maxHeight = '0'` with `overflow: hidden` |
| `$el.animate({...})` | `el.animate([...], {duration: 300})` (Web Animations API) |

**Prefer CSS transitions over JS animations:**

```css
.fade-element {
    transition: opacity 0.3s ease;
}
.fade-element.hidden {
    opacity: 0;
}
```

```javascript
// Show
el.classList.remove('hidden');
// Hide
el.classList.add('hidden');
```

---

## jQuery Plugin Replacements

### Datepicker → HTML5 date input

```html
<!-- jQuery UI -->
<input type="text" id="date" />
<script>$('#date').datepicker({ dateFormat: 'yy-mm-dd' });</script>

<!-- Vanilla (HTML5) -->
<input type="date" id="date" />
```

### DataTables → Vanilla table sorting

```javascript
// Simple sort on header click
document.querySelectorAll('th[data-sort]').forEach(th => {
    th.addEventListener('click', () => {
        const table = th.closest('table');
        const tbody = table.querySelector('tbody');
        const col = th.cellIndex;
        const rows = [...tbody.querySelectorAll('tr')];
        const asc = th.dataset.order !== 'asc';

        rows.sort((a, b) => {
            const aText = a.cells[col].textContent.trim();
            const bText = b.cells[col].textContent.trim();
            return asc
                ? aText.localeCompare(bText, undefined, { numeric: true })
                : bText.localeCompare(aText, undefined, { numeric: true });
        });

        th.dataset.order = asc ? 'asc' : 'desc';
        rows.forEach(row => tbody.append(row));
    });
});
```

### Select2 → HTML5 datalist

```html
<!-- Select2 -->
<select id="city" class="select2">...</select>
<script>$('#city').select2();</script>

<!-- Vanilla (HTML5 datalist) -->
<input list="cities" id="city" />
<datalist id="cities">
    <option value="Paris">
    <option value="Lyon">
    <option value="Marseille">
</datalist>
```

### Dialog → HTML5 dialog element

```html
<!-- jQuery UI Dialog -->
<div id="dialog" title="Confirm">Are you sure?</div>
<script>$('#dialog').dialog({ modal: true });</script>

<!-- Vanilla (HTML5) -->
<dialog id="dialog">
    <h3>Confirm</h3>
    <p>Are you sure?</p>
    <form method="dialog">
        <button value="cancel">Cancel</button>
        <button value="confirm">OK</button>
    </form>
</dialog>
<script>
document.getElementById('dialog').showModal();
</script>
```

### Autocomplete → fetch + datalist

```javascript
// jQuery UI Autocomplete
$('#search').autocomplete({ source: '/api/search' });

// Vanilla JS
const input = document.getElementById('search');
const datalist = document.getElementById('search-results');

input.addEventListener('input', async () => {
    if (input.value.length < 2) return;
    const response = await fetch(`/api/search?q=${encodeURIComponent(input.value)}`);
    const results = await response.json();
    datalist.innerHTML = results
        .map(r => `<option value="${r}">`)
        .join('');
});
```

### Sortable → HTML5 Drag and Drop

```javascript
// jQuery UI Sortable
$('#list').sortable();

// Vanilla Drag and Drop
const list = document.getElementById('list');

list.querySelectorAll('li').forEach(item => {
    item.draggable = true;

    item.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', '');
        item.classList.add('dragging');
    });

    item.addEventListener('dragend', () => {
        item.classList.remove('dragging');
    });
});

list.addEventListener('dragover', (e) => {
    e.preventDefault();
    const dragging = list.querySelector('.dragging');
    const afterElement = [...list.querySelectorAll('li:not(.dragging)')].find(child => {
        const box = child.getBoundingClientRect();
        return e.clientY < box.top + box.height / 2;
    });
    if (afterElement) {
        list.insertBefore(dragging, afterElement);
    } else {
        list.append(dragging);
    }
});
```

---

## Common Patterns

### Document ready

```javascript
// jQuery
$(document).ready(function() { ... });
$(function() { ... });

// Vanilla JS
document.addEventListener('DOMContentLoaded', () => { ... });
```

### Check if element exists

```javascript
// jQuery
if ($('#el').length) { ... }

// Vanilla JS
if (document.getElementById('el')) { ... }
```

### Get/set form values

```javascript
// jQuery
const formData = $('#myForm').serialize();

// Vanilla JS
const formData = new URLSearchParams(new FormData(document.getElementById('myForm'))).toString();
// Or use FormData directly for fetch()
```

### Window scroll

```javascript
// jQuery
$(window).scroll(function() {
    if ($(this).scrollTop() > 100) { ... }
});

// Vanilla JS
window.addEventListener('scroll', () => {
    if (window.scrollY > 100) { ... }
});
```
