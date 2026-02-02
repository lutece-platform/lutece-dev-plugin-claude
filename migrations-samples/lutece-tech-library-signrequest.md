# Migration Analysis: lutece-tech-library-signrequest (v7 to v8)

## Overview

| Attribute | v7 (develop) | v8 (develop8) |
|-----------|--------------|---------------|
| **Artifact Version** | 3.0.1-SNAPSHOT | 4.0.0-SNAPSHOT |
| **Parent POM** | 6.0.0 | 8.0.0-SNAPSHOT |
| **library-jwt dependency** | [1.0.0,) | [3.0.0-SNAPSHOT,) |

## Summary of Changes

- **27 files changed**: 588 insertions, 109 deletions
- **Major migration**: javax.* to jakarta.* namespace
- **New classes**: 3 new Java classes added
- **Test framework**: JUnit 4 to JUnit 5 migration
- **New dependencies**: library-lutece-unit-testing, log4j-core (test scope)

---

## 1. POM Changes

### Parent POM Version
```xml
<!-- v7 -->
<version>6.0.0</version>

<!-- v8 -->
<version>8.0.0-SNAPSHOT</version>
```

### Artifact Version
```xml
<!-- v7 -->
<version>3.0.1-SNAPSHOT</version>

<!-- v8 -->
<version>4.0.0-SNAPSHOT</version>
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

### Dependency Changes
```xml
<!-- library-jwt: version upgrade -->
<!-- v7 -->
<version>[1.0.0,)</version>

<!-- v8 -->
<version>[3.0.0-SNAPSHOT,)</version>

<!-- New dependencies in v8 -->
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-lutece-unit-testing</artifactId>
    <type>jar</type>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-core</artifactId>
    <scope>test</scope>
</dependency>
```

### Removed Properties
```xml
<!-- Removed in v8 -->
<properties>
    <jiraProjectName>SIGNREQUEST</jiraProjectName>
    <jiraComponentId>11582</jiraComponentId>
</properties>
```

---

## 2. Java Namespace Migration (javax to jakarta)

All servlet-related imports have been migrated:

| v7 Import | v8 Import |
|-----------|-----------|
| `javax.servlet.Filter` | `jakarta.servlet.Filter` |
| `javax.servlet.FilterChain` | `jakarta.servlet.FilterChain` |
| `javax.servlet.FilterConfig` | `jakarta.servlet.FilterConfig` |
| `javax.servlet.ServletException` | `jakarta.servlet.ServletException` |
| `javax.servlet.ServletRequest` | `jakarta.servlet.ServletRequest` |
| `javax.servlet.ServletResponse` | `jakarta.servlet.ServletResponse` |
| `javax.servlet.http.HttpServletRequest` | `jakarta.servlet.http.HttpServletRequest` |
| `javax.servlet.http.HttpServletResponse` | `jakarta.servlet.http.HttpServletResponse` |

### Affected Files
- `AbstractJWTAuthenticator.java`
- `AbstractJWTRSAAuthenticator.java`
- `BasicAuthorizationAuthenticator.java`
- `ClientHeaderHashAuthenticator.java`
- `HeaderHashAuthenticator.java`
- `JWTNoEncryptionAuthenticator.java`
- `JWTRSAKeyStoreFileAuthenticator.java`
- `JWTSecretKeyAuthenticator.java`
- `NoSecurityAuthenticator.java`
- `RequestAuthenticator.java`
- `RequestHashAuthenticator.java`
- `AbstractRequestFilter.java` (servlet package)

---

## 3. New Classes Added in v8

### 3.1 IPAuthentificator.java
New IP-based request authenticator with allow/block mode support.

```java
package fr.paris.lutece.util.signrequest;

public class IPAuthentificator implements RequestAuthenticator {

    public enum MODE {
        ALLOW,
        BLOCK
    }

    private Set<String> _listIPs;
    private Set<String> _listAuthorizedPath;
    private MODE _mode;

    public IPAuthentificator(String strMode, List<String> listIPs, List<String> listAuthorizedPath)

    @Override
    public boolean isRequestAuthenticated(HttpServletRequest request)

    @Override
    public AuthenticateRequestInformations getSecurityInformations(List<String> elements)
}
```

**Features:**
- Supports ALLOW and BLOCK modes
- Can exclude specific paths from IP restriction via `authorizedPath`
- Uses TreeSet for efficient IP lookup

### 3.2 AbstractSignRequestAuthenticatorProducer.java
CDI producer base class for creating RequestAuthenticator instances from MicroProfile Config.

```java
package fr.paris.lutece.util.signrequest.cdi;

