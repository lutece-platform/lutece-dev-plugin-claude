# Lutece Form Plugin Forms - Migration v7 to v8 Analysis

## Summary

This document analyzes the migration differences between Lutece v7 (branch `develop`) and Lutece v8 (branch `develop_core8`) for **lutece-form-plugin-forms**.

**Key Statistics:**
- **592 files changed**
- **15,200 insertions, 74,524 deletions**
- Version change: `3.1.0-SNAPSHOT` -> `4.0.0-SNAPSHOT`
- Parent POM: `6.1.0` -> `8.0.0-SNAPSHOT`

---

## 1. POM.xml Changes

### Parent POM Version

```xml
<!-- BEFORE (v7) -->
<parent>
    <artifactId>lutece-global-pom</artifactId>
    <groupId>fr.paris.lutece.tools</groupId>
    <version>6.1.0</version>
</parent>
<version>3.1.0-SNAPSHOT</version>

<!-- AFTER (v8) -->
<parent>
    <artifactId>lutece-global-pom</artifactId>
    <groupId>fr.paris.lutece.tools</groupId>
    <version>8.0.0-SNAPSHOT</version>
</parent>
<version>4.0.0-SNAPSHOT</version>
```

### Dependencies Updates

| Dependency | v7 Version | v8 Version |
|------------|-----------|-----------|
| lutece-core | [7.1.2-SNAPSHOT,) | [8.0.0-SNAPSHOT,) |
| plugin-genericattributes | [2.4.6-SNAPSHOT,) | [3.0.0-SNAPSHOT,) |
| plugin-regularexpression | [3.0.4,) | [5.0.0-SNAPSHOT,) |
| plugin-filegenerator | [2.1.3,) | [3.0.0-SNAPSHOT,) |
| library-utils | [1.0.0,) | [2.0.0-SNAPSHOT,) |
| plugin-htmltopdf | [1.0.0,) | [2.0.0-SNAPSHOT,) |

### New Dependencies

```xml
<!-- New in v8 -->
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>plugin-mermaidjs</artifactId>
    <version>[2.0.0-SNAPSHOT,)</version>
    <type>lutece-plugin</type>
</dependency>
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

### Removed Dependencies

```xml
<!-- Removed in v8 -->
<dependency>
    <groupId>org.apache.pdfbox</groupId>
    <artifactId>pdfbox</artifactId>
    <version>2.0.25</version>
</dependency>
```

---

## 2. javax -> jakarta Migration

All `javax.*` imports have been migrated to `jakarta.*`.

### Validation Constraints

```java
// BEFORE (v7)
import javax.validation.constraints.NotEmpty;
import javax.validation.constraints.Size;
import javax.validation.constraints.Min;

// AFTER (v8)
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Min;
```

**Files affected:** `Control.java`, `ControlGroup.java`, `Form.java`, `Group.java`, `Question.java`, `Step.java`, `FormMessage.java`

### Servlet API

```java
// BEFORE (v7)
import javax.servlet.http.HttpServletRequest;

// AFTER (v8)
import jakarta.servlet.http.HttpServletRequest;
```

### CDI Annotations

```java
// NEW in v8
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.context.RequestScoped;
import jakarta.enterprise.context.SessionScoped;
import jakarta.enterprise.inject.spi.CDI;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.event.Observes;
```

---

## 3. Spring -> CDI Migration

### Spring Context File Removal

The Spring context file has been **completely removed**:
- **Deleted:** `webapp/WEB-INF/conf/plugins/forms_context.xml` (626 lines)

### New CDI beans.xml

**New file:** `src/main/resources/META-INF/beans.xml`

```xml
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0" bean-discovery-mode="annotated">
</beans>
```

### SpringContextService -> CDI.current()

**Pattern in Home classes:**

```java
// BEFORE (v7)
import fr.paris.lutece.portal.service.spring.SpringContextService;

private static IFormDAO _dao = SpringContextService.getBean( "forms.formDAO" );
private static FormsCacheService _cache = SpringContextService.getBean( "forms.cacheService" );

// AFTER (v8)
import jakarta.enterprise.inject.spi.CDI;

