# Migration Analysis: lutece-tech-plugin-filegenerator (v7 to v8)

## Overview

This document analyzes the migration differences between Lutece v7 (branch `develop`) and Lutece v8 (branch `develop_core8`) for the `lutece-tech-plugin-filegenerator` plugin.

**Version Change:** 2.1.6-SNAPSHOT -> 3.0.0-SNAPSHOT

## Summary of Changes

| Category | Files Changed |
|----------|---------------|
| Configuration | 6 files |
| Java Classes | 7 files modified, 2 files added |
| Templates | 1 file |
| JSP Files | 3 files |
| SQL Scripts | 4 files |
| Tests | 1 file |

**Total:** 23 files changed, 340 insertions(+), 174 deletions(-)

---

## 1. POM.xml Changes

### Parent POM
```xml
<!-- v7 -->
<version>6.1.0</version>

<!-- v8 -->
<version>8.0.0-SNAPSHOT</version>
```

### Lutece Core Dependency
```xml
<!-- v7 -->
<version>[7.0.4,)</version>

<!-- v8 -->
<version>[8.0.0-SNAPSHOT,)</version>
```

### Repository URLs (HTTP to HTTPS)
```xml
<!-- v7 -->
<url>http://dev.lutece.paris.fr/snapshot_repository</url>
<url>http://dev.lutece.paris.fr/maven_repository</url>

<!-- v8 -->
<url>https://dev.lutece.paris.fr/snapshot_repository</url>
<url>https://dev.lutece.paris.fr/maven_repository</url>
```

### New Test Dependencies
```xml
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-lutece-unit-testing</artifactId>
    <type>jar</type>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.glassfish.jaxb</groupId>
    <artifactId>jaxb-runtime</artifactId>
    <scope>test</scope>
</dependency>
```

### Removed Properties
```xml
<!-- Removed in v8 -->
<jiraProjectName>FGENTOR</jiraProjectName>
<jiraComponentId>15765</jiraComponentId>
```

---

## 2. CDI Migration (Spring to Jakarta CDI)

### 2.1 DAO Layer - TemporaryFileDAO.java

**Added CDI Annotation:**
```java
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public final class TemporaryFileDAO implements ITemporaryFileDAO
```

### 2.2 Home Class - TemporaryFileHome.java

**Before (v7):**
```java
import fr.paris.lutece.portal.service.spring.SpringContextService;

private static ITemporaryFileDAO _dao = SpringContextService.getBean( "temporaryFileDAO" );
```

**After (v8):**
```java
import jakarta.enterprise.inject.spi.CDI;

private static ITemporaryFileDAO _dao = CDI.current( ).select( ITemporaryFileDAO.class ).get( );
```

### 2.3 Daemon - TemporaryFileDaemon.java

**Before (v7):**
```java
TemporaryFileService.getInstance( ).removeTemporaryFile( temporaryFile );
```

**After (v8):**
```java
import jakarta.enterprise.inject.spi.CDI;

private TemporaryFileService _temporaryFileService = CDI.current( ).select( TemporaryFileService.class ).get( );

_temporaryFileService.removeTemporaryFile( temporaryFile );
```

---

## 3. Service Layer Changes

### 3.1 TemporaryFileService.java

**Complete refactoring from Singleton to CDI-managed bean:**

**Before (v7):**
```java
public class TemporaryFileService
{
    private static final TemporaryFileService INSTANCE = new TemporaryFileService( );
    private IFileStoreServiceProvider _fileStoreServiceProvider;

    private TemporaryFileService( )
    {
        _fileStoreServiceProvider = FileService.getInstance( )
                .getFileStoreServiceProvider( AppPropertiesService.getProperty( "temporaryfiles.file.provider.service" ) );
    }

    public static final TemporaryFileService getInstance( )
    {
        return INSTANCE;
    }
}
```

**After (v8):**
```java
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;

@ApplicationScoped
public class TemporaryFileService
{
    @Inject
    @Named( "filegenerator.fileStoreServiceProvider" )
    private IFileStoreServiceProvider _fileStoreServiceProvider;
}
```

**Removed Method:**
```java
// Removed in v8 - loadPhysicalFile method was removed
public PhysicalFile loadPhysicalFile( String idFile )
```

