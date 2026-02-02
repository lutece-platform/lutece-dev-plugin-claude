# Migration Analysis: lutece-tech-plugin-asynchronousupload

## Summary

| Aspect | v7 (develop) | v8 (develop_core8) |
|--------|--------------|-------------------|
| **Plugin Version** | 1.1.11-SNAPSHOT | 2.0.0-SNAPSHOT |
| **Parent POM** | 6.1.0 | 8.0.0-SNAPSHOT |
| **Core Dependency** | [4.4.1,) | [8.0.0-SNAPSHOT,) |
| **DI Framework** | Spring | CDI (Jakarta EE) |
| **Servlet API** | javax.servlet | jakarta.servlet |
| **JSON Library** | net.sf.json-lib | Jackson (fasterxml) |
| **File Upload** | Apache Commons FileUpload (FileItem) | Lutece MultipartItem |
| **Frontend Library** | jQuery File Upload | Uppy |

## Statistics

```
50 files changed, 1179 insertions(+), 7738 deletions(-)
```

**Significant file changes:**
- Major removal of jQuery File Upload library (7000+ lines deleted)
- Introduction of Uppy library for file uploads
- Complete rewrite of frontend JavaScript

---

## 1. POM Changes

### Parent POM
```xml
<!-- v7 -->
<version>6.1.0</version>

<!-- v8 -->
<version>8.0.0-SNAPSHOT</version>
```

### Plugin Version
```xml
<!-- v7 -->
<version>1.1.11-SNAPSHOT</version>

<!-- v8 -->
<version>2.0.0-SNAPSHOT</version>
```

### Core Dependency
```xml
<!-- v7 -->
<dependency>
    <groupId>fr.paris.lutece</groupId>
    <artifactId>lutece-core</artifactId>
    <version>[4.4.1,)</version>
    <type>lutece-core</type>
</dependency>

<!-- v8 -->
<dependency>
    <groupId>fr.paris.lutece</groupId>
    <artifactId>lutece-core</artifactId>
    <version>[8.0.0-SNAPSHOT,)</version>
    <type>lutece-core</type>
</dependency>
```

### Dependency Changes

**Removed:**
```xml
<dependency>
    <groupId>net.sf.json-lib</groupId>
    <artifactId>json-lib</artifactId>
    <version>2.4</version>
    <classifier>jdk15</classifier>
</dependency>
```

**Added:**
```xml
<dependency>
   <groupId>fr.paris.lutece.plugins</groupId>
   <artifactId>library-lutece-unit-testing</artifactId>
   <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.glassfish.jaxb</groupId>
    <artifactId>jaxb-runtime</artifactId>
    <version>4.0.5</version>
    <scope>test</scope>
</dependency>
```

### Repository URLs
```xml
<!-- v7 -->
<url>http://dev.lutece.paris.fr/snapshot_repository</url>

<!-- v8 (HTTPS) -->
<url>https://dev.lutece.paris.fr/snapshot_repository</url>
```

---

## 2. Dependency Injection: Spring to CDI

### Spring Context Removal

**Deleted file:** `webapp/WEB-INF/conf/plugins/asynchronousupload_context.xml`

```xml
<!-- v7 Spring configuration -->
<beans xmlns="http://www.springframework.org/schema/beans">
    <bean id="asynchronous-upload.asynchronousUploadHandler"
          class="fr.paris.lutece.plugins.asynchronousupload.service.AsynchronousUploadHandler" />
</beans>
```

### CDI Configuration Added

**New file:** `src/main/resources/META-INF/beans.xml`

```xml
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0" bean-discovery-mode="annotated">
</beans>
```

### CDI Annotations on Services

**AsynchronousUploadHandler.java:**
```java
// v7
public class AsynchronousUploadHandler extends AbstractAsynchronousUploadHandler {
    private static final String BEAN_NAME = "asynchronous-upload.asynchronousUploadHandler";

    public static AsynchronousUploadHandler getHandler() {
        return SpringContextService.getBean(BEAN_NAME);
    }
}

// v8
@ApplicationScoped
@Named("asynchronous-upload.asynchronousUploadHandler")
public class AsynchronousUploadHandler extends AbstractAsynchronousUploadHandler {

    @Deprecated
    public static AsynchronousUploadHandler getHandler() {
        return CDI.current().select(AsynchronousUploadHandler.class).get();
    }
}
```