public abstract class AbstractSignRequestAuthenticatorProducer {

    @Inject
    private Instance<HashService> _hashServices;

    protected RequestAuthenticator produceRequestAuthenticator(String configPrefix)
}
```

**Supported Authenticators via Config:**
- `signrequest.HeaderHashAuthenticator`
- `signrequest.RequestHashAuthenticator`
- `signrequest.JWTNoEncryptionAuthenticator`
- `signrequest.JWTSecretKeyAuthenticator`
- `signrequest.JWTRSAPlainTextAuthenticator`
- `signrequest.JWTRSATrustStoreFileAuthenticator`
- `signrequest.IPAuthenticator`

**Configuration Properties:**
| Property Suffix | Description |
|-----------------|-------------|
| `.name` | Authenticator type name |
| `.cfg.hashService` | Hash service name (default: signrequest.Sha1HashService) |
| `.cfg.signatureElements` | Signature elements list |
| `.cfg.privateKey` | Private key |
| `.cfg.publicKey` | Public key |
| `.cfg.claimsToCheck` | JWT claims map |
| `.cfg.validityPeriod` | Token validity period (default: 60000) |
| `.cfg.jwtHttpHeader` | JWT HTTP header name |
| `.cfg.encryptionAlgorythmName` | Encryption algorithm |
| `.cfg.secretKey` | Secret key |
| `.cfg.cacertPath` | CA certificate path |
| `.cfg.cacertPassword` | CA certificate password |
| `.cfg.alias` | Key alias |
| `.cfg.mode` | IP authenticator mode |
| `.cfg.ips` | IP addresses list |
| `.cfg.authorizedPath` | Authorized paths list |

### 3.3 Sha512HashService.java
New hash service implementation using SHA-512 algorithm.

```java
package fr.paris.lutece.util.signrequest.security;

@ApplicationScoped
@Named("signrequest.Sha512HashService")
public class Sha512HashService implements HashService {
    @Override
    public String getHash(String strSource)
}
```

---

## 4. CDI Annotations Added

### Sha1HashService.java
```java
// Added CDI annotations
@ApplicationScoped
@Named("signrequest.Sha1HashService")
public class Sha1HashService implements HashService
```

---

## 5. API Changes

### 5.1 AbstractJWTAuthenticator
The `isRequestAuthenticated` method signature changed:

```java
// v7 - Concrete implementation
@Override
public boolean isRequestAuthenticated(HttpServletRequest request) {
    // Verify JWT without signature check
    if (!JWTUtil.containsValidUnsafeJWT(request, _strJWTHttpHeader)) {
        return false;
    }
    if (!JWTUtil.checkPayloadValues(request, _strJWTHttpHeader, _mapClaimsToCheck)) {
        return false;
    }
    return true;
}

// v8 - Abstract method + protected helper
public abstract boolean isRequestAuthenticated(HttpServletRequest request);

protected boolean isRequestAuthenticated(HttpServletRequest request, Key key) {
    return JWTUtil.checkPayloadValues(request, key, _strJWTHttpHeader, _mapClaimsToCheck);
}
```

### 5.2 AbstractJWTRSAAuthenticator
```java
// v7
@Override
public boolean isRequestAuthenticated(HttpServletRequest request) {
    boolean isAuthenticated = super.isRequestAuthenticated(request);
    if (isAuthenticated) {
        return JWTUtil.checkSignature(request, _strJWTHttpHeader, getKeyPair().getPublic());
    }
    return false;
}

// v8 - Signature check BEFORE payload validation
@Override
public boolean isRequestAuthenticated(HttpServletRequest request) {
    Key key = getKeyPair().getPublic();
    boolean validSignature = JWTUtil.checkSignature(request, _strJWTHttpHeader, key);
    if (validSignature) {
        return super.isRequestAuthenticated(request, key);
    }
    return false;
}
```

### 5.3 JWTNoEncryptionAuthenticator
```java
// v7
return super.isRequestAuthenticated(request);

// v8 - Uses unsecured payload check
return JWTUtil.checkUnsecuredPayloadValues(request, _strJWTHttpHeader, _mapClaimsToCheck);
```

### 5.4 JWTSecretKeyAuthenticator
```java
// v7
boolean isAuthenticated = super.isRequestAuthenticated(request);
if (isAuthenticated) {
    Key key = JWTUtil.getKey(_strSecretKey, _strEncryptionAlgorythmName);
    return JWTUtil.checkSignature(request, _strJWTHttpHeader, key);
}

