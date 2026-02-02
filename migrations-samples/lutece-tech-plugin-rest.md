# Lutece REST Plugin Migration Analysis: v7 to v8

## Overview

This document analyzes the migration changes between Lutece v7 (branch `develop`) and Lutece v8 (branch `develop8`) for the `lutece-tech-plugin-rest` plugin.

**Plugin Version Change:** `3.3.3-SNAPSHOT` -> `4.0.0-SNAPSHOT`

**Summary Statistics:**
- 23 files changed
- 425 insertions
- 602 deletions

## Major Architecture Changes

### 1. Jersey to Jakarta EE RESTEasy Migration

The most significant change is the complete migration from **Jersey (JAX-RS implementation)** to **Jakarta EE native REST** (RESTEasy in WildFly/JBoss or similar implementations).

#### Removed Classes (Jersey-specific)
- `LuteceApplicationResourceConfig.java` - Jersey ResourceConfig class
- `LuteceJerseySpringServlet.java` - Jersey servlet filter with Spring integration
- `LuteceJerseySpringWebApplicationInitializer.java` - Jersey Spring initializer

#### Added Classes (Jakarta EE)
- `LuteceRestApplication.java` - Standard JAX-RS Application class with `@ApplicationPath`
- `RestAuthenticatorRequestFilter.java` - CDI-based ContainerRequestFilter for authentication
- `RestRequestAuthenticator.java` - CDI Qualifier annotation
- `RestRequestAuthenticatorProducer.java` - CDI Producer for RequestAuthenticator

### 2. Package Namespace Migration

All JAX-RS imports changed from `javax.ws.rs` to `jakarta.ws.rs`:

| v7 (javax) | v8 (jakarta) |
|------------|--------------|
| `javax.ws.rs.*` | `jakarta.ws.rs.*` |
| `javax.ws.rs.core.*` | `jakarta.ws.rs.core.*` |
| `javax.ws.rs.container.*` | `jakarta.ws.rs.container.*` |
| `javax.ws.rs.ext.*` | `jakarta.ws.rs.ext.*` |
| `javax.servlet.*` | `jakarta.servlet.*` |
| `javax.inject.*` | `jakarta.inject.*` |

### 3. Spring to CDI Migration

| v7 (Spring) | v8 (CDI) |
|-------------|----------|
| `SpringContextService.getBean()` | `@Inject` with CDI |
| `SpringContextService.getBeansOfType()` | `CDI.current().select()` |
| `@Autowired` | `@Inject` |
| Spring beans in `*_context.xml` | CDI producers with `@Produces` |

### 4. Configuration Migration

| v7 | v8 |
|----|-----|
| `AppPropertiesService.getProperty()` | `ConfigProvider.getConfig().getOptionalValue()` |
| `rest_context.xml` Spring beans | `rest.properties` MicroProfile Config |

## Detailed Code Changes

### pom.xml Changes

```xml
<!-- v7 Parent POM -->
<parent>
    <artifactId>lutece-global-pom</artifactId>
    <version>6.0.0</version>
</parent>

<!-- v8 Parent POM -->
<parent>
    <artifactId>lutece-global-pom</artifactId>
    <version>8.0.0-SNAPSHOT</version>
</parent>
```

#### Removed Dependencies (v7)
```xml
<!-- Jersey dependencies removed -->
<dependency>
    <groupId>fr.paris.lutece</groupId>
    <artifactId>lutece-core</artifactId>
    <version>[7.0.0,)</version>
    <type>lutece-core</type>
</dependency>
<dependency>
    <groupId>org.glassfish.jersey.core</groupId>
    <artifactId>jersey-server</artifactId>
    <version>${jerseyVersion}</version>
</dependency>
<dependency>
    <groupId>org.glassfish.jersey.ext</groupId>
    <artifactId>jersey-spring5</artifactId>
    <version>${jerseyVersion}</version>
</dependency>
<dependency>
    <groupId>org.glassfish.jersey.media</groupId>
    <artifactId>jersey-media-json-jackson</artifactId>
    <version>${jerseyVersion}</version>
</dependency>
<dependency>
    <groupId>org.glassfish.jersey.media</groupId>
    <artifactId>jersey-media-multipart</artifactId>
    <version>${jerseyVersion}</version>
</dependency>
```

