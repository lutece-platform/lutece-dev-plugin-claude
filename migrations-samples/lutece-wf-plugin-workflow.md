# Lutece Workflow Plugin Migration Analysis (v7 to v8)

## Summary

This document analyzes the migration changes between Lutece v7 (branch `develop`) and Lutece v8 (branch `develop_core8`) for the `lutece-wf-plugin-workflow` plugin.

**Key Changes:**
- 230 files modified
- Spring XML configuration replaced by CDI annotations
- javax.* packages migrated to jakarta.*
- New CDI producers pattern for TaskTypes and TaskConfigServices
- Spring @Transactional replaced by Jakarta @Transactional

---

## 1. pom.xml Changes

### Version Updates

| Dependency | v7 | v8 |
|------------|-----|-----|
| lutece-global-pom | 6.0.0 | 8.0.0-SNAPSHOT |
| plugin-workflow | 6.0.4-SNAPSHOT | 7.0.0-SNAPSHOT |
| lutece-core | [7.0.0,) | 8.0.0-SNAPSHOT |
| library-workflow-core | [3.0.2,) | 4.0.0-SNAPSHOT |
| plugin-mermaidjs | [1.0.0,) | [2.0.0-SNAPSHOT,) |

### New Dependencies

```xml
<!-- JUnit -->
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

### Repository URLs Changed to HTTPS

```xml
<!-- Before -->
<url>http://dev.lutece.paris.fr/maven_repository</url>

<!-- After -->
<url>https://dev.lutece.paris.fr/maven_repository</url>
```

---

## 2. javax to jakarta Migration

### Package Replacements

| v7 (javax) | v8 (jakarta) |
|------------|--------------|
| `javax.inject.Inject` | `jakarta.inject.Inject` |
| `javax.inject.Named` | `jakarta.inject.Named` |
| `javax.servlet.http.HttpServletRequest` | `jakarta.servlet.http.HttpServletRequest` |
| `javax.validation.constraints.Min` | `jakarta.validation.constraints.Min` |
| `javax.validation.constraints.NotNull` | `jakarta.validation.constraints.NotNull` |

### Transaction Annotation Migration

**Before (Spring):**
```java
import org.springframework.transaction.annotation.Transactional;

@Transactional( "workflow.transactionManager" )
public void create( CommentValue commentValue, Plugin plugin )
```

**After (Jakarta):**
```java
import jakarta.transaction.Transactional;

@Transactional
public void create( CommentValue commentValue, Plugin plugin )
```

---

## 3. Spring to CDI Migration

### 3.1 Spring Context XML Removal

The file `webapp/WEB-INF/conf/plugins/workflow_context.xml` (319 lines) has been **completely removed**. All bean definitions are now handled via CDI annotations.

### 3.2 New beans.xml Added

```xml
<!-- src/main/resources/META-INF/beans.xml -->
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0" bean-discovery-mode="annotated">
</beans>
```

### 3.3 SpringContextService to CDI Migration

**Before (Spring):**
```java
import fr.paris.lutece.portal.service.spring.SpringContextService;

IWorkflowService _workflowService = SpringContextService.getBean( WorkflowService.BEAN_SERVICE );
List<IResourceArchiver> archiverList = SpringContextService.getBeansOfType( IResourceArchiver.class );
```

**After (CDI):**
```java
import jakarta.enterprise.inject.literal.NamedLiteral;
import jakarta.enterprise.inject.spi.CDI;

IWorkflowService _workflowService = CDI.current( ).select( IWorkflowService.class, NamedLiteral.of( WorkflowService.BEAN_SERVICE ) ).get( );
List<IResourceArchiver> archiverList = CDI.current( ).select( IResourceArchiver.class ).stream( ).toList( );
```

---

## 4. DAO Pattern Changes

### CDI Annotations Added to DAOs

All DAO classes now have CDI annotations:

**Before:**
```java
public class ActionDAO implements IActionDAO
{
    // ...
}
```

**After:**
```java
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Named;

