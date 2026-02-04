# Lutecepowers

AI coding agent plugin for **Lutece 8** framework development. Works with **Claude Code** and **OpenCode**.

## Installation

### Claude Code

```bash
/plugin marketplace add lutece-platform/lutece-dev-plugin-claude
/plugin install lutecepowers-v8
# install in user scope
```

### OpenCode

See [.opencode/INSTALL.md](.opencode/INSTALL.md) — clone, symlink plugin + skills, restart OpenCode.

## What it does

At session start, the plugin automatically:

1. **Clones/updates reference repos** — 21 Lutece v8 repositories into `~/.lutece-references/` (shared script: `scripts/setup-references.sh`)
2. **Copies rules** — Detects if the current project is a Lutece plugin and copies coding constraint rules into `.claude/rules/` (or equivalent)
3. **Injects context** — Bootstrap message (Claude Code) or system prompt injection (OpenCode) with architecture patterns and available skills

## Skills

| Skill | Description |
|-------|-------------|
| `lutece-patterns` | Architecture reference: layered design, CDI patterns, CRUD lifecycle, pagination, XPages, daemons, security checklist |
| `lutece-migration-v8` | Migration v7 → v8 (Spring → CDI/Jakarta). 6 phases, 5 scripts for mechanical work + AI for the rest |
| `lutece-scaffold` | Interactive plugin scaffold generator. Optional XPage, Cache, RBAC, Site features |
| `lutece-site` | Interactive site generator with database config and plugin dependencies |
| `lutece-dao` | DAO + Home layer patterns: DAOUtil lifecycle, SQL constants, CDI lookup |
| `lutece-workflow` | Workflow module patterns: tasks, CDI producers, components, templates |
| `lutece-rbac` | RBAC: entity permissions, ResourceIdService, plugin.xml, JspBean authorization |
| `lutece-cache` | Cache: AbstractCacheableService, CDI init, invalidation via CDI events |
| `lutece-lucene-indexer` | Plugin-internal Lucene search: custom index, daemon, CDI events |
| `lutece-solr-indexer` | Solr search module: SolrIndexer interface, CDI auto-discovery, batch indexing |
| `lutece-elasticdata` | Elasticsearch DataSource: DataSource/DataObject interfaces, two-daemon indexing |

## Agent

| Agent | Model | Description |
|-------|-------|-------------|
| `lutece-v8-reviewer` | Opus | Read-only compliance reviewer. Runs `scan-project.sh` + `verify-migration.sh`, then semantic analysis (CDI scopes, singletons, producers, cache guards). Produces a structured PASS/WARN/FAIL report. |

## Migration flow (`/lutece-migration-v8`)

**Input:** a Lutece v7 plugin/module/library (Spring, javax, XML context).

**Architecture:** scripts handle the mechanical 80%, AI handles the intelligent 20% (CDI scopes, producers, events, templates).

| Phase | What |
|-------|------|
| 0 — Scan | `scan-project.sh` → structured inventory. Verify all Lutece deps have v8 versions. |
| 1 — POM | Parent → `8.0.0-SNAPSHOT`, remove Spring/EhCache, update dependency versions |
| 2 — Java | `replace-imports.sh` + `replace-spring-simple.sh` → then CDI scopes, producers, events, cache, REST, deprecated APIs |
| 3 — Web | web.xml namespace, plugin descriptor, beans.xml, SQL Liquibase headers |
| 4 — UI | JSP scriptlet→EL, admin templates→v8 macros, jQuery→vanilla JS, SuggestPOI→LuteceAutoComplete |
| 5 — Tests | JUnit 4→5, assertion order, mock class renames |
| 6 — Build | `verify-migration.sh`, `mvn clean install` (max 5 iterations), v8-reviewer agent |

**Output:** migrated v8 plugin with green build and clean compliance report.

### Migration scripts

| Script | Purpose |
|--------|---------|
| `scan-project.sh` | Full project scan → structured inventory |
| `replace-imports.sh` | javax → jakarta mass replacement |
| `replace-spring-simple.sh` | Spring → CDI annotation replacements |
| `verify-migration.sh` | All verification checks → PASS/FAIL report |
| `add-liquibase-headers.sh` | Liquibase headers on SQL files |
| `setup-references.sh` | Clone/update 21 Lutece v8 reference repos |

## Rules

Rules are short constraints (5-15 lines) automatically loaded when the agent touches matching files.

| Rule | Scope |
|------|-------|
| `web-bean` | `**/web/**/*.java` — JspBean/XPage: CDI, CRUD lifecycle, security tokens |
| `service-layer` | `**/service/**/*.java` — CDI scopes, injection, events, cache |
| `dao-patterns` | `**/business/**/*.java` — DAOUtil lifecycle, SQL constants, Home facade |
| `template-back-office` | `**/templates/admin/**/*.html` — v8 Freemarker macros, BS5/Tabler |
| `template-front-office` | `**/templates/skin/**/*.html` — BS5 classes, vanilla JS, no jQuery |
| `jsp-admin` | `**/*.jsp` — JSP boilerplate, bean naming |
| `plugin-descriptor` | `**/plugins/*.xml` — Mandatory tags, core-version-dependency |
| `messages-properties` | global — i18n key conventions |
| `dependency-references` | global — Auto-fetch Lutece dep sources, v8 branch detection |

## Platform compatibility

| Feature | Claude Code | OpenCode |
|---------|-------------|----------|
| Session init (refs + rules) | SessionStart hook | `session.created` event |
| System prompt context | Hook echo | `experimental.chat.system.transform` |
| Skills | Native `/skill` | Native `skill` tool (via symlink) |
| Agent (v8-reviewer) | Native Task delegation | Not yet supported |
| Rules (path-scoped) | Native `.claude/rules/` | Copied but no path-scoping |
| Scripts (bash) | Native Bash tool | Native shell |

## Tests

```bash
pip install -r tests/requirements.txt
python3 -m pytest tests/test.py -v

# Run a specific test
python3 -m pytest tests/test.py -v -k "v8_reviewer"

# Run tests in parallel
python3 -m pytest tests/test.py -v -n 4
```

Latest results: [TEST_REPORT.md](TEST_REPORT.md)

## Local development

```bash
# Test against a Lutece project
cd /path/to/your-lutece-plugin
claude --plugin-dir /path/to/lutecepowers
```
