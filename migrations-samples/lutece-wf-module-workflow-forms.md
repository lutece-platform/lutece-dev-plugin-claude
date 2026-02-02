# Migration Analysis: lutece-wf-module-workflow-forms (v7 to v8)

## Overview

This document analyzes the migration differences between Lutece v7 (`develop` branch) and Lutece v8 (`develop_core8` branch) for the `lutece-wf-module-workflow-forms` module.

**Version Changes:**
- Module version: `2.3.4-SNAPSHOT` -> `3.0.0-SNAPSHOT`
- Parent POM: `6.0.0` -> `8.0.0-SNAPSHOT`
- lutece-core: `[7.0.0,)` -> `[8.0.0-SNAPSHOT,)`
- plugin-forms: `[2.4.2-SNAPSHOT,)` -> `[4.0.0-SNAPSHOT,)`
- plugin-workflow: `[5.3.0,)` -> `[7.0.0-SNAPSHOT,)`
- library-signrequest: `[2.0.5,)` -> `[4.0.0-SNAPSHOT,)`

**Summary of Changes:**
- 101 files changed, +1,435 lines / -573 lines
- Complete migration from Spring to CDI (Jakarta EE)
- javax.* to jakarta.* namespace migration
- Removal of Spring context XML configuration
- New CDI producer classes for beans
- Database schema updates for iteration support

---

## 1. Dependency Injection Migration (Spring -> CDI)

### 1.1 Package Imports Migration

All `javax.*` imports are replaced with `jakarta.*`:

```java
// Before (v7)
import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.HttpServletRequest;
import javax.validation.constraints.Min;
import javax.validation.constraints.NotNull;

// After (v8)
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.context.Dependent;
import jakarta.enterprise.context.RequestScoped;
import jakarta.enterprise.inject.Produces;
```

### 1.2 Spring Context File Removal

The entire `workflow-forms_context.xml` file (331 lines) is **deleted**. All bean definitions previously in this XML file are now handled via CDI annotations.

### 1.3 CDI beans.xml Addition

A new `META-INF/beans.xml` file is added:

```xml
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0" bean-discovery-mode="annotated">
</beans>
```

---

## 2. CDI Annotations on Classes

### 2.1 DAO Classes

All DAOs receive `@ApplicationScoped` and `@Named` annotations:

```java
// Example: CompleteFormResponseDAO.java
@ApplicationScoped
@Named( "worklow-forms.completeFormResponseDAO" )
public class CompleteFormResponseDAO implements ICompleteFormResponseDAO { }

// Example: ResubmitFormResponseDAO.java
@ApplicationScoped
@Named( "worklow-forms.resubmitFormResponseDAO" )
public class ResubmitFormResponseDAO implements IResubmitFormResponseDAO { }

// Example: EditFormResponseConfigDao.java
@ApplicationScoped
@Named( EditFormResponseConfigDao.BEAN_NAME )
public class EditFormResponseConfigDao implements ITaskConfigDAO<EditFormResponseConfig> {
    public static final String BEAN_NAME = "worklow-forms.editFormResponseConfigDao";
}
```

**All DAOs migrated:**
- `CompleteFormResponseDAO`
- `CompleteFormResponseTaskConfigDAO`
- `CompleteFormResponseTaskHistoryDAO`
- `CompleteFormResponseValueDAO`
- `DuplicateFormResponseTaskConfigDAO`
- `EditFormResponseConfigDao`
- `EditFormResponseConfigValueDao`
- `EditFormResponseTaskHistoryDAO`
- `FormResponseValueStateControllerConfigDao`
- `LinkedValuesFormResponseConfigDAO`
- `LinkedValuesFormResponseConfigValueDAO`
- `ModifyFormResponseUpdateStatusTaskConfigDAO`
- `ResubmitFormResponseDAO`
- `ResubmitFormResponseTaskConfigDAO`
- `ResubmitFormResponseTaskHistoryDAO`
- `ResubmitFormResponseValueDAO`

### 2.2 Service Classes

Services use `@ApplicationScoped` with `@Named`:

```java
// CompleteFormResponseService.java
@ApplicationScoped
@Named( "workflow-forms.taskCompleteResponseService" )
public class CompleteFormResponseService extends AbstractFormResponseService implements ICompleteFormResponseService { }

// ResubmitFormResponseService.java
@ApplicationScoped
@Named( "workflow-forms.taskResubmitResponseService" )
public class ResubmitFormResponseService extends AbstractFormResponseService implements IResubmitFormResponseService { }

// FormsTaskService.java
@ApplicationScoped
@Named( "workflow-forms.formsTaskService" )
public class FormsTaskService implements IFormsTaskService { }
```

### 2.3 Task Classes

Tasks use `@Dependent` scope (prototype equivalent):

```java
// CompleteFormResponseTask.java
@Dependent
@Named( "workflow-forms.completeFormResponseTask" )
public class CompleteFormResponseTask extends Task { }

// ResubmitFormResponseTask.java
@Dependent
@Named( "workflow-forms.resubmitFormResponseTask" )
public class ResubmitFormResponseTask extends Task { }

// DuplicateFormResponseTask.java
@Dependent
@Named( "workflow-forms.duplicateFormResponseTask" )
public class DuplicateFormResponseTask extends SimpleTask { }

// EditFormResponseTask.java
@Dependent
@Named( "workflow-forms.editFormResponseTask" )
public class EditFormResponseTask extends AbstractEditFormsTask { }

// EditFormResponseAutoUpdateTask.java
@Dependent
@Named( "workflow-forms.editFormResponseAutoUpdateTask" )
public class EditFormResponseAutoUpdateTask extends SimpleTask { }

// LinkedValuesFormResponseTask.java
@Dependent
@Named( "workflow-forms.linkedValuesFormResponseTask" )
public class LinkedValuesFormResponseTask extends SimpleTask { }

// ModifyFormResponseUpdateDateTask.java
@Dependent
@Named( "workflow-forms.modifyUpdateDateTask" )
public class ModifyFormResponseUpdateDateTask extends SimpleTask { }

// ModifyFormResponseUpdateStatusTask.java
@Dependent
@Named( "workflow-forms.modifyUpdateStatusTask" )
public class ModifyFormResponseUpdateStatusTask extends SimpleTask { }
```

### 2.4 Task Config Classes

Config objects use `@Dependent` scope:

```java
// CompleteFormResponseTaskConfig.java
@Dependent
@Named( "workflow-forms.completeFormResponseTaskConfig" )
public class CompleteFormResponseTaskConfig extends AbstractCompleteFormResponseTaskConfig { }

// ResubmitFormResponseTaskConfig.java
@Dependent
@Named( "workflow-forms.resubmitFormResponseTaskConfig" )
public class ResubmitFormResponseTaskConfig extends AbstractCompleteFormResponseTaskConfig { }

// DuplicateFormResponseTaskConfig.java
@Dependent
@Named( "workflow-forms.duplicateFormResponseTaskConfig" )
public class DuplicateFormResponseTaskConfig extends TaskConfig { }

// LinkedValuesFormResponseConfig.java
@Dependent
@Named( "workflow-forms.linkedValuesFormResponseConfig" )
public class LinkedValuesFormResponseConfig extends TaskConfig { }
```

### 2.5 XPage Applications

XPage apps use `@RequestScoped` with special naming convention:

```java
// CompleteFormResponseApp.java
@RequestScoped
@Named( "workflow-forms.xpage.workflow-complete-form" )
public class CompleteFormResponseApp extends AbstractFormResponseApp<CompleteFormResponse> { }

// ResubmitFormResponseApp.java
@RequestScoped
@Named( "workflow-forms.xpage.workflow-resubmit-form" )
public class ResubmitFormResponseApp extends AbstractFormResponseApp<ResubmitFormResponse> { }
```

**Note:** The `application-class` elements in `workflow-forms.xml` are removed as CDI handles bean discovery:

```xml
<!-- Before (v7) -->
<application>
    <application-id>workflow-resubmit-form</application-id>
    <application-class>fr.paris.lutece.plugins.workflow.modules.forms.web.ResubmitFormResponseApp</application-class>
</application>

<!-- After (v8) -->
<application>
    <application-id>workflow-resubmit-form</application-id>
</application>
```

### 2.6 Task Components

Task components use `@ApplicationScoped`:

```java
// CompleteFormResponseTaskComponent.java
@ApplicationScoped
@Named( "workflow-forms.completetFormResponseTaskComponent" )
public class CompleteFormResponseTaskComponent extends AbstractFormResponseTaskComponent { }

// ResubmitFormResponseTaskComponent.java
@ApplicationScoped
@Named( "workflow-forms.resubmitFormResponseTaskComponent" )
public class ResubmitFormResponseTaskComponent extends AbstractFormResponseTaskComponent { }

// EditFormResponseTaskComponent.java
@ApplicationScoped
@Named( "workflow-forms.editFormResponseTaskComponent" )
public class EditFormResponseTaskComponent extends AbstractFormResponseTaskComponent { }
```

---

## 3. CDI Producer Classes

### 3.1 TaskTypeProducer

A new `TaskTypeProducer` class creates `ITaskType` beans using `@ConfigProperty`:

```java
@ApplicationScoped
public class TaskTypeProducer {

    @Produces
    @ApplicationScoped
    @Named( "workflow-forms.completeFormResponseTypeTask" )
    public ITaskType produceCompleteFormResponseTypeTask(
            @ConfigProperty( name = "workflow-forms.completeFormResponseTypeTask.key" ) String key,
            @ConfigProperty( name = "workflow-forms.completeFormResponseTypeTask.titleI18nKey" ) String titleI18nKey,
            @ConfigProperty( name = "workflow-forms.completeFormResponseTypeTask.beanName" ) String beanName,
            @ConfigProperty( name = "workflow-forms.completeFormResponseTypeTask.configBeanName" ) String configBeanName,
            @ConfigProperty( name = "workflow-forms.completeFormResponseTypeTask.configRequired" ) boolean configRequired,
            @ConfigProperty( name = "workflow-forms.completeFormResponseTypeTask.formTaskRequired" ) boolean formTaskRequired,
            @ConfigProperty( name = "workflow-forms.completeFormResponseTypeTask.taskForAutomaticAction" ) boolean taskForAutomaticAction )
    {
        return buildTaskType( key, titleI18nKey, beanName, configBeanName, configRequired, formTaskRequired, taskForAutomaticAction );
    }

    // Similar producers for all task types...
}
```

### 3.2 TaskConfigServiceProducer

Creates `ITaskConfigService` beans with DAO injection:

```java
@ApplicationScoped
public class TaskConfigServiceProducer {

    @Produces
    @ApplicationScoped
    @Named( "workflow-forms.taskResubmitResponseConfigService" )
    public ITaskConfigService produceTaskResubmitResponseConfigService(
            @Named( "worklow-forms.taskResubmitFormResponseConfigDAO" ) ITaskConfigDAO<ResubmitFormResponseTaskConfig> dao )
    {
        TaskConfigService taskService = new TaskConfigService( );
        taskService.setTaskConfigDAO( (ITaskConfigDAO) dao );
        return taskService;
    }

    @Produces
    @ApplicationScoped
    @Named( "workflow-forms.taskCompleteResponseConfigService" )
    public ITaskConfigService produceTaskCompleteResponseConfigService(
            @Named( "worklow-forms.taskCompleteFormResponseConfigDAO" ) ITaskConfigDAO<CompleteFormResponseTaskConfig> dao )
    {
        TaskConfigService taskService = new TaskConfigService( );
        taskService.setTaskConfigDAO( (ITaskConfigDAO) dao );
        return taskService;
    }
}
```

### 3.3 AuthenticatorProducer (SignRequest)

Creates authenticator beans using property-based configuration:

```java
@ApplicationScoped
public class AuthenticatorProducer extends AbstractSignRequestAuthenticatorProducer {

    @Produces
    @ApplicationScoped
    @Named( "workflow-forms.resubmitFormResponseRequestAuthenticator" )
    public AbstractPrivateKeyAuthenticator produceResubmitFormResponseRequestAuthenticator( )
    {
        return (AbstractPrivateKeyAuthenticator) produceRequestAuthenticator( "workflow-forms.resubmitFormResponseRequestAuthenticator" );
    }

    @Produces
    @ApplicationScoped
    @Named( "workflow-forms.completeFormResponseRequestAuthenticator" )
    public AbstractPrivateKeyAuthenticator produceCompleteFormResponseRequestAuthenticator( )
    {
        return (AbstractPrivateKeyAuthenticator) produceRequestAuthenticator( "workflow-forms.completeFormResponseRequestAuthenticator" );
    }
}
```

### 3.4 EditFormResponseConfigProducer

Creates config beans with `@Dependent` scope:

```java
@ApplicationScoped
public class EditFormResponseConfigProducer {

    @Produces
    @Dependent
    @Named( "workflow-forms.editFormResponseConfig" )
    public EditFormResponseConfig produceEditFormResponseConfig( )
    {
        return new EditFormResponseConfig( );
    }

    @Produces
    @Dependent
    @Named( "workflow-forms.editFormResponseAutoUpdateConfig" )
    public EditFormResponseConfig produceEditFormResponseAutoUpdateConfig( )
    {
        return new EditFormResponseConfig( );
    }
}
```

---

## 4. Properties File Configuration

### 4.1 Task Type Configuration (New)

Task types are now configured via properties instead of Spring XML:

```properties
# workflow-forms.properties additions

# Task Type: modifyUpdateStatus
workflow-forms.modifyUpdateStatusTypeTask.key=modifyUpdateStatusTask
workflow-forms.modifyUpdateStatusTypeTask.titleI18nKey=module.workflow.forms.task.modifyUpdateStatus.title
workflow-forms.modifyUpdateStatusTypeTask.beanName=workflow-forms.modifyUpdateStatusTask
workflow-forms.modifyUpdateStatusTypeTask.configBeanName=workflow-forms.modifyFormResponseUpdateStatusTaskConfig
workflow-forms.modifyUpdateStatusTypeTask.configRequired=true
workflow-forms.modifyUpdateStatusTypeTask.formTaskRequired=true
workflow-forms.modifyUpdateStatusTypeTask.taskForAutomaticAction=true

# Task Type: editFormResponse
workflow-forms.editFormResponseTypeTask.key=editFormResponseTypeTask
workflow-forms.editFormResponseTypeTask.titleI18nKey=module.workflow.forms.task.editFormResponse.title
workflow-forms.editFormResponseTypeTask.beanName=workflow-forms.editFormResponseTask
workflow-forms.editFormResponseTypeTask.configBeanName=workflow-forms.editFormResponseConfig
workflow-forms.editFormResponseTypeTask.configRequired=true
workflow-forms.editFormResponseTypeTask.formTaskRequired=true
workflow-forms.editFormResponseTypeTask.taskForAutomaticAction=false

# ... similar for all other task types
```

### 4.2 SignRequest Configuration (New)

Authenticators are configured via properties:

```properties
# SignRequest configuration
workflow-forms.resubmitFormResponseRequestAuthenticator.name=signrequest.RequestHashAuthenticator
workflow-forms.resubmitFormResponseRequestAuthenticator.cfg.hashService=signrequest.Sha1HashService
workflow-forms.resubmitFormResponseRequestAuthenticator.cfg.signatureElements=id_history,id_task
workflow-forms.resubmitFormResponseRequestAuthenticator.cfg.privateKey=change me

workflow-forms.completeFormResponseRequestAuthenticator.name=signrequest.RequestHashAuthenticator
workflow-forms.completeFormResponseRequestAuthenticator.cfg.hashService=signrequest.Sha1HashService
workflow-forms.completeFormResponseRequestAuthenticator.cfg.signatureElements=id_history,id_task
workflow-forms.completeFormResponseRequestAuthenticator.cfg.privateKey=change me
```

