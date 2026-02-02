# Lutecepowers

Claude Code plugin for **Lutece 8** framework development.

## Installation

```bash
/plugin marketplace add lutece-platform/lutece-dev-plugin-claude
/plugin install lutecepowers-v8
install it in user scope.
```

## Hook (SessionStart)

At session start, the plugin runs 3 hooks automatically:

1. **System prompt injection** — Informs Claude of available skills and instructs it to always consult the reference repos (`~/.lutece-references/`) via Read/Grep/Glob before writing any Lutece code
2. **Reference repos clone/update** — Clones 20 v8 repositories into `~/.lutece-references/` on first run, then pulls **all** repos in that directory at every session start (including repos added manually). This ensures references are always up to date.
3. **Rules copy** — Runs `scripts/lutece-rules-setup.sh` to copy rule templates into the target project's `.claude/rules/`

## Skills

Skills are multi-step procedures loaded progressively by Claude on demand.

| Skill | Description |
|-------|-------------|
| `lutece-migration-v8` | Migration v7 → v8 (Spring → CDI/Jakarta). Script-accelerated with 5 bash scripts for mechanical work + Claude intelligence for the rest. 7 phases with parallel execution (3/4/5 run concurrently). |
| `lutece-scaffold` | Interactive plugin scaffold generator. Creates plugins with optional XPage, Cache, RBAC and Site features. |
| `lutece-site` | Interactive site generator. Creates a site with database configuration and optional plugin dependencies. |
| `lutece-workflow` | Rules and patterns for creating/modifying workflow modules. Tasks, CDI producers, components, templates. |
| `lutece-dao` | DAO and Home layer patterns: DAOUtil lifecycle, SQL constants, Home static facade, CDI lookup. |
| `lutece-cache` | Cache implementation: AbstractCacheableService, CDI initialization, invalidation via CDI events. |
| `lutece-rbac` | RBAC implementation: entity permissions, ResourceIdService, plugin.xml declaration, JspBean authorization. |
| `lutece-lucene-indexer` | Plugin-internal Lucene search: custom index, daemon, CDI events, batch processing. |
| `lutece-solr-indexer` | Solr search module: SolrIndexer interface, CDI auto-discovery, SolrItem dynamic fields, batch indexing, incremental updates via CDI events. |
| `lutece-elasticdata` | Elasticsearch DataSource module: DataSource/DataObject interfaces, CDI auto-discovery, @ConfigProperty injection, two-daemon indexing, incremental updates. |
| `lutece-patterns` | Lutece 8 architecture reference: layered architecture, CDI patterns, CRUD lifecycle, pagination, XPages, daemons, security checklist. |

## Migration Flow (`/lutece-migration-v8`)

**Input:** a Lutece v7 plugin/module/library (Spring, javax, XML context).

**Architecture:** scripts handle mechanical 80% (imports, grep checks, scanning), Claude handles intelligent 20% (CDI scopes, producers, events, templates).

**Resources consumed during migration:**

| Resource | Usage |
|----------|-------|
| `~/.lutece-references/` | Lutece 8 repos cloned at session start — read for dependency source code (never jar decompilation) |
| `migrations-samples/` | Real migration analyses (diffs per category) — consulted as pattern reference |
| GitHub (`lutece-platform`, `lutece-secteur-public`) | Each Lutece dependency is checked for a v8 branch, and its `pom.xml` is read to confirm `parent version = 8.0.0-SNAPSHOT` |

**Phase 0 — Project scan:** `scan-project.sh` produces a structured inventory of the entire project (Java files, templates, JSP, SQL, REST endpoints). Every Lutece dependency is verified for v8 availability. A version map and migration plan are produced.

**Phase 1 — POM migration:** parent POM → `8.0.0-SNAPSHOT`, remove Spring/EhCache/javax.mail dependencies, update all Lutece dependency versions using the Phase 0 version map.

**Phase 2 — Java mega-phase:** `replace-imports.sh` (javax→jakarta) + `replace-spring-simple.sh` (Spring→CDI 1:1) run first, then Claude handles: context XML→beans.xml, CDI scopes, SpringContextService replacement, producers, events, cache, REST, deprecated APIs, DAOUtil. Pattern files (`patterns/*.md`) are the single source of truth.

**Phases 3, 4, 5 — Parallel execution** (unblocked after Phase 2):
- **Phase 3 (web & config):** web.xml namespace, plugin descriptor, beans.xml, SQL Liquibase headers, config migration
- **Phase 4 (UI):** JSP scriptlet→EL, admin templates→v8 macros, skin templates, jQuery→vanilla JS
- **Phase 5 (tests):** JUnit 4→5 annotations, assertion order, mock class renames

