# Phase 5: Build, Verification & Final Review

---

## Step 1 — Full verification sweep

Run the complete verification script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-site-v8/scripts/verify-site-migration.sh"
```

**ALL checks must PASS** (WARN is acceptable but should be fixed if possible).

If any FAIL → go back to the relevant phase and fix the issue. Do NOT proceed to build with FAIL checks.

---

## Step 2 — Site assembly + database init

```bash
mvn clean lutece:site-assembly antrun:run
```

This assembles the site and runs the SQL scripts to initialize/update the database.

If you need to specify a local configuration directory for the database:

```bash
mvn clean lutece:site-assembly antrun:run -DlocalConfDirectory="/path/to/conf"
```

### Build-fix loop protocol

If BUILD FAILURE:
1. Read the **first** error message from the Maven output
2. Identify the root cause (missing dependency, wrong version, config issue)
3. Fix in the relevant file (pom.xml, config, etc.)
4. Re-run `mvn clean lutece:site-assembly antrun:run`
5. If new errors → repeat from 1
6. **Maximum 5 iterations** — if still failing after 5 attempts, report to user with the remaining errors and ask for guidance

Common build errors after site migration:
- Missing plugin version → check dependency version map from Phase 0
- Plugin not found in repository → verify the v8 version is deployed to the Maven repo
- Incompatible plugin versions → check transitive dependency conflicts
- Config file issues → verify properties files are in correct locations

---

## Step 3 — Execute database upgrade script

If a `migration-upgrade.sql` was generated during Phase 2:

```bash
mysql -u USER -p DB_NAME < migration-upgrade.sql
```

This activates plugins and cleans up removed plugin data. **Always review the SQL before executing.**

---

## Step 4 — Test with OpenLiberty (optional but recommended)

Start the site in development mode:

```bash
mvn liberty:dev
```

This starts OpenLiberty with hot reload.

### Post-startup verification loop

Run these checks **in order**. If any fails, diagnose and fix before moving to the next:

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1 | App started | Look for `CWWKZ0001I` in console | Application started |
| 2 | Front office | `curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/{site-name}/jsp/site/Portal.jsp` | `200` |
| 3 | Back office | `curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/{site-name}/jsp/admin/AdminLogin.jsp` | `200` |
| 4 | XPages | `curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/{site-name}/jsp/site/Portal.jsp?page=<xpage>` | `200` (not `302` redirect to error) |
| 5 | CSS/JS | Check browser console for 404 errors | No missing resources |
| 6 | Server logs | Check for `ERROR` lines (ignore OpenTelemetry warnings) | No application errors |

### Common post-startup failures and fixes

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| "Xpage 'xxx' cannot be retrieved" | Plugin not activated | Run SQL to activate in `core_datastore` |
| ClassNotFoundException | Missing plugin dependency in POM | Add the dependency |
| NPE on front-office | `theme.globalThemeCode` deleted from datastore | Re-insert it |
| Layout broken / CSS 404 | Removed plugin provided CSS | Create local copy in `webapp/css/` |
| DB access error (SQL 1045) | Missing `allowPublicKeyRetrieval` in JDBC URL | Fix server.xml DataSource URL |
| JNDI lookup failure | `portal.ds` mismatch with `jndiName` in server.xml | Align both values |

To run without dev mode:

```bash
mvn liberty:run
```

---

## Step 5 — Verify assembled site structure

After successful assembly, verify the target directory:

```bash
ls target/*/WEB-INF/
```

Check that:
- `WEB-INF/web.xml` has Jakarta namespace (or is absent — v8 doesn't always require it)
- `WEB-INF/conf/` contains expected configuration
- `WEB-INF/templates/skin/` contains migrated templates
- No jQuery files are included in the assembled webapp
- No Spring context XML files remain
- `src/main/liberty/config/server.xml` exists with proper features

---

## Step 6 — Final verification

Run one last time:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-site-v8/scripts/verify-site-migration.sh"
```

This is the final gate. All checks must be clean.

---

## Phase Report

After this phase completes, output the final migration report:

```
## Site Migration Complete
- Site: [siteName]
- Version: [old] → [new]
- Parent: [old] → 8.0.0-SNAPSHOT
- Plugins: [N] (list with versions)
- Templates migrated: [N]
- jQuery occurrences removed: [N]
- SQL files updated: [N]
- SQL upgrade script: [generated/executed/N/A]
- OpenLiberty config: server.xml created
- Build: SUCCESS (mvn clean lutece:site-assembly)
- Post-startup checks: [ALL PASS / details]
- Verification: ALL PASS
```
