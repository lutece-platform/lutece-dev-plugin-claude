# Phase 3: Web Configuration, Plugin Descriptor & SQL

---

## Step 1 — web.xml namespace (if applicable)

If the project has web.xml fragments in `webapp/`:

1. Replace namespace: `http://java.sun.com/xml/ns/javaee` → `https://jakarta.ee/xml/ns/jakartaee`
2. Update version to `6.0`
3. Remove Spring listeners if present (e.g., `ContextLoaderListener`)

---

## Step 2 — Plugin descriptor

Update the plugin descriptor file (`webapp/WEB-INF/plugins/pluginName.xml`):

1. Update `<version>` to the v8 version (from Phase 1 POM)
2. Update `<min-core-version>` to `8.0.0`
3. **Remove `<application-class>`** from all `<application>` elements — XPages are auto-discovered via CDI

```xml
<!-- BEFORE -->
<application>
    <application-id>myPlugin</application-id>
    <application-class>fr.paris.lutece.plugins.myplugin.web.MyXPage</application-class>
</application>

<!-- AFTER -->
<application>
    <application-id>myPlugin</application-id>
</application>
```

---

## Step 3 — beans.xml verification

Verify `src/main/resources/META-INF/beans.xml` exists and has correct content (should have been created in Phase 2 Step 2). If missing, create it now.

---

## Step 4 — SQL Liquibase headers

Run the script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/add-liquibase-headers.sh" . "pluginName"
```

This adds Liquibase headers to all SQL files that don't have them.

Then create upgrade SQL scripts if needed:
- `src/sql/plugins/pluginName/upgrade/update_db_pluginName-oldVersion-newVersion.sql`

---

## Step 5 — Configuration migration (if applicable)

If CDI beans need property values from `.properties` files, and the project previously used `AppPropertiesService`:

**In CDI-managed beans**, prefer `@ConfigProperty`:
```java
@Inject
@ConfigProperty(name = "myplugin.myProperty", defaultValue = "default")
private String _myProperty;
```

**In libraries** (no CDI context), use `ConfigProvider.getConfig()`:
```java
import org.eclipse.microprofile.config.Config;
import org.eclipse.microprofile.config.ConfigProvider;

private static Config _config = ConfigProvider.getConfig();
String value = _config.getOptionalValue(PROPERTY_KEY, String.class).orElse("default");
```

`AppPropertiesService.getProperty()` still works in v8 — MicroProfile Config is optional but preferred in CDI beans.

---

## Verification

Run the verification script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/lutece-migration-v8/scripts/verify-migration.sh"
```

Web/Config checks (WB01, WB02, ST01) must PASS.

Mark task as completed ONLY when verification passes.
