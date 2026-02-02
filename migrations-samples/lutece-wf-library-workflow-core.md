# Migration Analysis: lutece-wf-library-workflow-core (v7 to v8)

## Overview

This document analyzes the migration differences between Lutece v7 (branch `develop`) and Lutece v8 (branch `develop4.x`) for the `lutece-wf-library-workflow-core` library.

**Library Version Changes:**
- v7: `3.0.1-SNAPSHOT`
- v8: `4.0.0-SNAPSHOT`

**Parent POM Changes:**
- v7: `lutece-global-pom` version `6.0.0`
- v8: `lutece-global-pom` version `8.0.0-SNAPSHOT`

---

## Summary of Changes

| Category | Files Modified | Lines Added | Lines Removed |
|----------|---------------|-------------|---------------|
| Total | 31 files | +759 | -231 |

---

## 1. Jakarta EE Migration (javax -> jakarta)

The most significant change is the migration from Java EE (`javax.*`) to Jakarta EE (`jakarta.*`) namespaces.

### Affected Imports

| Old Import (v7) | New Import (v8) |
|-----------------|-----------------|
| `javax.inject.Inject` | `jakarta.inject.Inject` |
| `javax.servlet.http.HttpServletRequest` | `jakarta.servlet.http.HttpServletRequest` |
| `org.springframework.beans.factory.InitializingBean` | `jakarta.annotation.PostConstruct` |

### Files Affected

- `ActionService.java`
- `ActionStateService.java`
- `IconService.java`
- `ResourceHistoryService.java`
- `ResourceWorkflowService.java`
- `StateService.java`
- `TaskService.java`
- `WorkflowService.java`
- `IAutomaticActionPrerequisiteService.java`
- `IMarkerProvider.java`
- `IProviderManager.java`
- `IWorkflowService.java`
- `AsynchronousSimpleTask.java`
- `ITask.java`
- `TaskComponent.java`
- `ITaskComponent.java`
- `ITaskComponentManager.java`
- `SimpleTaskComponent.java`

---

## 2. UID Support (New Feature)

v8 introduces UID (Unique Identifier) support across all workflow entities for JSON serialization/export purposes. Integer IDs are marked with `@JsonIgnore` to exclude them from JSON serialization.

### Action.java

```java
// New fields
private String _strUid;
private Collection<String> _listUidsLinkedAction;
private String _strUidStateAfter;
private String _strUidAlternativeStateAfter;
private List<String> _listUidStateBefore;

// New methods
public String getUid()
public void setUid(String strUid)
public Collection<String> getListUidsLinkedAction()
public void setListUidsLinkedAction(Collection<String> listUidsLinkedAction)
public String getStrUidStateAfter()
public void setStrUidStateAfter(String strUidStateAfter)
public String getStrUidAlternativeStateAfter()
public void setStrUidAlternativeStateAfter(String strUidAlternativeStateAfter)
public List<String> getListUidStateBefore()
public void setListUidStateBefore(List<String> listUidStateBefore)

// Fields marked with @JsonIgnore
@JsonIgnore private int _nId;
@JsonIgnore private State _stateAfter;
@JsonIgnore private State _alternativeStateAfter;
@JsonIgnore private Workflow _workflow;
@JsonIgnore private Collection<Integer> _listIdsLinkedAction;
@JsonIgnore private List<ITask> _listTasks;
@JsonIgnore private List<Integer> _listIdStateBefore;
```

### State.java

```java
// New field
private String _strUid;

// New methods
public String getUid()
public void setUid(String strUid)

// Fields marked with @JsonIgnore
@JsonIgnore private int _nId;
@JsonIgnore private Workflow _workflow;
@JsonIgnore private List<Action> _listActions;
```

### Workflow.java

```java
// New field
private String _strUid;

// New methods
public String getUid()
public void setUid(String strUid)

// Fields marked with @JsonIgnore
@JsonIgnore private int _nId;
@JsonIgnore private List<Action> _listActions;
@JsonIgnore private List<State> _listStates;
```