### 3.2 TemporaryFileGeneratorService.java

**Major Changes:**

1. **CDI Annotations:**
```java
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class TemporaryFileGeneratorService
{
    @Inject
    private TemporaryFileService _temporaryFileService;
}
```

2. **Deprecated getInstance() method:**
```java
@Deprecated( since = "3.0", forRemoval = true )
public static TemporaryFileGeneratorService getInstance( )
{
    return CDI.current( ).select( TemporaryFileGeneratorService.class ).get( );
}
```

3. **Async Processing Change - CompletableFuture to Jakarta Asynchronous:**

**Before (v7):**
```java
import java.util.concurrent.CompletableFuture;

public void generateFile( IFileGenerator generator, AdminUser user )
{
    CompletableFuture.runAsync( new GenerateFileRunnable( generator, user ) );
}
```

**After (v8):**
```java
import jakarta.enterprise.concurrent.Asynchronous;

@Asynchronous
public void generateFile( IFileGenerator generator, AdminUser user )
{
    new GenerateFileRunnable( generator, user, _temporaryFileService ).run( );
}
```

4. **Property Name Change:**
```java
// v7
"temporaryfiles.max.size"

// v8
"filegenerator.temporaryfiles.max.size"
```

---

## 4. New CDI Producer Classes

### 4.1 FileGeneratorFileStoreServiceProviderProducer.java (NEW)

Complete new file for CDI-based FileStoreServiceProvider configuration:

```java
package fr.paris.lutece.plugins.filegenerator.service.download;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Named;

@ApplicationScoped
public class FileGeneratorFileStoreServiceProviderProducer
{
    @Produces
    @ApplicationScoped
    @Named( "filegenerator.fileStoreServiceProvider" )
    public IFileStoreServiceProvider produceTemporaryFileDatabaseFileStoreServiceProvider(
            @ConfigProperty( name = "filegenerator.fileStoreServiceProvider.fileStoreService" ) String fileStoreImplName,
            @ConfigProperty( name = "filegenerator.fileStoreServiceProvider.rbacService" ) String rbacImplName,
            @ConfigProperty( name = "filegenerator.fileStoreServiceProvider.downloadService" ) String dlImplName )
    {
        return new FileStoreServiceProvider( "fileGeneratorDatabaseFileStoreProvider",
                CdiHelper.getReference( IFileStoreService.class, fileStoreImplName ),
                CdiHelper.getReference( IFileDownloadUrlService.class, dlImplName ),
                CdiHelper.getReference( IFileRBACService.class, rbacImplName ),
                false );
    }
}
```

### 4.2 TemporaryFileRBACService.java (NEW)

New RBAC service implementation:

```java
package fr.paris.lutece.plugins.filegenerator.service.download;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Named;

@ApplicationScoped
@Named( "filegenerator.temporaryfileRBACService" )
public class TemporaryFileRBACService implements IFileRBACService
{
    @Override
    public void checkAccessRights( Map<String, String> fileData, User user )
            throws AccessDeniedException, UserNotSignedException
    {
        String resourceId = fileData.get( FileService.PARAMETER_RESOURCE_ID );
        if ( null != user )
        {
            AdminUser adminUser = (AdminUser) user;
            TemporaryFile file = TemporaryFileHome.findByPrimaryKey( Integer.valueOf( resourceId ) );
            if ( file.getUser( ).getUserId( ) != adminUser.getUserId( ) )
            {
                throw new AccessDeniedException( MESSAGE_FILE_ACCESS_DENIED );
            }
        }
        else
        {
            throw new AccessDeniedException( MESSAGE_FILE_ACCESS_DENIED );
        }
    }
}
```

---

## 5. JspBean Changes - TemporaryFilesJspBean.java

### 5.1 Import Changes (javax to jakarta)
```java
// v7
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

// v8
import jakarta.servlet.http.HttpServletRequest;
```

### 5.2 CDI Annotations Added
```java
import jakarta.enterprise.context.RequestScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;

@RequestScoped
@Named
@Controller( controllerJsp = "ManageMyFiles.jsp", ... )
public class TemporaryFilesJspBean extends MVCAdminJspBean
```

