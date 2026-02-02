# Lutece Core Migration Guide: v7 to v8

## Overview

This document details the migration patterns between Lutece v7 (branch `develop`) and Lutece v8 (branch `develop8.x`) for `lutece-core`. The migration involves **728 modified Java files** and introduces significant architectural changes.

## Key Changes Summary

| Category | Lutece v7 | Lutece v8 |
|----------|-----------|-----------|
| **Parent POM** | `lutece-global-pom:6.1.0` | `lutece-global-pom:8.0.0-SNAPSHOT` |
| **Core Version** | `7.0.17-SNAPSHOT` | `8.0.0-SNAPSHOT` |
| **DI Framework** | Spring Framework 5.3.x | Jakarta CDI 4.0 |
| **Servlet API** | `javax.servlet` | `jakarta.servlet` (EE 10) |
| **Web App Version** | web-app 3.1 | web-app 6.0 |
| **Cache** | EhCache 2.x | JCache (JSR-107) / EhCache 3.x |
| **Configuration** | Spring XML + Properties | MicroProfile Config + CDI |

---

## 1. POM.xml Changes

### 1.1 Parent POM Update

```xml
<!-- BEFORE (v7) -->
<parent>
    <artifactId>lutece-global-pom</artifactId>
    <groupId>fr.paris.lutece.tools</groupId>
    <version>6.1.0</version>
</parent>
<version>7.0.17-SNAPSHOT</version>
<properties>
    <springVersion>5.3.30</springVersion>
</properties>

<!-- AFTER (v8) -->
<parent>
    <artifactId>lutece-global-pom</artifactId>
    <groupId>fr.paris.lutece.tools</groupId>
    <version>8.0.0-SNAPSHOT</version>
</parent>
<version>8.0.0-SNAPSHOT</version>
<!-- No Spring version property - Spring is removed -->
```

### 1.2 Removed Dependencies

The following dependencies have been **removed** in v8:

```xml
<!-- REMOVED: Spring Framework -->
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-aop</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-beans</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-context</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-core</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-orm</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-tx</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-web</artifactId>
</dependency>

<!-- REMOVED: Old Cache -->
<dependency>
    <groupId>net.sf.ehcache</groupId>
    <artifactId>ehcache-core</artifactId>
</dependency>
<dependency>
    <groupId>net.sf.ehcache</groupId>
    <artifactId>ehcache-web</artifactId>
</dependency>

<!-- REMOVED: Quartz Scheduler -->
<dependency>
    <groupId>org.quartz-scheduler</groupId>
    <artifactId>quartz</artifactId>
</dependency>

<!-- REMOVED: Scannotation -->
<dependency>
    <groupId>org.scannotation</groupId>
    <artifactId>scannotation</artifactId>
</dependency>

<!-- REMOVED: Old Mail -->
<dependency>
    <groupId>com.sun.mail</groupId>
    <artifactId>javax.mail</artifactId>
</dependency>

<!-- REMOVED: JPA/Persistence -->
<dependency>
    <groupId>org.eclipse.persistence</groupId>
    <artifactId>javax.persistence</artifactId>
</dependency>
```

### 1.3 New Dependencies

```xml
<!-- NEW: JCache API (JSR-107) -->
<dependency>
    <groupId>javax.cache</groupId>
    <artifactId>cache-api</artifactId>
    <version>1.1.1</version>
</dependency>

<!-- NEW: EhCache 3.x with Jakarta support -->
<dependency>
    <groupId>org.ehcache</groupId>
    <artifactId>ehcache</artifactId>
    <version>3.11.1</version>
    <classifier>jakarta</classifier>
    <scope>runtime</scope>
</dependency>

<!-- NEW: Classgraph for scanning -->
<dependency>
    <groupId>io.github.classgraph</groupId>
    <artifactId>classgraph</artifactId>
    <version>4.8.181</version>
</dependency>

<!-- NEW: Log4j Jakarta Web -->
<dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-jakarta-web</artifactId>
    <scope>runtime</scope>
</dependency>

<!-- NEW: Lutece Libraries -->
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-lutece-unit-testing-common</artifactId>
    <version>1.0.0-SNAPSHOT</version>
</dependency>
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-lutece-resources</artifactId>
    <version>1.0.0-SNAPSHOT</version>
</dependency>
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-priority-extension</artifactId>
    <version>1.0.0-SNAPSHOT</version>
</dependency>
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-core-utils</artifactId>
    <version>1.0.0-SNAPSHOT</version>
</dependency>

<!-- NEW: OWASP HTML Sanitizer -->
<dependency>
    <groupId>com.googlecode.owasp-java-html-sanitizer</groupId>
    <artifactId>owasp-java-html-sanitizer</artifactId>
    <version>20240325.1</version>
</dependency>
```

