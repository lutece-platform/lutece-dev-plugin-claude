# Migration Analysis: lutece-wf-module-workflow-forms-automatic-assignment

## Overview

Migration from Lutece v7 (develop) to Lutece v8 (develop_core8) for the module `workflow-forms-automatic-assignment`.

**Version Change:** `2.1.1-SNAPSHOT` -> `3.0.0-SNAPSHOT`

## Summary of Changes

| Category | Files Changed | Description |
|----------|--------------|-------------|
| POM | 1 | Parent POM and dependencies upgrade |
| Java | 12 | CDI migration, javax to jakarta, API changes |
| Configuration | 3 | Spring context removed, beans.xml added, properties updated |
| SQL | 2 | Schema changes (position -> code) |
| Templates | 1 | Parameter name changes |
| JSP | 4 | EL expression syntax migration |
| Properties | 1 | Encoding fixes and entry types configuration |

---

## 1. POM Changes

### Parent POM
```xml
<!-- Before -->
<parent>
    <artifactId>lutece-global-pom</artifactId>
    <groupId>fr.paris.lutece.tools</groupId>
    <version>5.2.0</version>
</parent>

<!-- After -->
<parent>
    <artifactId>lutece-global-pom</artifactId>
    <groupId>fr.paris.lutece.tools</groupId>
    <version>8.0.0-SNAPSHOT</version>
</parent>
```

### Dependencies Update
| Dependency | v7 Version | v8 Version |
|------------|-----------|-----------|
| lutece-core | [7.0.0,) | [8.0.0-SNAPSHOT,) |
| plugin-workflow | [5.3.0,) | [7.0.0-SNAPSHOT,) |
| plugin-forms | [2.4.0,) | [4.0.0-SNAPSHOT,) |

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

## 2. Java Migration

### 2.1 Package Migration (javax -> jakarta)

All Java files have been migrated from `javax` to `jakarta`:

```java
// Before
import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.HttpServletRequest;
import javax.validation.constraints.Min;
import javax.validation.constraints.NotNull;
import org.springframework.transaction.annotation.Transactional;

// After
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.transaction.Transactional;
```

### 2.2 CDI Annotations Added

#### DAOs

**AutomaticAssignmentDAO.java**
```java
@ApplicationScoped
@Named( AutomaticAssignmentDAO.BEAN_NAME )
public class AutomaticAssignmentDAO implements IAutomaticAssignmentDAO
```

**TaskAutomaticAssignmentConfigDAO.java**
```java
@ApplicationScoped
@Named( "workflow-formsautomaticassignment.taskAutomaticAssignmentConfigDAO" )
public class TaskAutomaticAssignmentConfigDAO implements ITaskAutomaticAssignmentConfigDAO
```

#### Services

**AutomaticAssignmentService.java**
```java
// Before: final class with private constructor (singleton pattern)
public final class AutomaticAssignmentService implements IAutomaticAssignmentService {
    private AutomaticAssignmentService() { }
}

// After: CDI managed bean
@ApplicationScoped
@Named( AutomaticAssignmentService.BEAN_SERVICE )
public class AutomaticAssignmentService implements IAutomaticAssignmentService {
    public AutomaticAssignmentService() { }
}
```

**TaskAutomaticAssignmentConfigService.java**
```java
@ApplicationScoped
@Named( TaskAutomaticAssignmentConfigService.BEAN_SERVICE )
public class TaskAutomaticAssignmentConfigService extends TaskConfigService {

    @Inject
    public TaskAutomaticAssignmentConfigService(
        @Named( "workflow-formsautomaticassignment.taskAutomaticAssignmentConfigDAO" )
        ITaskConfigDAO<TaskAutomaticAssignmentConfig> taskAutomaticAssignmentConfigDAO) {
        setTaskConfigDAO( (ITaskConfigDAO) taskAutomaticAssignmentConfigDAO );
    }
}
```

#### Tasks & Components

**TaskAutomaticAssignment.java**
```java
@Dependent
@Named( "workflow-formsautomaticassignment.taskAutomaticAssignment" )
public class TaskAutomaticAssignment extends SimpleTask
```

**TaskAutomaticAssignmentConfig.java**
```java
@Dependent
@Named( "workflow-formsautomaticassignment.taskAutomaticAssignmentConfig" )
public class TaskAutomaticAssignmentConfig extends TaskConfig
```

