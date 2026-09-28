#!/usr/bin/env bash
# Checks every grep and pom check of verify-migration.sh both ways: a line in the defect's shape fires it, the v8 form, a
# comment or a longer name does not. TM01 reads templates, which needs an assembled webapp: test-template-rules covers it.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
V="$HERE/../../tools/verify-migration.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0

# Writes one fixture project: $1 name, $2 relative file, $3 content.
fixture() {
    mkdir -p "$T/$1/$(dirname "$2")"
    printf '%s\n' "$3" > "$T/$1/$2"
}

# Records a failure when a check does not answer the expected status on a fixture.
expect() {
    local got
    got=$( ( cd "$T/$1" && bash "$V" . 2>/dev/null ) | sed 's/\x1b\[[0-9;]*m//g' | grep -oE "(PASS|FAIL|WARN) \[$2\]" | head -1 | cut -d' ' -f1)
    [ "$got" = "$3" ] || { echo "FAIL: $2 on $1 expected $3, got ${got:-nothing}"; fails=$((fails + 1)); }
}

J=src/java/x/A.java
while IFS='|' read -r code sev file bad good; do
    [ -n "$code" ] || continue
    fixture "$code-bad" "$file" "$bad"
    fixture "$code-good" "$file" "$good"
    expect "$code-bad" "$code" "$sev"
    expect "$code-good" "$code" PASS
done <<ROWS
JX01|FAIL|$J|import javax.servlet.http.HttpServletRequest;|import jakarta.servlet.http.HttpServletRequest;
JX02|FAIL|$J|import javax.validation.Valid;|import jakarta.validation.Valid;
JX03|FAIL|$J|import javax.annotation.PostConstruct;|import jakarta.annotation.PostConstruct;
JX04|FAIL|$J|import javax.inject.Inject;|import jakarta.inject.Inject;
JX05|FAIL|$J|import javax.enterprise.context.ApplicationScoped;|import jakarta.enterprise.context.ApplicationScoped;
JX06|FAIL|$J|import javax.ws.rs.GET;|import jakarta.ws.rs.GET;
JX07|FAIL|$J|import javax.xml.bind.JAXBContext;|import jakarta.xml.bind.JAXBContext;
JX09|FAIL|$J|import javax.persistence.Entity;|import jakarta.persistence.Entity;
JX08|FAIL|$J|import javax.transaction.Transactional;|import javax.transaction.xa.XAResource;
SP01|FAIL|$J|X x = SpringContextService.getBean( "x" );|X x = CDI.current( ).select( X.class ).get( );
SP02|FAIL|$J|import org.springframework.stereotype.Service;|import jakarta.inject.Named;
SP04|FAIL|$J|    @Autowired|    @Inject
SP05|FAIL|$J|public class A implements InitializingBean|public class A implements Serializable
SP06|FAIL|$J|@Component( "x" )|@Named( "x" )
SP07|FAIL|$J|@Service( "x" )|@Named( "x" )
SP08|FAIL|$J|@Repository( "x" )|@Named( "x" )
DL01|FAIL|$J|import net.sf.json.JSONObject;|import com.fasterxml.jackson.databind.JsonNode;
EV01|FAIL|$J|ResourceEventManager.register( listener );|void onEvent( @Observes ResourceEvent event ) { }
EV02|FAIL|$J|public class L implements EventRessourceListener|public class L
EV03|FAIL|$J|LuteceUserEventManager.getInstance( ).register( l );|void onEvent( @Observes LuteceUserEvent event ) { }
EV04|FAIL|$J|QueryListenersService.getInstance( ).registerQueryListener( l );|void onEvent( @Observes QueryEvent event ) { }
EV05|FAIL|$J|public class M extends AbstractEventManager|public class M
CA01|FAIL|$J|import net.sf.ehcache.Cache;|import javax.cache.Cache;
CA02|FAIL|$J|_cache.putInCache( strKey, value );|_cache.put( strKey, value );
CA03|FAIL|$J|public class C extends AbstractCacheableService|public class C extends AbstractCacheableService<String, Object>
DP02|FAIL|$J|        FileImageService.init( );|        CiteFileImageService.init( );
DP03|FAIL|$J|        Map<String, Object> model = getModel( );|        Map<String, Object> model = request.getModel( );
DA01|FAIL|$J|        daoUtil.free( );|        daoUtil.close( );
JP01|FAIL|$J|import org.hibernate.Session;|import org.hibernate.validator.constraints.Length;
CD02|FAIL|$J|ICaptchaService c = new CaptchaSecurityService();|@Inject @Named( BeanUtils.BEAN_CAPTCHA_SERVICE ) Instance<ICaptchaService> _captcha;
CD09|FAIL|$J|boolean b = PluginService.isPluginEnable( "jcaptcha" );|boolean b = _captchaService.isResolvable( );
CD03|WARN|$J|        CompletableFuture.runAsync( ( ) -> run( ) );|        CompletableFuture.runAsync( ( ) -> run( ), _executor );
CD04|FAIL|$J|import org.apache.commons.fileupload.FileItem;|import fr.paris.lutece.portal.service.upload.MultipartItem;
MV02|FAIL|$J|public class B extends AbstractPaginatorJspBean|public class B extends MVCAdminJspBean
WB02|FAIL|webapp/WEB-INF/plugins/x.xml|<application-class>x.App</application-class>|<!-- <application-class>x.App</application-class> -->
WB03|FAIL|webapp/WEB-INF/web.xml|<listener-class>org.springframework.web.context.ContextLoaderListener</listener-class>|<listener-class>x.MyListener</listener-class>
JS01|FAIL|webapp/jsp/admin/x/X.jsp|<jsp:useBean id="x" scope="session" class="x.XJspBean" />|<%@ page errorPage="../ErrorPage.jsp" %>
LG01|FAIL|$J|        AppLogService.error( "Error " + e.getMessage( ), e );|        AppLogService.error( "Error {}", e.getMessage( ), e );
LG02|WARN|$J|        if ( AppLogService.isDebugEnabled( ) )|        AppLogService.debug( "x {}", y );
TS01|FAIL|src/test/java/x/ATest.java|import org.junit.Test;|import org.junit.jupiter.api.Test;
TS02|FAIL|src/test/java/x/ATest.java|import org.junit.Before;|import org.junit.jupiter.api.BeforeEach;
TS03|FAIL|src/test/java/x/ATest.java|import org.junit.Assert;|import org.junit.jupiter.api.Assertions;
TS04|FAIL|src/test/java/x/ATest.java|MokeHttpServletRequest r = new MokeHttpServletRequest( );|MockHttpServletRequest r = new MockHttpServletRequest( );
TS05|FAIL|src/test/java/x/ATest.java|import org.junit.BeforeClass;|import org.junit.jupiter.api.BeforeAll;
TS07|FAIL|src/test/java/x/ATest.java|X x = SpringContextService.getBean( "x" );|@Inject X _x;
TS08|FAIL|src/test/java/x/ATest.java|import org.springframework.mock.web.MockHttpServletRequest;|import fr.paris.lutece.test.mocks.MockHttpServletRequest;
JP03|FAIL|src/main/resources/META-INF/persistence.xml|<property name="hibernate.dialect" value="x"/>|<property name="eclipselink.logging.level" value="x"/>
JP07|WARN|src/main/liberty/config/server.xml|<feature>persistenceContainer-3.1</feature>|<feature>persistence-3.1</feature>
WB01|FAIL|webapp/WEB-INF/web.xml|<web-app xmlns="http://java.sun.com/xml/ns/javaee">|<web-app xmlns="https://jakarta.ee/xml/ns/jakartaee">
ROWS