### 1.4 Updated Dependencies

```xml
<!-- Updated versions -->
<dependency>
    <groupId>commons-io</groupId>
    <artifactId>commons-io</artifactId>
    <version>2.20.0</version> <!-- was 2.11.0 -->
</dependency>
<dependency>
    <groupId>org.jsoup</groupId>
    <artifactId>jsoup</artifactId>
    <version>1.21.2</version> <!-- was 1.16.2 -->
</dependency>
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-lucene</artifactId>
    <version>6.0.0-SNAPSHOT</version> <!-- was 5.0.3 -->
</dependency>
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-workflow-core</artifactId>
    <version>4.0.0-SNAPSHOT</version> <!-- was 3.0.4 -->
</dependency>
<dependency>
    <groupId>fr.paris.lutece.plugins</groupId>
    <artifactId>library-freemarker</artifactId>
    <version>2.0.0-SNAPSHOT</version> <!-- was 1.3.4 -->
</dependency>
```

---

## 2. Package Renames (javax to jakarta)

### 2.1 Servlet API

```java
// BEFORE (v7)
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServlet;

// AFTER (v8)
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.ServletContext;
import jakarta.servlet.ServletException;
import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.FilterConfig;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServlet;
```

### 2.2 Validation API

```java
// BEFORE (v7)
import javax.validation.ConstraintViolation;

// AFTER (v8)
import jakarta.validation.ConstraintViolation;
```

### 2.3 Annotation API

```java
// BEFORE (v7)
import javax.annotation.PostConstruct;

// AFTER (v8)
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
```

---

## 3. Spring to CDI Migration

### 3.1 Spring Context Removal

The core Spring context file `webapp/WEB-INF/conf/core_context.xml` has been **completely removed** (298 lines deleted). All bean definitions are now handled via CDI annotations.

### 3.2 New CDI Configuration

A new `META-INF/beans.xml` file has been added:

```xml
<beans xmlns="https://jakarta.ee/xml/ns/jakartaee"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/beans_4_0.xsd"
       version="4.0" bean-discovery-mode="annotated">

    <alternatives>
        <!-- Alternatives can be configured here -->
        <!-- <class>fr.paris.lutece.portal.service.mail.MemoryQueue</class> -->
        <!-- <class>fr.paris.lutece.portal.service.html.VoidHtmlCleaner</class> -->
        <!-- <class>fr.paris.lutece.util.rsa.RSAKeyEnvironmentProvider</class> -->
    </alternatives>
</beans>
```

### 3.3 Bean Annotation Changes

#### DAOs - Add @ApplicationScoped

```java
// BEFORE (v7) - Spring XML configuration
// In core_context.xml:
// <bean id="adminDashboardDAO" class="fr.paris.lutece.portal.business.dashboard.AdminDashboardDAO" />

// Class had no annotations:
public class AdminDashboardDAO implements IAdminDashboardDAO { ... }

// AFTER (v8) - CDI annotations
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class AdminDashboardDAO implements IAdminDashboardDAO { ... }
```

#### Services - Add @ApplicationScoped

```java
// BEFORE (v7)
public final class AccessControlService {
    private static AccessControlService _singleton;

    private AccessControlService() {
        try {
            _provider = SpringContextService.getBean("accesscontrol.accessControlServiceProvider");
        } catch (NoSuchBeanDefinitionException e) { ... }
    }

    public static synchronized AccessControlService getInstance() {
        if (_singleton == null) {
            _singleton = new AccessControlService();
        }
        return _singleton;
    }
}

// AFTER (v8)
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Instance;
import jakarta.inject.Inject;
import jakarta.inject.Named;

@ApplicationScoped
public class AccessControlService {
    private IAccessControlServiceProvider _provider;

    @Inject
    @Named("accesscontrol.accessControlServiceProvider")
    Instance<IAccessControlServiceProvider> providerInstance;

    public static AccessControlService getInstance() {
        return CDI.current().select(AccessControlService.class).get();
    }
}
```

