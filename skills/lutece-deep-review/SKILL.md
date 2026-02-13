---
name: lutece-deep-review
description: "Deep review of any Lutece plugin via Agent Teams. Traces the complete request lifecycle — template to bean to service to DAO to SQL — and cross-references layers to find guaranteed bugs (disconnects that will crash at runtime). Use when user says 'deep review', 'flow review', 'cross-layer review', or 'trace bugs'."
user-invocable: true
---

# Lutece Deep Review — Agent Teams Flow Tracer

## Purpose

Deep-reviews any Lutece plugin/module (v7 or v8) by tracing the **complete request lifecycle** across all layers (template, bean, service, DAO, SQL, config) and cross-referencing them to find **guaranteed bugs** — disconnects between layers that will crash at runtime.

This is NOT a conformity checker (use the `v8-reviewer` agent for v8 compliance). This is a **flow tracer** that finds bugs a compiler and static checks cannot. Works on any Lutece version.

**Prerequisites:** Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`).

---

## What "Guaranteed Bug" Means

A finding is reported ONLY if **both sides of a disconnect are provably confirmed**:

| Disconnect | Side A (proven) | Side B (proven) | Bug |
|---|---|---|---|
| Template → Bean | Template uses `${foo.bar}` | Bean never puts `bar` in model | NPE at render |
| Form → Bean | Form field `name="title"` | Bean action has no `title` parameter | Value silently lost |
| Form action → Bean | `action=doCreateFoo` | No `doCreateFoo()` method in bean | 404 or crash |
| Bean → Service | Bean calls `_service.findAll()` | Service has no `findAll()` method | Compile error |
| DAO → Entity | SQL `SELECT title` | Entity has `_strName`, not `_strTitle` | Wrong data mapping |
| i18n → Properties | Template uses `#i18n{key}` | Key absent from `.properties` files | Shows raw key |
| Config → Code | plugin.xml declares right `FOO_MANAGE` | No RBAC check in bean for that right | Security hole |
| Code → Config | Bean checks `FOO_DELETE` right | plugin.xml doesn't declare `FOO_DELETE` | Always denied |
| Redirect → View | Bean redirects to `VIEW_MANAGE` | No `@View(VIEW_MANAGE)` method exists | Redirect crash |
| XPage path | Code registers `/app/foo` | plugin.xml declares different path | Page not found |

**If there is ANY ambiguity** (dynamic model population, conditional logic, inheritance, reflection), the finding is **skipped**. Zero false positives.

---

## PHASE A — Scan & Locate (Lead executes directly)

### A.1 — Verify Lutece project
Confirm the current directory is a Lutece 8 project (`pom.xml` with lutece-plugin/module/library packaging).

### A.2 — Locate plugin root

```bash
PLUGIN_ROOT=$(ls -d ~/.claude/plugins/cache/lutece-plugins/lutecepowers-v8/*/ 2>/dev/null | sort -V | tail -1)
if [ -z "$PLUGIN_ROOT" ]; then
  PLUGIN_ROOT=$(ls -d .claude/plugins/cache/lutece-plugins/lutecepowers-v8/*/ 2>/dev/null | sort -V | tail -1)
fi
echo "PLUGIN_ROOT=$PLUGIN_ROOT"
```

### A.3 — Run project scanner

```bash
mkdir -p .review
bash "<PLUGIN_ROOT>/skills/lutece-migration-v8-agent-teams/scripts/scan-project.sh" . > .review/scan.json
```

### A.4 — Run verify-migration.sh

```bash
bash "<PLUGIN_ROOT>/skills/lutece-migration-v8-agent-teams/scripts/verify-migration.sh" . --json 2>&1 | tee .review/verify-output.txt
```

Display scan summary to user (project type, artifact, file counts).

---

## PHASE B — Spawn Teammates

Switch to **Delegate Mode** (Shift+Tab). From this point, you orchestrate only.

### Spawn 5 teammates in parallel + 1 delayed:

1. **Script Runner** (runs first, no deps)
   - Instructions: `<PLUGIN_ROOT>/skills/lutece-deep-review/teammates/script-runner.md`
   - Input: `.review/scan.json`, `.review/verify-output.txt`
   - Outputs: `.review/script-results.json`

2. **Template Flow Mapper** (no deps)
   - Instructions: `<PLUGIN_ROOT>/skills/lutece-deep-review/teammates/template-mapper.md`
   - Input: `.review/scan.json`
   - Outputs: `.review/template-flows.json`

3. **Java Flow Mapper** (no deps)
   - Instructions: `<PLUGIN_ROOT>/skills/lutece-deep-review/teammates/java-mapper.md`
   - Input: `.review/scan.json`
   - Outputs: `.review/java-flows.json`

4. **Config Mapper** (no deps)
   - Instructions: `<PLUGIN_ROOT>/skills/lutece-deep-review/teammates/config-mapper.md`
   - Input: `.review/scan.json`
   - Outputs: `.review/config-map.json`

5. **Semantic V8 Checker** (no deps)
   - Instructions: `<PLUGIN_ROOT>/skills/lutece-deep-review/teammates/semantic-checker.md`
   - Input: `.review/scan.json`
   - Outputs: `.review/semantic-checks.json`

6. **Cross-Layer Verifier** (blocked by teammates 1-5)
   - Instructions: `<PLUGIN_ROOT>/skills/lutece-deep-review/teammates/cross-layer-verifier.md`
   - Input: ALL `.review/*.json` files
   - Outputs: `.review/guaranteed-bugs.json`

### Spawn instructions template

