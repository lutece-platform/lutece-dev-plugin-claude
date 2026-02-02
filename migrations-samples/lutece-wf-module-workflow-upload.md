# Migration Analysis: lutece-wf-module-workflow-upload (v7 to v8)

## Overview

This document analyzes the migration changes between Lutece v7 (`develop` branch) and Lutece v8 (`develop_core8` branch) for the `lutece-wf-module-workflow-upload` module.

**Module Version Changes:**
- v7: `1.1.5-SNAPSHOT`
- v8: `2.0.0-SNAPSHOT`

## Summary of Changes

| Category | Files Modified | Description |
|----------|----------------|-------------|
| POM | 1 | Version bumps and dependency updates |
| DAOs | 3 | CDI annotations + try-with-resources |
| Services | 6 | CDI migration, Spring removal |
| Web Layer | 2 | CDI injection, JSP bean changes |
| Configuration | 3 | Spring XML removed, properties added |
| JSPs | 2 | EL expression syntax |
| New Files | 3 | CDI producers, beans.xml |

**Total: 25 files changed, 473 insertions, 408 deletions**

---

## 1. POM.xml Changes

### Parent POM
```xml
- <version>7.0.2</version>
+ <version>8.0.0-SNAPSHOT</version>
```

### Dependencies Updated

| Dependency | v7 Version | v8 Version |
|------------|------------|------------|
| lutece-core | `[5.0.0,)` | `[8.0.0-SNAPSHOT,)` |
| plugin-workflow | `[4.3.2,)` | `[7.0.0-SNAPSHOT,)` |
| plugin-asynchronousupload | `[1.0.5,)` | `[2.0.0-SNAPSHOT,)` |
| library-signrequest | `[2.0.1-SNAPSHOT,)` | `[4.0.0-SNAPSHOT,)` |

---

## 2. Java Package Migrations

### Import Changes (javax to jakarta)

| v7 Import | v8 Import |
|-----------|-----------|
| `javax.inject.Inject` | `jakarta.inject.Inject` |
| `javax.inject.Named` | `jakarta.inject.Named` |
| `javax.servlet.http.HttpServletRequest` | `jakarta.servlet.http.HttpServletRequest` |
| `javax.servlet.http.HttpSession` | `jakarta.servlet.http.HttpSession` |
| `javax.servlet.http.HttpServlet` | `jakarta.servlet.http.HttpServlet` |
| `javax.servlet.ServletException` | `jakarta.servlet.ServletException` |
| `org.apache.commons.fileupload.FileItem` | `fr.paris.lutece.portal.service.upload.MultipartItem` |

### Spring to CDI Migrations

| v7 (Spring) | v8 (CDI) |
|-------------|----------|
| `SpringContextService.getBean()` | `@Inject` field injection |
| `@Transactional` | Removed (handled at framework level) |
| `scope="prototype"` | `@Dependent` |
| Spring XML context | `@ApplicationScoped`, `@Produces` |

---

## 3. DAO Layer Changes

### Pattern: DAOUtil try-with-resources

All DAOs now use try-with-resources pattern and remove `daoUtil.free()` calls.

**Before (v7):**
```java
public void insert(UploadFile upload, Plugin plugin) {
    DAOUtil daoUtil = new DAOUtil(SQL_QUERY_INSERT, plugin);
    int nPos = 0;
    daoUtil.setInt(++nPos, upload.getIdFile());
    daoUtil.setInt(++nPos, upload.getIdHistory());
    daoUtil.executeUpdate();
    daoUtil.free();
}
```

**After (v8):**
```java
@ApplicationScoped
public class UploadFileDAO implements IUploadFileDAO {
    @Override
    public synchronized void insert(UploadFile upload, Plugin plugin) {
        try(DAOUtil daoUtil = new DAOUtil(SQL_QUERY_INSERT, plugin)) {
            int nPos = 0;
            daoUtil.setInt(++nPos, upload.getIdFile());
            daoUtil.setInt(++nPos, upload.getIdHistory());
            daoUtil.executeUpdate();
        }
    }
}
```

### DAOs Modified

| DAO Class | CDI Annotation |
|-----------|----------------|
| `UploadFileDAO` | `@ApplicationScoped` |
| `UploadHistoryDAO` | `@ApplicationScoped` |
| `TaskUploadConfigDAO` | `@ApplicationScoped` + `@Named("workflow-upload.taskUploadConfigDAO")` |

