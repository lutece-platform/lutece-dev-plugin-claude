# Archetypes of sites

Measured on the sites of one organisation, several hundred, most of them on v7. No site ships Java of its own; nearly
all have overrides under `conf/override`, most have Spring contexts (`oauth2`, `mylutece-oauth2`,
`workflow-notifygru`, `core`), and most a `src/conf/<env>/` per environment. The work of an update is the
composition, the configuration, the templates and the database, whatever the archetype.

| Archetype | Recognised by | Target | What weighs |
|---|---|---|---|
| Site on a v7 theme of its family | a `lutece-site` theme dependency | the v8 pack that succeeds that theme (the organisation's successors file) | per-environment overrides, Spring contexts, per-environment templates, plugins without v8 |
| Site already on a pack | a `lutece-site` pack dependency | the same pack, v8 version | parent, BOM, pack version |
| Site on a layer with no v8 version | a theme or pack the gate reports `NO-V8` with no successor | none yet | the gate stops: the layer itself is migrated first |
| Starter site | `<family>-starter` | the starter 8.x | the plugins the v8 starter no longer brings |
| Explicit site on a theme | a theme and a plugin list | BOM + explicit list | many template overrides; a site-specific plugin in its own repository, migrated first |
| Site without theme | its own skin, `web.xml`, `core_context.xml`, JSP overrides | BOM + explicit list | the web.xml and the JSP, the Ant-built SQL |
| v6 or older site | `lutece-site-pom` 2.x or 3.x | a double jump | `plugin-directory` and `plugin-form` have no v8: a rewrite on forms, or a new site |
| v8 site | `lutece-site-pom` 8.x | the current level | parent, BOM and pack versions, contexts left over, `server.xml`, Liquibase |

## Build of a v7 site

A v7 site declares its repositories in `http://`; a user mirror of `external:http:*` that points to the snapshot
repository hides the release repository, and the v7 parent is not found. Build it with its own settings file (a
mirror of `external:http:*` to `https://dev.lutece.paris.fr/maven_repository`, the release and snapshot repositories
in https) and `--repo .migration/m2`. A private artefact no public repository serves (a v7 theme, a pack) is built
from its source tag with `mvn install` into that same repository.

A `src/conf/<env>/` holding a file where the default webapp has a directory of the same name (or the reverse) makes
`site-assembly -P<env>` fail: it is a defect of the site, fixed before the before state can be assembled.
