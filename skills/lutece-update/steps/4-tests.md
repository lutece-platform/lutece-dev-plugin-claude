# Step 4 — Unit tests

`src/test/`. `verify-file.sh` reports what JUnit 4 and v7 leave, each finding with what to do (TS*, PM13): jupiter
imports, `@Test` / `@BeforeEach` / `@AfterEach` on the `LuteceTestCase` methods (TS06), the literal assertion message
last (TS03), the Lutece mocks `fr.paris.lutece.test.mocks` (TS04), `SpringContextService` lookups (SP01). Conventions: `rules/testing.md`. This step is what makes the tests run in a real CDI
container; a test that fails because of production code is fixed in the production code.

## What a v8 test container needs

- **Injection**: `@Inject` works in a `LuteceTestCase` (Weld); inject the interface, `Instance<T>` for a service of
  another plugin that may be absent.
- **Test dependencies**, only when a test needs them, test scope, versions from the parent: `jaxb-runtime` for a test
  that renders a JspBean or XPage (ehcache reads its XML through JAXB); plus `hibernate-validator` and `expressly` for a
  test that calls `processController`. Business tests (DAO, Home) need none.
- **Config source** when Weld aborts with `SRCFG02000` before any test: `src/test/resources/META-INF/microprofile-config.properties`
  with `mp.config.profile=test`, `daemon.zoneId=Europe/Paris` and the three
  `lutece.defaultFileServiceProvider.*` keys copied from the core's `webapp/WEB-INF/conf/config.properties` (they are
  CDI bean names resolved later: a wrong one fails far from this file). Add any key the exceptions name.
- **A half-started container**: `AppInit.initServices` logs `Error ininitialised service` once and skips every service
  after the one that threw, so the NPE a test shows (`PluginService._pluginCache is null`) is rarely the cause. Grep
  the log for `LUTECE SERVER started successfully`; without it, find the single swallowed stack (usually a missing
  `jaxb-runtime`). When the plugin cache genuinely cannot exist, pass a `null` `Plugin` to the Home/DAO: `DAOUtil`
  falls back on the portal pool.
- **A JspBean test that renders a v8 admin template**: `CommonsService.activateCommons( CommonsService.getCurrentCommonsKey( ) )`
  in `@BeforeEach` (else `pageContainer` is missing), and the three test dependencies above (else `WELD-000049` on
  `BeanValidationProducer`).
- **The security token is not checked in a unit test** (no `SecurityTokenFilter`): delete a v7 line that forged one;
  the e2e bench proves the token. A reference test that fails without a token (`sitelabels` `LabelJspBeanTest`) tests
  a bean that validates the token by hand in its actions (MV03), not a `securityTokenEnabled` controller.
- **A test asserting on a rendered page** controls the page template: the root page of a fresh install renders no
  portlet column; create the host page with template 2 (`One column`). When the code under test changes its rendering
  (XSL portlet ported to HTML), re-read every assertion written against the old output.
- `LocalVariables.setLocal( … )` in a test: `LocalVariables.remove( )` in `@AfterEach`.

Helpers of `library-lutece-unit-testing`: `AdminUserUtils.registerAdminUserWithRight( request, user, "RIGHT" )`,
`ReflectionTestUtils.setField( … )`, `Utils.getRandomName( )`, `Utils.getFileContent( … )`.