### 4.3 Entry Type Configuration Change

```properties
# Before (v7) - using numeric IDs
task_linked_values_form_response_list_entry_id_type_available=101;102;105

# After (v8) - using bean names
task_linked_values_form_response_list_entry_id_type_available=forms.entryTypeRadioButton;forms.entryTypeCheckBox;forms.entryTypeSelect
```

---

## 5. Home Classes Migration (SpringContextService -> CDI)

### 5.1 CDI.current() Pattern

Home classes replace `SpringContextService.getBean()` with `CDI.current().select()`:

```java
// Before (v7) - EditFormResponseConfigValueHome.java
import fr.paris.lutece.portal.service.spring.SpringContextService;
private static IEditFormResponseConfigValueDao _dao = SpringContextService.getBean( EditFormResponseConfigValueDao.BEAN_NAME );

// After (v8)
import jakarta.enterprise.inject.spi.CDI;
private static IEditFormResponseConfigValueDao _dao = CDI.current( ).select( IEditFormResponseConfigValueDao.class ).get( );
```

### 5.2 CdiHelper Pattern

Static service accessors use `CdiHelper`:

```java
// Before (v7) - ResubmitFormResponseRequestAuthenticatorService.java
import fr.paris.lutece.portal.service.spring.SpringContextService;
public static AbstractPrivateKeyAuthenticator getRequestAuthenticator( )
{
    return SpringContextService.getBean( BEAN_RESUBMIT_FORM_REQUEST_AUTHENTICATOR );
}

// After (v8)
import fr.paris.lutece.portal.service.util.CdiHelper;
public static AbstractPrivateKeyAuthenticator getRequestAuthenticator( )
{
    return CdiHelper.getReference( AbstractPrivateKeyAuthenticator.class, BEAN_RESUBMIT_FORM_REQUEST_AUTHENTICATOR );
}
```

---

## 6. Constructor Injection Pattern

### 6.1 Task Components with Constructor Injection

Components receive `ITaskType` and `ITaskConfigService` via constructor:

```java
// CompleteFormResponseTaskComponent.java
@Inject
public CompleteFormResponseTaskComponent(
        @Named( "workflow-forms.completeFormResponseTypeTask" ) ITaskType taskType,
        @Named( "workflow-forms.taskCompleteResponseConfigService" ) ITaskConfigService taskConfigService )
{
    setTaskType( taskType );
    setTaskConfigService( taskConfigService );
}

// EditFormResponseTaskComponent.java
@Inject
public EditFormResponseTaskComponent(
        IFormsTaskService formsTaskService,
        IEditFormResponseTaskService editFormResponseTaskService,
        IEditFormResponseTaskHistoryService editFormResponseTaskHistoryService,
        @Named( "workflow-forms.editFormResponseTypeTask" ) ITaskType taskType,
        @Named( "workflow-forms.editFormResponseConfigService" ) ITaskConfigService taskConfigService )
{
    _formsTaskService = formsTaskService;
    _editFormResponseTaskService = editFormResponseTaskService;
    _editFormResponseTaskHistoryService = editFormResponseTaskHistoryService;
    setTaskType( taskType );
    setTaskConfigService( taskConfigService );
}
```

### 6.2 Task Info Providers with Constructor Injection

```java
// CompleteFormResponseTaskInfoProvider.java
@ApplicationScoped
@Named( "workflow-forms.completeFormResponseTaskInfoProvider" )
public class CompleteFormResponseTaskInfoProvider extends AbstractCompleteFormResponseTaskInfoProvider {

    @Inject
    public CompleteFormResponseTaskInfoProvider( @Named( "workflow-forms.completeFormResponseTypeTask" ) ITaskType taskType )
    {
        setTaskType( taskType );
    }
}
```

### 6.3 Config Services with Constructor Injection

