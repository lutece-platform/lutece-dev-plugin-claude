# How a site's configuration is resolved

`site_check.py config <war>` computes it; `site_check.py config <war> --against <dump> --env <env>` checks the model
against the running site. What follows is what the model implements, each point read in the code or measured.

## Lutece 8

| Ordinal | Source | Files |
|---|---|---|
| 600 | Liberty `appProperties` | server.xml of the environment |
| 500 | Liberty `<variable>` | server.xml: a variable named like a Lutece key wins over every file |
| 500 | `VaultConfigSource` (`library-configsource-vault`) | values read from Vault at run time, none in the war |
| 400 | system properties | `-D` |
| 300 | environment variables | `key`, `key` with non-alphanumerics as `_`, the same upper-cased |
| 250 | `LuteceOverrideConfigSource` | `WEB-INF/conf/override/*.properties`, `override/plugins/*.properties` |
| n | a ConfigSource a jar ships | the properties files at the root of that jar; n is the constant its `getOrdinal( )` returns, read in its bytecode (180 for the configuration library measured) |
| 150 | `LuteceConfigSource` | `config`, `db`, `lutece`, `search`, `daemons`, `caches`, `editors`.properties, then `conf/plugins/*`, `conf/themes/*` |
| 100 | `microprofile-config.properties` | `META-INF/` of the jars and of `WEB-INF/classes` |

- **Inside one source**, files load in the order of `FileSorterUtil.sortByPropertiesPrecedence` and the last one
  loaded wins (`AppInitPropertiesService`, `WebConfResourceLocator`, `PropertiesService.loadFile`): the seven root
  files, then `conf/plugins/*`, then `conf/themes/*` in the base source; `conf/override/*`, then
  `conf/override/plugins/*` in the override source; alphabetical order of the path inside each directory. So a theme
  beats a plugin, and `override/plugins/x.properties` beats `override/lutece.properties`. Two files of one source
  setting the same key differently is SI26.
- **Profiles** resolve source by source (SmallRye Config 3.18, measured): in one source `%dev.key` wins over `key`;
  a source of higher ordinal wins whatever the profile, so a plain key at 250 beats `%dev.key` at 180. A key
  starting with a profile name but no `%` is a literal name nobody reads (SI29).
- **An empty value masks** the key of every lower source: the property is absent and the caller's default applies.
- The configuration is read once at startup: `AppPropertiesService` has no reload in v8.

## Lutece 7

- 7.0.10 and later: one MicroProfile source (ordinal 100). Loading order, the last one wins: the seven root files,
  then the directories `plugins/`, `themes/`, `override/`, `override/plugins/`, each in file system order
  (`File.listFiles`, unspecified: two files of one directory setting the same key were already undetermined).
- Before 7.0.10: `AppPropertiesService` only, same files, a key set empty returns `""` instead of the default.
- `src/conf/<env>/` was copied over `webapp/` by the `-P<env>` profile of `lutece-site-pom` 7.x.

## What no longer exists in v8

| v7 | v8 |
|---|---|
| `src/conf/<env>/` per environment | one override with `%<env>.key` keys (`site_check.py envconf`) and an environment that sets `MP_CONFIG_PROFILE` (SI09, SI84) |
| `*_context.xml` (core and plugins) | ignored: a bean value is a key the v8 plugin reads with `@ConfigProperty`, a replaced bean is an `@Alternative` in a plugin (SI20) |
| `log.properties` | log4j2 files or the container (SI21) |
| `db.properties` pools (C3p0, Tomcat) | `portal.poolservice=fr.paris.lutece.util.pool.service.ManagedConnectionService`, `portal.ds=jdbc/portal`, a `<dataSource jndiName="jdbc/portal">` in `server.xml` (SI22, SI23) |
| core keys `head.url.*.css.mode*`, `system.*`, `path.logs`, `autoInit`, `file.*`, Ehcache 2 keys | removed; a site that still sets them sets nothing (SI27) |

## Keys that seed the database

Some values are only copied into the database the first time: `plugins.dat` (`PluginService.loadPluginsStatus`
writes `core.plugins.status.<name>.installed` and `.pool` only when absent), `caches.dat`
(`Lutece107CacheManager`), `matomo.default.*` (`MatomoInclude.java:85-99`). On a database that already has them,
changing the file changes nothing: the value is changed in the back office or by an SQL script of the site.