// v8 - Key retrieved first, signature check before payload
Key key = JWTUtil.getKey(_strSecretKey, _strEncryptionAlgorythmName);
boolean validSignature = JWTUtil.checkSignature(request, _strJWTHttpHeader, key);
if (validSignature) {
    return super.isRequestAuthenticated(request, key);
}
```

### 5.5 HeaderHashAuthenticator & RequestHashAuthenticator
New constructors added for programmatic instantiation:

```java
// New constructor
public HeaderHashAuthenticator(HashService hashService, List<String> lSignatureElements, String strPrivateKey) {
    setHashService(hashService);
    setSignatureElements(lSignatureElements);
    setPrivateKey(strPrivateKey);
}

public RequestHashAuthenticator(HashService hashService, List<String> lSignatureElements, String strPrivateKey) {
    setHashService(hashService);
    setSignatureElements(lSignatureElements);
    setPrivateKey(strPrivateKey);
}
```

---

## 6. JWTUtil API Changes (library-jwt dependency)

The `JWTUtil.checkPayloadValues` method signature changed:

```java
// v7
JWTUtil.checkPayloadValues(request, HTTP_HEADER_NAME, mapJWTClaims)

// v8 - Requires key parameter
JWTUtil.checkPayloadValues(request, key, HTTP_HEADER_NAME, mapJWTClaims)

// v8 - New method for unsecured JWT
JWTUtil.checkUnsecuredPayloadValues(request, HTTP_HEADER_NAME, mapJWTClaims)
```

---

## 7. Test Framework Migration (JUnit 4 to JUnit 5)

### Import Changes
```java
// v7
import static org.junit.Assert.*;
import org.junit.Test;
import fr.paris.lutece.test.MokeHttpServletRequest;

// v8
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import fr.paris.lutece.test.mocks.MockHttpServletRequest;
```

### Assertion Changes
```java
// v7
assertTrue(authenticator.isRequestAuthenticated(request));

// v8
Assertions.assertTrue(authenticator.isRequestAuthenticated(request));
```

### Mock Request Changes
```java
// v7
MokeHttpServletRequest request = new MokeHttpServletRequest();
request.addMokeHeader(HEADER_AUTHORIZATION, value);

// v8
MockHttpServletRequest request = new MockHttpServletRequest();
request.addHeader(HEADER_AUTHORIZATION, value);
```

### Test Key Changes
Some test keys were regenerated with longer key sizes:

```java
// v7 - 1024-bit RSA keys
private static final String PUB_KEY = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCUp/oV1vWc...";
private static final String SECRET_KEY = "testestestestest";

// v8 - 2048-bit RSA keys + longer secret
private static final String PUB_KEY = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlJTE...";
private static final String SECRET_KEY = "testestestestesttestestestestest";
```

---

## 8. Migration Checklist

### Required Changes
- [ ] Update parent POM to 8.0.0-SNAPSHOT
- [ ] Update artifact version to 4.0.0-SNAPSHOT
- [ ] Replace all `javax.servlet.*` imports with `jakarta.servlet.*`
- [ ] Update library-jwt dependency to [3.0.0-SNAPSHOT,)
- [ ] Add library-lutece-unit-testing dependency (test scope)
- [ ] Add log4j-core dependency (test scope)

### Code Adjustments
- [ ] Update `JWTUtil.checkPayloadValues()` calls to include key parameter
- [ ] Use `JWTUtil.checkUnsecuredPayloadValues()` for unsigned JWT validation
- [ ] If extending `AbstractJWTAuthenticator`, implement `isRequestAuthenticated(HttpServletRequest)` as abstract method
- [ ] Update test classes from JUnit 4 to JUnit 5

### CDI Integration
- [ ] Use `@ApplicationScoped` and `@Named` annotations on HashService implementations
- [ ] Extend `AbstractSignRequestAuthenticatorProducer` for CDI-based authenticator configuration

### Security Considerations
- [ ] RSA keys should be at least 2048 bits
- [ ] Secret keys for HMAC should be at least 256 bits (32 characters)

---

## 9. Breaking Changes Summary

| Change | Impact | Migration Action |
|--------|--------|------------------|
| javax to jakarta namespace | High | Update all imports |
| JWTUtil.checkPayloadValues signature | High | Add key parameter |
| AbstractJWTAuthenticator.isRequestAuthenticated now abstract | High | Implement in subclasses |
| MokeHttpServletRequest renamed | Medium | Use MockHttpServletRequest |
| JUnit 4 to JUnit 5 | Medium | Update test imports and assertions |
| Minimum key sizes increased | Low | Generate new test keys |
