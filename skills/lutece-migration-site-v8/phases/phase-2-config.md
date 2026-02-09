# Phase 2: Configuration Migration

**Reference documentation:** `~/Documents/Formation/LuteceV8/comite-achitecture.wiki/Configuration-et-build-d'un-site-Lutece.md`

## Step 1 — OpenLiberty configuration (NEW in v8)

Lutece 8 runs on **OpenLiberty** instead of Tomcat. Create the OpenLiberty configuration directory:

```
src/main/liberty/config/
├── server.xml           # Main server config (features, DB, app)
├── bootstrap.properties # Bootstrap properties (can be empty)
├── jvm.options          # JVM options (optional, can be empty)
└── server.env           # Environment variables (OpenTelemetry, etc.)
```

**All 4 files should exist**, even if some are empty (bootstrap.properties, jvm.options).

### server.xml

Create `src/main/liberty/config/server.xml` with the required features:

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<server description="lutece server">
    <featureManager>
        <feature>persistence-3.1</feature>
        <feature>beanValidation-3.0</feature>
        <feature>jndi-1.0</feature>
        <feature>jdbc-4.2</feature>
        <feature>localConnector-1.0</feature>
        <feature>cdi-4.0</feature>
        <feature>servlet-6.0</feature>
        <feature>pages-3.1</feature>
        <feature>mpConfig-3.1</feature>
        <feature>mail-2.1</feature>
        <feature>xmlBinding-4.0</feature>
        <feature>concurrent-3.0</feature>
        <feature>restfulWS-3.1</feature>
        <feature>mpHealth-4.0</feature>
        <feature>mpTelemetry-2.0</feature>
    </featureManager>

    <variable defaultValue="9090" name="http.port"/>
    <variable defaultValue="9443" name="https.port"/>

    <applicationManager autoExpand="true"/>
    <httpEndpoint host="*" httpPort="${http.port}" httpsPort="${https.port}" id="defaultHttpEndpoint"/>

    <!-- OpenTelemetry source configuration -->
    <mpTelemetry source="message, trace, ffdc"/>

    <!-- Application entry: set context-root to the site name -->
    <!-- In dev mode (mvn liberty:dev), the liberty-maven-plugin manages deployment
         via a loose-archive .war.xml in dropins — the <application> entry below
         may generate a warning if lutece.war doesn't exist. You can comment it out
         for dev, or set name/context-root to match your site's artifactId. -->
    <application context-root="lutece" location="lutece.war" name="lutece" type="war"/>
    <applicationMonitor dropinsEnabled="false" updateTrigger="disabled"/>

    <!-- JDBC library from deployed WAR -->
    <library id="jdbcLib">
        <fileset dir="/config/apps/expanded/lutece.war/WEB-INF/lib/" includes="*.jar"/>
    </library>

    <!-- Database connection variables - CUSTOMIZE THESE -->
    <variable defaultValue="DB_USER" name="portal.user"/>
    <variable defaultValue="DB_PASSWORD" name="portal.password"/>

    <!-- JNDI DataSource — URL-based approach (recommended, most reliable) -->
    <dataSource jndiName="jdbc/portal">
        <jdbcDriver libraryRef="jdbcLib"/>
        <properties url="jdbc:mysql://localhost:3306/DB_NAME?useSSL=false&amp;allowPublicKeyRetrieval=true&amp;serverTimezone=Europe/Paris"
                    user="${portal.user}" password="${portal.password}"/>
    </dataSource>
