# Migration Analysis: lutece-tech-library-httpaccess (v7 to v8)

## Overview

This document analyzes the migration changes between Lutece v7 (`develop` branch) and Lutece v8 (`develop_core8` branch) for the `lutece-tech-library-httpaccess` library.

## Summary Statistics

| Files Changed | Insertions | Deletions |
|---------------|------------|-----------|
| 9 files       | 142        | 171       |

## POM Changes

### Parent POM Version
- **Before**: `lutece-global-pom` version `6.1.0`
- **After**: `lutece-global-pom` version `8.0.0-SNAPSHOT`

### Artifact Version
- **Before**: `3.0.3-SNAPSHOT`
- **After**: `4.0.0-SNAPSHOT`

### Repository URLs
- Changed from `http://` to `https://` for both snapshot and release repositories

### Dependency Changes

| Dependency | v7 | v8 |
|------------|-----|-----|
| lutece-core | `[7.0.0,)` (type: lutece-core) | **REMOVED** |
| library-core-utils | N/A | `1.0.0-SNAPSHOT` (NEW) |
| library-signrequest | `[3.0.0,)` | `[4.0.0-SNAPSHOT,)` |
| mockwebserver | `5.0.0-alpha.10` | `5.0.0-alpha.16` |
| library-lutece-unit-testing | N/A | NEW (test scope) |
| log4j-slf4j-impl | N/A | NEW (test scope) |
| log4j-core | N/A | NEW (test scope) |

### Removed Properties
```xml
<!-- Removed in v8 -->
<jiraProjectName>HTTPACCESS</jiraProjectName>
<jiraComponentId>10158</jiraComponentId>
```

## Java Code Changes

### 1. HttpAccess.java

#### Import Changes
```java
// REMOVED
- import org.apache.commons.fileupload.FileItem;
- import fr.paris.lutece.portal.service.util.AppLogService;

// ADDED
+ import org.apache.logging.log4j.LogManager;
+ import org.apache.logging.log4j.Logger;
+ import fr.paris.lutece.portal.service.upload.MultipartItem;
```

#### Logger Migration
```java
// Before (AppLogService)
AppLogService.error( strError + e.getMessage( ), e );

// After (Log4j2 Logger)
private static Logger _logger = LogManager.getLogger( "lutece.application" );
_logger.error( strError + e.getMessage( ), e );
```

#### FileItem to MultipartItem Migration
All methods using `FileItem` have been migrated to use `MultipartItem`:

```java
// Before
public String doPostMultiPart( String strUrl, Map<String, List<String>> params,
    Map<String, FileItem> fileItems ) throws HttpAccessException

// After
public String doPostMultiPart( String strUrl, Map<String, List<String>> params,
    Map<String, MultipartItem> fileItems ) throws HttpAccessException
```

**Affected methods:**
- `doPostMultiPart()` (4 overloads)
- `downloadFile()` - return type changed from `FileItem` to `MultipartItem`

#### Simplified File Handling
The multipart file handling has been simplified - removed the conditional logic for `isInMemory()`:

```java
// Before (complex logic with temp files)
if ( fileItem.isInMemory( ) ) {
    // ... handle in-memory
} else {
    File file = File.createTempFile( "httpaccess-multipart-", null );
    listFiles.add( file );
    fileItem.write( file );
    // ...
}

// After (simplified - always use InputStream)
builder.addBinaryBody( paramFileItem.getKey( ), fileItem.getInputStream( ),
    contentType, fileItem.getName( ) );
```

#### Null Check Added
Added null check for entity before processing response:
```java
// After
if ( entity != null )
{
    strResponseBody = EntityUtils.toString( entity, ... );
}
```

### 2. MemoryFileItem.java

#### Interface Change
```java
// Before
public class MemoryFileItem implements FileItem

// After
public class MemoryFileItem implements MultipartItem
```

#### Import Changes
```java
// REMOVED
- import org.apache.commons.fileupload.FileItem;
- import org.apache.commons.fileupload.FileItemHeaders;
- import java.io.File;
- import java.io.OutputStream;

// ADDED
+ import fr.paris.lutece.portal.service.upload.MultipartItem;
+ import java.io.ByteArrayInputStream;
```

#### InputStream Implementation
Now properly implements `getInputStream()`:
```java
// Before
public InputStream getInputStream( ) throws IOException {
    throw new UnsupportedOperationException( );
}

// After
public InputStream getInputStream( ) throws IOException {
    return new ByteArrayInputStream( _data );
}
```

#### Removed Methods
The following methods were removed (not part of `MultipartItem` interface):
- `getOutputStream()`
- `write(File file)`
- `getHeaders()`
- `setHeaders(FileItemHeaders headers)`

### 3. PropertiesHttpClientConfiguration.java

#### Configuration API Migration
Migrated from `AppPropertiesService` to MicroProfile Config:

```java
// Before
import fr.paris.lutece.portal.service.util.AppLogService;
import fr.paris.lutece.portal.service.util.AppPropertiesService;

this.setProxyHost( AppPropertiesService.getProperty( PROPERTY_PROXY_HOST ) );

// After
import org.eclipse.microprofile.config.Config;
import org.eclipse.microprofile.config.ConfigProvider;

private static Config _config = ConfigProvider.getConfig( );

this.setProxyHost( _config.getOptionalValue( PROPERTY_PROXY_HOST, String.class ).orElse( null ) );
```

#### Logger Migration
```java
// Before
AppLogService.error( "Error during initialisation...", e );

// After
private static Logger _logger = LogManager.getLogger( "lutece.application" );
_logger.error( "Error during initialisation...", e );
```

### 4. SimpleResponseValidator.java

#### Configuration API Migration
```java
// Before
import fr.paris.lutece.portal.service.util.AppPropertiesService;
String strAuthorizedStatusList = AppPropertiesService.getProperty( strProperty, strDefault );

// After
import org.eclipse.microprofile.config.ConfigProvider;
String strAuthorizedStatusList = ConfigProvider.getConfig( )
    .getOptionalValue( strProperty, String.class ).orElse( strDefault );
```

### 5. HttpClientConfiguration.java

Minor cleanup: removed `// TODO: Auto-generated Javadoc` comments.

## Test Changes

### JUnit Migration (JUnit 4 to JUnit 5)

```java
// Before (JUnit 4)
import org.junit.Test;
import org.junit.Before;
import org.junit.After;
import org.junit.BeforeClass;

// After (JUnit 5)
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
```

### Removed Lutece Initialization
```java
// REMOVED - No longer needed
@BeforeClass
public static void initLutece( ) {
    AppPathService.init( "" );
    AppPropertiesService.init( "" );
}
```

### Logger Migration
```java
// Before
import org.apache.log4j.Logger;
private Logger _logger = Logger.getLogger( this.getClass( ) );

// After
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
private Logger _logger = LogManager.getLogger( this.getClass( ) );
```

### FileItem to MultipartItem in Tests
```java
// Before
import org.apache.commons.fileupload.FileItem;
Map<String, FileItem> mapFileItem = new HashMap( );

// After
import fr.paris.lutece.portal.service.upload.MultipartItem;
Map<String, MultipartItem> mapFileItem = new HashMap( );
```

### New Test Case
Added test for empty content (204 response):
```java
@Test
public void testEmptyContent( ) throws HttpAccessException, JsonMappingException, JsonProcessingException
{
    // Tests handling of 204 No Content responses
}
```

### Removed Configuration
```java
// REMOVED in test setup
configuration.setConnectionPoolEnabled( true );
```

## Key Migration Patterns

### 1. Dependency Decoupling
- **lutece-core dependency removed** - replaced with `library-core-utils`
- Library is now independent from the full Lutece core

### 2. FileUpload API Migration
| v7 (Commons FileUpload) | v8 (Lutece MultipartItem) |
|-------------------------|---------------------------|
| `org.apache.commons.fileupload.FileItem` | `fr.paris.lutece.portal.service.upload.MultipartItem` |
| `FileItemHeaders` | Removed |
| `isInMemory()` check | Simplified to always use `getInputStream()` |

### 3. Configuration API Migration
| v7 (AppPropertiesService) | v8 (MicroProfile Config) |
|---------------------------|--------------------------|
| `AppPropertiesService.getProperty(key)` | `ConfigProvider.getConfig().getOptionalValue(key, String.class).orElse(null)` |
| `AppPropertiesService.getProperty(key, default)` | `ConfigProvider.getConfig().getOptionalValue(key, String.class).orElse(default)` |

### 4. Logging Migration
| v7 | v8 |
|----|-----|
| `AppLogService.error()` | `Logger.error()` (Log4j2) |
| `org.apache.log4j.Logger` | `org.apache.logging.log4j.Logger` |

### 5. Testing Migration
| v7 (JUnit 4) | v8 (JUnit 5) |
|--------------|--------------|
| `@Test` (org.junit) | `@Test` (org.junit.jupiter.api) |
| `@Before` | `@BeforeEach` |
| `@After` | `@AfterEach` |
| `@BeforeClass` | `@BeforeAll` (but removed in this case) |

## Migration Checklist

- [ ] Update parent POM to `8.0.0-SNAPSHOT`
- [ ] Update artifact version to `4.0.0-SNAPSHOT`
- [ ] Replace `lutece-core` dependency with `library-core-utils`
- [ ] Update `library-signrequest` to `4.0.0-SNAPSHOT`
- [ ] Replace `FileItem` with `MultipartItem`
- [ ] Migrate `AppPropertiesService` to MicroProfile Config
- [ ] Migrate `AppLogService` to Log4j2 Logger
- [ ] Update tests from JUnit 4 to JUnit 5
- [ ] Remove `AppPathService.init()` and `AppPropertiesService.init()` from tests
- [ ] Add test dependencies: `library-lutece-unit-testing`, `log4j-slf4j-impl`, `log4j-core`