@ApplicationScoped
@Named( "workflow.actionDAO" )
public class ActionDAO implements IActionDAO
{
    // ...
}
```

### List of Migrated DAOs

| DAO Class | Bean Name |
|-----------|-----------|
| `ActionDAO` | `workflow.actionDAO` |
| `ActionStateDAO` | `workflow.actionStateDAO` |
| `IconDAO` | `workflow.iconDAO` |
| `PrerequisiteDAO` | `PrerequisiteDAO.BEAN_NAME` |
| `ResourceHistoryDAO` | `workflow.resourceHistoryDAO` |
| `ResourceUserHistoryDAO` | `workflow.resourceUserHistoryDAO` |
| `ResourceWorkflowDAO` | `workflow.resourceWorkflowDAO` |
| `StateDAO` | `workflow.stateDAO` |
| `TaskDAO` | `workflow.taskDAO` |
| `WorkflowDAO` | `worklow.workflowDAO` |

---

## 5. Service Pattern Changes

### 5.1 New Service Implementation Classes

In v8, abstract service classes from `library-workflow-core` require concrete implementations with CDI annotations:

**New files created:**
- `ActionServiceImpl.java`
- `ActionStateServiceImpl.java`
- `IconServiceImpl.java`
- `ResourceHistoryServiceImpl.java`
- `ResourceWorkflowServiceImpl.java`
- `StateServiceImpl.java`
- `TaskServiceImpl.java`
- `WorkflowServiceImpl.java`

**Example pattern:**
```java
package fr.paris.lutece.plugins.workflow.service;

import fr.paris.lutece.plugins.workflowcore.service.action.ActionService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Named;

@ApplicationScoped
@Named( ActionService.BEAN_SERVICE )
public class ActionServiceImpl extends ActionService
{
    // Empty class - just provides CDI annotations for parent
}
```

### 5.2 Service Class Annotations

**Before:**
```java
public class CommentValueService implements ICommentValueService
{
    @Inject
    private ICommentValueDAO _dao;
}
```

**After:**
```java
@ApplicationScoped
@Named( CommentValueService.BEAN_SERVICE )
public class CommentValueService implements ICommentValueService
{
    @Inject
    private ICommentValueDAO _dao;
}
```

---

## 6. Workflow-Specific Changes

### 6.1 Task Type Configuration via Properties File

**New file: `webapp/WEB-INF/conf/plugins/workflow-tasks.properties`**

Task types are now configured via MicroProfile Config properties instead of Spring beans:

```properties
## Tasks types
workflow.taskTypeComment.key=taskTypeComment
workflow.taskTypeComment.titleI18nKey=module.workflow.comment.task_title
workflow.taskTypeComment.beanName=workflow.taskComment
workflow.taskTypeComment.configBeanName=workflow.taskCommentConfig
workflow.taskTypeComment.configRequired=true
workflow.taskTypeComment.formTaskRequired=true

