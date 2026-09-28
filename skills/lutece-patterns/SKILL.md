---
name: lutece-patterns
description: "Use before writing or reviewing any Lutece 8 code (CRUD, JspBean, XPage, service, DAO, daemon, template) and when answering questions about Lutece 8 architecture, layered design or coding conventions. Canonical patterns extracted from lutece-core."
---

# Lutece 8 — Architecture Patterns

Write each layer like the reference that already does it, read in `~/.lutece-references/` (core, then
`lutece-form-plugin-forms` for a complete plugin): copy its shape, not a memory of it. The rule of each layer is
loaded with the files it scopes (on another harness, read it before editing). After writing, `tools/lutece-check.sh`
and `tools/verify-file.sh` report what a script can see.

```
JspBean / XPage   web: request, validation, templates     rules/web-bean.md, rules/jsp-admin.md   core ThemeJspBean, forms FormJspBean
Service           business logic                          rules/service-layer.md                  forms FormService
Home              static facade over the DAO              rules/dao-patterns.md                   core RoleHome, forms FormHome
DAO               DAOUtil, SQL, try-with-resources        rules/dao-patterns.md                   core RoleDAO, forms FormDAO
Entity            POJO                                    rules/java-conventions.md
```

Never skip a layer. Templates: skills `lutece-update-template-bo` / `-fo`. SQL: `rules/sql-liquibase.md`. Tests:
`rules/testing.md`.

## Entity

Getters and setters only, `Serializable` with a `serialVersionUID`. Field prefixes: `_str` String, `_n` int, `_b`
boolean, `_date` Timestamp, `_list` collection. Implement `RBACResource` for permissions, `AdminWorkgroupResource` for
workgroup filtering, `IExtendableResource` for the extension system, only when needed.

## Daemon

`extends Daemon`, `run( )` ends with `setLastRunLogs( … )`. Declared in `plugin.xml` (`<daemon-id>`, `<daemon-name>`,
`<daemon-description>`, `<daemon-class>`, no interval tag); instantiated by the core through `Class.forName`, so no CDI
scope and dependencies through `CDI.current( ).select( … )`. Interval in properties, in seconds:
`daemon.<id>.interval=3600`, `daemon.<id>.onstartup=0`. On demand: `AppDaemonService.signalDaemon( "<id>" )`.

## Configuration

- `@Inject @ConfigProperty( name = "…", defaultValue = "…" )` in a CDI bean; `AppPropertiesService.getProperty( … )`
  in a static context (Home, `static final`, non-CDI class). A key shipped empty reads `null`.
- `DatastoreService.getInstanceDataValue( key, default )` / `setInstanceDataValue`: a key-value store in the database,
  read explicitly, not a config source; `#dskey{…}` in a template.

## Events

Fire with `CDI.current( ).getBeanManager( ).getEvent( ).fire( … )` or `.fireAsync( … )`, qualified with
`.select( new TypeQualifier( EventAction.CREATE ) )`; observe with `@Observes` / `@ObservesAsync`. Core resource
events: `fr.paris.lutece.portal.business.event.ResourceEvent` (`getIdResource( )`, `getTypeResource( )`). Several
implementations of one interface: `CDI.current( ).select( IProvider.class ).stream( )`.

## Security, every admin feature

1. `@Controller( right = … )`: `processController` checks it (never `init( )` in the bean or the JSP).
2. `securityTokenEnabled = true`: the core puts the token in every form and validates every `@Action` POST.
3. `securityTokenAction` on confirmation views, so the confirm button carries the token of the action.
4. `RBACService.getAuthorizedCollection( )` when RBAC is on; `AdminWorkgroupService.getAuthorizedCollection( )` for
   workgroups.