### 3.4 SpringContextService.getBean() Migration

#### Pattern 1: Static DAO Reference in Home Classes

```java
// BEFORE (v7)
import fr.paris.lutece.portal.service.spring.SpringContextService;

public final class AdminDashboardHome {
    private static IAdminDashboardDAO _dao = SpringContextService.getBean("adminDashboardDAO");
}

// AFTER (v8)
import jakarta.enterprise.inject.spi.CDI;

public final class AdminDashboardHome {
    private static IAdminDashboardDAO _dao = CDI.current().select(IAdminDashboardDAO.class).get();
}
```

#### Pattern 2: Named Bean Lookup

```java
// BEFORE (v7)
IFileStoreServiceProvider provider = SpringContextService.getBean("defaultDatabaseFileStoreProvider");

// AFTER (v8)
import jakarta.enterprise.inject.literal.NamedLiteral;

IFileStoreServiceProvider provider = CDI.current()
    .select(IFileStoreServiceProvider.class, NamedLiteral.of("defaultDatabaseFileStoreProvider"))
    .get();
```

#### Pattern 3: Iterating Over Beans of Type

```java
// BEFORE (v7)
for (PortletEventListener listener : SpringContextService.getBeansOfType(PortletEventListener.class)) {
    listener.processPortletEvent(event);
}

// AFTER (v8)
CDI.current().select(PortletEventListener.class).forEach(
    listener -> listener.processPortletEvent(event)
);
```

#### Pattern 4: CDI Injection in Classes

```java
// BEFORE (v7) - Manual lookup
public class MyService {
    public void doSomething() {
        IMyDAO dao = SpringContextService.getBean("myDAO");
        dao.save(entity);
    }
}

// AFTER (v8) - Injection
import jakarta.inject.Inject;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class MyService {
    @Inject
    private IMyDAO dao;

    public void doSomething() {
        dao.save(entity);
    }
}
```

---

## 4. CDI Producers

### 4.1 Producer Pattern for Complex Bean Creation

CDI Producers replace Spring XML bean definitions for complex bean configurations.

```java
// BEFORE (v7) - Spring XML
// <bean id="commonsBoostrap5Tabler" class="fr.paris.lutece.portal.business.template.CommonsInclude">
//     <property name="key" value="Bootstrap5Tabler" />
//     <property name="default" value="true" />
//     <property name="name" value="Tabler 1.0.0" />
//     <property name="files">
//         <list>
//             <value>commons_bs5_tabler.html</value>
//             <value>commons_backport.html</value>
//             <value>admin/util/calendar/macro_datetimepicker.html</value>
//         </list>
//     </property>
// </bean>

// AFTER (v8) - CDI Producer
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Named;
import jakarta.inject.Singleton;

@ApplicationScoped
public class CommonsIncludeProducer {

    @Produces
    @Named("commonsBoostrap5Tabler")
    @Singleton
    public CommonsInclude commonsBoostrap5TablerProduces() {
        return new CommonsInclude.CommonsIncludeBuilder("commonsBoostrap5Tabler")
            .setDefault(true)
            .setName("Bootstrap 5.1 + Tabler 1.0 + Backport file (v6.x compatible) (Default)")
            .setFiles(List.of(
                "commons_bs5_tabler.html",
                "commons_backport.html",
                "admin/util/calendar/macro_datetimepicker.html"
            ))
            .build();
    }
}
```

### 4.2 RemovalListenerService Producer

