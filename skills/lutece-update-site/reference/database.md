# A site's database across the update

A fresh install proves the war starts; it proves nothing about the database the environments already have. Three
things decide what that database becomes.

## 1. Liquibase takes over a v7 database only through the migration mode, the core first

`plugin-liquibase` runs the scripts `SqlPathInfo` recognises (`sql/plugins/<p>/(core|plugin)/…`,
`upgrade/update…<from>-<to>.sql`, `sql/themes/<t>/…`) whose first line is `-- liquibase formatted sql` (SI12), and
only from the classpath (`WEB-INF/classes/sql`). On a database with no `DATABASECHANGELOG` and no recorded versions,
it runs nothing and records the versions the war declares (`TestIncludeAllFilter`, `LiquibaseRunnerContext`): every
v7 → v8 upgrade script is then skipped for good. Three more facts decide the procedure:

- It runs the files in path order, and the core cannot take part in `runAfter`: `sql/plugins/` and `sql/themes/` run
  before `sql/upgrade/`, the core's. A theme or a plugin script that needs a table of the v8 core (`core_theme`), or
  writes a datastore key the core upgrade deletes, fails or is undone in a single start (SI13).
- The migration mode records a version for every plugin descriptor, a new plugin included: its create and init
  scripts would then never run. It records none for a theme.
- A component renamed in v8 (its SQL directory and descriptor name changed) is a new component to Liquibase: its
  upgrades never run, so the tables keep the former schema, and a create script no precondition guards drops them
  (SI14). The `prerun_db_*` fix-up such a component ships
  runs only on a database Liquibase already tracked under the former directory, and never from `WEB-INF/sql`, where
  `lutece-maven-plugin` leaves it (SI15).

The procedure that works, played on a copy of the production database before any environment:

1. `SHOW TABLES LIKE 'DATABASECHANGELOG%';`. The documented way to bring a v7 site under Liquibase is plugin-liquibase
   added alone to the v7 site, with `liquibase.enabled.at.startup=true`, started once: it creates `DATABASECHANGELOG`
   and records the installed versions, running nothing. A database that went through it skips step 3. It still
   needs the two passes: the v8 start would run the components before the core, and a component whose v7 SQL
   directory did not match its plugin name (the v7 log says `No plugin metadata for <dir>`) has no recorded
   version, so a normal v8 start installs it as new over its existing rows.
2. Write the two scripts of the takeover from the before and after wars:
   `site_check.py takeover .migration/before .migration/after --out .migration/takeover` (MySQL / MariaDB).
3. Without `DATABASECHANGELOG` only: start the v8 war once with `liquibase.migration.mode=true` (`LIQUIBASE_MIGRATION_MODE=true`): it creates
   `DATABASECHANGELOG` and records the versions of the war, without running anything. Stop it.
4. Play `takeover-1-core.sql` (the core back to its v7 version, every component marked newer than any script), start
   normally: only the core upgrades run. The pages may fail, the components are still v7. Stop it.
5. Play `takeover-2-components.sql` (each component back to the version the v7 site had installed, the keys of a
   renamed component moved to its new name, the version of a new component and of a theme removed so that their
   create and init scripts run), start normally: the component upgrades run on the v8 core schema.
6. Check the tables of every plugin the site declares itself: a pack or a starter only knows its own plugins.

A SI13 FAIL (a component script using a table the core upgrade drops) is a v7 upgrade the site never applied: apply
it to the v7 database first. The `lutece-e2e` bench plays the same sequence in `run.sh compare` with `E2E_TAKEOVER`
(`reference/compare.md` of that skill).

## 2. The core upgrade resets settings of the site

`update_db_lutece_core-7.9.9-8.0.0.sql` runs 179 `DELETE FROM core_datastore`: 36 `core.advanced_parameters.*`
(the security settings of the back-office accounts), the theme and site properties (`portal.theme.site_property.*`,
`portal.site.site_property.*`, meta), the cache statuses, the theme code. Before the upgrade, save those rows of the
production copy (`SELECT * FROM core_datastore WHERE entity_key LIKE 'core.advanced_parameters.%' OR entity_key LIKE
'portal.%site_property%' OR entity_key LIKE 'core.cache.status.%' OR entity_key LIKE 'theme%'`); after it, compare and
set again what the site had chosen, in the back office or in a SQL script of the site that runs after the core's.

## 3. Files that seed the database once

`plugins.dat`, `caches.dat` and some plugin keys (`matomo.default.*`) are copied into the database only when the key
is absent (`reference/configuration.md`). On an existing database, a plugin newly listed in `plugins.dat` is
installed, a plugin already known keeps its state: enabling or disabling one is done in the back office.

## Checks

- Before: `SELECT entity_key, entity_value FROM core_datastore WHERE entity_key LIKE 'core.plugins.status.%'` and the
  site properties, saved in `.migration/`.
- After the upgrade on the copy: the same query; every plugin of the before war that the after war still ships is
  installed with its v8 version; the site properties are those saved.
- The bench boots the after war on that copy: no startup exception, back office and front office answer.
