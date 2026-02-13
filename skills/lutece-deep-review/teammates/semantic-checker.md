# Semantic V8 Checker — Teammate Instructions

You are the **Semantic V8 Checker** teammate. You perform the 13 AI-only semantic checks that verify-migration.sh cannot do. These require reading code, understanding context, and comparing against reference implementations.

## Your Scope

- All Java source files in `src/java/` (not tests)
- All template files in `webapp/WEB-INF/templates/`
- All JavaScript files referenced by templates
- Reference implementations in `~/.lutece-references/`

**You NEVER modify source files.** Read-only.

---

## Reference Sources (Living Truth)

- **Lutece Core v8:** `~/.lutece-references/lutece-core/`
- **Forms plugin v8:** `~/.lutece-references/lutece-form-plugin-forms/`
- **Appointment plugin v8:** `~/.lutece-references/gru-plugin-appointment/`
- **All references:** `~/.lutece-references/` — search for matching patterns before flagging

**Reference-First Rule:** Before flagging a divergence, search references for the same pattern. If a reference project does it the same way, it's not a bug.

---

## Step 1: Read Scan Data

Read `.review/scan.json` to understand the project inventory (file types, class types, flags).

## Step 2: Build Reflection-Instantiated Class List

Parse `webapp/WEB-INF/plugins/*.xml` and extract fully-qualified class names from:
`<content-service-class>`, `<search-indexer-class>`, `<rbac-resource-type-class>`, `<filter-class>`, `<servlet-class>`, `<listener-class>`, `<page-include-service-class>`, `<dashboard-component-class>`, `<application-class>`

These classes are NOT CDI-managed. Save this list — needed for S1.

## Step 3: Execute Semantic Checks (S1–S13)

Create a task list and work through each check:

### S1. CDI Scope Correctness

**S1a. DAO classes** — Must be `@ApplicationScoped`. Flag `@RequestScoped` or `@SessionScoped` on DAOs.

**S1b. Service classes** — Before flagging missing `@ApplicationScoped`:
1. Check if class is in the reflection-instantiated list → skip
2. Check if class is a static facade (private constructor + all static methods) → skip
3. Check if class is old singleton (getInstance + static field) → skip
4. Only then flag missing scope

**S1c. JspBean/XPage classes:**
- Missing CDI scope → WARN
- `@SessionScoped` but no session-state instance fields → WARN: should be `@RequestScoped`
- `@RequestScoped` but has session-state instance fields (`_strCurrentPageIndex`, filters, working objects) → WARN: should be `@SessionScoped`

### S2. Singleton Patterns

For each `getInstance()` method:
- Body is `CDI.current().select().get()` → WARN (deprecated wrapper)
- Body is old singleton (static field + new) → FAIL (must migrate)

### S3. CDI Injection vs Static Lookup

- `CDI.current().select()` in a CDI-managed class to get another CDI bean → WARN (prefer `@Inject`)
- `CDI.current().select()` in static context (Home, utility) → PASS (only option)

### S4. CDI Producers Quality

For each `@Produces` method, search `~/.lutece-references/` for producers of the same type. Compare and flag divergence.
- Produces a class that could be `@ApplicationScoped` directly → WARN
- Hardcoded `@Named("literal")` → WARN (use `@ConfigProperty`)

### S5. Cache Service Defensive Guards

For each class extending `AbstractCacheableService`:
- Missing `isCacheEnable() && isCacheAvailable()` guards on put/get/remove → WARN
Reference: `FormsCacheService` in forms plugin

### S6. IDE Diagnostics (Optional)

If `mcp__ide__getDiagnostics` is available, collect errors/warnings for Java files. If not available, mark N/A.

### S7. Models Injection

- `getModel()` calls in JspBean/XPage → FAIL (use `Models` parameter or `@Inject Models`)
- `new HashMap` used as model in MVC bean → FAIL

### S8. Captcha CDI Pattern

- `new CaptchaSecurityService()` → FAIL (use `@Inject Instance<ICaptchaService>`)
- `captchaService.isAvailable()` → FAIL (use `isResolvable()`)
- No captcha usage → N/A

### S9. Event/Listener CDI Migration

- `*ListenerManager` class exists → FAIL
- `SpringContextService.getBeansOfType(I*Listener.class)` → FAIL
- `ResourceEventManager.register()/.fire()` → FAIL
- Old `I*Listener` interface with no implementations → WARN (dead code)

### S10. Pagination Modernization

- `_strCurrentPageIndex` / `_nItemsPerPage` instance fields → WARN (use `@Inject @Pager IPager`)
- `new LocalizedPaginator<>()` or `new Paginator<>()` → WARN

### S11. Template Message Patterns

- `${error}` without `.message` inside `<#list errors as error>` → FAIL
- `${error.message}` → PASS

### S12. ConfigProperty vs AppPropertiesService

- `AppPropertiesService.getProperty()` in CDI bean where `@ConfigProperty` would work → WARN
- `@ConfigProperty` in non-CDI class → FAIL (won't be injected)

### S13. jQuery → Vanilla JS

- jQuery usage without plugin dependency → WARN (convert to vanilla ES6)
- jQuery required by jQuery plugin (DataTables, Select2, etc.) → PASS

---

## Output Format

Write `.review/semantic-checks.json`:

```json
{
  "summary": {
    "total": 13,
    "pass": 0,
    "fail": 0,
    "warn": 0,
    "na": 0
  },
  "checks": [
    {
      "id": "S1",
      "name": "CDI Scope Correctness",
      "status": "PASS|FAIL|WARN|N/A",
      "issueCount": 0,
      "findings": [
        {
          "severity": "WARN",
          "file": "src/java/.../MyService.java",
          "line": 25,
          "finding": "Service class without @ApplicationScoped",
          "expected": "Add @ApplicationScoped"
        }
      ]
    }
  ]
}
```

---

## Execution Strategy

1. Read `.review/scan.json` for project inventory
2. Build the reflection-instantiated class list (Step 2)
3. Work through S1–S13 sequentially, marking each task as you go
4. For each check, read relevant files and compare against references
5. Write `.review/semantic-checks.json`

### Key Rules

- Do NOT re-check patterns already covered by `verify-migration.sh` (javax, Spring imports, etc.) — those are in `.review/script-results.json`
- Use FAIL for things that break compilation or runtime
- Use WARN for best-practice violations
- Use N/A when a category doesn't apply
- Always include file path and line number
- Always search `~/.lutece-references/` before flagging divergence

## Step Final: Mark Complete

After writing `.review/semantic-checks.json`, mark your task as completed and notify the Lead.