workflow.taskTypeNotification.key=taskTypeNotification
workflow.taskTypeNotification.titleI18nKey=module.workflow.notification.task_title
workflow.taskTypeNotification.beanName=workflow.taskNotification
workflow.taskTypeNotification.configBeanName=workflow.taskNotificationConfig
workflow.taskTypeNotification.configRequired=true
workflow.taskTypeNotification.taskForAutomaticAction=true
```

### 6.2 TaskType Producer Class

**New file: `TaskTypeProducer.java`**

CDI producer that creates TaskType beans from configuration properties:

```java
@ApplicationScoped
public class TaskTypeProducer
{
    @Produces
    @ApplicationScoped
    @Named( "workflow.taskTypeComment" )
    public ITaskType produceTaskTypeComment(
            @ConfigProperty( name = "workflow.taskTypeComment.key" ) String key,
            @ConfigProperty( name = "workflow.taskTypeComment.titleI18nKey" ) String titleI18nKey,
            @ConfigProperty( name = "workflow.taskTypeComment.beanName" ) String beanName,
            @ConfigProperty( name = "workflow.taskTypeComment.configBeanName" ) String configBeanName,
            @ConfigProperty( name = "workflow.taskTypeComment.configRequired", defaultValue = "false" ) boolean configRequired,
            @ConfigProperty( name = "workflow.taskTypeComment.formTaskRequired", defaultValue = "false" ) boolean formTaskRequired,
            @ConfigProperty( name = "workflow.taskTypeComment.taskForAutomaticAction", defaultValue = "false" ) boolean taskForAutomaticAction )
    {
        return TaskTypeBuilder.buildTaskType( key, titleI18nKey, beanName, configBeanName,
                configRequired, formTaskRequired, taskForAutomaticAction );
    }
    // ... other task type producers
}
```

### 6.3 TaskConfigService Producer

**New file: `TaskConfigServiceProducer.java`**

Produces TaskConfigService beans with injected DAOs:

```java
@ApplicationScoped
public class TaskConfigServiceProducer
{
    @Produces
    @ApplicationScoped
    @Named( "workflow.taskCommentConfigService" )
    public ITaskConfigService produceTaskCommentConfigService(
            @Named( "workflow.taskCommentConfigDAO" ) ITaskConfigDAO<TaskCommentConfig> taskCommentConfigDAO )
    {
        TaskConfigService taskService = new TaskConfigService( );
        taskService.setTaskConfigDAO( (ITaskConfigDAO) taskCommentConfigDAO );
        return taskService;
    }
    // ... other config service producers
}
```

### 6.4 Task Classes Migration

**Before (Spring):**
```java
public class TaskComment extends Task
{
    @Inject
    @Named( "workflow.commentValueService" )
    private ICommentValueService _commentValueService;
}
```

**After (CDI):**
```java
@Dependent
@Named( "workflow.taskComment" )
public class TaskComment extends Task
{
    @Inject
    @Named( "workflow.commentValueService" )
    private ICommentValueService _commentValueService;
}
```

Note: Tasks use `@Dependent` scope (prototype equivalent) rather than `@ApplicationScoped`.

### 6.5 TaskComponent Constructor Injection

TaskComponents now use constructor injection for TaskType and TaskConfigService:

**Before (Spring XML):**
```xml
<bean id="workflow.commentTaskComponent"
    class="fr.paris.lutece.plugins.workflow.modules.comment.web.CommentTaskComponent"
    p:taskType-ref="workflow.taskTypeComment"
    p:taskConfigService-ref="workflow.taskCommentConfigService" />
```

**After (CDI):**
```java
@ApplicationScoped
@Named( "workflow.archiveTaskComponent" )
public class ArchiveTaskComponent extends NoFormTaskComponent
{
    ArchiveTaskComponent() {}

    @Inject
    public ArchiveTaskComponent(
            @Named( "workflow.taskTypeArchive" ) ITaskType taskType,
            @Named( "workflow.taskArchiveConfigService" ) ITaskConfigService taskConfigService )
    {
        setTaskType( taskType );
        setTaskConfigService( taskConfigService );
    }
}
```

### 6.6 TaskConfig Classes Migration

Config classes use `@Dependent` scope (prototype equivalent):

```java
@Dependent
@Named( "workflow.taskCommentConfig" )
public class TaskCommentConfig extends TaskConfig
{
    // ...
}
```

### 6.7 ResourceHistoryFactory Implementation

**New file: `ResourceHistoryFactoryImpl.java`**

```java
@ApplicationScoped
@Named( "workflow.resourceHistoryFactory" )
public class ResourceHistoryFactoryImpl extends ResourceHistoryFactory
{
    // CDI-annotated implementation of abstract factory
}
```

---

## 7. Daemon Changes

Daemons now use CDI programmatic lookup:

**Before:**
```java
public class ArchiveDaemon extends Daemon
{
    private IWorkflowService _workflowService = SpringContextService.getBean( WorkflowService.BEAN_SERVICE );
    private IActionService _actionService = SpringContextService.getBean( ActionService.BEAN_SERVICE );
}
```

**After:**
```java
public class ArchiveDaemon extends Daemon
{
    private IWorkflowService _workflowService = CDI.current( ).select( IWorkflowService.class,
            NamedLiteral.of( WorkflowService.BEAN_SERVICE ) ).get( );
    private IActionService _actionService = CDI.current( ).select( IActionService.class,
            NamedLiteral.of( ActionService.BEAN_SERVICE ) ).get( );
}
```

### WorkflowFilter Usage Update

```java
// Before
workflowFilter.setIsEnabled( 1 );

