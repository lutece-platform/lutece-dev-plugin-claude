---
name: lutece-migration-v8-agent-teams
description: "Migration v7 → v8 via Agent Teams. Parallel teammates, script-heavy, JSON-driven task decomposition."
user-invocable: true
---

# Lutece Migration v7→v8 — Agent Teams Orchestrator

## Purpose

Migrates any Lutece plugin/module/library from v7 to v8 using **Agent Teams (Swarm Mode)**. The Team Lead (you) orchestrates, specialized teammates execute in parallel, and bash scripts handle all mechanical work.

**Prerequisites:** Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`).

---

## PHASE A — Scan (Lead executes directly)

### A.1 — Verify Lutece project
Confirm the current directory is a Lutece project (pom.xml with lutece-plugin/module/library packaging).

### A.2 — Run scanner
```bash
mkdir -p .migration
bash ${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/scripts/scan-project.sh . > .migration/scan.json
```

### A.3 — Display summary
Read `.migration/scan.json` and show the user:
- Project type, artifact, version
- Migration scope (SMALL/MEDIUM/LARGE)
- Total migration points
- Recommended teammate count

### A.4 — Dependency v8 check (BLOCKER)
For every Lutece dependency in `scan.json`:
1. If `v8Status: "available"` → OK (already cloned in `~/.lutece-references/`)
2. If `v8Status: "unknown"` → Search GitHub orgs `lutece-platform` and `lutece-secteur-public` for v8 branch
3. Branch priority: `develop_core8` > `develop8` > `develop8.x` > `develop`
4. If a dependency has NO v8 version → **STOP**. Do not proceed. Report to user.
5. **Clone missing dependencies** — For each dependency confirmed v8 but not yet in `~/.lutece-references/`:
   ```bash
   git clone -q --branch <v8_branch> --single-branch https://github.com/<org>/<artifactId>.git ~/.lutece-references/<artifactId>
   ```
   This ensures teammates can search reference sources for ALL dependencies, not just the 21 pre-cloned repos.

---

## PHASE B — Task Decomposition (Lead executes directly)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/scripts/task-splitter.sh .migration/scan.json .migration
```

Read the output to know how many teammates to spawn.

---

## PHASE C — Spawn Teammates

Switch to **Delegate Mode** (Shift+Tab). From this point, you orchestrate only — never implement.

### Always spawn:
1. **Config Migrator** (1 teammate)
   - Instructions: `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/teammates/config-migrator.md`
   - Task file: `.migration/tasks-config.json`

2. **Verifier** (1 teammate)
   - Instructions: `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/teammates/verifier.md`
   - Starts monitoring immediately, builds only after all others complete

### Conditionally spawn:
3. **Java Migrator(s)** (1-3, based on `scan.json` recommendation)
   - Instructions: `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/teammates/java-migrator.md`
   - Task files: `.migration/tasks-java-0.json`, `.migration/tasks-java-1.json`, `.migration/tasks-java-2.json`
   - Each gets a DISTINCT file partition — no overlap

4. **Template Migrator** (0-1, if templates/JSP exist)
   - Instructions: `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/teammates/template-migrator.md`
   - Task file: `.migration/tasks-template.json`

5. **Test Migrator** (0-1, if test files exist)
   - Instructions: `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/teammates/test-migrator.md`
   - Task file: `.migration/tasks-test.json`

### Spawn instructions template
When spawning each teammate, provide:
```
Read your instruction file at [path to teammates/*.md].
Read your task assignment at [path to .migration/tasks-*.json].
Execute all steps in your instructions. Use scripts from ${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/scripts/.
Pattern files are at ${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/patterns/ — load only when needed.
Reference implementations: always search ~/.lutece-references/ before writing any new pattern.
Migration samples with real before/after diffs: ${CLAUDE_PLUGIN_ROOT}/migrations-samples/ — consult when stuck on a specific migration pattern.
Run verify-file.sh after each file you complete.
```

---

## PHASE D — Task Dependencies

Wire the dependency graph:

```
Config Migrator ──────────────────────────────────────── (no blockers, runs first)
    │
    ├──→ Java Migrator 0 ─┐
    ├──→ Java Migrator 1 ─┤ (blocked by Config Migrator)
    └──→ Java Migrator 2 ─┘
              │
              ├──→ Template Migrator ─┐ (blocked by ALL Java Migrators)
              └──→ Test Migrator ─────┤ (blocked by Config + at least 1 Java Migrator)
                                      │
                                      └──→ Verifier: Final Build (blocked by ALL above)
```

- Config Migrator runs first (POM, beans.xml, context XML catalog)
- Java Migrators start after Config completes (they need context-beans.json)
- Template Migrator starts after ALL Java Migrators complete (needs @Named bean names)
- Test Migrator starts after Config + at least 1 Java Migrator complete
- Verifier monitors continuously but only builds after ALL others complete

---

## PHASE E — Monitoring

While teammates work:

1. Check task list progress every ~30 seconds
2. Run progress report periodically:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/scripts/progress-report.sh .
   ```
3. **If a teammate is stuck** (same task > 5 min): send a message via mailbox asking for status
4. **If a teammate reports a blocker**: investigate and either reassign, advise, or fix the blocker
5. **If the Verifier reports increasing FAILs**: pause the responsible teammate and investigate

---

## PHASE F — Final Gate

When the Verifier reports ALL of the following (it must have completed through Phase 5):
- **BUILD SUCCESS** (both compile and tests)
- **verify-migration.sh**: 0 FAIL
- **Reviewer agent**: all FAIL items resolved (the Verifier runs this in Phase 5 — do NOT conclude before it completes)

Then:
1. Ask the Verifier to run final cleanup (.migration/ removal, context XML deletion)
2. Present the migration summary to the user:
   - `verify-migration.sh` results (PASS/FAIL/WARN counts)
   - Build result (`mvn clean install` — compile + tests)
   - Number of test classes, tests run, tests passed/failed/skipped
   - Reviewer agent verdict (PASS/FAIL/WARN counts)
   - List of files modified
3. Clean up the team
4. **STOP.** Do NOT commit. The user decides when and how to commit.

---

## Strict Rules

1. **Delegate mode**: After Phase B, the Lead orchestrates only — never modifies files
2. **No builds before completion**: The project WILL NOT compile during migration. Only the Verifier builds.
3. **NEVER commit**: The skill must NEVER create git commits. Leave that to the user.
4. **Reference-First Rule**: ALL teammates must search `~/.lutece-references/` before writing new patterns
5. **File ownership**: Each file is owned by exactly one teammate. No two teammates touch the same file.
6. **Script-first**: Teammates run mechanical scripts FIRST, then apply intelligence to remaining issues
7. **Verify per-file**: Teammates run `verify-file.sh` after each file, not just at the end

---

## Script Locations

All in `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/scripts/`:

| Script | Purpose | Used by |
|--------|---------|---------|
| `scan-project.sh` | Full project scan → JSON | Lead (Phase A) |
| `task-splitter.sh` | JSON scan → per-teammate task files | Lead (Phase B) |
| `migrate-java-mechanical.sh` | javax→jakarta + Spring→CDI on file list | Java Migrators |
| `migrate-template-mechanical.sh` | BO macros + null-safety + namespace | Template Migrator |
| `extract-context-beans.sh` | Spring context XML → JSON catalog | Config Migrator |
| `verify-migration.sh` | 70+ checks, optional --json mode | Verifier |
| `verify-file.sh` | Per-file verification subset | All teammates |
| `add-liquibase-headers.sh` | Liquibase headers on SQL files | Config Migrator |
| `progress-report.sh` | Migration progress display | Lead (Phase E) |

## Pattern Locations

All in `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8-agent-teams/patterns/`:

| File | Content | Loaded by |
|------|---------|-----------|
| `cdi-patterns.md` | CDI scopes, injection, producers, Models, Pager, RedirectScope | Java Migrators (always) |
| `events-patterns.md` | Event/listener migration | Java Migrators (if events) |
| `cache-patterns.md` | EhCache→JCache | Java Migrators (if cache) |
| `deprecated-api.md` | getInstance, getModel table | Java Migrators (ALWAYS for JspBean/XPage — getModel() migration is MANDATORY) |
| `mvc-patterns.md` | @RequestParam, CSRF auto-filter, @ModelAttribute | Java Migrators (if JspBean/XPage) |
| `template-macros.md` | v8 Freemarker macro quick reference | Template Migrator |
| `fileupload-patterns.md` | FileItem→MultipartItem | Java Migrators (if fileupload) |

## Key Imports Reference

```java
// CDI Core
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.context.RequestScoped;
import jakarta.enterprise.context.SessionScoped;
import jakarta.enterprise.context.Dependent;
import jakarta.enterprise.inject.spi.CDI;
import jakarta.enterprise.inject.Instance;
import jakarta.enterprise.inject.Produces;
import jakarta.enterprise.inject.literal.NamedLiteral;
import jakarta.inject.Inject;
import jakarta.inject.Named;

// CDI Events
import jakarta.enterprise.event.Observes;
import jakarta.enterprise.context.Initialized;

// Lifecycle
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;

// Servlet
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

// REST
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.*;

// Config
import org.eclipse.microprofile.config.inject.ConfigProperty;

// Cache — NOTE: javax, NOT jakarta
import javax.cache.Cache;
```
