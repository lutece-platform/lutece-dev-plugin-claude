---
name: lutece-scaffold
description: "Interactive Lutece 8 plugin scaffold generator. Creates plugins with optional XPage, Cache, RBAC and Site features. Supports parent-child entity relationships."
---

# Lutece 8 Plugin Scaffold Generator

Generate complete Lutece 8 plugin scaffolds through interactive questioning.

## Process Overview

```
Phase 1: Plugin Info     → Name, description, output directory
Phase 2: Entities        → Entities with fields, i18n labels (en/fr) and parent-child relations
Phase 3: Features        → XPage, Cache, RBAC, Site, Workflow (optional)
Phase 4: Generation      → Run the script, generate the scaffold
Phase 5: Feature Planning → Plan features (rules auto-loaded from .claude/rules/)
```

## Interaction Model

Use two interaction modes depending on the question type:

### AskUserQuestion tool (structured UI)
Use for all questions with **predefined choices**: yes/no, type selection, feature toggles, confirmations.
- **Batch independent questions** in a single call (max 4 questions)
- The user always has an **"Other"** option for custom input
- Headers must be **max 12 characters**

### Text output (free-form)
Use for **open-ended input**: names, descriptions, labels — anything always custom.

### Rules
- **NEVER ask all questions at once.** Respect the phase-by-phase flow.
- **Batch only within the same step** (e.g., field type + required together, NOT field type + entity name).
- **Always use AskUserQuestion for yes/no decisions** — never ask "yes or no?" in plain text.

## Phase 1: Plugin Info

Ask one question at a time:
1. **[Text]** Plugin name? (lowercase, no spaces, e.g., "taskmanager")
2. **[Text]** Plugin description? (en/fr)
3. **[AskUserQuestion]** Output directory?

```
AskUserQuestion:
  header: "Output dir"
  question: "Where should the plugin be generated?"
  options:
    - label: "Current directory"
      description: "{cwd}"
    - label: "~/dev/lutece"
      description: "Default Lutece development directory"
```

## Phase 2: Entities

For each entity:
1. **[Text]** Entity name? (PascalCase, e.g., "Project")
2. **[Text]** Entity label? (en/fr for i18n)
3. **[AskUserQuestion]** Parent entity? — only if at least one entity is already defined

```
AskUserQuestion:
  header: "Parent"
  question: "Does this entity have a parent entity?"
  options:
    - label: "None"
      description: "This is a root entity"
    - label: "{Entity1}"          # dynamically list already-defined entities
      description: "Child of {Entity1}"
    # ... up to 3 existing entities (max 4 options total)
```

4. Table name? (auto-default: `pluginname_entityname` — confirm silently, no question needed)
5. Fields — one by one:

For each field:
- **[Text]** Field name? (camelCase)
- **[Text]** Field label? (en/fr for i18n)
- **[AskUserQuestion]** Field type + Required — **batched in one call** (2 questions):

```
AskUserQuestion (batch 2 questions):
  Question 1:
    header: "Type"
    question: "What is the type of the field '{fieldName}'?"
    options:
      - label: "string"
        description: "VARCHAR(255) — text, email, url..."
      - label: "int"
        description: "INT — whole number"
      - label: "boolean"
        description: "SMALLINT — true/false"
      - label: "longtext"
        description: "LONG VARCHAR — long text, description"
  Question 2:
    header: "Required"
    question: "Is the field '{fieldName}' required?"
    options:
      - label: "Yes"
        description: "Field must have a value"
      - label: "No"
        description: "Field is optional"
```

> **Note:** If the user selects "Other" for type, accept any of: `long`, `double`, `float`, `timestamp`, `date`, `time`, `decimal`, `file`. Warn if the type is not in the supported list.

After each field — **[AskUserQuestion]**:

```
AskUserQuestion:
  header: "Next field"
  question: "Add another field to '{EntityName}'?"
  options:
    - label: "Yes"
      description: "Define the next field"
    - label: "No"
      description: "Done with fields for this entity"
```

After each entity — **[AskUserQuestion]**:

