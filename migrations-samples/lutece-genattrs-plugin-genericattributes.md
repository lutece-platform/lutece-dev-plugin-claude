# Migration Analysis: lutece-genattrs-plugin-genericattributes

## Overview

| Property | v7 (develop) | v8 (develop_core8) |
|----------|--------------|-------------------|
| Plugin version | 2.4.9-SNAPSHOT | 3.0.0-SNAPSHOT |
| Parent POM | 7.0.2 | 8.0.0-SNAPSHOT |
| lutece-core dependency | [7.0.17-SNAPSHOT,7.9.9) | [8.0.0-SNAPSHOT,) |

## Statistics

- **83 files changed**
- **815 insertions, 467 deletions**

---

## 1. Dependency Changes (pom.xml)

### Core Dependencies

```xml
<!-- v7 -->
<dependency>
    <groupId>fr.paris.lutece</groupId>
    <artifactId>lutece-core</artifactId>
    <version>[7.0.17-SNAPSHOT,7.9.9)</version>
</dependency>

<!-- v8 -->
<dependency>
    <groupId>fr.paris.lutece</groupId>
    <artifactId>lutece-core</artifactId>
    <version>[8.0.0-SNAPSHOT,)</version>
</dependency>
```

### Plugin Dependencies

```xml
<!-- v7 -->
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>plugin-asynchronousupload</artifactId>
    <version>[1.1.11-SNAPSHOT,1.9.9)</version>
</dependency>

<!-- v8 -->
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>plugin-asynchronousupload</artifactId>
    <version>[2.0.0-SNAPSHOT,)</version>
</dependency>
```

### New Test Dependencies

```xml
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-lutece-unit-testing</artifactId>
    <type>jar</type>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.glassfish.jaxb</groupId>
    <artifactId>jaxb-runtime</artifactId>
    <scope>test</scope>
</dependency>
```

---

## 2. Package Migrations (javax to jakarta)

### Servlet API

```java
// v7
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import javax.servlet.http.HttpSessionListener;
import javax.servlet.http.HttpSessionEvent;

// v8
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.HttpSessionListener;
import jakarta.servlet.http.HttpSessionEvent;
```

### XML Binding

```java
// v7
import javax.xml.bind.DatatypeConverter;

// v8
import jakarta.xml.bind.DatatypeConverter;
```

### CDI Annotations

```java
// v8 new imports
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.context.SessionScoped;
import jakarta.enterprise.inject.spi.CDI;
import jakarta.enterprise.inject.Produces;
import jakarta.enterprise.inject.literal.NamedLiteral;
import jakarta.enterprise.event.ObservesAsync;
import jakarta.inject.Named;
```

---

## 3. Spring to CDI Migration

### 3.1 DAO Classes

**Pattern: Remove `final`, add `@ApplicationScoped`**

```java
// v7
public final class EntryDAO implements IEntryDAO { }

// v8
@ApplicationScoped
public class EntryDAO implements IEntryDAO { }
```

Applied to:
- `EntryDAO`
- `EntryTypeDAO`
- `FieldDAO`
- `ResponseDAO`
- `ReferenceItemFieldDao`

### 3.2 Home Classes (DAO Injection)

**Pattern: Replace SpringContextService.getBean() with CDI.current().select()**

```java
// v7
private static IEntryDAO _dao = SpringContextService.getBean("genericattributes.entryDAO");

// v8
private static IEntryDAO _dao = CDI.current().select(IEntryDAO.class).get();
```

Applied to:
- `EntryHome`
- `EntryTypeHome`
- `FieldHome`
- `ResponseHome`
- `ReferenceItemFieldHome`

### 3.3 Service Manager Classes

**Pattern: Replace SpringContextService.getBeansOfType() with CDI stream**

```java
// v7
return SpringContextService.getBeansOfType(ICartoProvider.class);

// v8
return CDI.current().select(ICartoProvider.class).stream().toList();
```

Applied to:
- `CartoProviderManager`
- `MapProviderManager`
- `OcrProviderManager`

### 3.4 Named Bean Lookup

**Pattern: Use NamedLiteral for bean lookup by name**

```java
// v7 (EntryTypeServiceManager)
return SpringContextService.getBean(entryType.getBeanName());

// v8
return CDI.current().select(IEntryTypeService.class, NamedLiteral.of(entryType.getBeanName())).get();
```

### 3.5 Service Classes with @Named

**Pattern: Add @ApplicationScoped and @Named annotations**

```java
// v7 (defined in Spring XML)
<bean id="genericattributes.date0AnonymizationService"
      class="...Date0AnonymizationService" />

// v8 (annotated class)
@ApplicationScoped
@Named("genericattributes.date0AnonymizationService")
public class Date0AnonymizationService extends AbstractDateAnonymizationService { }
```

