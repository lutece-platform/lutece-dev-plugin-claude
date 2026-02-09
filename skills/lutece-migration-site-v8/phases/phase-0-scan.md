# Phase 0: Site Scan & Dependency Verification

## Pre-step — Read known pitfalls

**Before starting**, read `references/known-pitfalls.md` from this skill's directory. It contains real migration errors to avoid (plugins.dat, DataSource config, CSS impact, etc.).

## Step 1 — Run the site scanner

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-site-v8/scripts/scan-site.sh"
```

Read the entire output. It gives you:
- Site name, version, parent version
- **V8 status**: Is the site already V8? Does it use starters? BOM?
- **Liberty config**: Is OpenLiberty config present?
- **Override config**: Property overrides structure
- All Lutece plugin/module dependencies with current versions
- Template inventory (skin templates, jQuery usage)
- Config files (db.properties, web.xml, etc.)
- SQL files (Liquibase headers)
- Summary counts
- **Site type and migration scope**

### Interpret the scan results

Based on `site_type` in the output:

| Site Type | Meaning | Action |
|-----------|---------|--------|
| `V8_PACK_STARTER` | Already V8 with starter pattern | No migration needed |
| `V8_CLASSIC` | Already V8 but may need config updates | Verify Liberty config, overrides |
| `V7_MINIMAL` | V7 with no local templates/JS | Consider converting to pack starter |
| `V7_SMALL` | V7 with < 10 files to migrate | Standard migration |
| `V7_MEDIUM` | V7 with 10-50 files to migrate | Standard migration |
| `V7_LARGE` | V7 with 50+ files to migrate | Consider parallel agents |

## Step 1b — Consider pack starter conversion (if V7_MINIMAL)

If the scan shows `site_type: V7_MINIMAL` (no local templates, JS, SQL), **ask the user**:

> This site has no custom templates, JavaScript, or SQL files.
> It could be converted to the modern **V8 pack starter** pattern.
>
> Options:
> 1. **Convert to pack starter** — Use a starter (forms-starter, etc.) + external theme
> 2. **Keep current structure** — Migrate as-is without starter

If converting to pack starter:
1. Read `references/v8-pack-starter-structure.md` for the target structure
2. Identify which starter matches the site's plugin list
3. The migration will create a minimal V8 structure (POM + Liberty config + overrides)

## Step 2 — Dependency v8 verification (BLOCKER)

For each **Lutece dependency** found in `pom.xml` (groupId `fr.paris.lutece.*`):

1. **Check `~/.lutece-references/`** — If the repo is already cloned, read its `pom.xml` to confirm `<parent><version>` is `8.0.0-SNAPSHOT`
2. **If not found locally, search GitHub** — Search `lutece-platform` and `lutece-secteur-public` orgs:
   ```bash
   curl -s "https://api.github.com/search/repositories?q=org:lutece-platform+{artifactId}+in:name&per_page=3" | jq -r '.items[].name'
   curl -s "https://api.github.com/search/repositories?q=org:lutece-secteur-public+{artifactId}+in:name&per_page=3" | jq -r '.items[].name'
   ```
3. **Find the v8 branch** — Priority: `develop_core8` > `develop8` > `develop8.x` > `develop`
4. **Verify v8 compatibility** — Fetch the remote `pom.xml` and check parent version is `8.0.0-SNAPSHOT`
5. **Read the v8 version** — Extract `<version>` from the dependency's v8 pom.xml

### If a dependency has NO v8 version

**Do NOT skip silently.** Present the results in a table:

```
Dependency v8 check:

| Plugin | Repo | v8 Branch | v8 Version | Status |
|--------|------|-----------|------------|--------|
| plugin-forms | lutece-form-plugin-forms | develop_core8 | 4.0.0-SNAPSHOT | OK |
| plugin-announce | lutece-collab-plugin-announce | - | - | NO V8 |
```

For each plugin with **NO V8**, ask the user:

> Plugin `{artifactId}` has no Lutece 8 version available.
>
> Options:
> 1. **Migrate this plugin now** — I'll use the `lutece-migration-v8` skill to migrate it
> 2. **Remove from site** — Remove this dependency
> 3. **Keep anyway** — You know it works or will handle it manually

If the user chooses **"Migrate this plugin now"**:
1. Ask the user for the plugin's source code location (local path or GitHub URL)
2. Invoke the `lutece-migration-v8` skill on that plugin
3. Wait for the migration to complete
4. Resume this site migration with the newly available v8 version

## Step 3 — Produce the migration plan

Based on the scan output, produce a structured plan:

1. **Dependency version map**: artifactId → v8 version (for Phase 1)
2. **Config changes needed**: web.xml namespace, properties, context cleanup
3. **Template changes needed**: number of templates, jQuery occurrences to replace
4. **SQL changes needed**: files needing Liquibase headers
5. **Plugins without v8**: resolution for each (migrated, removed, or kept)

## Verification

1. ALL Lutece dependencies have a confirmed v8 version (or explicit user decision)
2. The migration plan covers all items from the scan output
3. Mark task as completed ONLY when the plan is complete and all dependencies are resolved