private static IFormDAO _dao = CDI.current( ).select( IFormDAO.class ).get( );
private static FormsCacheService _cache = CDI.current( ).select( FormsCacheService.class ).get( );
```

**Files affected:** All `*Home.java` files (FormHome, StepHome, QuestionHome, ControlHome, GroupHome, TransitionHome, etc.)

---

## 4. Service/DAO Pattern Changes

### DAO Classes - Adding @ApplicationScoped

All DAO classes now have the `@ApplicationScoped` annotation:

```java
// BEFORE (v7)
public final class FormDAO implements IFormDAO
{
    // ...
}

// AFTER (v8)
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public final class FormDAO implements IFormDAO
{
    // ...
}
```

**DAO classes migrated:**
- `ControlDAO.java`
- `ControlGroupDAO.java`
- `FormDAO.java`
- `FormActionDAO.java`
- `FormCategoryDAO.java`
- `FormDisplayDAO.java`
- `FormMessageDAO.java`
- `FormQuestionResponseDAO.java`
- `FormResponseDAO.java`
- `FormResponseStepDAO.java`
- `GroupDAO.java`
- `QuestionDAO.java`
- `StepDAO.java`
- `TransitionDAO.java`
- `GlobalFormsActionDAO.java`
- `FormExportConfigDao.java`
- `IndexerActionDAO.java`

### Service Classes - Adding @ApplicationScoped

```java
// BEFORE (v7)
public class FormIdAnonymizationService extends AbstractTextAnonymizationService
{
    // ...
}

// AFTER (v8)
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class FormIdAnonymizationService extends AbstractTextAnonymizationService
{
    // ...
}
```

---

## 5. EntryType Services Migration

### EntryType Classes - @ApplicationScoped + @Named

All EntryType classes now use CDI annotations:

```java
// BEFORE (v7)
public class EntryTypeText extends AbstractEntryTypeText implements IResponseComparator
{
    // No annotations
}

// AFTER (v8)
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;

@ApplicationScoped
@Named( "forms.entryTypeText" )
public class EntryTypeText extends AbstractEntryTypeText implements IResponseComparator
{
    @Inject
    public void addAnonymizationTypes(
        @Named("genericattributes.entryIdAnonymizationType") IEntryAnonymizationType entryIdAnonymizationType,
        @Named("genericattributes.entryCodeAnonymizationType") IEntryAnonymizationType entryCodeAnonymizationType,
        @Named("genericattributes.responseIdAnonymizationType") IEntryAnonymizationType responseIdAnonymizationType,
        @Named("forms.formIdAnonymizationType") IEntryAnonymizationType formIdAnonymizationType,
        @Named("forms.stepIdAnonymizationType") IEntryAnonymizationType stepIdAnonymizationType,
        @Named("forms.questionTitleAnonymizationType") IEntryAnonymizationType questionTitleAnonymizationType,
        @Named("genericattributes.randomGuidAnonymizationType") IEntryAnonymizationType randomGuidAnonymizationType,
        @Named("genericattributes.randomNumberAnonymizationType") IEntryAnonymizationType randomNumberAnonymizationType,
        @Named("genericattributes.defaultValueAnonymizationType") IEntryAnonymizationType defaultValueAnonymizationType)
    {
        setAnonymizationTypes( List.of(
            entryIdAnonymizationType, entryCodeAnonymizationType, responseIdAnonymizationType,
            formIdAnonymizationType, stepIdAnonymizationType, questionTitleAnonymizationType,
            randomGuidAnonymizationType, randomNumberAnonymizationType, defaultValueAnonymizationType
        ) );
    }
}
```

### Upload Handler Injection

```java
// BEFORE (v7)
@Override
public AbstractGenAttUploadHandler getAsynchronousUploadHandler( )
{
    return FormsAsynchronousUploadHandler.getHandler( );
}

// AFTER (v8)
@Inject
private FormsAsynchronousUploadHandler _formsAsynchronousUploadHandler;

@Override
public AbstractGenAttUploadHandler getAsynchronousUploadHandler( )
{
    return _formsAsynchronousUploadHandler;
}
```

---

## 6. CDI Producers

### New Producer Classes

**New file:** `FormsAnonymizationTypeProducer.java`

```java
@ApplicationScoped
public class FormsAnonymizationTypeProducer
{
    @Produces
    @ApplicationScoped
    @Named( "forms.formIdAnonymizationType" )
    public IEntryAnonymizationType produceFormIdAnonymizationType(
            @ConfigProperty( name = "forms.formIdAnonymizationType.wildcard" ) String wildcard,
            @ConfigProperty( name = "forms.formIdAnonymizationType.helpKey" ) String helpKey,
            @ConfigProperty( name = "forms.formIdAnonymizationType.serviceName" ) String serviceName )
    {
        return new EntryAnonymizationType( wildcard, helpKey, serviceName );
    }

