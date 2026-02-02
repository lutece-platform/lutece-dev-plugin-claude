# Phase 0: Project Scan & Migration Plan

## Step 1 — Run the scanner

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/scan-project.sh"
```

Read the entire output. It gives you:
- Project type, artifact, version, parent version
- Per-file analysis of all Java files (imports, Spring lookups, getInstance calls, class types)
- Context XML files and their bean definitions
- Template inventory (admin/skin, jQuery presence, v8 macros)
- JSP files (useBean, scriptlets, EL)
- SQL files (Liquibase headers)
- REST endpoints
- Summary counts and migration scope assessment

## Step 2 — Dependency v8 verification (BLOCKER)

For each **Lutece dependency** found in `pom.xml` (groupId `fr.paris.lutece.*`):

1. **Check `~/.lutece-references/`** — If the repo is already cloned, read its `pom.xml` to confirm `<parent><version>` is `8.0.0-SNAPSHOT`
2. **If not found locally, search GitHub** — Search `lutece-platform` and `lutece-secteur-public` orgs
3. **Find the v8 branch** — Priority: `develop_core8` > `develop8` > `develop8.x` > `develop`
4. **Verify v8 compatibility** — Fetch the remote `pom.xml` and check parent version is `8.0.0-SNAPSHOT`
5. **Read the v8 version** — Extract `<version>` from the dependency's v8 pom.xml. This is the version to use in Phase 1
6. **Clone into `~/.lutece-references/`** for later exploration

### If a dependency has NO v8 version

**STOP.** Do not proceed to Phase 1. Inform the user:

> Dependency `{artifactId}` has no Lutece 8 version. It must be migrated to v8 first before this plugin can be migrated.

Ask the user how to proceed (skip dependency, migrate it first, or provide a local path).

## Step 3 — Produce the migration plan

Based on the scan output, produce a structured migration plan:

1. **Script-handled** (mechanical, Phase 2 Step 1):
   - Number of javax imports to replace (replace-imports.sh)
   - Number of Spring annotations to replace (replace-spring-simple.sh)

2. **Claude-handled** (intelligent, Phase 2 Steps 2-9):
   - Context XML beans to migrate → CDI annotations or Producers
   - SpringContextService calls → CDI lookup (list each with target type)
   - getInstance() calls → @Inject or CDI.current().select()
   - Event listeners to migrate → @Observes
   - Cache services to migrate
   - JspBean/XPage scope decisions
   - Plugin.init() cleanup

3. **Dependency version map**: artifactId → v8 version (for Phase 1)

4. **Relevant patterns**: which pattern files from `patterns/` apply to this project:
   - `cdi-patterns.md` — always
   - `events-patterns.md` — only if event listeners detected
   - `cache-patterns.md` — only if cache services detected
   - `deprecated-api.md` — only if getInstance() calls detected

## Verification

1. The migration plan covers ALL items from the scan output
2. ALL Lutece dependencies have a confirmed v8 version
3. Mark task as completed ONLY when the plan is complete and all dependencies are resolved