### Prerequisite.java

```java
// New fields
private String _strPrerequisiteUid;
private String _strUidAction;

// New methods
public String getUidPrerequisite()
public void setUidPrerequisite(String strPrerequisiteUid)
public String getUidAction()
public void setUidAction(String strUidAction)

// Fields marked with @JsonIgnore
@JsonIgnore private int _nPrerequisiteId;
```

### Task.java (and ITask interface)

```java
// New fields
private String _strUid;
private String _strActionUid;

// New methods
String getUid()
void setUid(String strUid)
String getActionUid()
void setActionUid(String strActionUid)

// Fields marked with @JsonIgnore
@JsonIgnore private int _nId;
@JsonIgnore private Action _action;
```

---

## 3. Service Layer Changes

### IActionService.java / ActionService.java

New methods added:

```java
// Update action without modifying states and related actions
void updateActionWithoutStates(Action action);

// Get UIDs instead of IDs for linked actions
Collection<String> getListUidsLinkedAction(int nIdAction);

// New properly named methods (old ones deprecated)
List<Action> findActionsBetweenOrders(int nOrder1, int nOrder2, int nIdWorkflow);
List<Action> findActionsAfterOrder(int nOrder, int nIdWorkflow);
```

Deprecated methods:

```java
@Deprecated
List<Action> findStatesBetweenOrders(int nOrder1, int nOrder2, int nIdWorkflow);

@Deprecated
List<Action> findStatesAfterOrder(int nOrder, int nIdWorkflow);
```

### IActionStateService.java / ActionStateService.java

New method:

```java
List<String> findByUidAction(String strUidAction);
```

### IActionDAO.java

New methods and deprecations:

```java
// New method
Collection<String> selectListUidsLinkedAction(int nIdAction);

// Deprecated (replaced with properly named versions)
@Deprecated
List<Action> findStatesBetweenOrders(int nOrder1, int nOrder2, int nIdWorkflow);

@Deprecated
List<Action> findStatesAfterOrder(int nOrder, int nIdWorkflow);

// New default implementations
default List<Action> findActionsBetweenOrders(int nOrder1, int nOrder2, int nIdWorkflow) {
    return findStatesBetweenOrders(nOrder1, nOrder2, nIdWorkflow);
}

default List<Action> findActionsAfterOrder(int nOrder, int nIdWorkflow) {
    return findStatesAfterOrder(nOrder, nIdWorkflow);
}
```

### IActionStateDAO.java

New method:

```java
List<String> load(String strUidAction);
```

---

## 4. Task Processing Changes

### ITask.java - New Task Processing Signature

v8 introduces a new `processTaskWithResult` method signature that includes resource information directly:

```java
// New method (v8)
default boolean processTaskWithResult(
    int nIdResource,
    String strResourceType,
    int nIdResourceHistory,
    HttpServletRequest request,
    Locale locale,
    User user
) {
    // Default: calls deprecated method for backward compatibility
    return processTaskWithResult(nIdResourceHistory, request, locale, user);
}

// Deprecated (v7)
@Deprecated
default boolean processTaskWithResult(
    int nIdResourceHistory,
    HttpServletRequest request,
    Locale locale,
    User user
)
```

### AsynchronousSimpleTask.java

Updated signature:

```java
// v7
public boolean processTaskWithResult(int nIdResourceHistory, HttpServletRequest request, Locale locale, User user)
public abstract void processAsynchronousTask(int nIdResourceHistory, HttpServletRequest request, Locale locale, User user);

// v8
public boolean processTaskWithResult(int nResourceId, String strResourceType, int nIdResourceHistory, HttpServletRequest request, Locale locale, User user)
public abstract void processAsynchronousTask(int nResourceId, String strResourceType, int nIdResourceHistory, HttpServletRequest request, Locale locale, User user);
```

---

## 5. Provider Manager Refactoring