POM_OPEN='<project><dependencies>'
POM_CLOSE='</dependencies></project>'
while IFS='|' read -r code sev bad good; do
    [ -n "$code" ] || continue
    fixture "$code-bad" pom.xml "$POM_OPEN
$bad
$POM_CLOSE"
    fixture "$code-good" pom.xml "$POM_OPEN
$good
$POM_CLOSE"
    expect "$code-bad" "$code" "$sev"
    expect "$code-good" "$code" PASS
done <<POMS
PM01|FAIL|<dependency><groupId>org.springframework</groupId><artifactId>spring-core</artifactId></dependency>|<!-- <dependency><groupId>org.springframework</groupId></dependency> -->
PM02|FAIL|<dependency><groupId>net.sf.ehcache</groupId><artifactId>ehcache</artifactId></dependency>|<dependency><groupId>net.sf.ehcache</groupId><artifactId>ehcache</artifactId><scope>test</scope></dependency>
PM03|FAIL|<dependency><groupId>com.sun.mail</groupId><artifactId>javax.mail</artifactId></dependency>|<dependency><groupId>org.eclipse.angus</groupId><artifactId>angus-mail</artifactId></dependency>
PM04|FAIL|<dependency><groupId>org.glassfish.jersey.core</groupId><artifactId>jersey-common</artifactId></dependency>|<dependency><groupId>org.glassfish.jersey.core</groupId><artifactId>jersey-common</artifactId><scope>test</scope></dependency>
PM05|FAIL|<dependency><groupId>net.sf.json-lib</groupId><artifactId>json-lib</artifactId></dependency>|<dependency><groupId>com.fasterxml.jackson.core</groupId><artifactId>jackson-databind</artifactId></dependency>
PM07|WARN|<properties><springVersion>6.0.8</springVersion></properties>|<properties><jakartaVersion>10</jakartaVersion></properties>
PM08|WARN|<properties><jiraProjectName>X</jiraProjectName></properties>|<!-- <jiraProjectName>X</jiraProjectName> -->
JP02|FAIL|<dependency><groupId>org.hibernate</groupId><artifactId>hibernate-core</artifactId></dependency>|<dependency><groupId>org.hibernate.validator</groupId><artifactId>hibernate-validator</artifactId></dependency>
POMS
[ "$fails" -eq 0 ] && { echo "PASS: every grep and pom check fires on its defect and stays silent on the v8 form"; exit 0; }
exit 1