    @Produces
    @ApplicationScoped
    @Named( "forms.questionTitleAnonymizationType" )
    public IEntryAnonymizationType produceQuestionTitleAnonymizationType( ... ) { ... }

    @Produces
    @ApplicationScoped
    @Named( "forms.stepIdAnonymizationType" )
    public IEntryAnonymizationType produceStepIdAnonymizationType( ... ) { ... }
}
```

### New Producer Files Created

- `FormsAnonymizationTypeProducer.java`
- `FormColumnProducer.java`
- `FormFilterConfigurationProducer.java`
- `FormPanelConfigurationProducer.java`
- `ValidatorProducer.java`
- `ExportProducer.java`
- `EntryDataServiceProducer.java`
- `EntryDisplayServiceProducer.java`
- `RemovalListenerServicesProducer.java`
- `FormAnalyzerProducer.java`

---

## 7. XPage Changes

### XPage Annotations Update

```java
// BEFORE (v7)
@Controller( xpageName = FormXPage.XPAGE_NAME, pageTitleI18nKey = FormXPage.MESSAGE_PAGE_TITLE, pagePathI18nKey = FormXPage.MESSAGE_PATH )
public class FormXPage extends MVCApplication
{
    private static FormService _formService = SpringContextService.getBean( FormService.BEAN_NAME );
    private ICaptchaSecurityService _captchaSecurityService = new CaptchaSecurityService( );
}

// AFTER (v8)
import jakarta.enterprise.context.SessionScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;

@SessionScoped
@Named( "forms.xpage.forms" )
@Controller( xpageName = FormXPage.XPAGE_NAME, pageTitleI18nKey = FormXPage.MESSAGE_PAGE_TITLE, pagePathI18nKey = FormXPage.MESSAGE_PATH, securityTokenEnabled=false )
public class FormXPage extends MVCApplication
{
    @Inject
    private FormService _formService;
    @Inject
    private AccessControlService _accessControlService;
    @Inject
    private FormsAsynchronousUploadHandler _formsAsynchronousUploadHandler;
    @Inject
    private SecurityTokenService _securityTokenService;
    @Inject
    @Named(BeanUtils.BEAN_CAPTCHA_SERVICE)
    private Instance<ICaptchaService> _captchaService;
}
```

### FormResponseXPage

```java
// AFTER (v8)
@RequestScoped
@Named( "forms.xpage.formsResponse" )
@Controller( xpageName = FormResponseXPage.XPAGE_NAME, ... )
public class FormResponseXPage extends MVCApplication
{
    @Inject
    private FormsAsynchronousUploadHandler _formsAsynchronousUploadHandler;
    @Inject
    private WorkflowService _workflowService;
    @Inject
    private SecurityTokenService _securityTokenService;
}
```

### SecurityTokenService Migration

```java
// BEFORE (v7)
SecurityTokenService.getInstance( ).getToken( request, ACTION_PROCESS_ACTION )
SecurityTokenService.getInstance( ).validate( request, ACTION_PROCESS_ACTION )

// AFTER (v8)
@Inject
private SecurityTokenService _securityTokenService;

_securityTokenService.getToken( request, ACTION_PROCESS_ACTION )
_securityTokenService.validate( request, ACTION_PROCESS_ACTION )
```

### WorkflowService Migration

```java
// BEFORE (v7)
WorkflowService workflowService = WorkflowService.getInstance( );
workflowService.isDisplayTasksForm( nIdAction, locale );

// AFTER (v8)
@Inject
private WorkflowService _workflowService;

_workflowService.isDisplayTasksForm( nIdAction, locale );
```

---

## 8. Cache Service Changes

### Cache Implementation Update

```java
// BEFORE (v7)
import fr.paris.lutece.portal.business.event.EventRessourceListener;
import fr.paris.lutece.portal.business.event.ResourceEvent;
import fr.paris.lutece.portal.service.event.ResourceEventManager;

public class FormsCacheService extends AbstractCacheableService implements EventRessourceListener
{
    @Override
    public void initCache( )
    {
        super.initCache( );
        ResourceEventManager.register( this );
    }