**UploadCacheService.java:**
```java
// v7
public final class UploadCacheService extends AbstractCacheableService {
    private static UploadCacheService _instance = new UploadCacheService();

    private UploadCacheService() {
        initCache();
    }

    public static UploadCacheService getInstance() {
        return _instance;
    }
}

// v8
@ApplicationScoped
public class UploadCacheService extends AbstractCacheableService<String, String> {

    UploadCacheService() {
        // Ctor
    }

    @PostConstruct
    private void initUploadCacheService() {
        enableCache(true);
    }

    @Deprecated
    public static UploadCacheService getInstance() {
        return CDI.current().select(UploadCacheService.class).get();
    }
}
```

**AsynchronousUploadApp.java:**
```java
// v7
public class AsynchronousUploadApp extends MVCApplication {
    private IAsyncUploadHandler getHandler(HttpServletRequest request) {
        for (IAsyncUploadHandler handler : SpringContextService.getBeansOfType(IAsyncUploadHandler.class)) {
            // ...
        }
    }
}

// v8
@RequestScoped
@Named
public class AsynchronousUploadApp extends MVCApplication {

    @Inject
    private UploadCacheService _uploadCacheService;

    @Inject
    private Instance<IAsyncUploadHandler> _asyncUploadHandler;

    private IAsyncUploadHandler getHandler(HttpServletRequest request) {
        for (IAsyncUploadHandler handler : _asyncUploadHandler.stream().toList()) {
            // ...
        }
    }
}
```

**AsynchronousUploadSessionListener.java:**
```java
// v7
public void sessionDestroyed(HttpSessionEvent se) {
    for (IAsyncUploadHandler handler : SpringContextService.getBeansOfType(IAsyncUploadHandler.class)) {
        handler.removeAllFileItem(se.getSession());
    }
}

// v8
public void sessionDestroyed(HttpSessionEvent se) {
    for (IAsyncUploadHandler handler : CDI.current().select(IAsyncUploadHandler.class).stream().toList()) {
        handler.removeAllFileItem(se.getSession());
    }
}
```

---

## 3. Servlet API: javax to jakarta

### Import Changes (All Java Files)

```java
// v7
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.xml.bind.DatatypeConverter;

// v8
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import jakarta.xml.bind.DatatypeConverter;
```

### CDI-Specific Imports Added (v8)

```java
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.context.RequestScoped;
import jakarta.enterprise.context.Initialized;
import jakarta.enterprise.event.Observes;
import jakarta.enterprise.inject.Instance;
import jakarta.enterprise.inject.spi.CDI;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.servlet.ServletContext;
```

---

## 4. File Upload API: FileItem to MultipartItem

### Interface Changes

**IAsyncUploadHandler.java:**
```java
// v7
import org.apache.commons.fileupload.FileItem;

String canUploadFiles(HttpServletRequest request, String strFieldName, List<FileItem> listFileItemsToUpload, Locale locale);
List<FileItem> getListUploadedFiles(String strFieldName, HttpSession session);
List<FileItem> getListPartialUploadedFiles(String strFieldName, HttpSession session);
void addFileItemToUploadedFilesList(FileItem fileItem, String strFieldName, HttpServletRequest request);
void addFileItemToPartialUploadedFilesList(FileItem fileItem, String strFieldName, HttpServletRequest request);

// v8
import fr.paris.lutece.portal.service.upload.MultipartItem;

String canUploadFiles(HttpServletRequest request, String strFieldName, List<MultipartItem> listFileItemsToUpload, Locale locale);
List<MultipartItem> getListUploadedFiles(String strFieldName, HttpSession session);
List<MultipartItem> getListPartialUploadedFiles(String strFieldName, HttpSession session);
void addFileItemToUploadedFilesList(MultipartItem fileItem, String strFieldName, HttpServletRequest request);
void addFileItemToPartialUploadedFilesList(MultipartItem fileItem, String strFieldName, HttpServletRequest request);
```

### PartialFileItemGroup Implementation Change

```java
// v7
public class PartialFileItemGroup implements FileItem {
    private List<FileItem> _items;

    public void delete() {
        for (FileItem item : _items) {
            item.delete();
        }
    }

    public long getSize() {
        return _items.stream().collect(Collectors.summingLong(FileItem::getSize));
    }

    // Many FileItem interface methods implemented...
}

// v8 (Simplified - MultipartItem has fewer methods)
public class PartialFileItemGroup implements MultipartItem {
    private List<MultipartItem> _items;

    public void delete() throws IOException {
        for (MultipartItem item : _items) {
            item.delete();
        }
    }

    public long getSize() {
        return _items.stream().collect(Collectors.summingLong(MultipartItem::getSize));
    }

    // Fewer methods - removed: getOutputStream, getString, isFormField, isInMemory,
    // setFieldName, setFormField, write, getHeaders, setHeaders
}
```

