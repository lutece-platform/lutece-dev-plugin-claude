# Bench configuration of this project, read by lpe2e (the bench code lives in lutecepowers, its state in
# ~/.lutecepowers-e2e). No version is written here: every Lutece artefact of the bench site is the latest Lutece 8
# snapshot of the repositories, unless a line below pins one.
# Target under test: plugin | site (core: not supported). A site is assembled with its own pom.
E2E_TARGET=@@TARGET@@
# Source root of the artefact under test, relative to this file.
E2E_SRC=..
# Bench name: names its containers, its database and its state directory on the machine.
E2E_NAME=@@NAME@@
# Servlet context.
E2E_CONTEXT=lutece
# A plugin only — extra artefacts to assemble, as groupId:artifactId[:version[:type]], comma-separated (runtime deps not pulled
# transitively). No version, or `latest`: the latest Lutece 8 snapshot. Type: lutece-plugin by default.
E2E_PLUGINS=
# A plugin only — plugin names to mark installed in plugins.dat (comma-separated; the plugin under test is added
# automatically).
E2E_ENABLE=
# A plugin only — front-office authentication: plugin-mylutece + module-mylutece-database are assembled and enabled, with the
# account test/testtest (post-init-mylutece.sql). 0 leaves them out.
E2E_MYLUTECE=1
# Pins, only to reproduce a case on a given version (empty: the latest Lutece 8 snapshot).
#E2E_CORE_VERSION=
#E2E_LIQUIBASE_VERSION=
#E2E_MYLUTECE_VERSION=
#E2E_MYLUTECE_DATABASE_VERSION=
# A site only — the Maven profile it is assembled with: one without the environments' remote configuration source
# (Vault), which the bench cannot reach.
E2E_SITE_PROFILE=
# Scope of the screens/forms suites and of the crawl: target (the artefact under test only) | all (whole site).
# Empty: target for a plugin, all for a site (a site's screens are its plugins').
E2E_SCOPE=
# 1: the stand-ins of external systems run beside the application (CAS, OIDC, identitystore, notifygru, CRM, PayFiP,
# ANTS on http://fakes:9030, the project's own in harness/fakes/extra/*.py; an OpenID Connect provider on
# http://oauth2:8080). Every call is logged in artifacts/fakes/<channel>.log, which scenarios assert on.
E2E_FAKES=
# 1: real search engines run beside the application, Solr on http://localhost:8983 (or solr:8983) and Elasticsearch on
# http://localhost:9200 (or elastic:9200), started empty.
E2E_SEARCH=
# Restart the application once after the seed. The seed runs on a running application, so whatever the target
# cached from the tables at boot holds the state of an empty database for the whole run. Set to 1 when the
# artefact reads such a cache (a form list, a type registry, a reference list).
E2E_RESTART_AFTER_SEED=
# To prove a dependency fixed locally (mvn install in its clone) before it is published: 1 resolves the snapshots
# offline, from the local repository.
E2E_MVN_OFFLINE=0
# Synthetic volume loaded by the seed: none (default) | small | large (bottleneck hunting).
E2E_VOLUME=none
# Security keys the bench's own conf/override may switch off, comma-separated, each with its reason in a comment.
E2E_ALLOW_SECURITY_OFF=
# The database upgrade (lpe2e upgrade, reference/upgrade.md): the previous version's database taken over by the bench
# site. A plugin migrated from v7: E2E_V7_REF (git ref of the v7 sources), the v7 site pom and core, the extra
# artefacts at their v7 versions, the pins of v7 ranges that no longer compile (groupId:artifactId:version).
#E2E_V7_REF=
#E2E_V7_SITE_POM=7.0.8
#E2E_V7_CORE=7.1.9
#E2E_V7_PLUGINS=
#E2E_V7_DEP_PINS=
# A site: its v7 war (E2E_V7_WAR), a recette dump (E2E_V7_DUMP), the takeover scripts of site_check.py (E2E_TAKEOVER).
# A Lutece 8 update: the war of the version the environments run (E2E_BEFORE_WAR).
#E2E_V7_WAR=
#E2E_V7_DUMP=
#E2E_TAKEOVER=
#E2E_BEFORE_WAR=
# false: plugin-liquibase of the v7 line starts despite SQL files without the Liquibase header (reported), as an
# environment would with liquibase.safeRun=false.
#E2E_V7_SAFE_RUN=
