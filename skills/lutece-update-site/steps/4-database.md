# Step 4 — The database

What happens to an existing database: `reference/database.md`. Codes: SI12-SI14.

1. **SQL of the site** under `src/sql/`: a path `SqlPathInfo` recognises and the first line
   `-- liquibase formatted sql`, or it never runs (SI12). A site without its own plugin puts its settings script
   where it runs after the core's upgrade, or documents it as a manual step of the release.
2. **A database in production** (a v7 site, or a v8 site whose plugins move up): `site_check.py takeover` writes
   the two scripts of the takeover and prints what it would break (SI13: a component script that inserts a key the
   core upgrade inserts, or uses a table it drops; SI14: a renamed component whose create script drops the former
   tables). Then the recette dump of phase A, through `lpe2e upgrade` (`E2E_V7_WAR`, `E2E_V7_DUMP`,
   `E2E_TAKEOVER`): it plays `reference/database.md` §1 and lists the settings the takeover changed or removed
   (§2, `artifacts/datastore-lost.txt`).
3. **Scripts removed from a layer**: a pack or a theme that deleted its migration scripts or its `src/sql` in its v8
   tree still has them on its v7 branches and tags: read them there, never assume the upgrade path of a database
   from a v8 tree alone.
4. Record in the hand-over: whether the migration procedure was played, on which copy, and what the comparison of
   the saved rows showed. Not played: say so, the upgrade is not proven.