**AutomaticAssignmentTaskComponent.java**
```java
@ApplicationScoped
@Named( "workflow-formsautomaticassignment.automaticAssignmentTaskComponent" )
public class AutomaticAssignmentTaskComponent extends NoFormTaskComponent {

    @Inject
    public AutomaticAssignmentTaskComponent(
        @Named( "workflow-formsautomaticassignment.taskTypeAutomaticAssignment" ) ITaskType taskType,
        @Named( "workflow-formsautomaticassignment.taskAutomaticAssignmentConfigService" ) ITaskConfigService taskConfigService ) {
        setTaskType( taskType );
        setTaskConfigService( taskConfigService );
    }
}
```

**AutomaticAssignmentJspBean.java**
```java
@RequestScoped
@Named
public class AutomaticAssignmentJspBean extends PluginAdminPageJspBean {

    @Inject
    private IAutomaticAssignmentService _automaticAssignmentService;

    @Inject
    @Named( TaskAutomaticAssignmentConfigService.BEAN_SERVICE )
    private ITaskConfigService _taskAutomaticAssignmentConfigService;
}
```

### 2.3 New Producer Class

**TaskAutomaticTypeProducer.java** (NEW FILE)
```java
@ApplicationScoped
public class TaskAutomaticTypeProducer {

    @Produces
    @ApplicationScoped
    @Named( "workflow-formsautomaticassignment.taskTypeAutomaticAssignment" )
    public ITaskType produceTaskTypeAutomaticAssignment(
        @ConfigProperty( name = "workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.key" ) String key,
        @ConfigProperty( name = "workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.titleI18nKey" ) String titleI18nKey,
        @ConfigProperty( name = "workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.beanName" ) String beanName,
        @ConfigProperty( name = "workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.configBeanName" ) String configBeanName,
        @ConfigProperty( name = "workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.configRequired", defaultValue = "false" ) boolean configRequired,
        @ConfigProperty( name = "workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.taskForAutomaticAction", defaultValue = "false" ) boolean taskForAutomaticAction ) {

        TaskType taskType = new TaskType();
        taskType.setKey( key );
        taskType.setTitleI18nKey( titleI18nKey );
        taskType.setBeanName( beanName );
        taskType.setConfigBeanName( configBeanName );
        taskType.setConfigRequired( configRequired );
        taskType.setTaskForAutomaticAction( taskForAutomaticAction );
        return taskType;
    }
}
```

### 2.4 Transaction Annotation Changes

```java
// Before
@Transactional( AutomaticAssignmentPlugin.BEAN_TRANSACTION_MANAGER )
public void create( ... )

// After
@Transactional
public void create( ... )
```

### 2.5 API Changes: Position -> Code

A significant API change where entry file references changed from position (Integer) to code (String):

**ITaskAutomaticAssignmentConfigDAO.java**
```java
// Before
List<Integer> loadListPositionsEntryFile( int nIdTask );
void deleteListPositionsEntryFile( int nIdTask );
void insertListPositionsEntryFile( int nIdTask, Integer nPositionEntryFile );

// After
List<String> loadListCodesEntryFile( int nIdTask );
void deleteListCodesEntryFile( int nIdTask );
void insertListCodesEntryFile( int nIdTask, String nCodeEntryFile );
```

**TaskAutomaticAssignmentConfig.java**
```java
// Before
private List<Integer> _listPositionsQuestionFile;
public List<Integer> getListPositionsQuestionFile()
public void setListPositionsQuestionFile( List<Integer> listPositionsEntryFile )

// After
private List<String> _listCodesQuestionFile;
public List<String> getListCodesQuestionFile()
public void setListCodesQuestionFile( List<String> listCodesEntryFile )
```

**AutomaticAssignmentService.java**
```java
// Before - filtering by entry type ID
List<Integer> listIdTypesAuthorized = fillListEntryTypes( PROPERTY_ENTRIES_TYPE_ALLOWED );
return getAllQuestions( nIdTask ).stream()
    .filter( x -> listIdTypesAuthorized.contains( x.getEntry().getEntryType().getIdType() ) )

// After - filtering by entry type bean name
List<String> listIdTypesAuthorized = fillListEntryTypes( PROPERTY_ENTRIES_TYPE_ALLOWED );
return getAllQuestions( nIdTask ).stream()
    .filter( x -> listIdTypesAuthorized.contains( x.getEntry().getEntryType().getBeanName() ) )

// Before - matching by position
if ( formQuestionResponse.getQuestion().getEntry().getPosition() == nPosition ... )

// After - matching by code
if ( formQuestionResponse.getQuestion().getEntry().getCode().equals( nCode ) ... )
```

---

## 3. Configuration Changes

### 3.1 Spring Context Removed