```java
// EditFormResponseConfigService.java
@ApplicationScoped
@Named( "workflow-forms.editFormResponseConfigService" )
public class EditFormResponseConfigService extends TaskConfigService {

    @Inject
    public EditFormResponseConfigService(
            @Named( "worklow-forms.editFormResponseConfigDao" ) ITaskConfigDAO<EditFormResponseConfig> editFormResponseConfigDAO )
    {
        setTaskConfigDAO( (ITaskConfigDAO) editFormResponseConfigDAO );
    }
}
```

---

## 7. Database Schema Changes

### 7.1 Iteration Number Support

New column `iteration_number` added to response value tables:

```sql
-- update_db_workflow_forms-2.3.3-2.3.4.sql (new file)
ALTER TABLE workflow_task_resubmit_response_value ADD COLUMN iteration_number int default 0;
ALTER TABLE workflow_task_resubmit_response_value DROP PRIMARY KEY;
ALTER TABLE workflow_task_resubmit_response_value ADD PRIMARY KEY (id_history, id_entry, iteration_number);

ALTER TABLE workflow_task_complete_response_value ADD COLUMN iteration_number int default 0;
ALTER TABLE workflow_task_complete_response_value DROP PRIMARY KEY;
ALTER TABLE workflow_task_complete_response_value ADD PRIMARY KEY (id_history, id_entry, iteration_number);
```

### 7.2 Liquibase Headers

All SQL files receive Liquibase headers:

```sql
-- liquibase formatted sql
-- changeset workflow-forms:create_db_workflow-forms.sql
-- preconditions onFail:MARK_RAN onError:WARN
```

---

## 8. Business Logic Enhancements

### 8.1 Iteration Number in Value Objects

`AbstractCompleteFormResponseValue` gets iteration support:

```java
public abstract class AbstractCompleteFormResponseValue {

    public static final int DEFAULT_ITERATION_NUMBER = NumberUtils.INTEGER_MINUS_ONE;

    private int _nIdHistory;
    private int _nIdEntry;
    private int _nIterationNumber = DEFAULT_ITERATION_NUMBER;

    public int getIterationNumber( ) { return _nIterationNumber; }
    public void setIterationNumber( int nIterationNumber ) { _nIterationNumber = nIterationNumber; }
}
```

### 8.2 Form Response Validation

New validation methods in `FormsTaskService`:

```java
@Override
public List<FormQuestionResponse> getSubmittedFormQuestionResponses( HttpServletRequest request, FormResponse formResponse, List<Question> listQuestions )
{
    List<FormQuestionResponse> submittedFormResponses = new ArrayList<>( );
    for ( Question question : listQuestions )
    {
        IEntryDataService entryDataService = EntryServiceManager.getInstance( ).getEntryDataService( question.getEntry( ).getEntryType( ) );
        FormQuestionResponse responseFromForm = entryDataService.createResponseFromRequest( question, request, false );
        responseFromForm.setIdFormResponse( formResponse.getId( ) );
        submittedFormResponses.add( responseFromForm );
    }
    return submittedFormResponses;
}

@Override
public boolean areFormQuestionResponsesValid( List<FormQuestionResponse> listFormQuestionResponse )
{
    boolean areAllResponsesValid = Boolean.TRUE;
    for ( FormQuestionResponse formQuestionResponse : listFormQuestionResponse )
    {
        if ( !isResponseValid( formQuestionResponse ) )
        {
            areAllResponsesValid = Boolean.FALSE;
        }
    }
    return areAllResponsesValid;
}
```

### 8.3 Task Entry ID Parsing Change

Entry IDs now include iteration number:

```java
// Before (v7) - CompleteFormResponseTask.java
for ( String strIdEntry : listIdsEntry )
{
    if ( StringUtils.isNotBlank( strIdEntry ) && StringUtils.isNumeric( strIdEntry ) )
    {
        int nIdEntry = Integer.parseInt( strIdEntry );
        CompleteFormResponseValue editRecordValue = new CompleteFormResponseValue( );
        editRecordValue.setIdEntry( nIdEntry );
        listCompleteFormResponseValues.add( editRecordValue );
    }
}

// After (v8) - Format: "entryId_iterationNumber"
for ( String strIdEntry : listIdsEntry )
{
    if ( StringUtils.isNotBlank( strIdEntry ) )
    {
        String[] idEntryNIter = strIdEntry.split( "_" );
        if( idEntryNIter.length == 2 && StringUtils.isNumeric( idEntryNIter[0] ) && StringUtils.isNumeric( idEntryNIter[1] ))
        {
            CompleteFormResponseValue editRecordValue = new CompleteFormResponseValue( );
            editRecordValue.setIdEntry( Integer.parseInt( idEntryNIter[0] ) );
            editRecordValue.setIterationNumber( Integer.parseInt( idEntryNIter[1] ) );
            listCompleteFormResponseValues.add( editRecordValue );
        }
    }
}
```

