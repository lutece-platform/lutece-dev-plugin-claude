---
name: lutece-migration-v8
description: "Migration guide v7 → v8 (Spring → CDI/Jakarta). Script-accelerated with Task-based execution."
user-invocable: true
---

# Lutece Migration v7 to v8 — Orchestrator

## Purpose

Migrates any Lutece plugin/module/library from v7 to v8. Uses **bash scripts** for mechanical work (imports, verification) and **Claude intelligence** for the rest (CDI scopes, producers, events, templates).

**MIGRATION SAMPLES:** Real migration examples (v7 → v8 diffs) available at `${CLAUDE_PLUGIN_ROOT}/migrations-samples/`. Consult when needed.

---

## EXECUTION STRATEGY

### Step 1 — Create 7 tasks

```
TaskCreate({ subject: "Phase 0: Project scan", description: "Read phases/phase-0-scan.md then execute. Run scan-project.sh, verify deps, produce migration plan.", activeForm: "Scanning project..." })

TaskCreate({ subject: "Phase 1: POM migration", description: "Read phases/phase-1-pom.md then execute. Update parent, deps, versions.", activeForm: "Migrating POM..." })

TaskCreate({ subject: "Phase 2: Java migration", description: "Read phases/phase-2-java.md then execute. Scripts + Claude for all Java code.", activeForm: "Migrating Java code..." })

TaskCreate({ subject: "Phase 3: Web & config", description: "Read phases/phase-3-web.md then execute. web.xml, plugin.xml, beans.xml, SQL.", activeForm: "Migrating web config..." })

TaskCreate({ subject: "Phase 4: UI migration", description: "Read phases/phase-4-ui.md then execute. JSP, templates, JavaScript.", activeForm: "Migrating UI..." })

TaskCreate({ subject: "Phase 5: Test migration", description: "Read phases/phase-5-tests.md then execute. JUnit 4→5.", activeForm: "Migrating tests..." })

TaskCreate({ subject: "Phase 6: Build & review", description: "Read phases/phase-6-build.md then execute. Build, verify, reviewer agent.", activeForm: "Building & reviewing..." })
```

### Step 2 — Wire dependencies (use actual task IDs)

```
TaskUpdate({ taskId: "<phase1>", addBlockedBy: ["<phase0>"] })
TaskUpdate({ taskId: "<phase2>", addBlockedBy: ["<phase1>"] })
TaskUpdate({ taskId: "<phase3>", addBlockedBy: ["<phase2>"] })
TaskUpdate({ taskId: "<phase4>", addBlockedBy: ["<phase2>"] })
TaskUpdate({ taskId: "<phase5>", addBlockedBy: ["<phase2>"] })
TaskUpdate({ taskId: "<phase6>", addBlockedBy: ["<phase3>", "<phase4>", "<phase5>"] })
```

Phases 3, 4, 5 can run in parallel after Phase 2. Phase 6 waits for all three.

---

## Phase Execution Protocol

For each phase:
1. **Read the phase file**: `Read` the file `phases/phase-N-name.md` from this skill's directory
2. `TaskUpdate` → set status to `in_progress`
3. Execute ALL steps described in the phase file
4. Run the **verification** described at the end of the phase file
5. If verification fails → fix errors, re-run verification until it passes
6. `TaskUpdate` → set status to `completed` ONLY when verification passes
7. Output the phase report
8. Check `TaskList` → pick next unblocked task → go to step 1

---

## Script Locations

All scripts in `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/`:

| Script | Purpose | Used in |
|--------|---------|---------|
| `scan-project.sh` | Full project scan → structured inventory | Phase 0 |
| `replace-imports.sh` | javax→jakarta mass sed replacement | Phase 2 |
| `replace-spring-simple.sh` | Mechanical Spring→CDI annotation replacements | Phase 2 |
| `verify-migration.sh` | All 30 grep checks → structured PASS/FAIL report | Phase 2, 3, 4, 6 |
| `add-liquibase-headers.sh` | Liquibase headers on SQL files | Phase 3 |

---

## Pattern Reference Locations

All patterns in `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/patterns/`:

