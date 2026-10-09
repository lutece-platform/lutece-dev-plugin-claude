# A site's database across the update

A fresh install proves the war starts; it proves nothing about the database the environments already have. Three
things decide what that database becomes.

## 1. Liquibase takes over a v7 database only through the migration mode, the core first

`plugin-liquibase` runs the scripts `SqlPathInfo` recognises (`sql/plugins/<p>/(core|plugin)/…`,
`upgrade/update…<from>-<to>.sql`, `sql/themes/<t>/…`) whose first line is `-- liquibase formatted sql` (SI12), and
only from the classpath (`WEB-INF/classes/sql`). On a database with no `DATABASECHANGELOG` and no recorded versions,
it runs nothing and records the versions the war declares (`TestIncludeAllFilter`, `LiquibaseRunnerContext`): every
v7 → v8 upgrade script is then skipped for good. Three more facts decide the procedure:

- It runs the core scripts first, then the others in path order, reordered by `-- lutece runAfter:`: a component
  script that inserts a key the core upgrade inserts too, without deleting it first, hits a duplicate key (SI13).
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
   needs the takeover (steps 4 and 5): a component it recorded no version for is installed as new by a normal v8 start, over its
   existing rows. Two causes: its SQL has no
   `-- liquibase formatted sql` first line (`LiquibaseRunner files not managed by liquibase are …`, a start
   plugin-liquibase refuses unless `liquibase.safeRun=false`), or its SQL directory does not match its plugin name
   (plugin-liquibase 1.0.2: `resolves to component '<dir>' which is not declared by any plugin descriptor`, a refused
   start under `liquibase.safeRun=true`; earlier: `No plugin metadata for <dir>`).
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
it to the v7 database first. The `lutece-e2e` bench plays the same sequence, step 1 included, in `lpe2e upgrade` with
`E2E_TAKEOVER` (`reference/upgrade.md` of that skill).

## 2. Settings the takeover changes

`lpe2e upgrade` lists in `artifacts/datastore-lost.txt` the settings of the site (advanced parameters, site
properties, cache statuses, theme) whose value the takeover changed or removed. A value the site had chosen is set
again, in the back office or in a SQL script of the site that runs after the core's.

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