### Exception Handling Change

```java
// v7 - delete() throws no checked exception
FileItem fileItem = uploadedFiles.remove(nIndex);
fileItem.delete();

// v8 - delete() throws IOException
MultipartItem fileItem = uploadedFiles.remove(nIndex);
try {
    fileItem.delete();
} catch(IOException e) {
    AppLogService.error(e.getMessage(), e);
}
```

---

## 5. JSON Library: json-lib to Jackson

### Import Changes

```java
// v7
import net.sf.json.JSON;
import net.sf.json.JSONArray;
import net.sf.json.JSONObject;
import net.sf.json.JSONSerializer;

// v8
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
```

### API Changes

**Creating JSON Objects:**
```java
// v7
JSONObject json = new JSONObject();
json.element("key", "value");
json.accumulate("array_key", object);
json.accumulateAll(otherJson);

// v8
ObjectMapper mapper = new ObjectMapper();
ObjectNode json = mapper.createObjectNode();
json.put("key", "value");
json.set("array_key", arrayNode);
json.setAll(otherObjectNode);
```

**Parsing JSON:**
```java
// v7
JSON jsonFieldIndexes = JSONSerializer.toJSON(listIndexesFilesToRemove);
if (!jsonFieldIndexes.isArray()) { ... }
JSONArray jsonArray = (JSONArray) jsonFieldIndexes;
String value = jsonArray.getString(nIndex);

// v8
ObjectMapper mapper = new ObjectMapper();
JsonNode jsonFieldIndexes = mapper.valueToTree(listIndexesFilesToRemove);
if (!jsonFieldIndexes.isArray()) { ... }
ArrayNode jsonArray = (ArrayNode) jsonFieldIndexes;
String value = jsonArray.get(nIndex).asText();
```

**Building JSON with Arrays:**
```java
// v7
public static JSONObject getUploadedFileJSON(List<FileItem> listFileItem) {
    JSONObject json = new JSONObject();
    if (listFileItem != null) {
        for (FileItem fileItem : listFileItem) {
            JSONObject jsonObject = new JSONObject();
            jsonObject.element(JSON_KEY_FILE_NAME, fileItem.getName());
            json.accumulate(JSON_KEY_UPLOADED_FILES, jsonObject);
        }
        json.element(JSON_KEY_FILE_COUNT, listFileItem.size());
    }
    return json;
}

// v8 (Handles single vs multiple files differently)
public static ObjectNode getUploadedFileJSON(List<MultipartItem> listFileItem) {
    ObjectMapper mapper = new ObjectMapper();
    ObjectNode json = mapper.createObjectNode();

    if (listFileItem != null && !listFileItem.isEmpty()) {
        if (1 == listFileItem.size()) {
            ObjectNode jsonObject = mapper.createObjectNode();
            MultipartItem fileItem = listFileItem.get(0);
            jsonObject.put(JSON_KEY_FILE_NAME, fileItem.getName());
            json.set(JSON_KEY_UPLOADED_FILES, jsonObject);
            json.put(JSON_KEY_FILE_COUNT, 1);
        } else {
            ArrayNode uploadedFilesArray = mapper.createArrayNode();
            for (MultipartItem fileItem : listFileItem) {
                ObjectNode jsonObject = mapper.createObjectNode();
                jsonObject.put(JSON_KEY_FILE_NAME, fileItem.getName());
                uploadedFilesArray.add(jsonObject);
            }
            json.set(JSON_KEY_UPLOADED_FILES, uploadedFilesArray);
            json.put(JSON_KEY_FILE_COUNT, listFileItem.size());
        }
    } else {
        json.put(JSON_KEY_FILE_COUNT, 0);
    }
    return json;
}
```