---

## 4. Service Layer Changes

### UploadHistoryService

**CDI Annotations Added:**
```java
@ApplicationScoped
public class UploadHistoryService implements IUploadHistoryService {
    @Inject
    private IUploadHistoryDAO _uploadHistoryDao;

    @Inject
    private IUploadFileDAO _uploadFileDao;

    @Inject
    private IResourceHistoryService _resourceHistoryService;
}
```

**Removed:**
- `@Transactional("workflow.transactionManager")` annotations
- `SpringContextService.getBean()` calls
- Lazy initialization pattern for DAOs

**FileItem to MultipartItem:**
```java
- public void create(int nIdResourceHistory, int nidTask, List<FileItem> listFiles, Plugin plugin)
+ public void create(int nIdResourceHistory, int nidTask, List<MultipartItem> listFiles, Plugin plugin)
```

### TaskUploadAsynchronousUploadHandler

**Changes:**
```java
@ApplicationScoped
@Named(TaskUploadAsynchronousUploadHandler.BEAN_TASK_ASYNCHRONOUS_UPLOAD_HANDLER)
public class TaskUploadAsynchronousUploadHandler extends AbstractAsynchronousUploadHandler {
    public static final String BEAN_TASK_ASYNCHRONOUS_UPLOAD_HANDLER = "workflow-upload.taskUploadAsynchronousUploadHandler";

    private static Map<String, Map<String, List<MultipartItem>>> _mapAsynchronousUpload = ...
}
```

**Removed static getter:**
```java
// REMOVED in v8
public static TaskUploadAsynchronousUploadHandler getHandler() {
    return SpringContextService.getBean(BEAN_TASK_ASYNCHRONOUS_UPLOAD_HANDLER);
}
```

### TaskUpload (Task Implementation)

```java
@Dependent
@Named("workflow-upload.taskUpload")
public class TaskUpload extends Task {
    @Inject
    @Named(BEAN_UPLOAD_CONFIG_SERVICE)
    private ITaskConfigService _taskUploadConfigService;

    @Inject
    private IUploadHistoryService _uploadHistoryService;

    @Inject
    private IUploadFileDAO _uploadFileDAO;

    @Inject
    private TaskUploadAsynchronousUploadHandler _taskUploadAsynchronousUploadHandler;
}
```

---

## 5. New CDI Producer Classes

### TaskTypeUploadProducer

New file created to produce `ITaskType` bean via CDI:

```java
@ApplicationScoped
public class TaskTypeUploadProducer {
    @Produces
    @ApplicationScoped
    @Named("workflow-upload.taskTypeUpload")
    public ITaskType produceTaskTypeUploadTask(
            @ConfigProperty(name = "workflow-upload.taskTypeUpload.key") String key,
            @ConfigProperty(name = "workflow-upload.taskTypeUpload.titleI18nKey") String titleI18nKey,
            @ConfigProperty(name = "workflow-upload.taskTypeUpload.beanName") String beanName,
            @ConfigProperty(name = "workflow-upload.taskTypeUpload.configBeanName") String configBeanName,
            @ConfigProperty(name = "workflow-upload.taskTypeUpload.configRequired", defaultValue = "false") boolean configRequired,
            @ConfigProperty(name = "workflow-upload.taskTypeUpload.formTaskRequired", defaultValue = "false") boolean formTaskRequired,
            @ConfigProperty(name = "workflow-upload.taskTypeUpload.taskForAutomaticAction", defaultValue = "false") boolean taskForAutomaticAction) {
        return TaskTypeBuilder.buildTaskType(key, titleI18nKey, beanName, configBeanName, configRequired, formTaskRequired, taskForAutomaticAction);
    }
}
```

### TaskTypeUploadConfigServiceProducer

Replaces `FactoryDOA.java`:

```java
@ApplicationScoped
public class TaskTypeUploadConfigServiceProducer {
    @Produces
    @ApplicationScoped
    @Named("workflow-upload.taskUploadConfigService")
    public ITaskConfigService produceTaskTypeUploadConfigService(
            @Named("workflow-upload.taskUploadConfigDAO") ITaskConfigDAO<TaskUploadConfig> taskTypeUploadConfigDAO) {
        TaskConfigService taskService = new TaskConfigService();
        taskService.setTaskConfigDAO((ITaskConfigDAO) taskTypeUploadConfigDAO);
        return taskService;
    }
}
```

