# Migration Analysis: lutece-wf-module-workflow-formstopdf (v7 to v8)

## Overview

| Property | v7 (develop) | v8 (develop_core8) |
|----------|--------------|-------------------|
| **Module Version** | 1.0.0-SNAPSHOT | 2.0.0-SNAPSHOT |
| **Global POM** | 7.0.1 | 8.0.0-SNAPSHOT |
| **Lutece Core** | [7.0.5-SNAPSHOT,) | [8.0.0-SNAPSHOT,) |
| **Plugin Forms** | [3.0.1,) | [4.0.0-SNAPSHOT,) |
| **Plugin Workflow** | [6.0.0,) | [7.0.0-SNAPSHOT,) |
| **Library Workflow Core** | [1.2.1,3.0.4] | 4.0.0-SNAPSHOT |
| **Plugin HTML to PDF** | 1.0.0-SNAPSHOT | 2.0.0-SNAPSHOT |

## Summary of Changes

**Files Modified/Added: 25 files**
- +407 lines / -179 lines

### Key Migration Patterns

1. **Spring to CDI Migration**: Complete removal of Spring XML context, replaced with Jakarta CDI annotations
2. **Javax to Jakarta**: All servlet imports migrated from `javax.*` to `jakarta.*`
3. **CDI Producers**: New producer classes for TaskType and ConfigService
4. **SQL Liquibase**: Added Liquibase headers to SQL scripts
5. **Test Framework**: Updated to JUnit 5 with CDI injection

---

## Detailed Changes

### 1. Dependency Updates (pom.xml)

```xml
<!-- Added Test Dependencies -->
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

### 2. Spring Context Removal

**Deleted**: `webapp/WEB-INF/conf/plugins/workflow-formspdf_context.xml` (44 lines)

All Spring bean definitions were removed and replaced with CDI annotations.

---

### 3. CDI Configuration

**Added**: `src/main/resources/META-INF/beans.xml`

```xml
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0" bean-discovery-mode="annotated">
</beans>
```

---

### 4. CDI Producers for Workflow Components

#### 4.1 TaskType Producer

**New File**: `TaskTypeFormsPDFProducer.java`

```java
@ApplicationScoped
public class TaskTypeFormsPDFProducer
{
    @Produces
    @ApplicationScoped
    @Named( "workflow-formspdf.taskTypeFormsPDFTask" )
    public ITaskType produceTaskTypeFormsPDFTask(
            @ConfigProperty( name = "workflow-formspdf.taskTypeFormsPDFTask.key" ) String key,
            @ConfigProperty( name = "workflow-formspdf.taskTypeFormsPDFTask.titleI18nKey" ) String titleI18nKey,
            @ConfigProperty( name = "workflow-formspdf.taskTypeFormsPDFTask.beanName" ) String beanName,
            @ConfigProperty( name = "workflow-formspdf.taskTypeFormsPDFTask.configBeanName" ) String configBeanName,
            @ConfigProperty( name = "workflow-formspdf.taskTypeFormsPDFTask.configRequired", defaultValue = "false" ) boolean configRequired,
            @ConfigProperty( name = "workflow-formspdf.taskTypeFormsPDFTask.formTaskRequired", defaultValue = "false" ) boolean formTaskRequired,
            @ConfigProperty( name = "workflow-formspdf.taskTypeFormsPDFTask.taskForAutomaticAction", defaultValue = "false" ) boolean taskForAutomaticAction )
    {
        return buildTaskType( key, titleI18nKey, beanName, configBeanName, configRequired, formTaskRequired, taskForAutomaticAction );
    }

