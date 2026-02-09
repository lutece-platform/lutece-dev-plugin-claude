# Phase 4: SQL Migration

## Step 1 — Add Liquibase headers

If the site has custom SQL files (`src/sql/` or `webapp/sql/`), ensure each has a Liquibase header.

Use the script from the plugin migration skill (reusable):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/add-liquibase-headers.sh" . "siteName"
```

Replace `siteName` with the actual site name (from the POM artifact).

## Step 2 — Verify SQL syntax

Check SQL files for deprecated patterns:
- Old table structures that may conflict with v8 core changes
- References to removed columns or tables

## Step 3 — Upgrade scripts

If the site has custom database tables, create upgrade SQL scripts:
- `src/sql/upgrade/update_db_siteName-oldVersion-newVersion.sql`
- Document any schema changes needed for v8 compatibility

## Verification

1. All SQL files have Liquibase headers
2. No deprecated SQL patterns detected
3. Mark task as completed when checks pass