```
AskUserQuestion:
  header: "Next entity"
  question: "Add another entity?"
  options:
    - label: "Yes"
      description: "Define a new entity"
    - label: "No"
      description: "Move on to feature selection"
```

### Sub-Entity Support (Parent-Child Relations)

When an entity has a `parentEntity`, the scaffold automatically generates:

**Business Layer:**
- FK field `idParent` in the child entity (e.g., `idProject` for Task)
- `IEntityDAO`: `selectByParentId()`, `deleteByParentId()`
- `EntityDAO`: Implementation with SQL queries
- `EntityHome`: `findByParentId()`, `removeByParentId()`

**Service Layer (like forms plugin):**
- `EntityService`: Orchestrates cascade deletes
- `@Transactional` support for data integrity
- Recursive cascade through entity hierarchy

**Web Layer:**
- JSPBean: Filters list by parent, passes parent context
- Templates: Breadcrumb navigation, links to children
- i18n: Labels for child entity buttons

**Example Hierarchy:**
```
Project (parent)
└── Task (parentEntity: "Project")
    └── Comment (parentEntity: "Task")
```

When deleting a Project:
1. ProjectService.remove() is called
2. It calls TaskService.remove() for each Task
3. TaskService.remove() calls CommentService.remove() for each Comment
4. Then deletes the Task
5. Then deletes the Project

## Phase 3: Optional Features

### Step 1: Feature selection — **[AskUserQuestion multiSelect]**

Ask all features in a single multi-select question:

```
AskUserQuestion:
  header: "Features"
  question: "Which optional features do you want to enable?"
  multiSelect: true
  options:
    - label: "XPage"
      description: "Front-office page for the first entity"
    - label: "Cache"
      description: "Shared cache service for all entities"
    - label: "RBAC"
      description: "Role-based permissions (CREATE, MODIFY, DELETE...)"
    - label: "Site"
      description: "Test site with database configuration"
```

> **Workflow** is asked separately (next question) because the max is 4 options:

```
AskUserQuestion:
  header: "Workflow"
  question: "Do you want to integrate with the workflow system?"
  options:
    - label: "Yes"
      description: "Generate a separate workflow module with tasks"
    - label: "No"
      description: "No workflow integration"
```

### Step 2: Feature details (only for selected features)

**If XPage selected:**
- **[Text]** XPage name? (e.g., "mytasks")
- **[Text]** XPage title? (en/fr)

**If RBAC selected — [AskUserQuestion multiSelect]:**

```
AskUserQuestion:
  header: "Permissions"
  question: "Which RBAC permissions do you want?"
  multiSelect: true
  options:
    - label: "CREATE"
      description: "Permission to create resources"
    - label: "MODIFY"
      description: "Permission to modify resources"
    - label: "DELETE"
      description: "Permission to delete resources"
    - label: "VIEW"
      description: "Permission to view resources"
```

**If Site selected:**

Display the default credentials table, then use **[AskUserQuestion]** to confirm:

```
Database configuration for the test site:

| Parameter | Value |
|-----------|-------|
| Host      | localhost |
| Port      | 3306 |
| Database  | lutece_{pluginName} |
| User      | root |
| Password  | ??? |
```

```
AskUserQuestion:
  header: "DB Config"
  question: "Are these database settings correct?"
  options:
    - label: "Yes, confirm"
      description: "Use the values shown above"
    - label: "No, modify"
      description: "I want to change some values"
```

**IMPORTANT:**
- ALWAYS display this table BEFORE the AskUserQuestion
- If the user selects "No, modify", ask which values to change in **text mode**
- NEVER generate the site without credentials confirmation

The workflow module generates:
- A separate `module-workflow-{pluginName}` module
- For each entity: a state change task (TaskXxxStateChange)
- CDI configuration with producers (@Produces ITaskType, ITaskConfigService)
- Configuration, form and information templates
- FR/EN i18n for tasks