### UploadAuthenticatorProducer

Replaces Spring XML bean configuration for SignRequest:

```java
@ApplicationScoped
public class UploadAuthenticatorProducer extends AbstractSignRequestAuthenticatorProducer {
    @Produces
    @ApplicationScoped
    @Named("workflow-upload.requestAuthentication")
    public AbstractPrivateKeyAuthenticator produceUploadRequestAuthenticator() {
        return (AbstractPrivateKeyAuthenticator) produceRequestAuthenticator("workflow-upload.requestAuthentication");
    }
}
```

---

## 6. Deleted Files

### Factory Classes Removed

| Deleted File | Replacement |
|--------------|-------------|
| `factory/FactoryDOA.java` | Direct `@Inject` in services |
| `factory/FactoryService.java` | `UploadAuthenticatorProducer.java` |

### Spring Context File Removed

`webapp/WEB-INF/conf/plugins/workflow-upload_context.xml` - **DELETED**

All bean definitions moved to:
- CDI annotations on classes
- Properties file for configuration values
- CDI Producer classes for complex beans

---

## 7. Configuration Files

### New: beans.xml

```xml
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0" bean-discovery-mode="annotated">
</beans>
```

### Updated: workflow-upload.properties

Added MicroProfile Config properties:

```properties
# Upload task type
workflow-upload.taskTypeUpload.key=taskTypeUpload
workflow-upload.taskTypeUpload.titleI18nKey=module.workflow.upload.task_title
workflow-upload.taskTypeUpload.beanName=workflow-upload.taskUpload
workflow-upload.taskTypeUpload.configBeanName=workflow-upload.taskUploadConfig
workflow-upload.taskTypeUpload.configRequired=true
workflow-upload.taskTypeUpload.formTaskRequired=true

# SignRequest
workflow-upload.requestAuthentication.name=signrequest.RequestHashAuthenticator
workflow-upload.requestAuthentication.cfg.hashService=signrequest.Sha1HashService
workflow-upload.requestAuthentication.cfg.signatureElements=id_file
workflow-upload.requestAuthentication.cfg.privateKey=wkFileDownload
```

---

## 8. Web Layer Changes

### UploadJspBean

```java
@RequestScoped
@Named
public class UploadJspBean extends MVCAdminJspBean {
    @Inject
    private IUploadHistoryService _uploadHistoryService;

    @Inject
    private IResourceHistoryService _resourceHistoryService;

    @Inject
    private ITaskService _taskService;

    @Inject
    private ITaskComponentManager _taskComponentManager;

    @Inject
    private IUploadFileDAO _uploadFileDAO;
}
```

**RBAC Change:**
```java
- RBACService.isAuthorized(uploadValue, UploadResourceIdService.PERMISSION_DELETE, userConnected)
+ RBACService.isAuthorized(uploadValue, UploadResourceIdService.PERMISSION_DELETE, (User) userConnected)
```

### UploadTaskComponent

```java
@ApplicationScoped
@Named("workflow-upload.uploadTaskComponent")
public class UploadTaskComponent extends AbstractTaskComponent {
    @Inject
    private IUploadHistoryService _uploadHistoryService;

    @Inject
    private IUploadFileDAO _uploadFileDAO;

    @Inject
    @Named(TaskUploadAsynchronousUploadHandler.BEAN_TASK_ASYNCHRONOUS_UPLOAD_HANDLER)
    private TaskUploadAsynchronousUploadHandler _taskUploadAsynchronousUploadHandler;

    @Inject
    private Models model;

    @Inject
    public UploadTaskComponent(
            @Named("workflow-upload.taskTypeUpload") ITaskType taskType,
            @Named("workflow-upload.taskUploadConfigService") ITaskConfigService taskConfigService) {
        setTaskType(taskType);
        setTaskConfigService(taskConfigService);
    }
}
```

**Model Pattern Change:**
```java
// v7
Map<String, Object> model = new HashMap<String, Object>();
model.put(MARK_CONFIG, config);

// v8
@Inject
private Models model;
// ... then use directly
model.put(MARK_CONFIG, config);
```

---

## 9. JSP Changes

### Pattern: Session Bean to EL Expression

