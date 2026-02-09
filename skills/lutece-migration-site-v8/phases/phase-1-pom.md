# Phase 1: POM Migration

**Input from Phase 0:** Use the dependency version map produced by the scanner. Each Lutece dependency's v8 version was already verified — use those exact versions.

**Reference documentation:** `~/Documents/Formation/LuteceV8/comite-achitecture.wiki/`

## Steps

### 1. Update parent POM

Change the parent to Lutece 8. **For sites, use `lutece-site-pom`** (not `lutece-global-pom`):

```xml
<parent>
    <artifactId>lutece-site-pom</artifactId>
    <groupId>fr.paris.lutece.tools</groupId>
    <version>8.0.0-SNAPSHOT</version>
</parent>
```

> **Note:** `lutece-global-pom` is for plugins/libraries. Sites must use `lutece-site-pom`.

### 2. Update site version

**Increment the current major version by 1** and set to `X+1.0.0-SNAPSHOT` (e.g. `2.1.0-SNAPSHOT` → `3.0.0-SNAPSHOT`). Do NOT set it to `8.0.0-SNAPSHOT` — that is the core/parent version, not the site's own version.

### 3. Verify packaging

```xml
<packaging>lutece-site</packaging>
```

### 4. Add BOM for dependency management (recommended)

Add the Lutece BOM to centralize version management. **Note the groupId is `fr.paris.lutece.starters`**:

```xml
<dependencyManagement>
    <dependencies>
        <!-- Lutece BOM -->
        <dependency>
            <groupId>fr.paris.lutece.starters</groupId>
            <artifactId>lutece-bom</artifactId>
            <version>8.0.0-SNAPSHOT</version>
            <scope>import</scope>
            <type>pom</type>
        </dependency>
    </dependencies>
</dependencyManagement>
```

With the BOM, individual plugin versions can be omitted (the BOM provides them). If a specific version is needed, it overrides the BOM.

### 5. Update lutece-core dependency

```xml
<dependency>
    <groupId>fr.paris.lutece</groupId>
    <artifactId>lutece-core</artifactId>
    <version>[8.0.0-SNAPSHOT,)</version>
    <type>lutece-core</type>
</dependency>
```

### 6. Consider starters (recommended for new sites)

Lutece 8 introduces **starters** that bundle common plugin sets. Starters dramatically simplify dependency management:

| Starter | Use case | Key plugins included |
|---------|----------|---------------------|
| `forms-starter` | Dynamic forms management | forms, workflow, genericattributes, unittree, accesscontrol, lucene, rest |
| `appointment-starter` | Appointment/calendar management | appointment, workflow, genericattributes |
| `editorial-starter` | Editorial content management | document, htmldocs |
| `lutece-starter` | Complete application with all modules | All common plugins |

**Starter dependency format:**
```xml
<dependency>
    <groupId>fr.paris.lutece.starters</groupId>
    <artifactId>forms-starter</artifactId>
    <version>8.0.0-SNAPSHOT</version>
</dependency>
```

**Migration strategy:**
- If the site has many individual plugins that map to a starter, **replace them with the starter**
- Add only plugins NOT included in the starter as separate dependencies
- Plugins not in the starter still need explicit version (or use BOM)
- Comment dependencies with `<!-- Dépendance non importée par le starter XXX -->` for clarity

**Example: Before (v7 style)**
```xml
<dependency><artifactId>plugin-forms</artifactId>...</dependency>
<dependency><artifactId>plugin-workflow</artifactId>...</dependency>
<dependency><artifactId>plugin-genericattributes</artifactId>...</dependency>
<!-- ... 20 more plugins ... -->
```

**Example: After (v8 with starter)**
```xml
<!-- Main starter -->
<dependency>
    <groupId>fr.paris.lutece.starters</groupId>
    <artifactId>forms-starter</artifactId>
    <version>8.0.0-SNAPSHOT</version>
</dependency>

<!-- Dépendances non importées par le starter forms-starter -->
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>module-workflow-unittree</artifactId>
    <type>lutece-plugin</type>
</dependency>
```

### 7. Update all Lutece plugin/module dependency versions

Use the **dependency version map from Phase 0**. Use the exact versions verified earlier. Do NOT guess or hardcode versions. If using the BOM, versions can be omitted for plugins managed by the BOM.

### 8. Remove old/unnecessary dependencies

- `org.springframework` (Spring)
- `net.sf.ehcache` (EhCache)
- `com.sun.mail` (javax.mail)
- `org.glassfish.jersey` (Jersey)
- `net.sf.json-lib` (use Jackson)

> **WARNING — CSS/resource impact:** When removing Lutece plugins or themes (e.g. `site-theme-wiki`), check if the site's templates reference CSS or JS files provided by those dependencies. If templates use `<link href="css/xxx.css">` and that CSS came from the removed plugin, the layout will break. Either:
> 1. Keep the dependency if still needed for resources
> 2. Create local copies of the CSS/JS files in `webapp/css/` or `webapp/js/`
> 3. Remove the references from the templates

### 9. Configure logging for OpenLiberty telemetry (optional)

To redirect logs to `java.util.logging` for OpenTelemetry export:

```xml
<!-- Exclude log4j from lutece-core -->
<dependency>
    <groupId>fr.paris.lutece</groupId>
    <artifactId>lutece-core</artifactId>
    <version>[8.0.0-SNAPSHOT,)</version>
    <type>lutece-core</type>
    <exclusions>
        <exclusion>
            <groupId>org.apache.logging.log4j</groupId>
            <artifactId>log4j-core</artifactId>
        </exclusion>
        <exclusion>
            <groupId>org.apache.logging.log4j</groupId>
            <artifactId>log4j-slf4j-impl</artifactId>
        </exclusion>
        <exclusion>
            <groupId>org.apache.logging.log4j</groupId>
            <artifactId>log4j-jakarta-web</artifactId>
        </exclusion>
    </exclusions>
</dependency>

<!-- Log4j → JUL bridge -->
<dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-to-jul</artifactId>
    <scope>runtime</scope>
</dependency>

<!-- SLF4J → JUL bridge -->
<dependency>
    <groupId>org.slf4j</groupId>
    <artifactId>slf4j-jdk14</artifactId>
    <version>1.7.36</version>
    <scope>runtime</scope>
</dependency>
```

### 10. Remove springVersion property if present

### 11. Update repository URLs from `http://` to `https://`

### 12. Add theme dependency (if using external theme)

V8 sites often use external themes instead of local skin files:

```xml
<!-- External theme -->
<dependency>
    <groupId>fr.paris.lutece.themes</groupId>
    <artifactId>site-theme-parisfr</artifactId>
    <version>[3.0.0-SNAPSHOT]</version>
    <type>lutece-site</type>
</dependency>

<!-- jQuery theme library (if theme requires jQuery) -->
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-theme-jquery</artifactId>
    <version>2.0.0-SNAPSHOT</version>
    <type>lutece-plugin</type>
</dependency>
```

> **Note:** `library-theme-jquery` provides jQuery integration for themes that still need it. For new sites, prefer vanilla JS.

## Verification (MANDATORY before next phase)

1. Parent POM is `8.0.0-SNAPSHOT`
2. `lutece-core` dependency references v8
3. All plugin versions match the v8 version map from Phase 0 (or are managed by BOM)
4. No Spring, EhCache, Jersey, javax.mail dependencies
5. **No build** — site assembly will fail until all phases are done
6. Mark task as completed when all POM checks pass
