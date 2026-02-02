# Phase 1: POM Migration

**Input from Phase 0:** Use the dependency version map produced by the scanner. Each Lutece dependency's v8 version was already verified — use those exact versions.

## Steps

1. Update parent POM: `lutece-global-pom` version `6.x.x` → `8.0.0-SNAPSHOT`
2. Update artifact version: **increment the current major version by 1** and set to `X+1.0.0-SNAPSHOT` (e.g. `4.2.1-SNAPSHOT` → `5.0.0-SNAPSHOT`, `2.0.3-SNAPSHOT` → `3.0.0-SNAPSHOT`). Do NOT set it to `8.0.0-SNAPSHOT` — that is the core/parent version, not the plugin's own version
3. Remove Spring dependencies:
   - `spring-aop`, `spring-beans`, `spring-context`, `spring-core`, `spring-orm`, `spring-tx`, `spring-web`
4. Remove old cache dependencies:
   - `net.sf.ehcache:ehcache-core`, `net.sf.ehcache:ehcache-web`
5. Remove old mail dependency: `com.sun.mail:javax.mail`
6. Remove old persistence: `org.eclipse.persistence:javax.persistence`
7. Remove Quartz if present: `org.quartz-scheduler:quartz`
8. Remove Scannotation if present: `org.scannotation:scannotation`
9. Update `lutece-core` dependency version to `8.0.0-SNAPSHOT` (for plugins/modules)
10. Update all Lutece dependency versions using the **dependency version map from Phase 0**. Each dependency's v8 version was already verified and extracted — use those exact versions. Do NOT guess or hardcode versions
11. Add new dependencies if needed (JCache API, classgraph, etc.)
12. Remove `<springVersion>` property if present

## Library-specific POM Changes

For **libraries** (not plugins/modules), the `lutece-core` dependency may be **replaced** by `library-core-utils`:
```xml
<!-- REMOVED for libraries -->
<dependency>
    <groupId>fr.paris.lutece</groupId>
    <artifactId>lutece-core</artifactId>
    <type>lutece-core</type>
</dependency>

<!-- ADDED -->
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-core-utils</artifactId>
    <version>1.0.0-SNAPSHOT</version>
</dependency>
```

Also update repository URLs from `http://` to `https://`.

## Verification (MANDATORY before next phase)

1. Verify POM has no `org.springframework`, `net.sf.ehcache`, `javax.mail` dependencies
2. Verify parent POM is `8.0.0-SNAPSHOT` and core dependency is v8
3. Remove `net.sf.json-lib` if present (should use Jackson in v8)
4. Remove Jersey dependencies (`org.glassfish.jersey`) if present
5. **No build** — code still uses v7 imports, compilation will fail until Phase 2
6. Mark task as completed when all POM checks pass