    private ITaskType buildTaskType( String strKey, String strTitleI18nKey, String strBeanName, String strConfigBeanName,
            boolean bIsConfigRequired, boolean bIsFormTaskRequired, boolean bIsTaskForAutomaticAction )
    {
        TaskType taskType = new TaskType( );
        taskType.setKey( strKey );
        taskType.setTitleI18nKey( strTitleI18nKey );
        taskType.setBeanName( strBeanName );
        taskType.setConfigBeanName( strConfigBeanName );
        taskType.setConfigRequired( bIsConfigRequired );
        taskType.setFormTaskRequired( bIsFormTaskRequired );
        taskType.setTaskForAutomaticAction( bIsTaskForAutomaticAction );
        return taskType;
    }
}
```

#### 4.2 ConfigService Producer

**New File**: `TaskTypeFormsConfigServiceProducer.java`

```java
@ApplicationScoped
public class TaskTypeFormsConfigServiceProducer
{
    @Produces
    @ApplicationScoped
    @Named( "workflow-formspdf.formsPDFTaskConfigService" )
    public ITaskConfigService produceTaskTypeFormsConfigService(
            @Named( "workflow-formspdf.formsPDFTaskConfigDAO" ) ITaskConfigDAO<FormsPDFTaskConfig> taskTypeFormsConfigDAO )
    {
        TaskConfigService taskService = new TaskConfigService( );
        taskService.setTaskConfigDAO( (ITaskConfigDAO) taskTypeFormsConfigDAO );
        return taskService;
    }
}
```

---

### 5. Properties Configuration for TaskType

**Updated**: `webapp/WEB-INF/conf/plugins/workflow-formspdf.properties`

```properties
# Added TaskType configuration (replaces Spring XML)
workflow-formspdf.taskTypeFormsPDFTask.key=formsPDFTask
workflow-formspdf.taskTypeFormsPDFTask.titleI18nKey=module.workflow.formspdf.task_title
workflow-formspdf.taskTypeFormsPDFTask.beanName=workflow-formspdf.formsPDFTask
workflow-formspdf.taskTypeFormsPDFTask.configBeanName=workflow-formspdf.formsPDFTaskConfig
workflow-formspdf.taskTypeFormsPDFTask.configRequired=true
workflow-formspdf.taskTypeFormsPDFTask.formTaskRequired=false
workflow-formspdf.taskTypeFormsPDFTask.taskForAutomaticAction=true
```

---

### 6. Business Layer Annotations

#### 6.1 FormsPDFTaskConfig

```java
// Added annotations
@Dependent
@Named( "workflow-formspdf.formsPDFTaskConfig" )
public class FormsPDFTaskConfig extends TaskConfig
```

#### 6.2 FormsPDFTaskConfigDAO

```java
// Added annotations
@ApplicationScoped
@Named( "workflow-formspdf.formsPDFTaskConfigDAO" )
public class FormsPDFTaskConfigDAO implements ITaskConfigDAO<FormsPDFTaskConfig>
```

#### 6.3 FormsPDFTaskTemplate

```java
// Added annotations
@Dependent
@Named( "workflow-formspdf.formsPDFTaskTemplate" )
public class FormsPDFTaskTemplate
```

#### 6.4 FormsPDFTaskTemplateDAO

```java
// Added annotation
@ApplicationScoped
public class FormsPDFTaskTemplateDAO implements IFormsPDFTaskTemplateDAO
```

---

### 7. Home Class - Spring to CDI

**FormsPDFTaskTemplateHome.java**

```java
// v7 - Spring
import fr.paris.lutece.portal.service.spring.SpringContextService;
private static IFormsPDFTaskTemplateDAO _dao = SpringContextService.getBean( "workflow-formspdf.formsPDFTaskTemplateDAO" );

// v8 - CDI
import jakarta.enterprise.inject.spi.CDI;
private static IFormsPDFTaskTemplateDAO _dao = CDI.current( ).select( IFormsPDFTaskTemplateDAO.class ).get( );
```

---

### 8. Task Class Migration

**FormsPDFTask.java**

```java
// v7 - Spring static beans
import javax.servlet.http.HttpServletRequest;
import fr.paris.lutece.portal.service.spring.SpringContextService;
import fr.paris.lutece.plugins.workflowcore.service.resource.ResourceHistoryService;

private static final ITaskConfigService _formsPDFTaskConfigService = SpringContextService.getBean( "workflow-formspdf.formsPDFTaskConfigService" );
private static final IResourceHistoryService _resourceHistoryService = SpringContextService.getBean( ResourceHistoryService.BEAN_SERVICE );

// In processTask:
TemporaryFileGeneratorService.getInstance( ).generateFile( htmltopdf, user );

// v8 - CDI with injection
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.servlet.http.HttpServletRequest;

@Dependent
@Named( "workflow-formspdf.formsPDFTask" )
public class FormsPDFTask extends Task
{
    @Inject
    @Named( "workflow-formspdf.formsPDFTaskConfigService" )
    private ITaskConfigService _formsPDFTaskConfigService;

    @Inject
    private IResourceHistoryService _resourceHistoryService;

    @Inject
    private TemporaryFileGeneratorService _temporaryFileGeneratorService;

    // In processTask:
    _temporaryFileGeneratorService.generateFile( htmltopdf, user );
}
```

**Key Changes**:
- `@Dependent` scope for prototype-like behavior
- `@Inject` replaces `SpringContextService.getBean()`
- Instance services instead of static
- `TemporaryFileGeneratorService` injected instead of singleton pattern

---

### 9. Task Component Migration

**FormsPDFTaskComponent.java**

```java
// v7 - Spring configured
import javax.servlet.http.HttpServletRequest;
import java.util.HashMap;
import java.util.Map;