**Generated structure:**
```
module-workflow-{pluginName}/
├── src/java/.../workflow/modules/{pluginName}/
│   ├── business/
│   │   ├── Task{Entity}StateChangeConfig.java
│   │   └── Task{Entity}StateChangeConfigDAO.java
│   ├── service/
│   │   ├── Task{Entity}StateChange.java (extends SimpleTask)
│   │   ├── TaskType{Entity}StateChangeProducer.java (@Produces ITaskType)
│   │   └── Task{Entity}StateChangeConfigServiceProducer.java
│   └── web/
│       └── {Entity}StateChangeTaskComponent.java
├── webapp/WEB-INF/
│   ├── conf/plugins/workflow-{pluginName}.properties
│   ├── plugins/workflow-{pluginName}.xml
│   └── templates/admin/plugins/workflow/modules/{pluginName}/
│       ├── task_{entity}_statechange_config.html
│       ├── task_{entity}_statechange_form.html
│       └── task_{entity}_statechange_information.html
└── src/sql/plugins/workflow/modules/create_db_workflow-{pluginName}.sql
```

## Phase 4: Generation

1. Build JSON config from answers
2. Write config to `/tmp/{pluginName}-config.json`
3. Run: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/lutece-scaffold.sh" <config> <output>`
4. Show summary of generated files

### JSON Config Format

```json
{
  "pluginName": "taskmanager",
  "pluginDescription": {
    "en": "Task management plugin",
    "fr": "Plugin de gestion des tâches"
  },
  "packageBase": "fr.paris.lutece.plugins.taskmanager",
  "features": {
    "xpage": { "enabled": true, "name": "mytasks", "title": { "en": "My Tasks", "fr": "Mes tâches" } },
    "cache": { "enabled": true },
    "rbac": { "enabled": true, "permissions": ["CREATE", "MODIFY", "DELETE", "VIEW"] },
    "site": { "enabled": true, "name": "site-taskmanager", "database": { "host": "localhost", "port": 3306, "name": "lutece_taskmanager", "user": "root", "password": "<CONFIRM WITH USER>" } },
    "workflow": { "enabled": true }
  },
  "entities": [
    {
      "name": "Project",
      "label": { "en": "Project", "fr": "Projet" },
      "tableName": "taskmanager_project",
      "fields": [
        { "name": "name", "type": "string", "required": true, "label": { "en": "Name", "fr": "Nom" } },
        { "name": "description", "type": "longtext", "required": false, "label": { "en": "Description", "fr": "Description" } }
      ]
    },
    {
      "name": "Task",
      "label": { "en": "Task", "fr": "Tâche" },
      "tableName": "taskmanager_task",
      "parentEntity": "Project",
      "fields": [
        { "name": "title", "type": "string", "required": true, "label": { "en": "Title", "fr": "Titre" } },
        { "name": "completed", "type": "boolean", "required": true, "label": { "en": "Completed", "fr": "Terminée" } }
      ]
    }
  ]
}
```

### Field Types

| Type | Java | SQL |
|------|------|-----|
| string | String | VARCHAR(255) |
| longtext | String | LONG VARCHAR |
| int, number | int | INT |
| long | long | BIGINT |
| boolean | boolean | SMALLINT |
| double | double | DOUBLE |
| timestamp | Timestamp | TIMESTAMP |
| date | Date | DATE |

### Generated Files

**Base:**
- `plugin-{name}/pom.xml`, `beans.xml`
- `{Entity}.java`, `I{Entity}DAO.java`, `{Entity}DAO.java`, `{Entity}Home.java`
- `{Entity}Service.java` - Service layer with cascade support
- `{Entity}JspBean.java` (with `@SessionScoped`, `@Named` — `@SessionScoped` because the scaffold generates pagination instance fields)
- `manage_{entity}s.html`, `create_{entity}.html`, `modify_{entity}.html`
- `Manage{Entity}s.jsp`
- `{plugin}_messages.properties`, `_en.properties`, `_fr.properties`
- `create_db_{plugin}.sql`, `{plugin}.xml`

**For Child Entities:**
- FK field `idParent` auto-generated
- Index on FK column in SQL
- `findByParentId()`, `removeByParentId()` methods
- Breadcrumb navigation in templates
- Parent context in JSPBean