</server>
```

> **IMPORTANT — Lessons from real migrations:**
> - **Use URL-based `<properties url="jdbc:mysql://...">`** — This is the most reliable approach. The `properties.mysql` and generic `properties` with separate serverName/databaseName fields have caused connection failures in practice.
> - **Add `allowPublicKeyRetrieval=true`** in the URL — without it, MySQL 8+ connections fail with SQL 1045 errors due to `caching_sha2_password`
> - **Add `useSSL=false`** — avoids SSL negotiation issues in dev/local environments
> - **Verify the database name** in the URL matches the actual database (e.g. `site_support`, not `support`)
> - The `jndiName` value (e.g. `jdbc/portal`) must match `portal.ds` in db.properties

**Ask the user** for the database connection values (host, port, db name, user, password) before creating this file.

### server.env (OpenTelemetry configuration)

Create `src/main/liberty/config/server.env`:

```
# OpenTelemetry configuration
OTEL_SDK_DISABLED=false
OTEL_SDK_NAME=LUTECE
# Uncomment to export telemetry to a collector:
# OTEL_EXPORTER_OTLP_ENDPOINT=http://observability-opentelemetry-collector:4317
```

### bootstrap.properties

Create `src/main/liberty/config/bootstrap.properties` (can be empty initially):

```properties
# Bootstrap properties for Liberty server
# Add custom bootstrap properties here if needed
```

### jvm.options

Create `src/main/liberty/config/jvm.options` (can be empty initially):

```
# JVM options for Liberty server
# Example: -Xmx1024m
```

## Step 2 — web.xml (if present)

If the site has a `webapp/WEB-INF/web.xml` or web.xml fragments:

1. Replace namespace: `http://java.sun.com/xml/ns/javaee` → `https://jakarta.ee/xml/ns/jakartaee`
2. Update schema version to `6.0`
3. Remove Spring listeners if present (e.g., `ContextLoaderListener`)
4. Remove any `<context-param>` referencing Spring context XML

```xml
<!-- BEFORE -->
<web-app xmlns="http://java.sun.com/xml/ns/javaee" version="3.0">

<!-- AFTER -->
<web-app xmlns="https://jakarta.ee/xml/ns/jakartaee" version="6.0">
```

## Step 3 — Spring context XML cleanup

Delete any Spring context XML files:
- `webapp/WEB-INF/*_context.xml`
- `webapp/WEB-INF/conf/*_context.xml`

These are no longer used — CDI replaces Spring for bean management.

## Step 4 — db.properties

Two approaches for database configuration in v8:

**Option A (recommended): JNDI datasource via server.xml**
```properties
portal.poolservice=fr.paris.lutece.util.pool.service.ManagedConnectionService
portal.ds=jdbc/portal
```

> **CRITICAL:** The property name is **`portal.ds`** (NOT `portal.jndiname`). Using the wrong name causes JNDI lookup failures at runtime.

> **The `portal.ds` value must exactly match** the `jndiName` in `server.xml`'s `<dataSource>` element. If the site uses a custom JNDI name (e.g. `jdbc/SUPPORT`), both must match.

**Option B (traditional): Direct connection via db.properties**
```properties
portal.poolservice=fr.paris.lutece.util.pool.service.LuteceConnectionService
portal.driver=com.mysql.cj.jdbc.Driver
portal.url=jdbc:mysql://localhost/DB_NAME?autoReconnect=true&useUnicode=yes&characterEncoding=utf8&allowPublicKeyRetrieval=true&useSSL=false
portal.user=DB_USER
portal.password=DB_PASSWORD
portal.initconns=2
portal.maxconns=50
portal.logintimeout=2
portal.checkvalidconnectionsql=SELECT 1
```

If the JDBC driver class is `com.mysql.jdbc.Driver`, update to `com.mysql.cj.jdbc.Driver`.

## Step 5 — Property overrides structure

V8 sites use a specific override structure:

```
webapp/WEB-INF/conf/override/
├── profiles-config.properties   # Liquibase and profile settings
└── plugins/
    └── mylutece.properties      # Plugin-specific overrides
```

### profiles-config.properties (Liquibase configuration)

Create `webapp/WEB-INF/conf/override/profiles-config.properties`:

```properties
# Liquibase database migration
liquibase.enabled.at.startup=true
liquibase.accept.snapshot.versions=true

# MicroProfile Config profiles (optional)
# Active profile via MP_CONFIG_PROFILE env variable
# %dev.lutece.prod.url=https://dev.example.com/lutece/
# %rec.lutece.prod.url=https://rec.example.com/lutece/
# %prod.lutece.prod.url=https://prod.example.com/lutece/
```

