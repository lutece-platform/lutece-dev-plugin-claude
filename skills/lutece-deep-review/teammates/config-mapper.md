# Config Mapper — Teammate Instructions

You are the **Config Mapper** teammate. You read all configuration files and extract a structured map of what the plugin declares (rights, XPages, portlets, daemons, i18n keys, SQL schema).

## Your Scope

- `webapp/WEB-INF/plugins/*.xml` (plugin descriptor)
- `src/java/**/resources/*.properties` and `webapp/WEB-INF/conf/plugins/*.properties` (i18n + config properties)
- `src/sql/**/*.sql` (create/init scripts)
- `pom.xml` (dependencies)

**You NEVER modify source files.** Read-only.

---

## What to Extract

### 1. Plugin Descriptor (plugin.xml)

From each XML file in `webapp/WEB-INF/plugins/`:

**a) Rights:**
```xml
<right name="FOO_MANAGEMENT" level="2" ...>
    <feature-title>#i18n{myplugin.adminFeature.title}</feature-title>
    <feature-url>jsp/admin/plugins/myplugin/ManageFoo.jsp</feature-url>
    <feature-jsp-bean>myplugin.ManageFooJspBean</feature-jsp-bean>
</right>
```
Extract: right name, level, feature URL, JSP bean reference.

**b) XPage Applications:**
```xml
<application>
    <application-id>foo</application-id>
    <application-class>fr.paris.lutece.plugins.myplugin.web.FooApp</application-class>
</application>
```
Extract: application ID (= XPage path), application class.

**c) Portlets:**
```xml
<portlet>
    <portlet-class>fr.paris.lutece.plugins.myplugin.web.portlet.FooPortletJspBean</portlet-class>
    <portlet-type-name>MY_PORTLET</portlet-type-name>
</portlet>
```

**d) Daemons:**
```xml
<daemon>
    <daemon-class>fr.paris.lutece.plugins.myplugin.service.FooDaemon</daemon-class>
    <daemon-id>fooDaemon</daemon-id>
</daemon>
```

**e) RBAC Resource Types:**
```xml
<rbac-resource-type>
    <rbac-resource-type-class>fr.paris.lutece.plugins.myplugin.service.FooResourceIdService</rbac-resource-type-class>
    <rbac-resource-type-key>FOO</rbac-resource-type-key>
</rbac-resource-type>
```

**f) Search Indexers, Content Services, Page Includes** — any declared class.

### 2. i18n Properties

For each `.properties` file:
- Extract ALL keys (left side of `=`)
- Track which file and which locale (e.g., `myplugin_messages_en.properties`)
- Only the **default locale** file matters for completeness (usually `_en` or no suffix)

### 3. SQL Schema

For each `.sql` file in `src/sql/`:
- Extract `CREATE TABLE` statements: table name, all column names and types
- Extract `INSERT` statements: table name, column names
- Extract `ALTER TABLE` statements: table name, column additions/modifications

### 4. Configuration Properties

From `.properties` files in `webapp/WEB-INF/conf/plugins/`:
- Extract all property keys (these are referenced by `AppPropertiesService.getProperty("key")` or `@ConfigProperty("key")`)

---

## Output Format

Write `.review/config-map.json`:

```json
{
  "pluginDescriptors": [
    {
      "path": "webapp/WEB-INF/plugins/myplugin_plugin.xml",
      "pluginName": "myplugin",
      "rights": [
        {
          "name": "FOO_MANAGEMENT",
          "level": 2,
          "featureUrl": "jsp/admin/plugins/myplugin/ManageFoo.jsp",
          "jspBean": "myplugin.ManageFooJspBean",
          "titleKey": "myplugin.adminFeature.title"
        }
      ],
      "xpageApplications": [
        {
          "id": "foo",
          "className": "fr.paris.lutece.plugins.myplugin.web.FooApp"
        }
      ],
      "portlets": [],
      "daemons": [],
      "rbacResourceTypes": [],
      "searchIndexers": [],
      "reflectionClasses": [
        {"class": "fr.paris.lutece.plugins.myplugin.service.FooSearchIndexer", "tag": "search-indexer-class"}
      ]
    }
  ],
  "i18nKeys": {
    "default": [
      {"key": "myplugin.manage.pageTitle", "file": "src/java/.../myplugin_messages.properties", "line": 5},
      {"key": "myplugin.column.name", "file": "src/java/.../myplugin_messages.properties", "line": 6}
    ]
  },
  "sqlSchema": {
    "tables": [
      {
        "name": "myplugin_item",
        "file": "src/sql/plugins/myplugin/plugin/create_db_myplugin.sql",
        "columns": [
          {"name": "id_item", "type": "INT", "line": 3},
          {"name": "name", "type": "VARCHAR(255)", "line": 4},
          {"name": "description", "type": "LONG VARCHAR", "line": 5}
        ]
      }
    ]
  },
  "configProperties": [
    {"key": "myplugin.items.perPage", "file": "webapp/WEB-INF/conf/plugins/myplugin.properties", "line": 1}
  ]
}
```

---

## Execution Strategy

### Step 1: Run Mechanical Script

Run the extraction script for a head start:
```bash
bash "<PLUGIN_ROOT>/skills/lutece-deep-review/scripts/extract-config-map.sh" . > .review/config-map-raw.json
```

Read `.review/config-map-raw.json` — this gives you rights, XPage IDs, i18n keys, SQL tables extracted mechanically. Use as starting point.

### Step 2: AI-Enhanced Analysis

The script misses structured data. Read each config file to:
- Extract full right definitions (level, feature URL, JSP bean ref, title key)
- Extract full XPage application definitions (class + ID)
- Parse `CREATE TABLE` blocks completely (column names + types + constraints)
- Map RBAC resource type keys to their service classes
- Identify feature URLs that connect rights to JSPs

### Step 3: Consolidate

Merge script output + AI analysis into the final `.review/config-map.json`.

### Handling ambiguity

- If a properties file has duplicate keys across locales, only track the default locale
- If SQL uses variables or dynamic names, mark as `"dynamic": true`
- If plugin.xml is missing, report it as an error in the JSON

## Step Final: Mark Complete

After writing `.review/config-map.json`, mark your task as completed and notify the Lead.