### New Interface: IProviderManager

A new interface `IProviderManager` has been introduced, and `AbstractProviderManager` is now deprecated:

```java
@Deprecated(since = "4.0.0", forRemoval = true)
public abstract class AbstractProviderManager implements IProviderManager
```

The new `IProviderManager` interface:

```java
public interface IProviderManager {
    Collection<ProviderDescription> getAllProviderDescriptions(ITask task);
    ProviderDescription getProviderDescription(String strProviderId);
    IProvider createProvider(String strProviderId, ResourceHistory resourceHistory, HttpServletRequest request);
    String getId();
}
```

---

## 6. InfoMarker Enhancement

New constructor added:

```java
// New constructor in v8
public InfoMarker(String marker, String strData) {
    _strMarker = marker;
    _strValue = strData;
}
```

The `_strMarker` field is no longer `final` to support the new constructor.

---

## 7. Spring to CDI Migration

### TaskComponent.java

Replaced Spring's `InitializingBean` with Jakarta's `@PostConstruct`:

```java
// v7
public class TaskComponent implements ITaskComponent
// where ITaskComponent extends InitializingBean

@Override
public void afterPropertiesSet() throws Exception {
    Assert.notNull(_taskType, "The property 'taskType' is required.");
    // ...
}

// v8
@PostConstruct
public void afterPropertiesSet() {
    if (_taskType == null) {
        throw new IllegalArgumentException("The property 'taskType' is required.");
    }
    // ...
}
```

### ITaskComponent.java

No longer extends `InitializingBean`:

```java
// v7
public interface ITaskComponent extends InitializingBean

// v8
public interface ITaskComponent
```

---

## 8. WorkflowService Changes

### Alternative State Handling Fix

v8 adds null check for alternative state:

```java
// v8
if (isSuccess) {
    resourceWorkflow.setState(action.getStateAfter());
} else {
    State alternativeState = action.getAlternativeStateAfter();
    if (alternativeState != null && alternativeState.getId() > 0) {
        resourceWorkflow.setState(alternativeState);
    }
}

resourceWorkflow.setWorkFlow(action.getWorkflow());
```

### Task Processing Call

Updated to use new signature with resource information:

```java
// v7
task.processTaskWithResult(resourceHistory.getId(), request, locale, user)

// v8
task.processTaskWithResult(nIdResource, strResourceType, resourceHistory.getId(), request, locale, user)
```

---

## 9. POM Dependencies Changes

### Removed Dependencies (managed by parent POM)

- `javax.inject:javax.inject` - Removed (Jakarta now used)
- `org.springframework:spring-beans` - Removed (CDI now used)
- Version specifications for `commons-lang3`, `commons-beanutils`, `log4j-api`, `jackson-module-parameter-names` - Now managed by parent POM

### Repository URLs

Changed from HTTP to HTTPS:
- `http://dev.lutece.paris.fr/` -> `https://dev.lutece.paris.fr/`

---

## Migration Checklist

### Breaking Changes

1. **Jakarta EE Migration**: All `javax.*` imports must be changed to `jakarta.*`
2. **Task Interface**: If implementing `ITask`, must handle new `processTaskWithResult` signature with resource parameters
3. **AsynchronousSimpleTask**: If extending, must update `processAsynchronousTask` signature
4. **AbstractProviderManager**: Deprecated - migrate to implement `IProviderManager` directly
5. **Spring InitializingBean**: If relying on Spring's `InitializingBean`, use `@PostConstruct` instead

### Recommended Updates

1. Use `@JsonIgnore` annotations on integer ID fields for proper JSON serialization
2. Add UID support to custom workflow entities
3. Replace deprecated `findStatesBetweenOrders`/`findStatesAfterOrder` with new method names
4. Consider implementing UID-based lookups for portability

### Backward Compatibility

- Default implementations provided for new methods in interfaces
- Deprecated methods delegate to new implementations
- Old task processing signatures call new ones for backward compatibility