**Phase 6 — Build & review:** `verify-migration.sh` (58 checks), `mvn clean install` (build-fix loop, max 5 iterations), `lutece-v8-reviewer` agent, final verification gate.

**Output:** the migrated v8 plugin (CDI/Jakarta, `beans.xml`, annotation-driven) with a green build and a clean compliance report.

### Scripts

| Script | Purpose |
|--------|---------|
| `scan-project.sh` | Full project scan → structured inventory |
| `replace-imports.sh` | javax→jakarta mass sed replacement |
| `replace-spring-simple.sh` | Mechanical Spring→CDI annotation replacements |
| `verify-migration.sh` | All 58 grep checks → structured PASS/FAIL report |
| `add-liquibase-headers.sh` | Liquibase headers on SQL files |

### Pattern files

| File | Content |
|------|---------|
| `cdi-patterns.md` | Spring→CDI scopes, injection, producers, REST, config, logging (745 lines, 20 sections) |
| `events-patterns.md` | Event/listener migration patterns (268 lines) |
| `cache-patterns.md` | EhCache→JCache migration (100 lines) |
| `deprecated-api.md` | getInstance()→@Inject table, Models injection (100 lines) |

## Migration Samples

The `migrations-samples/` directory contains detailed analyses of real v7 → v8 migrations (plugins/modules/libraries). Each file documents the exact diffs per category (POM, imports, CDI, events, cache, templates, tests, etc.). These samples are consulted by the migration skill and by the v8-reviewer agent as references.

## Agents

Agents are specialized subagents that run in their own context window with restricted tools.

| Agent | Model | Tools | Description |
|-------|-------|-------|-------------|
| `lutece-v8-reviewer` | Haiku | Read, Grep, Glob, Bash | Reviews a Lutece plugin for v8 compliance. Checks CDI annotations, jakarta imports, POM dependencies, beans.xml, Spring residues. Produces a structured PASS/WARN/FAIL report. |


## Rules

Rules are constraints automatically loaded when Claude touches matching files. They are copied to the target project's `.claude/rules/` at session start.

| Rule | Scope | Description |
|------|-------|-------------|
| `web-bean` | `**/web/**/*.java` | JspBean/XPage constraints: CDI annotations, CRUD lifecycle, security tokens, pagination |
| `service-layer` | `**/service/**/*.java` | Service layer constraints: CDI scopes, injection, events, configuration, cache integration |
| `dao-patterns` | `**/business/**/*.java` | DAOUtil lifecycle, SQL constants, Home facade, CDI lookup |
| `template-back-office` | `**/templates/admin/**/*.html` | Freemarker macros, layout structure, i18n, null safety, BS5/Tabler already loaded (prefer macros), vanilla JS, no CDN |
| `template-front-office` | `**/templates/skin/**/*.html` | BS5/Tabler/core JS already loaded (no imports), BS5 classes only, vanilla JS (no jQuery), no CDN |
| `jsp-admin` | `**/*.jsp` | Admin feature JSP boilerplate, bean naming, errorPage |
| `plugin-descriptor` | `**/plugins/*.xml` | Mandatory tags, icon-url, core-version-dependency |
| `messages-properties` | global | i18n constraints: no prefix in .properties, prefix in Java/templates |
| `dependency-references` | global | Lutece deps: auto-fetch sources into `~/.lutece-references/`, v8 branch detection, warn if no v8. External deps: use Context7 MCP if available, suggest install otherwise |


## Tests

Tests are run via the Claude Agent SDK and defined in `tests/tests.json`. Each test case spins up a Claude session with the plugin loaded against a fixture project, then asserts expected behavior (tool usage, file reads, agent delegation).

```bash
# Install dependencies (first time only)
pip install -r tests/requirements.txt

# Run all tests
python3 -m pytest tests/test.py -v

# Run a specific test
python3 -m pytest tests/test.py -v -k "v8_reviewer"

# Run tests in parallel
python3 -m pytest tests/test.py -v -n 4
```

Latest results: [TEST_REPORT.md](TEST_REPORT.md)

## Manual Testing

To test the plugin locally against a Lutece project:

```bash
cd /path/to/your-lutece-plugin-to-test
claude --plugin-dir /path/to/lutece-dev-plugin-claude
```