public class FormsPDFTaskComponent extends AbstractTaskComponent
{
    @Override
    public String getDisplayConfigForm( HttpServletRequest request, Locale locale, ITask task )
    {
        Map<String, Object> model = new HashMap<>( );
        // ...
    }
}

// v8 - CDI with constructor injection
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.servlet.http.HttpServletRequest;
import fr.paris.lutece.portal.web.cdi.mvc.Models;

@ApplicationScoped
@Named( "workflow-formspdf.formsPDFTaskComponent" )
public class FormsPDFTaskComponent extends AbstractTaskComponent
{
    @Inject
    public FormsPDFTaskComponent( @Named( "workflow-formspdf.taskTypeFormsPDFTask" ) ITaskType taskType,
                                  @Named( "workflow-formspdf.formsPDFTaskConfigService" ) ITaskConfigService taskConfigService )
    {
        setTaskType( taskType );
        setTaskConfigService( taskConfigService );
    }

    @Inject
    private Models model;

    @Override
    public String getDisplayConfigForm( HttpServletRequest request, Locale locale, ITask task )
    {
        // model is injected, no more HashMap creation
        FormsPDFTaskConfig config = getTaskConfigService( ).findByPrimaryKey( task.getId( ) );
        model.put( MARK_ID_TASK, request.getParameter(PARAMETER_ID_TASK));
        // ...
    }
}
```

**Key Changes**:
- `@ApplicationScoped` (singleton)
- Constructor injection for TaskType and TaskConfigService
- `Models` utility class injected instead of `new HashMap<>()`

---

### 10. JspBean Migration

**FormsPDFTaskTemplateJspBean.java**

```java
// v7
import javax.servlet.http.HttpServletRequest;
import java.util.Locale;

@Controller( controllerJsp = "ManageTemplates.jsp", controllerPath = "jsp/admin/plugins/workflow/modules/formspdf/", right = "WORKFLOW_MANAGEMENT" )
public class FormsPDFTaskTemplateJspBean extends MVCAdminJspBean
{
    // session fields
    private int _nIdTask;

    @View( value = VIEW_MANAGE_TEMPLATES, defaultView = true )
    public String getManageTemplates( HttpServletRequest request )
    {
        Locale locale = getLocale( );
        Map<String, Object> model = getModel( );

        if (_nIdTask == 0)
        {
            _nIdTask = NumberUtils.toInt( request.getParameter(PARAMETER_TASK_ID), DEFAULT_ID_VALUE);
        }
        model.put(MARK_TASK_ID, _nIdTask);
        // ...
    }

    @Action( value = ACTION_MODIFY_TEMPLATE )
    public String doModifyTemplate( HttpServletRequest request )
    {
        // ...
        return redirectView( request, VIEW_MANAGE_TEMPLATES );
    }
}

// v8
import jakarta.enterprise.context.RequestScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.servlet.http.HttpServletRequest;
import java.util.LinkedHashMap;
import fr.paris.lutece.portal.web.cdi.mvc.Models;

@RequestScoped
@Named
@Controller( controllerJsp = "ManageTemplates.jsp", controllerPath = "jsp/admin/plugins/workflow/modules/formspdf/", right = "WORKFLOW_MANAGEMENT", securityTokenEnabled = true )
public class FormsPDFTaskTemplateJspBean extends MVCAdminJspBean
{
    @Inject
    private Models model;

    @View( value = VIEW_MANAGE_TEMPLATES, defaultView = true )
    public String getManageTemplates( HttpServletRequest request )
    {
        // No session field, get from request each time
        model.put( MARK_TASK_ID, NumberUtils.toInt( request.getParameter( PARAMETER_TASK_ID ), DEFAULT_ID_VALUE ) );
        // ...
    }

    @Action( value = ACTION_MODIFY_TEMPLATE )
    public String doModifyTemplate( HttpServletRequest request )
    {
        // ...
        Map<String, String> mapParameters = new LinkedHashMap<>( );
        mapParameters.put( PARAMETER_TASK_ID, request.getParameter( PARAMETER_TASK_ID ) );
        return redirect( request, VIEW_MANAGE_TEMPLATES, mapParameters );
    }
}
```

**Key Changes**:
- `@RequestScoped` instead of session bean
- `@Named` for CDI discovery
- `securityTokenEnabled = true` added to `@Controller`
- Session field `_nIdTask` removed - now read from request each time
- `Models` injected instead of `getModel()`
- `redirect()` with parameters replaces `redirectView()` to preserve task_id

---

### 11. JSP Changes

**ManageTemplates.jsp**

```jsp
<!-- v7 - Session scoped bean -->
<jsp:useBean id="manageFormsPDFTaskTemplate" scope="session" class="fr.paris.lutece.plugins.workflow.modules.formspdf.web.task.FormsPDFTaskTemplateJspBean" />
<% String strContent = manageFormsPDFTaskTemplate.processController ( request , response ); %>
<%= strContent %>