```java
// BEFORE (v7) - Spring XML
// <bean id="mailinglistRemovalService" class="fr.paris.lutece.portal.service.util.RemovalListenerService" />
// <bean id="workgroupRemovalService" class="fr.paris.lutece.portal.service.util.RemovalListenerService" />
// ...

// AFTER (v8) - CDI Producer
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Named;

@ApplicationScoped
public class RemovalListenerServiceProducer {

    @Produces
    @Named(BeanUtils.BEAN_MAILINGLIST_REMOVAL_SERVICE)
    @ApplicationScoped
    public RemovalListenerService mailingProducer() {
        return new RemovalListenerService();
    }

    @Produces
    @Named(BeanUtils.BEAN_WORKGROUP_REMOVAL_SERVICE)
    @ApplicationScoped
    public RemovalListenerService workGroupProducer() {
        RemovalListenerService service = new RemovalListenerService();
        service.registerListener(new MailingListWorkgroupRemovalListener());
        return service;
    }

    // ... other producers
}
```

### 4.3 Daemon Executor Producer

```java
// BEFORE (v7) - Spring XML
// <bean id="daemonExecutor" class="java.util.concurrent.ThreadPoolExecutor">
//     <constructor-arg index="0" value="${daemon.ScheduledThreadCorePoolSize:1}" />
//     <constructor-arg index="1" value="${daemon.maximumPoolSize:30}" />
//     ...
// </bean>

// AFTER (v8) - CDI Producer with MicroProfile Config
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;

@ApplicationScoped
public class DaemonExecutorProducer {

    @Inject
    DaemonThreadFactory _daemonThreadFactory;

    @Inject
    @ConfigProperty(name = "daemon.ScheduledThreadCorePoolSize", defaultValue = "1")
    private int corePoolSize;

    @Inject
    @ConfigProperty(name = "daemon.maximumPoolSize", defaultValue = "30")
    private int maximumPoolSize;

    @Inject
    @ConfigProperty(name = "daemon.keepAliveTime", defaultValue = "60")
    private long keepAliveTime;

    @Inject
    @ConfigProperty(name = "daemon.timeUnit", defaultValue = "SECONDS")
    private String timeUnitString;

    @Produces
    @ApplicationScoped
    @DaemonExecutor
    public ExecutorService executorServiceProduces() {
        return new ThreadPoolExecutor(
            corePoolSize,
            maximumPoolSize,
            keepAliveTime,
            TimeUnit.valueOf(timeUnitString),
            new SynchronousQueue<>(),
            _daemonThreadFactory
        );
    }
}
```

---

## 5. CDI Events

### 5.1 Event Observer Pattern

CDI Events replace Spring ApplicationListener and custom listener patterns.

```java
// BEFORE (v7) - Custom listener interface
public interface PageEventListener extends EventListener {
    void processPageEvent(PageEvent event);
}

// Registration via Spring
// SpringContextService.getBeansOfType(PageEventListener.class).forEach(...)

// AFTER (v8) - CDI Observer
import jakarta.enterprise.event.Observes;

@ApplicationScoped
public class PageCacheEventObserver {

    public void processPageEvent(@Observes PageEvent event) {
        // Handle the event
    }
}
```

### 5.2 Firing Events

```java
// BEFORE (v7)
for (PortletEventListener listener : SpringContextService.getBeansOfType(PortletEventListener.class)) {
    listener.processPortletEvent(event);
}

// AFTER (v8)
CDI.current().getBeanManager().getEvent().fire(event);
```

### 5.3 Cache Events

```java
// NEW in v8 - Cache event
public class LuteceCacheEvent {
    public enum LuteceCacheEventType {
        RESET,
        CLEAR,
    }

    private final Cache source;
    private final LuteceCacheEventType _type;

    // Constructor, getters...
}

// Firing cache event
CDI.current().getBeanManager().getEvent().fire(new LuteceCacheEvent(_cache, LuteceCacheEventType.RESET));

// Observing cache event
public void cacheShutDownEvent(@Observes CacheService.ShutDownEvent event) {
    // Handle shutdown
}
```

### 5.4 Startup Events with Priority

```java
// NEW in v8 - CDI Lifecycle events with priority
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.context.Initialized;
import jakarta.enterprise.event.Observes;
import jakarta.servlet.ServletContext;

@ApplicationScoped
public class ServletContextInitNotifier {

    public void initializedService(
        @Observes
        @Initialized(ApplicationScoped.class)
        @Priority(value = 1)
        ServletContext context) {
        // Initialize services
    }

    public void initializedOtherService(
        @Observes
        @Priority(value = 3)
        @Initialized(ApplicationScoped.class)
        ServletContext context) {
        // Initialize other services later
    }
}
```