---

## 9. Template Changes

### 9.1 Form Action Name Change

```html
<!-- Before (v7) -->
<input type="hidden" name="action" value="do_modify_response" />

<!-- After (v8) -->
<input type="hidden" name="action" value="doEditResponse" />
```

### 9.2 Iteration Display Support

Templates updated to show iteration numbers:

```html
<!-- Before (v7) -->
<#list list_entries as entry>
    <b>${entry.title}</b>
    <!-- ... -->
</#list>

<!-- After (v8) -->
<#list edit_response.listCompleteReponseValues as reponseValues>
    <#list list_entries as entry>
        <#if reponseValues.idEntry==entry.idEntry>
            <b>${entry.title} <#if reponseValues.iterationNumber &gt; 0>(${reponseValues.iterationNumber+1})</#if></b>
            <!-- ... -->
        </#if>
    </#list>
</#list>
```

---

## 10. File Service Migration

### 10.1 DuplicateFormResponseTask

```java
// Before (v7)
import fr.paris.lutece.portal.service.file.FileService;
file = FileService.getInstance( ).getFileStoreServiceProvider( ).getFile( strFileKey );

// After (v8)
import fr.paris.lutece.portal.service.file.IFileStoreServiceProvider;

@Inject
@Named( "defaultDatabaseFileStoreProvider" )
private IFileStoreServiceProvider _fileStoreService;

file = _fileStoreService.getFile( strFileKey );
```

---

## 11. Workflow Module-Specific Patterns Summary

| Pattern | v7 (Spring) | v8 (CDI) |
|---------|-------------|----------|
| Task class scope | `scope="prototype"` in XML | `@Dependent` |
| Service scope | Singleton in XML | `@ApplicationScoped` |
| DAO scope | Singleton in XML | `@ApplicationScoped` |
| XPage scope | Per-request | `@RequestScoped` |
| Config object scope | `scope="prototype"` in XML | `@Dependent` |
| Task type config | XML bean properties | `@ConfigProperty` + properties file |
| Task component injection | XML `p:taskType-ref` | Constructor injection with `@Named` |
| SignRequest config | XML bean with properties | Producer + properties file |

---

## 12. Migration Checklist for Workflow Modules

1. **Add CDI beans.xml** - Create `META-INF/beans.xml` with version 4.0
2. **Delete Spring context XML** - Remove `*_context.xml` file
3. **Replace imports** - `javax.*` -> `jakarta.*`
4. **Annotate DAOs** - `@ApplicationScoped` + `@Named`
5. **Annotate Services** - `@ApplicationScoped` + `@Named`
6. **Annotate Tasks** - `@Dependent` + `@Named`
7. **Annotate Task Configs** - `@Dependent` + `@Named`
8. **Annotate XPages** - `@RequestScoped` + `@Named("module.xpage.page-id")`
9. **Annotate Task Components** - `@ApplicationScoped` + `@Named`
10. **Create TaskTypeProducer** - For all task types with `@ConfigProperty`
11. **Create TaskConfigServiceProducer** - For all config services
12. **Update properties file** - Add task type configurations
13. **Update Home classes** - `SpringContextService.getBean()` -> `CDI.current().select()`
14. **Add constructor injection** - For task components with `ITaskType` and `ITaskConfigService`
15. **Update plugin XML** - Remove `<application-class>` elements
16. **Add Liquibase headers** - To all SQL files