**DELETED:** `webapp/WEB-INF/conf/plugins/workflow-formsautomaticassignment_context.xml`

The entire Spring context file has been removed. All bean definitions are now handled via CDI annotations.

### 3.2 CDI beans.xml Added

**NEW:** `src/main/resources/META-INF/beans.xml`
```xml
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0" bean-discovery-mode="annotated">
</beans>
```

### 3.3 Properties Configuration Updated

**File:** `webapp/WEB-INF/conf/plugins/workflow-formsautomaticassignment.properties`

```properties
# Before - Entry types by ID
workflow-forms-automatic-assignment.entriesTypeFiles=108,110
workflow-forms-automatic-assignment.entriesTypeAllowed=101,102,105

# After - Entry types by bean name
workflow-forms-automatic-assignment.entriesTypeFiles=forms.entryTypeFile,forms.entryTypeImage
workflow-forms-automatic-assignment.entriesTypeAllowed=forms.entryTypeRadioButton,forms.entryTypeCheckBox,forms.entryTypeSelect

# NEW - TaskType configuration for CDI Producer
workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.key=taskAutomaticAssignment
workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.titleI18nKey=module.workflow.formsautomaticassignment.task_title
workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.beanName=workflow-formsautomaticassignment.taskAutomaticAssignment
workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.configBeanName=workflow-formsautomaticassignment.taskAutomaticAssignmentConfig
workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.configRequired=true
workflow-forms-automatic-assignment.taskTypeAutomaticAssignment.taskForAutomaticAction=true
```

---

## 4. Database Schema Changes

### 4.1 Create Script Updated

**File:** `create_db_workflow_forms_automatic_assignment.sql`

```sql
-- Before
CREATE TABLE workflow_forms_auto_assignment_ef(
  id_task INT DEFAULT NULL,
  position_form_question_file INT DEFAULT NULL,
  PRIMARY KEY (id_task, position_form_question_file)
);

-- After
CREATE TABLE workflow_forms_auto_assignment_ef(
  id_task INT NOT NULL,
  code_form_question_file varchar(100) NOT NULL,
  PRIMARY KEY (id_task, code_form_question_file)
);
```

**Liquibase header added:**
```sql
-- liquibase formatted sql
-- changeset workflow-formsautomaticassignment:create_db_workflow_forms_automatic_assignment.sql
-- preconditions onFail:MARK_RAN onError:WARN
```

### 4.2 Upgrade Script Added

**NEW:** `update_db_workflow_forms_automatic_assignment-2.1.1-3.0.0.sql`

```sql
-- liquibase formatted sql
-- changeset workflow-formsautomaticassignment:update_db_workflow_forms_automatic_assignment-2.1.1-3.0.0.sql
-- preconditions onFail:MARK_RAN onError:WARN
DROP TABLE IF EXISTS workflow_forms_auto_assignment_ef;

CREATE TABLE workflow_forms_auto_assignment_ef(
  id_task INT NOT NULL,
  code_form_question_file varchar(100) NOT NULL,
  PRIMARY KEY (id_task, code_form_question_file)
);
```

---

## 5. Template Changes

**File:** `task_config.html`

```html
<!-- Before -->
<@checkBox ... name='list_position_question_file_checked' ... value='${question.entry.position}'
    checked=( config.listPositionsQuestionFile?? && config.listPositionsQuestionFile?has_content && isSelected( question.entry.position, config.listPositionsQuestionFile )) />

<!-- After -->
<@checkBox ... name='list_code_question_file_checked' ... value='${question.entry.code}'
    checked=( config.listCodesQuestionFile?? && config.listCodesQuestionFile?has_content && isSelected( question.entry.code, config.listCodesQuestionFile )) />
```

---

## 6. JSP Migration

All JSP files migrated from scriptlet-based `jsp:useBean` to EL expression syntax:

**Example: DeleteAssignment.jsp**
```jsp
<!-- Before -->
<jsp:useBean id="workflowAutomaticAssignment" scope="session"
    class="fr.paris.lutece.plugins.workflow.modules.formsautomaticassignment.web.AutomaticAssignmentJspBean" />
<%
    workflowAutomaticAssignment.init( request, WorkflowJspBean.RIGHT_MANAGE_WORKFLOW);
    response.sendRedirect( workflowAutomaticAssignment.doDeleteAssignment(request) );
%>

<!-- After -->
${ automaticAssignmentJspBean.init( pageContext.request, WorkflowJspBean.RIGHT_MANAGE_WORKFLOW ) }
${ pageContext.response.sendRedirect( automaticAssignmentJspBean.doDeleteAssignment( pageContext.request ) ) }
```