---

## 6. MicroProfile Config

### 6.1 Configuration Property Injection

```java
// BEFORE (v7)
String value = AppPropertiesService.getProperty("daemon.maximumPoolSize", "30");
int maxPoolSize = Integer.parseInt(value);

// AFTER (v8) - MicroProfile Config injection
import org.eclipse.microprofile.config.inject.ConfigProperty;
import jakarta.inject.Inject;

@Inject
@ConfigProperty(name = "daemon.maximumPoolSize", defaultValue = "30")
private int maximumPoolSize;
```

### 6.2 Optional Configuration

```java
import org.eclipse.microprofile.config.Config;

@Inject
private Config _config;

// Get optional value
String insertAfter = _config.getOptionalValue("modifyPasswordUserMenuItemProvider.insertAfter", String.class)
    .orElse(null);
```

---

## 7. Cache Migration (EhCache 2 to JCache/JSR-107)

### 7.1 Cache Service Changes

```java
// BEFORE (v7) - EhCache 2.x
import net.sf.ehcache.Cache;
import net.sf.ehcache.CacheManager;
import net.sf.ehcache.Element;

public abstract class AbstractCacheableService implements CacheableService, CacheEventListener {
    private Cache _cache;

    protected void initCache() {
        _cache = CacheService.getInstance().createCache(strCacheName);
    }

    public Object getFromCache(String key) {
        Element element = _cache.get(key);
        return element != null ? element.getObjectValue() : null;
    }

    public void putInCache(String key, Object value) {
        _cache.put(new Element(key, value));
    }
}

// AFTER (v8) - JCache (JSR-107)
import javax.cache.Cache;
import javax.cache.CacheManager;
import javax.cache.configuration.MutableConfiguration;

public abstract class AbstractCacheableService<K, V> implements Cache<K, V>, CacheableService {

    // JCache API methods
    public V get(K key) { ... }
    public void put(K key, V value) { ... }
    public boolean containsKey(K key) { ... }
    public void clear() { ... }
}
```

### 7.2 Cache Producer with Custom Annotation

```java
// NEW in v8 - Custom cache qualifier
import jakarta.inject.Qualifier;
import java.lang.annotation.*;

@Qualifier
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.FIELD, ElementType.METHOD, ElementType.PARAMETER, ElementType.TYPE})
public @interface LuteceCache {
    String cacheName();
    Class<?> keyType() default Object.class;
    Class<?> valueType() default Object.class;
    boolean enable() default false;
    boolean preventGlobalReset() default false;
}

// Cache injection
@Inject
@LuteceCache(cacheName = "myCache", keyType = String.class, valueType = MyObject.class, enable = true)
private Lutece107Cache<String, MyObject> myCache;
```

### 7.3 Cache Producer

```java
@ApplicationScoped
public class LuteceCacheProducer {

    @Inject
    protected ILuteceCacheManager luteceCacheManager;

    @Produces
    @LuteceCache(cacheName = "", keyType = Object.class, valueType = Object.class, enable = false, preventGlobalReset = false)
    public <K, V> Lutece107Cache<K, V> produceLuteceCache(InjectionPoint injectionPoint) {
        LuteceCache qualifier = injectionPoint.getQualifiers().stream()
            .filter(LuteceCache.class::isInstance)
            .map(LuteceCache.class::cast)
            .findFirst()
            .orElse(null);

        if (qualifier == null || qualifier.cacheName().isEmpty()) {
            throw new IllegalStateException("The LuteceCache annotation is missing.");
        }

        return new Default107Cache<>(
            qualifier.cacheName(),
            (Class<K>) qualifier.keyType(),
            (Class<V>) qualifier.valueType(),
            qualifier.enable(),
            qualifier.preventGlobalReset()
        );
    }
}
```

---

## 8. Singleton Pattern Changes

### 8.1 Deprecated Static getInstance()

Many singleton patterns have been deprecated in favor of CDI injection.