### 3.6 JspBeans with CDI Scopes

```java
// v8
@SessionScoped
@Named
@Controller(controllerJsp = "ManageEntryType.jsp", ...)
public class EntryTypeJspBean extends MVCAdminJspBean { }
```

---

## 4. Event System Migration

### 4.1 ResourceEvent to Custom EntryEvent

**New class: `EntryEvent`**

```java
// v8 - New event class
public class EntryEvent {
    private String _strId;
    private String _strResourceType;
    private IEventParam<?> _param;
    // constructors and getters/setters
}
```

### 4.2 Event Firing

```java
// v7
ResourceEvent event = new ResourceEvent();
event.setIdResource(String.valueOf(entry.getIdEntry()));
event.setTypeResource(entry.getResourceType());
ResourceEventManager.fireAddedResource(event);

// v8
EntryEvent event = new EntryEvent();
event.setId(String.valueOf(entry.getIdEntry()));
event.setResourceType(entry.getResourceType());
CDI.current().getBeanManager().getEvent()
    .select(EntryEvent.class, new TypeQualifier(EventAction.CREATE))
    .fire(event);
```

### 4.3 Event Actions

| Action | v7 Method | v8 TypeQualifier |
|--------|-----------|-----------------|
| Create | `fireAddedResource()` | `EventAction.CREATE` |
| Update | `fireUpdatedResource()` | `EventAction.UPDATE` |
| Delete | `fireDeletedResource()` | `EventAction.REMOVE` |

### 4.4 Event Listeners (Observer Pattern)

```java
// v7
public class GenattReferenceItemListener implements IReferenceItemListener {
    @Override
    public void addReferenceItem(ReferenceItem item) { }
}

// v8
@ApplicationScoped
public class GenattReferenceItemListener {
    public void addReferenceItem(
        @ObservesAsync @Type(EventAction.CREATE) ReferenceItemEvent event) {
        ReferenceItem item = event.getReferenceItem();
        // ...
    }
}
```

---

## 5. File Upload API Migration

### 5.1 FileItem to MultipartItem

```java
// v7
import org.apache.commons.fileupload.FileItem;

// v8
import fr.paris.lutece.portal.service.upload.MultipartItem;
```

### 5.2 GenAttFileItem Interface Change

```java
// v7
public class GenAttFileItem implements FileItem { }

// v8
public class GenAttFileItem implements MultipartItem { }
```

### 5.3 Removed Methods from GenAttFileItem

- `getOutputStream()`
- `isFormField()`
- `isInMemory()`
- `setFormField()`
- `write()`
- `getHeaders()`
- `setHeaders()`

### 5.4 IOcrProvider Interface

```java
// v7
List<Response> process(FileItem fileUploaded, int nIdTargetEntry, String strResourceType);

// v8
List<Response> process(MultipartItem fileUploaded, int nIdTargetEntry, String strResourceType);
```

---

## 6. FileService Instance Pattern

```java
// v7
FileService.getInstance().getFileStoreServiceProvider()

// v8 (injection-based)
private FileService _fileService;

private GenericAttributeFileService() {
    _fileService = CDI.current().select(FileService.class).get();
}
// then use: _fileService.getFileStoreServiceProvider()
```

---

## 7. Configuration Migration

### 7.1 Spring XML Removed

**Deleted file:** `webapp/WEB-INF/conf/plugins/genericattributes_context.xml`

### 7.2 CDI beans.xml Added

**New file:** `src/main/resources/META-INF/beans.xml`

```xml
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee
                           https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0" bean-discovery-mode="annotated">
</beans>
```

### 7.3 Configuration Properties for CDI Producer

New entries in `genericattributes.properties` for `@ConfigProperty` injection:

```properties
# anonymization beans configuration
genericattributes.date0AnonymizationType.wildcard=%0
genericattributes.date0AnonymizationType.helpKey=genericattributes.anonymization.date.zero.help
genericattributes.date0AnonymizationType.serviceName=genericattributes.date0AnonymizationService
# ... (similar for all anonymization types)
```

### 7.4 CDI Producer Pattern

```java
@ApplicationScoped
public class EntryAnonymizationTypeProducer {

    @Produces
    @ApplicationScoped
    @Named("genericattributes.date0AnonymizationType")
    public IEntryAnonymizationType produceDate0AnonymizationType(
            @ConfigProperty(name = "genericattributes.date0AnonymizationType.wildcard") String wildcard,
            @ConfigProperty(name = "genericattributes.date0AnonymizationType.helpKey") String helpKey,
            @ConfigProperty(name = "genericattributes.date0AnonymizationType.serviceName") String serviceName) {
        return new EntryAnonymizationType(wildcard, helpKey, serviceName);
    }
}
```

---

## 8. JSP Migration