| File | Content | Read when |
|------|---------|-----------|
| `cdi-patterns.md` | Spring→CDI scopes, injection, producers, REST, config, logging | Always (Phase 2) |
| `events-patterns.md` | Event/listener migration patterns | If events detected (Phase 2) |
| `cache-patterns.md` | EhCache→JCache migration | If cache detected (Phase 2) |
| `deprecated-api.md` | getInstance()→@Inject table, Models injection | If deprecated calls detected (Phase 2) |

---

## Build Verification Strategy

| Phases | Verification type |
|--------|------------------|
| 0 | Migration plan completeness + dependency check |
| 1 | POM content checks (no build) |
| 2-5 | `verify-migration.sh` — grep checks only, **no build** |
| 6 | `verify-migration.sh` + `mvn clean install` + **lutece-v8-reviewer** agent |

The project **will NOT compile** between Phases 1 and 5. This is expected.

---

## Strict Rules

- **Phases 1-5: verify with scripts/grep only** — do NOT run `mvn install` (it will fail)
- **Phase 6: NEVER mark completed without BUILD SUCCESS**
- **NEVER start a phase while a blocking phase is still `in_progress` or `pending`**
- **If verification fails, fix all errors before re-running**
- **No commits between phases** — commit only at the end when everything is green
- **ALWAYS re-read the phase file** before starting a phase — do not rely on context memory
- **Source lookup: ALWAYS use `~/.lutece-references/`** to read Lutece dependency sources (Read/Grep/Glob). NEVER decompile jars from `.m2/repository/`

### Reference-First Rule

**Before writing ANY new class or pattern (Producer, Service, DAO, EventListener, Cache, REST endpoint, XPage...), you MUST search `~/.lutece-references/` for an existing implementation of the same pattern.**

The references are the **living truth**. The patterns in this skill are a **static guide** that may lag behind. When a reference implementation exists, it takes priority over the pattern documentation.

**Protocol:**
1. Identify what you're about to write (e.g., a CDI producer for `FileStoreServiceProvider`, an event listener, a cache service)
2. **Search the references** with Grep/Glob for the same class, interface, or pattern (e.g., `Grep @Produces ~/.lutece-references/`, `Grep IFileStoreServiceProvider ~/.lutece-references/`, `Grep AbstractCacheableService ~/.lutece-references/`)
3. **Read the matching files** to understand the real-world implementation
4. **Reproduce the same structure** — naming conventions, annotations, property patterns, injection style
5. Only fall back to the pattern documentation when no reference implementation exists

This rule applies to ALL phases, not just producers. Examples:
- Writing a `@Produces` method → search `Grep @Produces ~/.lutece-references/`
- Writing an `@Observes` listener → search `Grep @Observes ~/.lutece-references/`
- Writing a cache service → search `Grep AbstractCacheableService ~/.lutece-references/`
- Writing a REST endpoint → search `Grep @Path ~/.lutece-references/`
- Writing a DAO → search for similar DAOs in `~/.lutece-references/`

---

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
import jakarta.enterprise.inject.Alternative;
import jakarta.enterprise.inject.literal.NamedLiteral;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.inject.Singleton;

// CDI Events
import jakarta.enterprise.event.Observes;
import jakarta.enterprise.event.ObservesAsync;
import jakarta.enterprise.context.Initialized;
import jakarta.annotation.Priority;
import fr.paris.lutece.portal.service.event.EventAction;
import fr.paris.lutece.portal.service.event.Type;
import fr.paris.lutece.portal.service.event.Type.TypeQualifier;
import fr.paris.lutece.portal.business.event.ResourceEvent;

// Lifecycle
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;

// Servlet
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

// REST
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.*;

// Validation
import jakarta.validation.ConstraintViolation;

// Config
import org.eclipse.microprofile.config.inject.ConfigProperty;

// Cache — NOTE: javax, NOT jakarta
import javax.cache.Cache;
```

---

## Phase Report Format

After each phase, output:
```
## Phase N Complete
- Files modified: [list]
- Scripts run: [list]
- Verification: [PASS/FAIL with details]
- Build: [SUCCESS/FAILURE or N/A]
- Task status: completed
```