#### Added Dependencies (v8)
```xml
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-signrequest</artifactId>
    <version>[4.0.0-SNAPSHOT,)</version>
</dependency>
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-core-utils</artifactId>
    <version>1.0.0-SNAPSHOT</version>
</dependency>
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-databind</artifactId>
</dependency>
```

### JAX-RS Application Class

#### v7: LuteceApplicationResourceConfig.java (Jersey ResourceConfig)
```java
public class LuteceApplicationResourceConfig extends ResourceConfig {
    public LuteceApplicationResourceConfig() {
        // Manual registration of providers and resources
        register(JacksonFeature.withoutExceptionMappers());
        register(new UncaughtThrowableMapper());
        register(new LuteceJerseyLoggingFilter());

        // Spring bean discovery
        Map<String, Object> providers = SpringContextService.getContext()
            .getBeansWithAnnotation(Provider.class);
        for (Object o : providers.values()) {
            register(o.getClass());
        }

        // Extension mapping via Jersey ServerProperties
        property(ServerProperties.MEDIA_TYPE_MAPPINGS, mapExtensionToMediaType);
    }
}
```

#### v8: LuteceRestApplication.java (Standard JAX-RS Application)
```java
@ApplicationPath(RestConstants.APP_PATH)  // "/rest/"
public class LuteceRestApplication extends Application {

    @Override
    public Map<String, Object> getProperties() {
        Map<String, Object> mapExtensionToMediaType = new HashMap<>();

        // Default media type mappings
        mapExtensionToMediaType.put("atom", MediaType.APPLICATION_ATOM_XML_TYPE);
        mapExtensionToMediaType.put("xml", MediaType.APPLICATION_XML_TYPE);
        mapExtensionToMediaType.put("json", MediaType.APPLICATION_JSON_TYPE);
        mapExtensionToMediaType.put("kml", RestMediaTypes.APPLICATION_KML_TYPE);

        // MicroProfile Config for additional mappings
        Config config = ConfigProvider.getConfig();
        Map<String, String> mapMediaTypeMapping = config
            .getOptionalValue("rest.mediaTypeMapping", Map.class)
            .orElse(new HashMap<>(0));

        return mapExtensionToMediaType;
    }
}
```

### Authentication Filter Migration

#### v7: LuteceJerseySpringServlet.java (Servlet Filter)
```java
public class LuteceJerseySpringServlet extends ServletContainer {
    private static final String BEAN_REQUEST_AUTHENTICATOR = "rest.requestAuthenticator";

    @Override
    public void doFilter(HttpServletRequest request, HttpServletResponse response,
                         FilterChain chain) throws IOException, ServletException {
        if (checkRequestAuthentification(request)) {
            super.doFilter(request, response, chain);
        } else {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        }
    }

    private boolean checkRequestAuthentification(HttpServletRequest request) {
        // Spring bean lookup
        RequestAuthenticator ra = (RequestAuthenticator)
            SpringContextService.getBean(BEAN_REQUEST_AUTHENTICATOR);
        return ra.isRequestAuthenticated(request);
    }
}
```

#### v8: RestAuthenticatorRequestFilter.java (CDI ContainerRequestFilter)
```java
@Provider
@PreMatching
@Priority(Priorities.AUTHENTICATION)
public class RestAuthenticatorRequestFilter implements ContainerRequestFilter {

    private static final String SECURITY_ACTIVATED = "rest.security.activated";

    @Inject
    private HttpServletRequest _httpRequest;

    @Inject
    @RestRequestAuthenticator  // Custom CDI Qualifier
    private RequestAuthenticator _requestAuthenticator;

    private final Config _config;

    public RestAuthenticatorRequestFilter() {
        this._config = ConfigProvider.getConfig();
    }

    @Override
    public void filter(ContainerRequestContext requestContext) throws IOException {
        if (_config.getOptionalValue(SECURITY_ACTIVATED, Boolean.class).orElse(false)) {
            if (isRequestAuthenticated(_httpRequest)) {
                LOGGER.debug("Request authenticated: " + _httpRequest.getMethod()
                    + " " + _httpRequest.getContextPath() + _httpRequest.getServletPath()
                    + _httpRequest.getPathInfo());
            } else {
                requestContext.abortWith(
                    Response.status(Response.Status.UNAUTHORIZED).build()
                );
            }
        }
    }
}
```

### CDI Producer Pattern for RequestAuthenticator