**Before (v7):**
```jsp
<%@ page errorPage="../../ErrorPage.jsp" %>
<jsp:useBean id="manageUpload" scope="session" class="fr.paris.lutece.plugins.workflow.modules.upload.web.UploadJspBean" />
<%
    response.sendRedirect(manageUpload.getConfirmRemoveUpload(request));
%>
```

**After (v8):**
```jsp
<%@ page errorPage="../../ErrorPage.jsp" %>

${ pageContext.response.sendRedirect(uploadJspBean.getConfirmRemoveUpload(pageContext.request)) }
```

The bean name `uploadJspBean` is derived from the class name `UploadJspBean` with `@Named` annotation (no explicit name means default naming convention).

---

## 10. TaskConfig Changes

### TaskUploadConfig

Added CDI annotations for prototype scope equivalent:

```java
@Dependent
@Named("workflow-upload.taskUploadConfig")
public class TaskUploadConfig extends TaskConfig {
    // ... existing code
}
```

---

## 11. Provider Classes

### UploadMarkerProvider

```java
@ApplicationScoped
@Named("workflow-upload.uploadMarkerProvider")
public class UploadMarkerProvider implements IMarkerProvider {
    @Inject
    private ITaskService _taskService;

    @Inject
    @Named(value="workflow-upload.uploadTaskInfoProvider")
    private ITaskInfoProvider _uploadTaskInfoProvider;
}
```

### UploadTaskInfoProvider

```java
@ApplicationScoped
@Named("workflow-upload.uploadTaskInfoProvider")
public class UploadTaskInfoProvider extends AbstractTaskInfoProvider {
    @Inject
    private IUploadFileDAO _uploadFileDAO;

    @Inject
    public UploadTaskInfoProvider(@Named("workflow-upload.taskTypeUpload") ITaskType taskType) {
        setTaskType(taskType);
    }
}
```

---

## 12. RequestAuthenticationService

**Change from Spring to CDI:**

```java
// v7
return (AbstractPrivateKeyAuthenticator) SpringContextService.getBean(BEAN_REQUEST_AUTHENTICATION);

// v8
return CdiHelper.getReference(AbstractPrivateKeyAuthenticator.class, BEAN_REQUEST_AUTHENTICATION);
```

---

## Migration Checklist

### Required Changes

- [x] Update pom.xml parent version to 8.0.0-SNAPSHOT
- [x] Update all dependency versions
- [x] Migrate javax imports to jakarta
- [x] Replace FileItem with MultipartItem
- [x] Add CDI annotations to all beans
- [x] Create beans.xml in META-INF
- [x] Remove Spring context XML file
- [x] Create CDI Producer classes for complex beans
- [x] Add MicroProfile Config properties for task types
- [x] Use try-with-resources for DAOUtil
- [x] Remove daoUtil.free() calls
- [x] Remove @Transactional annotations
- [x] Replace SpringContextService.getBean() with @Inject
- [x] Update JSPs to use EL expressions instead of scriptlets
- [x] Add explicit User cast for RBAC authorization calls
- [x] Use Models injection instead of creating HashMap for models

### Bean Naming Convention

| Bean Type | Naming Pattern | Example |
|-----------|----------------|---------|
| DAO | `module-name.daoName` | `workflow-upload.taskUploadConfigDAO` |
| Service | `module-name.serviceName` | `workflow-upload.taskUploadConfigService` |
| Task | `module-name.taskName` | `workflow-upload.taskUpload` |
| TaskType | `module-name.taskTypeName` | `workflow-upload.taskTypeUpload` |
| Component | `module-name.componentName` | `workflow-upload.uploadTaskComponent` |
| Config | `module-name.configName` | `workflow-upload.taskUploadConfig` |

---

## Notes

1. **Scope Changes:**
   - `scope="prototype"` in Spring becomes `@Dependent` in CDI
   - Singleton beans use `@ApplicationScoped`
   - Request-scoped beans use `@RequestScoped`

2. **Constructor Injection:**
   - Components that need taskType and configService use constructor injection with `@Inject`

3. **MultipartItem:**
   - New Lutece 8 abstraction replacing Apache Commons FileUpload's FileItem
   - `delete()` method now throws `IOException` requiring try-catch

4. **Models Pattern:**
   - v8 introduces `Models` CDI bean for template model management
   - Replaces manual `HashMap<String, Object>` creation