**If XPage:** `{Plugin}XPage.java`, `list_{entity}s.html` (skin)

**If Cache:** `service/cache/{Plugin}CacheService.java`

**If RBAC:** `service/{Plugin}ResourceIdService.java`, `service/{Plugin}Plugin.java`

**If Site:** `sites/{site-name}/` with DB config

**If Workflow:** `module-workflow-{plugin}/` with Task, Producer, Component, Templates, SQL

## Example Flow

```
User: /lutece-scaffold

── Phase 1 ──
Assistant: Plugin name? (lowercase, no spaces)
User: taskmanager
Assistant: Description? (en/fr)
User: Task manager / Gestionnaire de tâches
Assistant: [AskUserQuestion: "Output dir" → "Current directory", "~/dev/lutece"]
User: selects "Current directory"

── Phase 2: Entity "Project" ──
Assistant: First entity name? (PascalCase)
User: Project
Assistant: Label? (en/fr)
User: Project / Projet
  (no parent question — first entity)
Assistant: First field name?
User: name
Assistant: Label? (en/fr)
User: Name / Nom
Assistant: [AskUserQuestion batch:
    "Type" → string ✓ / int / boolean / longtext
    "Required" → Yes ✓ / No]
User: selects "string" + "Yes"
Assistant: [AskUserQuestion: "Next field" → Yes / No]
User: selects "Yes"
Assistant: Field name?
User: description
Assistant: Label? (en/fr)
User: Description / Description
Assistant: [AskUserQuestion batch: "Type" → longtext ✓, "Required" → No ✓]
Assistant: [AskUserQuestion: "Next field" → Yes / No]
User: selects "No"
Assistant: [AskUserQuestion: "Next entity" → Yes / No]
User: selects "Yes"

── Phase 2: Entity "Task" ──
Assistant: Entity name?
User: Task
Assistant: Label? (en/fr)
User: Task / Tâche
Assistant: [AskUserQuestion: "Parent" → "None" / "Project"]
User: selects "Project"
Assistant: Field name?
User: title
Assistant: Label? (en/fr)
User: Title / Titre
Assistant: [AskUserQuestion batch: "Type" → string ✓, "Required" → Yes ✓]
Assistant: [AskUserQuestion: "Next field" → Yes / No]
User: selects "Yes"
Assistant: Field name?
User: completed
Assistant: Label? (en/fr)
User: Completed / Terminée
Assistant: [AskUserQuestion batch: "Type" → boolean ✓, "Required" → Yes ✓]
Assistant: [AskUserQuestion: "Next field" → Yes / No]
User: selects "No"
Assistant: [AskUserQuestion: "Next entity" → Yes / No]
User: selects "No"

── Phase 3 ──
Assistant: [AskUserQuestion multiSelect: "Features"
    → XPage ✓, Cache ✓, RBAC ✓, Site ✓]
User: selects all four
Assistant: [AskUserQuestion: "Workflow" → Yes ✓ / No]
User: selects "Yes"
Assistant: XPage name?
User: mytasks
Assistant: XPage title? (en/fr)
User: My Tasks / Mes tâches
Assistant: [AskUserQuestion multiSelect: "Permissions"
    → CREATE ✓, MODIFY ✓, DELETE ✓, VIEW ✓]
User: selects all four
Assistant: (displays DB credentials table)
Assistant: [AskUserQuestion: "DB Config" → "Yes, confirm" / "No, modify"]
User: selects "No, modify"
Assistant: Which values to change?
User: password = root
Assistant: Updated. Confirmed.

── Phase 4 ──
Scaffold generated!
- Plugin: plugin-taskmanager/
- Entity: Project (2 fields)
- Entity: Task (2 fields) → child of Project
- XPage: mytasks
- Cache: TaskmanagerCacheService
- RBAC: 4 permissions
- Site: site-taskmanager
- Workflow: module-workflow-taskmanager/

Next steps:
1. cd plugin-taskmanager && mvn clean install
2. cd module-workflow-taskmanager && mvn clean install
3. cd sites/site-taskmanager && mvn lutece:site-assembly
4. cd target/site-taskmanager-1.0.0-SNAPSHOT/WEB-INF/sql && ant
5. cd ../../../.. && mvn liberty:dev

What specific features do you want to develop?
```

