---
name: lutece-migration-site-v8
description: "Migration guide for Lutece sites v7 → v8. Scans dependencies, verifies v8 availability, migrates POM/config/templates/SQL. Triggers plugin migration skill when needed."
user-invocable: true
---

# Lutece Site Migration v7 to v8 — Orchestrator

## Purpose

Migrates a Lutece **site** (deployable application assembling lutece-core + plugins) from v7 to v8. A site has no Java code — only POM, config, templates, and SQL. In v8, sites run on **OpenLiberty** instead of Tomcat.

**Key feature:** If a plugin dependency has no v8 version, the skill asks the user and can trigger the `lutece-migration-v8` skill to migrate that plugin first.

**Reference documentation:** `~/Documents/Formation/LuteceV8/comite-achitecture.wiki/`

---

## EXECUTION STRATEGY

### Step 1 — Create 6 tasks

```
TaskCreate({ subject: "Phase 0: Site scan", description: "Read phases/phase-0-scan.md then execute. Scan site, verify all plugin deps have v8 versions. Trigger plugin migration if needed.", activeForm: "Scanning site..." })

TaskCreate({ subject: "Phase 1: POM migration", description: "Read phases/phase-1-pom.md then execute. Update parent, plugin versions, remove old deps.", activeForm: "Migrating POM..." })

TaskCreate({ subject: "Phase 2: Config migration", description: "Read phases/phase-2-config.md then execute. web.xml, properties, context cleanup.", activeForm: "Migrating config..." })

TaskCreate({ subject: "Phase 3: Templates migration", description: "Read phases/phase-3-templates.md then execute. Skin templates, jQuery→vanilla JS.", activeForm: "Migrating templates..." })

TaskCreate({ subject: "Phase 4: SQL migration", description: "Read phases/phase-4-sql.md then execute. Liquibase headers, SQL cleanup.", activeForm: "Migrating SQL..." })

TaskCreate({ subject: "Phase 5: Build & review", description: "Read phases/phase-5-build.md then execute. Site assembly, verification.", activeForm: "Building & reviewing..." })
```

### Step 2 — Wire dependencies (use actual task IDs)

```
TaskUpdate({ taskId: "<phase1>", addBlockedBy: ["<phase0>"] })
TaskUpdate({ taskId: "<phase2>", addBlockedBy: ["<phase1>"] })
TaskUpdate({ taskId: "<phase3>", addBlockedBy: ["<phase1>"] })
TaskUpdate({ taskId: "<phase4>", addBlockedBy: ["<phase1>"] })
TaskUpdate({ taskId: "<phase5>", addBlockedBy: ["<phase2>", "<phase3>", "<phase4>"] })
```

Phases 2, 3, 4 can run in parallel after Phase 1. Phase 5 waits for all three.

---

## Site Types

### Classic site (v7 → v8 migration)
- Has local templates in `webapp/WEB-INF/templates/`
- Has local JS/CSS files in `webapp/`
- Has SQL files to migrate
- May have Spring context XML files
- **Full migration path:** Phases 0-5 all needed

### Pack starter site (v8 native style)
- Uses a **starter** (forms-starter, appointment-starter, etc.)
- **No local templates** — all templates in plugins/starters
- **No local JS/CSS** — theme provided by external dependency
- **No local SQL** — database handled by Liquibase in plugins
- Structure: POM + Liberty config + property overrides only
- **Simplified migration:** Phase 0 (verify deps), Phase 1 (POM), Phase 2 (config), Phase 5 (build)

When Phase 0 scan shows `scope: MINIMAL`, consider if the site can be converted to pack starter style.

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

All scripts in `${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-site-v8/scripts/`:

| Script | Purpose | Used in |
|--------|---------|---------|
| `scan-site.sh` | Full site scan → structured inventory | Phase 0 |
| `generate-upgrade-sql.sh` | Generate SQL: activate plugins + clean removed plugin data | Phase 2, 5 |
| `verify-site-migration.sh` | All site migration checks → structured PASS/FAIL report | Phase 2, 3, 4, 5 |

---

## Pattern Reference Locations

| File | Content | Read when |
|------|---------|-----------|
| `references/v8-pack-starter-structure.md` | V8 pack starter site structure reference | Phase 0 (site analysis), Phase 1 (POM), Phase 2 (config) |
| `references/known-pitfalls.md` | Real migration errors and solutions (plugins.dat, DataSource, CSS, etc.) | **Phase 0 (MUST READ before starting)**, Phase 2, Phase 5 |

---

## Build Verification Strategy

| Phases | Verification type |
|--------|------------------|
| 0 | Dependency availability check |
| 1 | POM content checks (no build) |
| 2-4 | `verify-site-migration.sh` — grep checks only, **no build** |
| 5 | `verify-site-migration.sh` + `mvn clean lutece:site-assembly antrun:run` |

---

## Plugin Migration Trigger (Phase 0)

When a plugin dependency has no v8 version:

1. **List all plugins without v8** in a table
2. **Ask the user** for each: "This plugin has no v8 version. Migrate it now?"
3. If **yes** → Invoke the `lutece-migration-v8` skill on that plugin
4. If **no** → Remove the plugin from the site or keep with user's explicit acknowledgment
5. **Resume site migration** once all plugins are resolved

---

## Strict Rules

- **Phases 1-4: verify with scripts/grep only** — do NOT run `mvn` (assembly will fail)
- **Phase 5: NEVER mark completed without successful site assembly**
- **NEVER start a phase while a blocking phase is still `in_progress` or `pending`**
- **If verification fails, fix all errors before re-running**
- **ALWAYS re-read the phase file** before starting a phase — do not rely on context memory
- **Reference-first:** search `~/.lutece-references/` for real v8 site examples before guessing

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