```
Read your instruction file at [path to teammates/*.md].
The plugin root is: <PLUGIN_ROOT>
Scan data is at .review/scan.json.
Reference implementations: ~/.lutece-references/
You are READ-ONLY — do NOT modify any source files.
Write your output JSON to .review/<your-output-file>.json
```

---

## PHASE C — Task Dependencies

```
Script Runner ──────────────────────────────── (no blockers)
Template Flow Mapper ──────────────────────── (no blockers)
Java Flow Mapper ──────────────────────────── (no blockers)
Config Mapper ─────────────────────────────── (no blockers)
Semantic V8 Checker ───────────────────────── (no blockers)
    │   │   │   │   │
    └───┴───┴───┴───┘
            │
            └──→ Cross-Layer Verifier (blocked by ALL 5 above)
```

Teammates 1-5 run in **full parallel**. Teammate 6 starts only after ALL others complete.

---

## PHASE D — Monitoring

While teammates work:
1. Check task list progress every ~30 seconds
2. When ALL 5 parallel teammates report complete, spawn the Cross-Layer Verifier
3. If a teammate is stuck (>3 min): send a message asking for status
4. When the Cross-Layer Verifier finishes, proceed to Phase E

---

## PHASE E — Report Assembly

When the Cross-Layer Verifier completes:

1. Read ALL `.review/*.json` files
2. Assemble the final report (format below)
3. Present to the user
4. Clean up the team

### Report format

~~~
# Lutece Deep Review Report

**Project:** <artifactId> | **Type:** <plugin/module/library> | **Version:** <version>

## Script Results (verify-migration.sh)

<TOTAL, PASS, FAIL, WARN counts from script-results.json>

## Semantic V8 Analysis

| # | Check | Status | Issues |
|---|-------|--------|--------|
| S1 | CDI Scope Correctness | PASS/WARN | 0 |
| S2 | Singleton Patterns | PASS/FAIL | 0 |
| S3 | Injection vs Static Lookup | PASS/WARN | 0 |
| S4 | Producer Quality | PASS/WARN | 0 |
| S5 | Cache Defensive Guards | PASS/WARN | 0 |
| S6 | IDE Diagnostics & Deprecated API | PASS/FAIL/N/A | 0 |
| S7 | Models Injection | PASS/FAIL/N/A | 0 |
| S8 | Captcha CDI Pattern | PASS/FAIL/N/A | 0 |
| S9 | Event/Listener CDI Migration | PASS/FAIL/N/A | 0 |
| S10 | Pagination Modernization | PASS/WARN/N/A | 0 |
| S11 | Template Message Patterns | PASS/FAIL/N/A | 0 |
| S12 | ConfigProperty Usage | PASS/WARN | 0 |
| S13 | jQuery → Vanilla JS | PASS/WARN/N/A | 0 |
| | **Total semantic** | | **X** |

## Cross-Layer Flow Analysis

| # | Disconnect Type | Count |
|---|----------------|-------|
| F1 | Template → Model attribute missing | X |
| F2 | Form field → Bean parameter mismatch | X |
| F3 | Form action → Bean method missing | X |
| F4 | Bean → Service method missing | X |
| F5 | DAO SQL → Entity field mismatch | X |
| F6 | i18n key → Properties missing | X |
| F7 | Config right → Code RBAC missing | X |
| F8 | Code RBAC → Config right missing | X |
| F9 | Redirect → View method missing | X |
| F10 | XPage path → Config mismatch | X |
| | **Total guaranteed bugs** | **X** |

## All Findings

### Semantic Findings (S1–S13)

<from semantic-checks.json, grouped by check>

### Guaranteed Bugs (F1–F10)

<from guaranteed-bugs.json, grouped by disconnect type>

| Template | Expression | Expected in Bean | Bean Method | Status |
|----------|-----------|-----------------|-------------|--------|
| `path/to/template.html:12` | `${foo.bar}` | `model.put("bar", ...)` | `getManageFoo()` | BUG |

### Script Findings (FAIL/WARN)

<from script-results.json>
~~~

---

## PHASE F — Fix Proposal (optional)

After presenting the report, ask the user:
- "Do you want me to fix the X guaranteed bugs found?"
- Options: "Yes, fix all" / "No, report only"

If yes, the Lead coordinates fix work (can spawn fix teammates or return to single-session mode).

---

## Strict Rules

1. **Delegate mode**: After Phase A, the Lead orchestrates only
2. **READ-ONLY**: No teammate modifies source files during review
3. **NEVER commit**: Never create git commits
4. **Zero false positives**: Only report guaranteed bugs. If ANY ambiguity exists, skip the finding
5. **JSON-mediated**: Teammates communicate via `.review/*.json` files, not prose
6. **Reference-First**: Compare against `~/.lutece-references/` when unsure about Lutece conventions
7. **Reuse scripts**: Use existing `scan-project.sh` and `verify-migration.sh` — don't reinvent

---

## Script Locations

Existing scripts (from migration skill):
- `<PLUGIN_ROOT>/skills/lutece-migration-v8-agent-teams/scripts/scan-project.sh`
- `<PLUGIN_ROOT>/skills/lutece-migration-v8-agent-teams/scripts/verify-migration.sh`

New scripts (in this skill):
- `<PLUGIN_ROOT>/skills/lutece-deep-review/scripts/extract-template-flows.sh`
- `<PLUGIN_ROOT>/skills/lutece-deep-review/scripts/extract-java-flows.sh`
- `<PLUGIN_ROOT>/skills/lutece-deep-review/scripts/extract-config-map.sh`
- `<PLUGIN_ROOT>/skills/lutece-deep-review/scripts/cross-layer-verify.sh`