### 5.3 Dependency Injection
```java
@Inject
private TemporaryFileService _temporaryFileService;

@Inject
@Named( "filegenerator.fileStoreServiceProvider" )
private IFileStoreServiceProvider _fileStoreServiceProvider;
```

### 5.4 doDownloadFile Method Removed

The `doDownloadFile` method was completely removed. Download is now handled via the FileStoreServiceProvider's download URL mechanism.

### 5.5 doDeleteFile Return Type Changed
```java
// v7
public void doDeleteFile( HttpServletRequest request, HttpServletResponse response )

// v8
public String doDeleteFile( HttpServletRequest request )
```

### 5.6 New Download Links Generation
```java
Map<String, String> mapDownloadLinks = new HashMap<>( );
for ( TemporaryFile temporaryFile : listFiles )
{
    Map<String, String> additionnalData = new HashMap<>( );
    additionnalData.put( FileService.PARAMETER_RESOURCE_ID, String.valueOf( temporaryFile.getIdFile( ) ) );
    mapDownloadLinks.put( String.valueOf( temporaryFile.getIdFile( ) ),
            _fileStoreServiceProvider.getFileDownloadUrlBO( temporaryFile.getIdPhysicalFile( ), additionnalData ) );
}
model.put( MARK_DOWNLOAD_LINKS, mapDownloadLinks );
```

---

## 6. Configuration Files

### 6.1 beans.xml (NEW)
```
src/main/resources/META-INF/beans.xml
```

### 6.2 filegenerator.properties Changes
Property name changes to use `filegenerator.` prefix.

### 6.3 filegenerator_context.xml (REMOVED)
Spring context file removed - replaced by CDI annotations.

---

## 7. Test Changes - TemporaryFileBusinessTest.java

### JUnit 5 Migration
```java
// v7 (JUnit 4 style)
@Override
protected void setUp( ) throws Exception
{
    super.setUp( );
}

// v8 (JUnit 5 style)
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@BeforeEach
protected void setUp( ) throws Exception
{
    // No super.setUp() call
}

@Test
public void testCRUD( )
```

---

## 8. Migration Checklist

### Mandatory Changes
- [ ] Update pom.xml parent version to 8.0.0-SNAPSHOT
- [ ] Update lutece-core dependency to [8.0.0-SNAPSHOT,)
- [ ] Change all `javax.*` imports to `jakarta.*`
- [ ] Replace Spring beans with CDI annotations (`@ApplicationScoped`, `@RequestScoped`)
- [ ] Replace `SpringContextService.getBean()` with `CDI.current().select().get()`
- [ ] Replace singleton patterns with `@ApplicationScoped` beans
- [ ] Add `@Inject` for dependencies
- [ ] Create CDI producers for complex bean configurations
- [ ] Add `beans.xml` in `META-INF/`
- [ ] Remove Spring context XML files
- [ ] Update JUnit 4 tests to JUnit 5

### New Patterns in v8
- Use `@Named` qualifier for specific bean selection
- Use `@ConfigProperty` from MicroProfile Config for properties
- Use `jakarta.enterprise.concurrent.Asynchronous` instead of `CompletableFuture.runAsync()`
- Use `CdiHelper.getReference()` for programmatic CDI lookup with qualifiers
- Implement `IFileRBACService` for file access control
- Use `FileStoreServiceProvider` with CDI producer pattern

### Property Changes
| v7 Property | v8 Property |
|-------------|-------------|
| `temporaryfiles.max.size` | `filegenerator.temporaryfiles.max.size` |
| `temporaryfiles.file.provider.service` | `filegenerator.fileStoreServiceProvider.fileStoreService` |

---

## 9. Architecture Changes Summary

### Download Flow Changes

**v7 Architecture:**
```
JSP -> JspBean.doDownloadFile() -> TemporaryFileService.loadPhysicalFile() -> Response
```

**v8 Architecture:**
```
JSP -> FileStoreServiceProvider.getFileDownloadUrlBO() -> Core Download Mechanism with RBAC
```

### Dependency Injection Pattern

**v7:** Spring XML configuration + Singleton patterns
**v8:** CDI annotations + Producer methods + Named qualifiers

### File Access Control

**v7:** Manual check in JspBean
**v8:** Dedicated `TemporaryFileRBACService` implementing `IFileRBACService`