```jsp
<!-- v7 -->
<jsp:useBean id="manageEntryType" scope="session"
    class="fr.paris.lutece.plugins.genericattributes.web.admin.EntryTypeJspBean" />
<% String strContent = manageEntryType.processController(request, response); %>
<%= strContent %>

<!-- v8 -->
${ pageContext.setAttribute('strContent',
    entryTypeJspBean.processController(pageContext.request, pageContext.response)) }
${ pageContext.getAttribute('strContent') }
```

**Key changes:**
- No more `<jsp:useBean>` with explicit class
- Use EL expressions with CDI managed bean name (`entryTypeJspBean`)
- Use `pageContext.request/response` instead of implicit objects

---

## 9. Test Framework Migration

### 9.1 JUnit 4 to JUnit 5

```java
// v7
import org.junit.Test;
public void setUp() throws Exception {
    super.setUp();
}

// v8
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;

@BeforeEach
public void setUp() throws Exception { }

@AfterEach
public void tearDown() throws Exception { }
```

### 9.2 Assertions Format

```java
// v7
assertEquals("Message", expected, actual);

// v8 (JUnit 5 format)
assertEquals(expected, actual, "Message");
```

### 9.3 CDI Extension for Tests

**New file:** `src/test/java/.../util/EntryTypeServiceExtension.java`

```java
public class EntryTypeServiceExtension implements Extension {
    public static final List<String> beanNames = new ArrayList<>();
    public static final int NUMBER_OF_ENTRYTYPES = 30;

    protected void addBeansToCdi(@Observes final AfterBeanDiscovery abd,
                                  final BeanManager bm) {
        // Dynamically register test beans
        abd.addBean()
            .beanClass(MockEntryTypeService.class)
            .name(beanName)
            .addTypes(MockEntryTypeService.class, IEntryTypeService.class)
            .addQualifier(NamedLiteral.of(beanName))
            .scope(ApplicationScoped.class)
            .produceWith(obj -> new MockEntryTypeService());
    }
}
```

### 9.4 SPI Registration for Test Extension

**New file:** `src/test/resources/META-INF/services/jakarta.enterprise.inject.spi.Extension`

```
fr.paris.lutece.plugins.genericattributes.util.EntryTypeServiceExtension
```

---

## 10. Logging Pattern Updates

```java
// v7 (string concatenation)
AppLogService.info(CartoProviderManager.class.getName() + " : No map provider found for key " + strKey);

// v8 (parameterized logging)
AppLogService.info("{} : No map provider found for key {}", CartoProviderManager.class.getName(), strKey);
```

---

## 11. ErrorMessage Interface

New method added to `GenericAttributeError`:

```java
@Override
public String getParamName() {
    return null;
}
```

---

## 12. File.getIdFile() to File.getFileKey()

```java
// v7
_file.setIdFile(file.getIdFile());

// v8
_file.setFileKey(file.getFileKey());
```

---

## 13. SQL Changes

### Upgrade Script

**New file:** `update_db_genericattributes-2.4.6-3.0.0.sql`

```sql
-- liquibase formatted sql
-- changeset genericattributes:update_db_genericattributes-2.4.6-3.0.0.sql
UPDATE core_admin_right SET icon_url='ti ti-input-check' WHERE id_right='ENTRY_TYPE_MANAGEMENT';
```

---

## Migration Checklist

### Java Code
- [ ] Replace `javax.servlet.*` with `jakarta.servlet.*`
- [ ] Replace `javax.xml.bind.*` with `jakarta.xml.bind.*`
- [ ] Replace `FileItem` with `MultipartItem`
- [ ] Add `@ApplicationScoped` to DAO classes
- [ ] Remove `final` from DAO classes
- [ ] Replace `SpringContextService.getBean()` with `CDI.current().select()`
- [ ] Replace `SpringContextService.getBeansOfType()` with CDI stream pattern
- [ ] Add `@Named` annotation to services that need bean name lookup
- [ ] Migrate event system from ResourceEventManager to CDI events
- [ ] Update logging to use parameterized format
- [ ] Replace `FileService.getInstance()` with injected instance

### Configuration
- [ ] Delete Spring context XML file
- [ ] Create `src/main/resources/META-INF/beans.xml`
- [ ] Create CDI Producer classes for complex beans
- [ ] Add `@ConfigProperty` configuration to properties file

### JSP
- [ ] Remove `<jsp:useBean>` tags
- [ ] Use EL expressions with CDI bean names
- [ ] Use `pageContext.request/response`

### Tests
- [ ] Migrate to JUnit 5 annotations
- [ ] Update assertion format
- [ ] Create CDI Extension for dynamic bean registration
- [ ] Register Extension via SPI file

### Database
- [ ] Create upgrade SQL script with liquibase format