## Phase 5: Feature Planning

After scaffold generation, ask: **"What specific features do you want to develop?"**

**IMPORTANT:** Before developing any feature:
1. **Search `~/.lutece-references/`** for real implementation patterns (Read/Grep/Glob on the reference repos)
3. Write a plan in `docs/plans/YYYY-MM-DD-<feature>.md`
4. Validate the plan BEFORE coding

## Scaffold Limitations

**IMPORTANT:** The scaffold has a defined scope. When the user requests something outside this scope, you MUST clearly inform them and offer Phase 5 (post-scaffold development) as an alternative.

### Features supported by the scaffold

| Feature | Supported | Details |
|---------|-----------|---------|
| Admin CRUD (JSPBean) | Yes | For all entities |
| XPage (front-office) | Yes | **First entity only** (list view) |
| Cache | Yes | Shared CacheService for all entities |
| RBAC | Yes | Permissions on the first entity |
| Test site | Yes | With DB config |
| Workflow | Yes | Separate module, tasks for root entities |
| Parent-child relations (1-N) | Yes | Cascade delete via Service |

### What the scaffold does NOT support

If the user requests any of these features, **clearly inform them** that the scaffold does not generate it, then offer to develop it in Phase 5:

| Request | Response to give |
|---------|-----------------|
| REST API | "The scaffold does not generate a REST API. I can develop it in Phase 5 after generation." |
| Many-to-many relations | "The scaffold only supports parent-child relations (1-N). For N-N, I will create the junction table manually in Phase 5." |
| Search / Lucene | "Lucene indexing is not generated. Use `/lutece-lucene-indexer` after the scaffold." |
| Unit tests | "The scaffold creates the test structure but not the test files. I can write them in Phase 5." |
| Bean Validation (JSR-303) | "Server-side validation is not generated. To be added manually in Phase 5." |
| Import/Export (CSV, batch) | "Not supported by the scaffold. Phase 5." |
| Multiple admin features | "The scaffold generates a single admin feature pointing to the first entity. Other entities are accessible via parent-child navigation or Phase 5." |
| Enum fields | "The `enum` type does not exist in the scaffold. Use `int` or `string` and handle the enum in Phase 5." |
| Computed / virtual fields | "Not supported. To be implemented in the Service in Phase 5." |
| Multiple file upload | "The scaffold handles one `file` field (type `File`) per entity but not multi-upload. Phase 5." |

### Supported field types

Recognized types are: `string`, `longtext`, `int`, `long`, `boolean`, `double`, `float`, `timestamp`, `date`, `time`, `decimal`, `file`.

**WARNING — Silent fallback:** Any unrecognized type (e.g., `email`, `url`, `json`, `enum`, `uuid`) will be silently converted to `String / VARCHAR(255)`. You MUST warn the user if the requested type is not in the list above:

> "The type `{type}` is not recognized by the scaffold and will be treated as `string` (VARCHAR 255). If you need specific behavior (validation, format), we will add it in Phase 5."

### XPage: first entity limitation

The generated XPage only covers the first entity of the plugin (list view with pagination). If the user wants front-office pages for other entities, inform them:

> "The XPage is generated only for the `{firstEntity}` entity. For other entities, I will develop additional views in Phase 5."

## Key Principles

- **AskUserQuestion for choices** - Use structured UI for all yes/no, selections, and confirmations
- **Text for custom input** - Names, descriptions, labels stay free-form
- **One step at a time** - Do not overwhelm; respect the phase flow
- **Accept shortcuts** - "title:string:Title" = field with type and EN label
- **Smart defaults** - Minimize input
- **Inform on limits** - Always warn if a request falls outside scaffold scope
- **i18n from the start** - Always ask for en/fr
- **Parent-child support** - Ask for parent entity for each entity
- **Service layer** - Cascade is handled at the service level, not SQL
- **Rules auto-loaded** - `.claude/rules/` constraints apply automatically when touching relevant files