```java
// BEFORE (v7)
public final class AttributeService {
    private static AttributeService _instance;

    public static synchronized AttributeService getInstance() {
        if (_instance == null) {
            _instance = new AttributeService();
        }
        return _instance;
    }
}

// Usage
AttributeService.getInstance().getAllAttributes(locale);

// AFTER (v8)
@ApplicationScoped
public class AttributeService {

    // getInstance() kept for backward compatibility but deprecated
    public static AttributeService getInstance() {
        return CDI.current().select(AttributeService.class).get();
    }
}

// Preferred usage
@Inject
private AttributeService attributeService;
```

---

## 9. Web.xml Changes

### 9.1 Namespace Update

```xml
<!-- BEFORE (v7) -->
<web-app xmlns="http://java.sun.com/xml/ns/javaee"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://java.sun.com/xml/ns/javaee http://java.sun.com/xml/ns/javaee/web-app_3_1.xsd"
    version="3.1">

<!-- AFTER (v8) -->
<web-app xmlns="https://jakarta.ee/xml/ns/jakartaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee https://jakarta.ee/xml/ns/jakartaee/web-app_6_0.xsd"
         version="6.0">
```

### 9.2 Removed Listeners

```xml
<!-- REMOVED in v8 -->
<listener>
    <display-name>Lutece context listener</display-name>
    <listener-class>fr.paris.lutece.portal.service.init.AppInitListener</listener-class>
</listener>

<listener>
    <display-name>Spring Context Listener</display-name>
    <listener-class>org.springframework.web.context.request.RequestContextListener</listener-class>
</listener>
```

### 9.3 New Filters

```xml
<!-- NEW in v8 -->
<filter>
    <filter-name>pageSecurityHeaderFilter</filter-name>
    <filter-class>fr.paris.lutece.portal.service.filter.PageSecurityHeaderFilter</filter-class>
</filter>

<filter>
    <filter-name>restApiSecurityHeaderFilter</filter-name>
    <filter-class>fr.paris.lutece.portal.service.filter.RestApiSecurityHeaderFilter</filter-class>
</filter>

<filter>
    <filter-name>securityTokenFilterSite</filter-name>
    <filter-class>fr.paris.lutece.portal.service.security.SecurityTokenFilterSite</filter-class>
</filter>

<filter>
    <filter-name>securityTokenFilterAdmin</filter-name>
    <filter-class>fr.paris.lutece.portal.service.security.SecurityTokenFilterAdmin</filter-class>
</filter>

<filter>
    <filter-name>multipartFilterAdmin</filter-name>
    <filter-class>fr.paris.lutece.portal.web.upload.AdminMultipartFilter</filter-class>
</filter>
```

### 9.4 Multipart Configuration

```xml
<!-- NEW in v8 - Multipart config on servlet -->
<servlet>
    <servlet-name>SiteUploadServlet</servlet-name>
    <servlet-class>fr.paris.lutece.portal.web.upload.UploadServlet</servlet-class>
    <init-param>
        <param-name>activateNormalizeFileName</param-name>
        <param-value>true</param-value>
    </init-param>
    <multipart-config>
        <max-request-size>10485760</max-request-size>
    </multipart-config>
</servlet>
```

---

## 10. CDI Alternatives

### 10.1 Alternative Pattern

```java
// Define an alternative implementation
import jakarta.enterprise.inject.Alternative;

@Alternative
@ApplicationScoped
public class VoidHtmlCleaner implements IHtmlCleaner {
    // Implementation that doesn't modify HTML
}

// Activate in beans.xml
<beans>
    <alternatives>
        <class>fr.paris.lutece.portal.service.html.VoidHtmlCleaner</class>
    </alternatives>
</beans>
```

---

## 11. CDI Extension for Early Initialization

```java
// NEW in v8 - CDI Extension
import jakarta.enterprise.inject.spi.Extension;
import jakarta.enterprise.inject.spi.BeforeBeanDiscovery;
import jakarta.annotation.Priority;
import jakarta.enterprise.event.Observes;

public class AppInitExtension implements Extension {

    protected void initPropertiesServices(
        @Observes
        @Priority(value = 1)
        final BeforeBeanDiscovery bd) {

        // Initialize properties before CDI beans are discovered
        AppInit.initConfigLog();
    }
}
```