    public void addedResource( ResourceEvent event ) { handleEvent( event ); }
    public void deletedResource( ResourceEvent event ) { handleEvent( event ); }
    public void updatedResource( ResourceEvent event ) { handleEvent( event ); }
}

// AFTER (v8)
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import fr.paris.lutece.plugins.genericattributes.business.EntryEvent;

@ApplicationScoped
public class FormsCacheService extends AbstractCacheableService<String, Object>
{
    @PostConstruct
    public void initCache( )
    {
        initCache( CACHE_NAME, String.class, Object.class );
    }

    @Override
    public void put( String key, Object value ) { ... }

    @Override
    public Object get( String key ) { ... }

    @Override
    public boolean remove( String key ) { ... }

    public void processEntryEvent( @Observes EntryEvent event )
    {
        if ( isCacheEnable( ) && Form.RESOURCE_TYPE.equals( event.getResourceType( ) ) )
        {
            resetCache( );
        }
    }
}
```

### Cache Method Changes

```java
// BEFORE (v7)
_cache.getFromCache( cacheKey )
_cache.putInCache( cacheKey, value )
_cache.removeKey( cacheKey )

// AFTER (v8)
_cache.get( cacheKey )
_cache.put( cacheKey, value )
_cache.remove( cacheKey )
```

---

## 9. Properties File Changes

### New Configuration Properties

Properties have been added for CDI producers configuration:

```properties
# anonymization
forms.formIdAnonymizationType.wildcard=%f
forms.formIdAnonymizationType.helpKey=forms.anonymization.form.help
forms.formIdAnonymizationType.serviceName=forms.formIdAnonymizationService

# breadcrumb
forms.horizontalBreadcrumb.beanName=forms.horizontalBreadcrumb
forms.horizontalBreadcrumb.displayBeanName=forms.breadcrumb.horizontal.name

# dataservice (example)
forms.entryTypeTextDataService.name=forms.entryTypeText

# displayservice (example)
forms.entryTypeTextDisplayService.name=forms.entryTypeText

# export
forms.export.csv.formatExportName=forms.csvExport
forms.export.csv.formatExportDisplayName=forms.export.csv.name
forms.export.csv.formatExportDescription=forms.export.csv.description

# filterconfig
forms.forms.filterConfiguration.position=1
forms.forms.filterConfiguration.filterLabel=forms.filter.form.title
forms.forms.filterConfiguration.filterName=forms_title

# formcolumn
forms.forms.column.position=1
forms.forms.column.formColumnTitle=forms.column.form.title

# panel
forms.formsPanel.panelConfiguration.technicalCode=forms
forms.formsPanel.panelConfiguration.position=1
forms.formsPanel.panelConfiguration.title=forms.formsPanel.panelConfiguration.title

# validator
forms.patternValidator.beanName=forms.patternValidator
forms.patternValidator.displayName=forms.validator.pattern.name
forms.patternValidator.availableEntryTypeItems=forms.entryTypeText,forms.entryTypeTextArea,forms.entryTypeGeolocation

# Forms indexer
forms.index.writer.ms.timeout.lock=3600000
forms.index.writer.multi.apps=true
forms.index.writer.auto.initialize=true
daemon.formsIndexerDaemon.onstartup=1
daemon.formsIndexerDaemon.interval=30
forms.search.lucene.analyser.className=fr.paris.lutece.plugins.lucene.service.analyzer.LuteceFrenchAnalyzer
```

---

## 10. Plugin XML Changes

### forms.xml Updates

```xml
<!-- BEFORE (v7) -->
<version>3.1.0-SNAPSHOT</version>
<icon-url>images/admin/skin/feature_default_icon.png</icon-url>
<min-core-version>6.1.0</min-core-version>

<applications>
    <application>
        <application-id>forms</application-id>
        <application-class>fr.paris.lutece.plugins.forms.web.FormXPage</application-class>
    </application>
</applications>

<!-- AFTER (v8) -->
<version>4.0.0-SNAPSHOT</version>
<icon-url>themes/admin/shared/plugins/forms/images/forms.svg</icon-url>
<min-core-version>8.0.0</min-core-version>

<applications>
    <application>
        <application-id>forms</application-id>
        <!-- No application-class - auto-discovered via CDI -->
    </application>