### Plugin-specific overrides

For plugin configuration overrides, create files in `webapp/WEB-INF/conf/override/plugins/`:

Example: `webapp/WEB-INF/conf/override/plugins/mylutece.properties`:

```properties
# MyLutece authentication configuration
mylutece.url.login=jsp/site/Portal.jsp?page=mylutece&action=login
mylutece.url.doLogout=jsp/site/plugins/mylutece/DoMyLuteceLogout.jsp
mylutece.url.createAccount=jsp/site/Portal.jsp?page=mylutece&action=createAccount
mylutece.url.viewAccount.redirect=jsp/site/Portal.jsp?page=mydashboard
mylutece.template.accessDenied=/skin/plugins/mylutece/page_access_denied.html
mylutece.template.accessControled=/skin/plugins/mylutece/page_access_controled.html

# User attribute mapping (identity provider → Lutece)
mylutece.attribute.mapping.user.name.given=first_name
mylutece.attribute.mapping.user.name.family=last_name
mylutece.attribute.mapping.user.mail.contact=mail_contact
```

## Step 6 — Plugin activation (`plugins.dat`)

> **CRITICAL — Common post-migration failure:** After migration, the site starts but XPages return errors like "The specified Xpage 'xxx' cannot be retrieved". This is because **plugins are not activated**.

In Lutece 8, plugin status is stored in `core_datastore` (keys `core.plugins.status.<plugin>.installed`). The file `plugins.dat` (`WEB-INF/plugins/plugins.dat`) provides **default values at first startup only**.

### Create/update `plugins.dat`

Ensure `webapp/WEB-INF/plugins/plugins.dat` exists and lists **all plugins that should be active**:

```
#<plugin_name>;<status (1=installed)>;<pool>
core_extensions;1;portal
lucene;1;portal
forms;1;portal
workflow;1;portal
genericattributes;1;portal
mylutece;1;portal
html;1;portal
contact;1;portal
rest;1;portal
```

**Rules:**
- List EVERY plugin the site uses (check POM dependencies for the list)
- The `pool` column should be `portal` (the JNDI datasource)
- After a clean rebuild (`site-assembly`), this file seeds plugin activation in the database
- If plugins are already in `core_datastore` (existing DB), the file is ignored — you must INSERT/UPDATE directly in the database

### For existing databases — Generate upgrade SQL script

Use the automated script to generate SQL for plugin activation AND cleanup of removed plugins:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-site-v8/scripts/generate-upgrade-sql.sh" . "removed_plugin1,removed_plugin2" > migration-upgrade.sql
```

Arguments:
- First argument: project root (`.` for current directory)
- Second argument: comma-separated list of plugins **removed** during migration (from Phase 0/1)

The script generates:
1. **Plugin activation** — `INSERT INTO core_datastore` for all plugins in the POM
2. **Cleanup of removed plugins** — Deletes admin rights, roles, portlet types, dashboards, and datastore entries for each removed plugin
3. **Table drop suggestions** — Commented-out `DROP TABLE` statements for manual review

> **CRITICAL — Protected datastore keys:** The script protects `theme.globalThemeCode`, `portal.theme.*`, and `core.*` keys. Deleting `theme.globalThemeCode` causes a NPE in `ThemeDAO.getGlobalTheme()` that breaks the entire front-office.

**After generating**, review the SQL file and execute:
```bash
mysql -u USER -p DB_NAME < migration-upgrade.sql
```

## Step 7 — Other properties files

Scan all `.properties` files for references to deprecated patterns:
- `SpringContextService` references → remove
- Old class names that may have changed in v8

## Verification

Run the verification script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-site-v8/scripts/verify-site-migration.sh"
```

Config checks (WB01, WB03, SP03) must PASS.

Mark task as completed ONLY when verification passes.