#### v8: RestRequestAuthenticatorProducer.java
```java
@ApplicationScoped
public class RestRequestAuthenticatorProducer extends AbstractSignRequestAuthenticatorProducer {

    private static final String CONFIG_PREFIX = "rest.requestAuthenticator";

    @Produces
    @ApplicationScoped
    @RestRequestAuthenticator  // Custom Qualifier
    public RequestAuthenticator produceRequestAuthenticator() {
        return produceRequestAuthenticator(CONFIG_PREFIX);
    }
}
```

#### v8: RestRequestAuthenticator.java (CDI Qualifier)
```java
@Qualifier
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.FIELD, ElementType.METHOD, ElementType.PARAMETER,
         ElementType.TYPE, ElementType.ANNOTATION_TYPE})
public @interface RestRequestAuthenticator {
}
```

### Logging Migration

#### v7 (Log4j 1.x)
```java
import org.apache.log4j.Logger;

private static final Logger LOGGER = Logger.getLogger(RestConstants.REST_LOGGER);
```

#### v8 (Log4j 2.x)
```java
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

private static final Logger LOGGER = LogManager.getLogger(RestConstants.REST_LOGGER);
```

### Exception Mappers

#### v7: Manual Registration in ResourceConfig
```java
// In LuteceApplicationResourceConfig
if (AppPropertiesService.getPropertyBoolean(GENERIC_EXCEPTION_MAPPER, true)) {
    register(JacksonFeature.withoutExceptionMappers());
    register(new UncaughtThrowableMapper());
    register(new UncaughtJerseyExceptionMapper());
}
```

#### v8: Auto-Discovery with @Provider Annotation
```java
@Provider
public class UncaughtThrowableMapper extends GenericUncaughtExceptionMapper<Throwable, String> {
    // Implementation
}

@Provider
public class UncaughtJerseyExceptionMapper extends GenericUncaughtJerseyExceptionMapper<WebApplicationException, String> {
    // Implementation
}
```

### Configuration Changes

#### v7: rest_context.xml (Spring Beans)
```xml
<beans>
    <!-- Spring bean configuration for authenticator -->
    <bean id="rest.requestAuthenticator"
          class="fr.paris.lutece.util.signrequest.NoSecurityAuthenticator" />

    <!-- Or with JWT authentication -->
    <bean id="rest.requestAuthenticator"
          class="fr.paris.lutece.util.signrequest.JWTSecretKeyAuthenticator">
        <constructor-arg index="0">
            <map>
                <entry key="PAYLOAD_KEY" value="PAYLOAD_VALUE" />
            </map>
        </constructor-arg>
        <!-- ... more constructor args ... -->
    </bean>
</beans>
```

#### v8: rest.properties (MicroProfile Config)
```properties
# Security activation
rest.security.activated=false

# RestRequestAuthenticator config
## e.g. signrequest.HeaderHashAuthenticator / if empty, NoSecurityAuthenticator by default
#rest.requestAuthenticator.name=

## Config elements depends on the chosen implementation
#rest.requestAuthenticator.cfg.signatureElements=
#rest.requestAuthenticator.cfg.privateKey=
#rest.requestAuthenticator.cfg.publicKey=
#rest.requestAuthenticator.cfg.claimsToCheck=
#rest.requestAuthenticator.cfg.jwtHttpHeader=
#rest.requestAuthenticator.cfg.validityPeriod=
#rest.requestAuthenticator.cfg.encryptionAlgorythmName=
#rest.requestAuthenticator.cfg.secretKey=
#rest.requestAuthenticator.cfg.cacertPath=
#rest.requestAuthenticator.cfg.cacertPassword=
#rest.requestAuthenticator.cfg.alias=

# Logging
rest.log.activated=false

# MediaType mappings
rest.mediaTypeMapping=
```

### Plugin Descriptor Changes (rest.xml)

#### v7: Filter Registration
```xml
<filters>
    <filter>
        <filter-name>REST Filter</filter-name>
        <url-pattern>/rest/*</url-pattern>
        <init-param>
            <param-name>javax.ws.rs.Application</param-name>
            <param-value>fr.paris.lutece.plugins.rest.service.LuteceApplicationResourceConfig</param-value>
        </init-param>
        <init-param>
            <param-name>jersey.config.servlet.filter.contextPath</param-name>
            <param-value>/</param-value>
        </init-param>
        <init-param>
            <param-name>jersey.config.server.provider.classnames</param-name>
            <param-value>org.glassfish.jersey.filter.LoggingFilter;
                org.glassfish.jersey.media.multipart.MultiPartFeature</param-value>
        </init-param>
        <filter-class>fr.paris.lutece.plugins.rest.service.LuteceJerseySpringServlet</filter-class>
    </filter>
</filters>
```