---

## 12. Lifecycle Annotations

### 12.1 PostConstruct

```java
// BEFORE (v7) - javax
import javax.annotation.PostConstruct;

// AFTER (v8) - jakarta
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;

@ApplicationScoped
public class MyService {

    @PostConstruct
    private void init() {
        // Initialize after dependency injection
    }

    @PreDestroy
    private void cleanup() {
        // Cleanup before destruction
    }
}
```

---

## 13. Deprecated Services

Several service accessor classes have been deprecated with instructions to use CDI injection:

```java
/**
 * Returns the {@link RemovalListenerService} instance.
 * <p>
 * This static accessor is <strong>deprecated</strong> and will be removed in a future release.
 * Instead of calling this method directly, you should use <b>CDI dependency injection</b>
 * to obtain an instance of {@code RemovalListenerService}.
 * </p>
 *
 * <pre>{@code
 * @Inject
 * @Named(BeanUtils.BEAN_MAILINGLIST_REMOVAL_SERVICE)
 * private RemovalListenerService removalListenerService;
 * }</pre>
 *
 * @deprecated since 8.0 - use CDI injection instead of this static method.
 */
@Deprecated(since = "8.0", forRemoval = true)
public static RemovalListenerService getService() {
    return CDI.current()
        .select(RemovalListenerService.class, NamedLiteral.of(BeanUtils.BEAN_MAILINGLIST_REMOVAL_SERVICE))
        .get();
}
```

---

## 14. Migration Checklist

### 14.1 For Plugin Developers

1. **Update pom.xml**
   - Change parent POM to `8.0.0-SNAPSHOT`
   - Remove Spring dependencies
   - Add any required Jakarta EE dependencies

2. **Package Imports**
   - Replace all `javax.servlet.*` with `jakarta.servlet.*`
   - Replace all `javax.validation.*` with `jakarta.validation.*`
   - Replace all `javax.annotation.*` with `jakarta.annotation.*`
   - Replace all `javax.inject.*` with `jakarta.inject.*`

3. **Spring to CDI**
   - Add `@ApplicationScoped` to DAO classes
   - Add `@ApplicationScoped` to Service classes
   - Replace `SpringContextService.getBean()` with `CDI.current().select()`
   - Replace Spring XML bean definitions with CDI Producers
   - Add `@Inject` for dependency injection

4. **Context Files**
   - Remove `*_context.xml` files
   - Create `META-INF/beans.xml` if needed

5. **Cache**
   - Migrate from EhCache 2.x API to JCache (JSR-107)
   - Use `@LuteceCache` annotation for cache injection

6. **Configuration**
   - Use `@ConfigProperty` for injected configuration values

7. **Events**
   - Replace custom listeners with CDI `@Observes`
   - Use `CDI.current().getBeanManager().getEvent().fire()` to fire events

### 14.2 Common Patterns Summary

| v7 Pattern | v8 Pattern |
|------------|------------|
| `SpringContextService.getBean("name")` | `CDI.current().select(Type.class).get()` |
| `SpringContextService.getBean("name")` (named) | `CDI.current().select(Type.class, NamedLiteral.of("name")).get()` |
| `SpringContextService.getBeansOfType(Type.class)` | `CDI.current().select(Type.class)` |
| Spring XML `<bean>` | `@ApplicationScoped` + class annotations |
| Spring XML with properties | CDI `@Produces` method |
| `@Component` / `@Service` (Spring) | `@ApplicationScoped` (CDI) |
| `@Autowired` | `@Inject` |
| `@Qualifier("name")` (Spring) | `@Named("name")` (CDI) |
| ApplicationListener | `@Observes` on method parameter |
| `getInstance()` singleton | `CDI.current().select(Type.class).get()` |

---

## 15. Related Files Changed

- **728 Java files modified**
- `pom.xml` - Dependencies and versions
- `webapp/WEB-INF/web.xml` - Servlet configuration
- `webapp/WEB-INF/conf/core_context.xml` - Removed
- `webapp/WEB-INF/conf/jpa_context.xml` - Removed
- `src/main/resources/META-INF/beans.xml` - New CDI configuration