</applications>

<!-- New daemon -->
<daemons>
    <daemon>
        <daemon-id>formsIndexerDaemon</daemon-id>
        <daemon-name>forms.daemon.indexerDameon.name</daemon-name>
        <daemon-description>forms.daemon.indexerDameon.description</daemon-description>
        <daemon-class>fr.paris.lutece.plugins.forms.service.search.FormsSearchIndexerDaemon</daemon-class>
    </daemon>
</daemons>
```

---

## 11. Serializable Pattern

Many business classes now implement `Serializable`:

```java
// BEFORE (v7)
public class Control implements Cloneable
{
    private int _nId;
}

// AFTER (v8)
public class Control implements Cloneable, Serializable
{
    private static final long serialVersionUID = 1L;
    private int _nId;
}
```

**Classes affected:**
- `Control.java`
- `Form.java`
- `FormMessage.java`
- `FormQuestionResponse.java`
- `FormResponse.java`
- `FormResponseStep.java`

---

## 12. New Files Created

### New Service Files
- `FormsSearchIndexerDaemon.java` - New daemon for forms indexing
- `FormGraphExportService.java` - Graph export service
- `LuceneLockManager.java` / `LuceneLockManagerDB.java` - Lock management for Lucene

### New Business Files
- `IStepDAO.java` - New DAO interface methods
- `StepDAO.java` - DAO implementation with new methods
- `IFormListDAO.java` - FormList DAO interface
- `ILockDAO.java` / `Lock.java` / `LockDAO.java` - Lock entities
- `IIndexerActionDAO.java` - Indexer action DAO interface

### New Event Files
- `ControlEvent.java` - Control event handling
- `FormResponseEvent.java` - Form response event handling

### New Producer Files
- `FormColumnProducer.java`
- `FormFilterConfigurationProducer.java`
- `FormPanelConfigurationProducer.java`
- `ValidatorProducer.java`
- `ExportProducer.java`
- `EntryDataServiceProducer.java`
- `EntryDisplayServiceProducer.java`
- `RemovalListenerServicesProducer.java`
- `FormsAnonymizationTypeProducer.java`
- `FormAnalyzerProducer.java`

---

## 13. Deleted Files

### Removed Services
- `FormsFileDownloadService.java`
- `FormsFileRBACService.java`

### Removed Spring Context
- `webapp/WEB-INF/conf/plugins/forms_context.xml` (626 lines)

### Removed Static Resources
- `webapp/css/admin/plugins/forms/forms.css`
- `webapp/css/plugins/forms/forms.css`
- `webapp/images/admin/skin/plugins/forms/*`
- `webapp/js/admin/plugins/forms/vis/*` (entire vis.js library)
- `webapp/js/jquery/plugins/toastr/*`
- `webapp/js/plugins/forms/forms.js`

---

## 14. Template Changes Summary

Templates have been significantly refactored to use Lutece macros:

```html
<!-- BEFORE (v7) -->
<div class="panel panel-default">
    <div class="panel-heading">
        <h3 class="panel-title">${step.title}</h3>
    </div>
    <div class="panel-body">${stepContent}</div>
</div>

<!-- AFTER (v8) -->
<#assign stepTitle=step.title!?replace("- hidden","") />
<@box title=stepTitle>
${stepContent}
</@box>
```

---

## Migration Checklist

1. [ ] Update `pom.xml` with new parent version and dependencies
2. [ ] Create `src/main/resources/META-INF/beans.xml`
3. [ ] Delete `*_context.xml` Spring configuration files
4. [ ] Replace all `javax.*` imports with `jakarta.*`
5. [ ] Add `@ApplicationScoped` to all DAO classes
6. [ ] Add `@ApplicationScoped` and `@Named` to service classes
7. [ ] Replace `SpringContextService.getBean()` with `CDI.current().select().get()`
8. [ ] Create CDI producer classes for beans that need configuration
9. [ ] Add `@SessionScoped`/`@RequestScoped` and `@Named` to XPage classes
10. [ ] Update XPage with `@Inject` for dependencies
11. [ ] Add `Serializable` to business objects
12. [ ] Update cache service to use new `AbstractCacheableService<K,V>` pattern
13. [ ] Add producer properties to `*.properties` files
14. [ ] Remove `application-class` from `plugin.xml` for XPages
15. [ ] Update templates to use Lutece macros