// After
workflowFilter.setIsEnabled( WorkflowFilter.FILTER_TRUE );
```

---

## 8. JspBean Changes

JspBeans now use field injection with CDI:

**Before:**
```java
public class CommentJspBean extends MVCAdminJspBean
{
    private ICommentValueService _commentValueService = SpringContextService.getBean( CommentValueService.BEAN_SERVICE );
}
```

**After:**
```java
@RequestScoped
@Named
public class CommentJspBean extends MVCAdminJspBean
{
    @Inject
    private ICommentValueService _commentValueService;

    @Inject
    private IResourceHistoryService _resourceHistoryService;
}
```

---

## 9. New Features Added

### 9.1 Workflow Cycle Detection

New utility class for detecting cycles in automatic actions:

- `StateTransition.java` - Represents state transitions
- `WorkflowCycleUtils.java` - Utility to detect automatic action loops

### 9.2 New Copy Features

New confirmation messages for copying workflow elements:
- `message.confirm_copy_task`
- `message.confirm_copy_state`
- `message.confirm_copy_action`

### 9.3 Automatic Loop Warning

New warning message when automatic actions create a loop:
- `message.warning.action.auto.loop`

---

## 10. Migration Checklist

### For DAO Classes:
- [ ] Add `@ApplicationScoped` annotation
- [ ] Add `@Named( "beanName" )` annotation
- [ ] Change `javax.inject` imports to `jakarta.inject`

### For Service Classes:
- [ ] Add `@ApplicationScoped` annotation
- [ ] Add `@Named( ServiceClass.BEAN_SERVICE )` annotation
- [ ] Change `@Transactional( "workflow.transactionManager" )` to `@Transactional`
- [ ] Change Spring transaction import to Jakarta transaction import

### For Task Classes:
- [ ] Add `@Dependent` annotation (for prototype scope)
- [ ] Add `@Named( "beanName" )` annotation
- [ ] Change `javax.servlet` to `jakarta.servlet`
- [ ] Change `javax.inject` to `jakarta.inject`

### For TaskComponent Classes:
- [ ] Add `@ApplicationScoped` annotation
- [ ] Add `@Named( "beanName" )` annotation
- [ ] Add constructor injection for TaskType and TaskConfigService
- [ ] Add default constructor for CDI proxy

### For TaskConfig Classes:
- [ ] Add `@Dependent` annotation
- [ ] Add `@Named( "beanName" )` annotation
- [ ] Change validation annotations from `javax.validation` to `jakarta.validation`

### For Static Service Lookups:
- [ ] Replace `SpringContextService.getBean()` with `CDI.current().select().get()`
- [ ] Replace `SpringContextService.getBeansOfType()` with `CDI.current().select().stream().toList()`

### Configuration Files:
- [ ] Delete `*_context.xml` Spring configuration file
- [ ] Create `META-INF/beans.xml` with CDI 4.0 configuration
- [ ] Create `*-tasks.properties` for task type configuration (if applicable)

---

## 11. Key Differences Summary

| Aspect | v7 (Spring) | v8 (CDI) |
|--------|-------------|----------|
| Bean Configuration | XML (`*_context.xml`) | Annotations + `beans.xml` |
| Bean Discovery | Spring scanning | CDI annotated mode |
| Singleton Beans | `class` in XML | `@ApplicationScoped` |
| Prototype Beans | `scope="prototype"` | `@Dependent` |
| Bean Naming | `id` attribute | `@Named` annotation |
| Property Injection | `p:property-ref` | Constructor/field `@Inject` |
| Service Lookup | `SpringContextService.getBean()` | `CDI.current().select().get()` |
| Transaction Management | `@Transactional("manager")` | `@Transactional` |
| Servlet API | `javax.servlet` | `jakarta.servlet` |
| Validation | `javax.validation` | `jakarta.validation` |
| Dependency Injection | `javax.inject` | `jakarta.inject` |