<!-- v8 - CDI managed bean via EL -->
${ pageContext.setAttribute( 'strContent', formsPDFTaskTemplateJspBean.processController( pageContext.request , pageContext.response ) ) }
${ pageContext.getAttribute( 'strContent' ) }
```

---

### 12. SQL Scripts - Liquibase Headers

**create_db_workflow-formspdf.sql**

```sql
-- v8 adds Liquibase headers
-- liquibase formatted sql
-- changeset workflow-formspdf:create_db_workflow-formspdf.sql
-- preconditions onFail:MARK_RAN onError:WARN

-- Column types standardized
-- v7: INT(11)
-- v8: INT (without size)

-- LONGTEXT changed to LONG VARCHAR for H2 compatibility
```

**init_db_workflow-formspdf.sql**

```sql
-- liquibase formatted sql
-- changeset workflow-formspdf:init_db_workflow-formspdf.sql
-- preconditions onFail:MARK_RAN onError:WARN
```

---

### 13. Plugin Descriptor

**workflow-formspdf.xml**

```xml
<!-- Core version updated -->
<min-core-version>8.0.0</min-core-version>
```

---

### 14. Test Framework Update

**TestFormsToPdf.java** (renamed from testFormsToPdf.java)

```java
// v7 - JUnit 4 style
import fr.paris.lutece.test.LuteceTestCase;

public class testFormsToPdf extends LuteceTestCase
{
    public void testIsActiveWhenActivationIsTrue( )
    {
        assert( true );
    }
}

// v8 - JUnit 5 with CDI injection
import org.junit.jupiter.api.Test;
import fr.paris.lutece.test.LuteceTestCase;
import jakarta.inject.Inject;

public class TestFormsToPdf extends LuteceTestCase
{
    @Inject
    private ITaskConfigDAO<FormsPDFTaskConfig> _formsPDFTaskConfigDAO;

    @Inject
    private IFormsPDFTaskTemplateDAO _formsPDFTaskTemplateDAO;

    @Test
    public void testIsActiveWhenActivationIsTrue( )
    {
        assert( true );
    }

    @Test
    public void testFormsPDFConfigTableCRUD( )
    {
        // Full CRUD test with injected DAO
    }

    @Test
    public void testFormsPDFTemplateTableCRUD( )
    {
        // Full CRUD test with injected DAO
    }
}
```

---

### 15. Template Updates

**manage_forms_pdf_templates.html**

- Changed from `@tform` with submit button to direct `@aButton` link
- Added `task_id` parameter to URLs for proper state management

**modify_forms_pdf_template.html**

- Added hidden `task_id` field
- Fixed checkbox label swap (noRTE/withRTE)

---

## Migration Checklist

| Category | Change Required |
|----------|-----------------|
| POM | Update parent POM to 8.0.0-SNAPSHOT, update all dependencies |
| Spring Context | Delete `*_context.xml`, add `META-INF/beans.xml` |
| Imports | Change `javax.servlet` to `jakarta.servlet` |
| TaskConfig | Add `@Dependent` and `@Named` |
| DAO | Add `@ApplicationScoped` and `@Named` |
| Task | Add `@Dependent`, `@Named`, use `@Inject` for services |
| TaskComponent | Add `@ApplicationScoped`, constructor injection |
| JspBean | Add `@RequestScoped`, `@Named`, inject `Models` |
| Home Classes | Replace `SpringContextService.getBean()` with `CDI.current().select()` |
| Producer | Create producer classes for TaskType and ConfigService |
| Properties | Add TaskType configuration properties |
| JSP | Replace `jsp:useBean` with EL expression |
| SQL | Add Liquibase headers, use `INT` instead of `INT(11)` |
| Plugin XML | Update `min-core-version` to 8.0.0 |
| Tests | Use JUnit 5 `@Test`, inject DAOs |

---

## Important Patterns

### Workflow Module CDI Pattern

1. **Task**: `@Dependent` + `@Named("module.task")`
2. **TaskConfig**: `@Dependent` + `@Named("module.taskConfig")`
3. **TaskConfigDAO**: `@ApplicationScoped` + `@Named("module.taskConfigDAO")`
4. **TaskComponent**: `@ApplicationScoped` + `@Named("module.taskComponent")` with constructor injection
5. **TaskType**: Produced via `@Produces` method with `@ConfigProperty` for externalized configuration
6. **ConfigService**: Produced via `@Produces` method

### Session State Removal

- JspBeans are now `@RequestScoped` instead of session-scoped
- State must be passed via request parameters
- Use `redirect()` with parameters map instead of `redirectView()`
