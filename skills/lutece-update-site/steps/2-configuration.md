# Step 2 — The configuration

How the v8 core resolves it: `reference/configuration.md`. Codes: SI09, SI20-SI30.

## Per-environment directories (`src/conf/<env>/`)

```bash
python3 ${LUTECEPOWERS_ROOT}/tools/site_check.py envconf . --out .migration/profiles-config.draft.properties 2> .migration/envconf-unconverted.txt
```

The draft merges every `conf/override` properties file of every environment: a value all environments share is a
plain key, a value that differs is `%<env>.key`, every line names the file it comes from, and no secret is copied.
Before moving it to `webapp/WEB-INF/conf/override/profiles-config.properties`:

- **Ask the user which MicroProfile profile each environment runs** (`MP_CONFIG_PROFILE` or `mp.config.profile`, set
  by the deployment, rarely in the repository). The directory names are only a proposal: a key prefixed by a profile
  no environment runs is ignored everywhere. Record the answer in the decisions file (`- profile <name>: …`).
- A key absent from one environment keeps the plugin's default there: the draft says so; confirm it.
- Every `UNCONVERTED` file is handled by one of the sections below or dropped with a decision.

## Spring contexts (`*_context.xml`)

v8 reads none of them (SI20). List what they set:

```bash
python3 ${LUTECEPOWERS_ROOT}/tools/spring-context-catalog.py . > .migration/spring-beans.json
```

Then draft the keys the v8 war reads:

```bash
python3 ${LUTECEPOWERS_ROOT}/tools/site_check.py spring . --war <after war> > .migration/spring.draft.properties
```

It writes `<bean id>.<property>` when a class or a default of the war names that key, under the profile of the
environment the context came from, holds secrets back, skips a context v7 never read (a misplaced directory: its
beans never applied), and lists, for every other property, the keys of the war with the same last segment. For each
of those, find how the v8 plugin reads that value (`@ConfigProperty(name = "…")`, a
producer, a `.properties` default) in its sources under `~/.lutece-references/` or in its v8 jar, and write that
key in `conf/override`, under the profile of the environment it came from. The key must be the one the code reads,
character for character (SI27 reports a key no class of the war names). A bean the site replaced (a mock, another
implementation) becomes an `@Alternative` in a plugin or a key the plugin offers (`library-notifygru.notifier.mock.enabled`),
never a context file. Write `- file <context>: <bean> -> <key>, …` in the decisions file.

## Values imposed by a library

A configuration library (a ConfigSource in a jar, between the plugins' defaults and `conf/override`) changes values
without any file of the site changing: every key it sets that differs from what the site had appears in SI80 at
phase E, with its origin. Decide each: keep the organisation's default, or set the site's value in `conf/override`.
A class it names that the war does not ship (an authentication class of a module the site does not embed) fails
SI28, and the back office does not start. A key served by Vault (ordinal 500) wins over `conf/override`.

## Database, logging, secrets

- `db.properties`: `portal.poolservice=fr.paris.lutece.util.pool.service.ManagedConnectionService`,
  `portal.ds=jdbc/portal`, and the same for every pool a `.pool` line of `plugins.dat` names; the datasource and its
  credentials live in `server.xml` (step 5) (SI22-SI24).
- `log.properties` goes (SI21).
- A password, a token, a client secret found in any file (SI30) is listed for Vault or the environment and removed
  from the repository; the key stays documented in a comment, without its value.