**Building JSON Errors (Accumulating):**
```java
// v7
public static void buildJsonError(JSONObject json, String strMessage) {
    if (json != null) {
        json.accumulate(JSON_KEY_FORM_ERROR, strMessage);
    }
}

// v8 (Manual array handling)
public static void buildJsonError(ObjectNode json, String strMessage) {
    if (json != null) {
        ObjectMapper mapper = new ObjectMapper();
        JsonNode node = json.get(JSON_KEY_FORM_ERROR);
        ArrayNode arrayErrors = mapper.createArrayNode();
        if (null != node && node.isArray()) {
            for (JsonNode jsonNode : node) {
                arrayErrors.add(jsonNode);
            }
        }
        arrayErrors.add(strMessage);
        json.set(JSON_KEY_FORM_ERROR, arrayErrors);
    }
}
```

---

## 6. Frontend: jQuery File Upload to Uppy

### Removed Files (jQuery File Upload)

```
webapp/js/plugins/asynchronousupload/jquery.fileupload.js (1606 lines)
webapp/js/plugins/asynchronousupload/jquery.fileupload-ui.js (759 lines)
webapp/js/plugins/asynchronousupload/jquery.fileupload-process.js (170 lines)
webapp/js/plugins/asynchronousupload/jquery.fileupload-validate.js (119 lines)
webapp/js/plugins/asynchronousupload/jquery.fileupload-image.js (346 lines)
webapp/js/plugins/asynchronousupload/jquery.fileupload-audio.js (101 lines)
webapp/js/plugins/asynchronousupload/jquery.fileupload-video.js (101 lines)
webapp/js/plugins/asynchronousupload/jquery.iframe-transport.js (227 lines)
webapp/js/plugins/asynchronousupload/load-image.all.min.js
webapp/js/plugins/asynchronousupload/vendor/jquery.ui.widget.js (808 lines)
webapp/js/plugins/asynchronousupload/vendor/jquery.Jcrop.js (1694 lines)
webapp/js/plugins/asynchronousupload/vendor/canvas-to-blob.js (143 lines)
webapp/js/plugins/asynchronousupload/vendor/promise-polyfill.js (316 lines)
webapp/js/plugins/asynchronousupload/cors/jquery.postmessage-transport.js
webapp/js/plugins/asynchronousupload/cors/jquery.xdr-transport.js
webapp/css/plugins/asynchronousupload/jquery.fileupload.css
webapp/css/plugins/asynchronousupload/jquery.fileupload-ui.css
webapp/css/plugins/asynchronousupload/jquery.Jcrop.css
```

### Added Files (Uppy)

```
webapp/js/plugins/asynchronousupload/uppy/uppy.min.js (70 lines)
webapp/js/plugins/asynchronousupload/uppy/uppy.min.mjs (70 lines)
webapp/css/plugins/asynchronousupload/uppy/uppy.min.css (12 lines)
webapp/themes/admin/shared/plugins/asynchronousupload/js/config.js (69 lines)
```

### Main.js Rewrite

The `main.js` file was completely rewritten from jQuery File Upload to Uppy:

**Key Differences:**
- Uses ES6+ syntax (const, let, arrow functions, template literals)
- Uses Uppy library instead of jQuery File Upload
- Maintains Map of Uppy instances per field
- Modern event handling

```javascript
// v8 Uppy Implementation
const uppyInstances = new Map();

document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.${handler_name}').forEach(initUppy);
});

function initUppy(input) {
    const uppy = new Uppy.Uppy({
        restrictions: {
            maxFileSize: maxFileSize,
            maxNumberOfFiles: maxFiles,
            allowedFileTypes: allowedTypes
        }
    });

    uppy.use(Uppy.XHRUpload, {
        endpoint: uploadUrl,
        fieldName: fieldName
    });

    uppyInstances.set(fieldName, uppy);
}
```

---

## 7. Template Changes

### Admin Template Macro Renames

```html
<!-- v7 -->
<#macro addFileInput ...>
<#macro addUploadedFilesBox ...>
<#macro addFileInputAndfilesBox ...>

<!-- v8 -->
<#macro addFileBOInput ...>
<#macro addBOUploadedFilesBox ...>
<#macro addFileBOInputAndfilesBox ...>
```

### Admin Template Changes

```html
<!-- v7 addRequiredJsFiles -->
<#macro addRequiredJsFiles>
<script>
var mapFileErrors = new Map();
var mapFilesNumber = new Map();
</script>
</#macro>

<!-- v8 addRequiredJsFiles -->
<#macro addRequiredJsFiles>
<script src="js/plugins/asynchronousupload/uppy/uppy.min.js"></script>
<script src="themes/admin/shared/plugins/asynchronousupload/js/config.js"></script>
</#macro>
```