**Files Updated:**
- `DeleteAssignment.jsp`
- `DoAddAutomaticAssignment.jsp`
- `DoUpdateDirectory.jsp`
- `ModifyQuestionAssignment.jsp`

---

## 7. Test Migration

**File:** `AutomaticAssignmentBusinessTest.java`

```java
// Before
import fr.paris.lutece.portal.service.spring.SpringContextService;

@Override
protected void setUp() throws Exception {
    super.setUp();
    _dao = SpringContextService.getBean( AutomaticAssignmentDAO.BEAN_NAME );
    _plugin = PluginService.getPlugin( WorkflowPlugin.PLUGIN_NAME );
}

// After
import jakarta.inject.Inject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@Inject
private IAutomaticAssignmentDAO _dao;

@BeforeEach
protected void setUp() throws Exception {
    super.setUp();
    _plugin = PluginService.getPlugin( WorkflowPlugin.PLUGIN_NAME );
}

@Test
public void testCRUD() { ... }
```

---

## 8. Key Migration Patterns

### Pattern 1: Service Injection
```java
// v7 - Spring injection
private IAutomaticAssignmentService _service = SpringContextService.getBean( AutomaticAssignmentService.BEAN_SERVICE );

// v8 - CDI injection
@Inject
private IAutomaticAssignmentService _service;
```

### Pattern 2: Named Bean with Qualifier
```java
// v7 - Spring
@Autowired
@Qualifier("beanName")
private IService _service;

// v8 - CDI
@Inject
@Named("beanName")
private IService _service;
```

### Pattern 3: Prototype/Dependent Scope
```java
// v7 - Spring prototype
<bean id="..." class="..." scope="prototype" />

// v8 - CDI dependent
@Dependent
@Named("...")
public class ...
```

### Pattern 4: TaskType Configuration via Producer
```java
// v7 - Spring XML bean definition
<bean id="..." class="fr.paris.lutece.plugins.workflowcore.business.task.TaskType"
    p:key="..."
    p:titleI18nKey="..."
    p:beanName="..." />

// v8 - CDI Producer with ConfigProperty
@Produces
@ApplicationScoped
@Named("...")
public ITaskType produceTaskType(
    @ConfigProperty( name = "...key" ) String key,
    @ConfigProperty( name = "...titleI18nKey" ) String titleI18nKey,
    @ConfigProperty( name = "...beanName" ) String beanName, ... )
```

---

## 9. Breaking Changes Summary

| Change | Impact | Migration Required |
|--------|--------|-------------------|
| Position -> Code | Database schema change | Yes - run upgrade SQL |
| Entry type ID -> Bean name | Configuration change | Update properties file |
| Spring -> CDI | Complete IoC change | Replace all Spring annotations |
| javax -> jakarta | Package rename | Update all imports |
| Transaction manager | Simplified | Remove transaction manager reference |

---

## 10. Files Summary

### Modified Files (22)
- `pom.xml`
- `business/AutomaticAssignmentDAO.java`
- `business/ITaskAutomaticAssignmentConfigDAO.java`
- `business/TaskAutomaticAssignmentConfig.java`
- `business/TaskAutomaticAssignmentConfigDAO.java`
- `service/AutomaticAssignmentService.java`
- `service/IAutomaticAssignmentService.java`
- `service/TaskAutomaticAssignment.java`
- `service/TaskAutomaticAssignmentConfigService.java`
- `web/AutomaticAssignmentJspBean.java`
- `web/AutomaticAssignmentTaskComponent.java`
- `resources/formsautomaticassignment_messages_fr.properties`
- `sql/.../create_db_workflow_forms_automatic_assignment.sql`
- `test/.../AutomaticAssignmentBusinessTest.java`
- `conf/plugins/workflow-formsautomaticassignment.properties`
- `plugins/workflow_forms_automatic_assignment.xml`
- `templates/.../task_config.html`
- `jsp/.../DeleteAssignment.jsp`
- `jsp/.../DoAddAutomaticAssignment.jsp`
- `jsp/.../DoUpdateDirectory.jsp`
- `jsp/.../ModifyQuestionAssignment.jsp`

### New Files (3)
- `service/TaskAutomaticTypeProducer.java`
- `src/main/resources/META-INF/beans.xml`
- `sql/.../upgrade/update_db_workflow_forms_automatic_assignment-2.1.1-3.0.0.sql`

### Deleted Files (1)
- `webapp/WEB-INF/conf/plugins/workflow-formsautomaticassignment_context.xml`