#### v8: No Filter Registration Needed
```xml
<!-- Filters section completely removed -->
<!-- JAX-RS auto-discovery via @ApplicationPath annotation on LuteceRestApplication -->
```

### CDI beans.xml Added

```xml
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee
                           https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0"
       bean-discovery-mode="annotated">
</beans>
```

### RestConstants Changes

```java
// v7
public static final String BASE_PATH = "/rest/";

// v8
public static final String BASE_PATH = "";
public static final String APP_PATH = "/rest/";  // Used in @ApplicationPath
```

### ResourceInfoManager Migration

#### v7: Spring Bean Discovery
```java
public static List<IResourceInfoProvider> getProviders() {
    return SpringContextService.getBeansOfType(IResourceInfoProvider.class);
}
```

#### v8: CDI Bean Discovery
```java
public static List<IResourceInfoProvider> getProviders() {
    return CDI.current().select(IResourceInfoProvider.class).stream().toList();
}
```

### AbstractWriter Configuration Access

#### v7
```java
String strEncoding = AppPropertiesService.getProperty(PROPERTY_WRITER_ENCODING);
```

#### v8
```java
String strEncoding = ConfigProvider.getConfig()
    .getOptionalValue(PROPERTY_WRITER_ENCODING, String.class)
    .orElse(null);
```

## Migration Checklist for Plugins Using lutece-tech-plugin-rest

### 1. Package Imports
- [ ] Replace all `javax.ws.rs.*` imports with `jakarta.ws.rs.*`
- [ ] Replace all `javax.servlet.*` imports with `jakarta.servlet.*`
- [ ] Replace all `javax.inject.*` imports with `jakarta.inject.*`

### 2. Annotations
- [ ] Add `@Provider` annotation to all JAX-RS providers (ExceptionMappers, Filters, etc.)
- [ ] Add `@ApplicationScoped`, `@RequestScoped`, etc. for CDI beans
- [ ] Remove `@Component` Spring annotations

### 3. Dependency Injection
- [ ] Replace `@Autowired` with `@Inject`
- [ ] Replace `SpringContextService.getBean()` with CDI injection or `CDI.current().select()`
- [ ] Create CDI Producers for complex bean creation

### 4. Configuration
- [ ] Remove Spring context XML files (`*_context.xml`)
- [ ] Migrate configuration to `.properties` files with MicroProfile Config
- [ ] Replace `AppPropertiesService.getProperty()` with `ConfigProvider.getConfig().getOptionalValue()`
- [ ] Add `beans.xml` file for CDI discovery

### 5. Logging
- [ ] Replace `org.apache.log4j.Logger` with `org.apache.logging.log4j.Logger`
- [ ] Replace `Logger.getLogger()` with `LogManager.getLogger()`

### 6. REST Resources
- [ ] Ensure `@Path` annotated classes are CDI beans (add scope annotations)
- [ ] Remove manual registration from ResourceConfig
- [ ] Use `@ApplicationPath` on Application class

### 7. Filters
- [ ] Migrate servlet filters to JAX-RS `ContainerRequestFilter`/`ContainerResponseFilter`
- [ ] Use `@Priority` for filter ordering
- [ ] Use `@PreMatching` for filters that run before resource matching

### 8. Plugin Descriptor
- [ ] Remove filter registrations from `plugin.xml`
- [ ] JAX-RS auto-discovery handles registration

## Key Migration Patterns Summary

| Pattern | v7 Approach | v8 Approach |
|---------|-------------|-------------|
| REST Application | `ResourceConfig` extends | `Application` extends with `@ApplicationPath` |
| Bean Discovery | Spring XML + `@Component` | CDI `beans.xml` + `@ApplicationScoped` |
| Dependency Injection | `@Autowired` / `SpringContextService` | `@Inject` / CDI Producers |
| Configuration | `AppPropertiesService` | MicroProfile Config |
| Logging | Log4j 1.x | Log4j 2.x |
| Servlet Filter | Custom `ServletContainer` | `@Provider ContainerRequestFilter` |
| Exception Mapping | Manual `register()` | Auto-discovery with `@Provider` |
| Resource Registration | Manual `register()` | Auto-discovery with `@Path` |