### Skin Template Changes

```html
<!-- v8 - Wrapped in cTpl -->
<@cTpl>
<!-- template content -->
</@cTpl>

<!-- v8 - Hidden file input with CSS for Uppy -->
<input type="file" name="${fieldName}" id="${fieldName}"
       class="${cssClass!} ${handler.handlerName} position-absolute opacity-0"
       style="pointer-events:none" />
```

### New Macros Use Core inputDropFiles

```html
<!-- v8 uses core macros -->
<@inputDropFiles name=fieldName handler=handler type=type ...>
    <#nested>
</@inputDropFiles>

<@inputDropFilesItem name=fieldName label=filename idx=file_index handler=handler ... />
```

---

## 8. Plugin Descriptor Changes

### asynchronousupload.xml

**Version Update:**
```xml
<!-- v7 -->
<version>1.1.11-SNAPSHOT</version>
<min-core-version>4.4.1</min-core-version>

<!-- v8 -->
<version>2.0.0-SNAPSHOT</version>
<min-core-version>8.0.0</min-core-version>
```

**Removed CSS/JS Declarations:**

All `<css-stylesheets>`, `<javascript-files>`, `<css-admin-stylesheets>`, and `<admin-javascript-files>` sections were removed. The v8 version relies on:
1. Core Uppy integration
2. Template-based JS/CSS inclusion

---

## 9. Test Updates

### UploadCacheServiceTest.java

```java
// v7
public void testCRUD() {
    UploadCacheService cacheService = UploadCacheService.getInstance();
    cacheService.enableCache(true);
    assertNotNull(cacheService.getCache());
    assertNull(cacheService.getFromCache("key"));
    cacheService.putInCache("key", "object");
    String object = (String) cacheService.getFromCache("key");
    cacheService.removeKey("key");
}

// v8
private @Inject UploadCacheService _cacheService;

@Test
public void testCRUD() {
    _cacheService.enableCache(true);
    assertNotNull(_cacheService.getCache());
    assertNull(_cacheService.get("key"));
    _cacheService.put("key", "object");
    String object = _cacheService.get("key");
    _cacheService.remove("key");
}
```

**Cache API Changes:**
| v7 Method | v8 Method |
|-----------|-----------|
| `getFromCache(key)` | `get(key)` |
| `putInCache(key, value)` | `put(key, value)` |
| `removeKey(key)` | `remove(key)` |

---

## 10. Migration Checklist

### Java Code
- [ ] Update imports from `javax.*` to `jakarta.*`
- [ ] Replace `FileItem` with `MultipartItem`
- [ ] Handle `IOException` from `MultipartItem.delete()`
- [ ] Replace `net.sf.json` with `com.fasterxml.jackson`
- [ ] Add CDI annotations (`@ApplicationScoped`, `@Named`, etc.)
- [ ] Replace `SpringContextService.getBean()` with `CDI.current().select()`
- [ ] Replace `SpringContextService.getBeansOfType()` with `Instance<T>` injection
- [ ] Add `@Inject` annotations for service dependencies
- [ ] Deprecate static factory methods with CDI alternatives

### Configuration
- [ ] Create `src/main/resources/META-INF/beans.xml`
- [ ] Delete Spring context XML files
- [ ] Update `pom.xml` parent, version, and dependencies
- [ ] Update plugin descriptor XML version and core dependency

### Frontend
- [ ] Replace jQuery File Upload with Uppy
- [ ] Update template macros to new names (addFileBOInput, etc.)
- [ ] Use core `inputDropFiles` macros
- [ ] Remove old JS/CSS file references

### Templates
- [ ] Wrap skin templates with `<@cTpl>` if using core template features
- [ ] Update macro names (addFileInput -> addFileBOInput)
- [ ] Update macro parameters for deprecated warnings

---

## Key Breaking Changes Summary

1. **Java Namespace**: All `javax.*` imports must become `jakarta.*`
2. **File Upload API**: `FileItem` replaced by `MultipartItem` (fewer methods, IOException on delete)
3. **JSON API**: Complete switch from json-lib to Jackson
4. **DI Framework**: Spring to CDI with different annotation and lookup patterns
5. **Frontend Library**: jQuery File Upload to Uppy (complete rewrite)
6. **Template Macros**: Renamed and refactored to use core components
7. **Cache API**: Method names changed (getFromCache -> get, etc.)
8. **Interface Javadoc**: "Spring beans" changed to "CDI beans"
