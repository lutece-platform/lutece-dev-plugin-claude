# Event Migration Patterns (v7 → v8)

Single source of truth for all event/listener migration patterns.

> **Reference-First Principle:** Before writing any event listener or firing code, **search `~/.lutece-references/` for existing `@Observes` implementations** (e.g., `Grep @Observes ~/.lutece-references/`). Reproduce the reference structure exactly.

## 1. ResourceEventManager → CDI Events

`ResourceEventManager` is `@Deprecated(forRemoval = true)` in lutece-core v8. The `EventRessourceListener` interface that goes with it is also deprecated. Both must be replaced by CDI `@Observes` with `@Type(EventAction.*)` qualifiers.

### 1.1 Listener Side — EventRessourceListener → @Observes

```java
// BEFORE: EventRessourceListener interface + manual registration
@ApplicationScoped
public class MyEventListener implements EventRessourceListener
{
    public void register( )
    {
        ResourceEventManager.register( this );
    }

    @Override
    public String getName( )
    {
        return "myEventListener";
    }

    @Override
    public void addedResource( ResourceEvent event )
    {
        // handle create
    }

    @Override
    public void updatedResource( ResourceEvent event )
    {
        // handle update
    }

    @Override
    public void deletedResource( ResourceEvent event )
    {
        // handle delete
    }
}

// AFTER: CDI @Observes — auto-discovered, no registration needed
@ApplicationScoped
public class MyEventListener
{
    public void addedResource( @Observes @Type( EventAction.CREATE ) ResourceEvent event )
    {
        // handle create
    }

    public void updatedResource( @Observes @Type( EventAction.UPDATE ) ResourceEvent event )
    {
        // handle update
    }

    public void deletedResource( @Observes @Type( EventAction.REMOVE ) ResourceEvent event )
    {
        // handle delete
    }
}
```

Key changes:
1. **Remove** `implements EventRessourceListener`
2. **Remove** `register()` method — CDI auto-discovers `@Observes` methods
3. **Remove** `getName()` method — no longer needed
4. **Add** `@Observes @Type(EventAction.XXX)` on each handler method parameter
5. **Remove** empty handler methods (e.g., `updatedResource` with empty body) — no need to observe events you don't handle
6. **Remove** imports: `EventRessourceListener`, `ResourceEventManager`
7. **Add** imports: `jakarta.enterprise.event.Observes`, `fr.paris.lutece.portal.service.event.EventAction`, `fr.paris.lutece.portal.service.event.Type`

### 1.2 Firing Side — fireXxx() → CDI event firing

```java
// BEFORE
ResourceEventManager.fireAddedResource( event );
ResourceEventManager.fireUpdatedResource( event );
ResourceEventManager.fireDeletedResource( event );

// AFTER
CDI.current( ).getBeanManager( ).getEvent( )
    .select( ResourceEvent.class, new TypeQualifier( EventAction.CREATE ) ).fire( event );

CDI.current( ).getBeanManager( ).getEvent( )
    .select( ResourceEvent.class, new TypeQualifier( EventAction.UPDATE ) ).fire( event );

CDI.current( ).getBeanManager( ).getEvent( )
    .select( ResourceEvent.class, new TypeQualifier( EventAction.REMOVE ) ).fire( event );
```

Required imports for the firing side:
```java
import fr.paris.lutece.portal.business.event.ResourceEvent;
import fr.paris.lutece.portal.service.event.EventAction;
import fr.paris.lutece.portal.service.event.Type.TypeQualifier;
import jakarta.enterprise.inject.spi.CDI;
```

**Tip for static utility classes** (Home-like classes with private constructor): Since `@Inject Event<ResourceEvent>` cannot be used in static context, use `CDI.current().getBeanManager().getEvent()` directly. Create a helper method to avoid repetition:

```java
private static void fireResourceEvent( int resourceId, String resourceType, EventAction action )
{
    ResourceEvent event = new ResourceEvent( );
    event.setIdResource( String.valueOf( resourceId ) );
    event.setTypeResource( resourceType );
    CDI.current( ).getBeanManager( ).getEvent( )
        .select( ResourceEvent.class, new TypeQualifier( action ) ).fire( event );
}
```

### 1.3 Plugin init() Cleanup

Remove any `ResourceEventManager.register()` calls from the plugin's `init()` method. CDI auto-discovers `@Observes` methods — no manual registration is needed.

```java
// BEFORE
@Override
public void init( )
{
    CDI.current( ).select( MyCacheService.class ).get( );
    CDI.current( ).select( MyEventListener.class ).get( ).register( );  // REMOVE this line
    FileImagePublicService.init( );
}

// AFTER
@Override
public void init( )
{
    CDI.current( ).select( MyCacheService.class ).get( );
    FileImagePublicService.init( );
}
```

Also remove the import for the listener class if it was only used in `init()`.

### 1.4 Action Mapping Table

| v7 method | EventAction | @Observes qualifier |
|-----------|------------|-------------------|
| `ResourceEventManager.fireAddedResource()` | `EventAction.CREATE` | `@Type(EventAction.CREATE)` |
| `ResourceEventManager.fireUpdatedResource()` | `EventAction.UPDATE` | `@Type(EventAction.UPDATE)` |
| `ResourceEventManager.fireDeletedResource()` | `EventAction.REMOVE` | `@Type(EventAction.REMOVE)` |

---

## 2. Spring Listener Interface → CDI @Observes

Replace custom Spring listener interfaces (discovered via `SpringContextService.getBeansOfType()`) with CDI `@Observes`:

```java
// BEFORE: custom listener interface + Spring discovery
public interface MyEventListener {
    void processEvent(MyEvent event);
}

// Firing:
for (MyListener l : SpringContextService.getBeansOfType(MyListener.class)) {
    l.onEvent(event);
}

// AFTER: CDI observer
@ApplicationScoped
public class MyEventObserver {
    public void processEvent(@Observes MyEvent event) {
        // Handle event
    }
}

// Firing:
CDI.current().getBeanManager().getEvent().fire(event);
```

---

## 3. CDI Events with TypeQualifier

For fine-grained event filtering on custom event types, use `@Type(EventAction.*)` qualifier:

```java
// Firing with qualifier
CDI.current().getBeanManager().getEvent()
    .select(MyEvent.class, new TypeQualifier(EventAction.CREATE))
    .fire(event);

// Observing with qualifier (synchronous)
public void onCreated(@Observes @Type(EventAction.CREATE) MyEvent event) { ... }

// Observing with qualifier (asynchronous)
public void onCreated(@ObservesAsync @Type(EventAction.CREATE) MyEvent event) { ... }
```

| Action | EventAction |
|--------|------------|
| Create | `EventAction.CREATE` |
| Update | `EventAction.UPDATE` |
| Delete | `EventAction.REMOVE` |

Use `@ObservesAsync` for events that don't need to block the caller (e.g., indexation, notifications). Use `@Observes` for events that must complete before the caller continues.

---

## 4. LuteceUserEventManager Migration

`LuteceUserEventManager` (extends `AbstractEventManager`) is `@Deprecated(forRemoval = true)` in lutece-core v8.

```java
// BEFORE
LuteceUserEventManager.getInstance().register("myListener", event -> handleEvent(event));
LuteceUserEventManager.getInstance().notifyListeners(new LuteceUserEvent(user, EventType.LOGIN_SUCCESSFUL));

// AFTER — Listener: CDI observer
@ApplicationScoped
public class MyUserEventListener
{
    public void onUserEvent( @Observes LuteceUserEvent event )
    {
        if ( LuteceUserEvent.EventType.LOGIN_SUCCESSFUL.equals( event.getEventType( ) ) )
        {
            handleEvent( event );
        }
    }
}

// AFTER — Firing:
CDI.current( ).getBeanManager( ).getEvent( ).fire( new LuteceUserEvent( user, EventType.LOGIN_SUCCESSFUL ) );
```

---

## 5. QueryListenersService Migration

`QueryListenersService` is `@Deprecated(forRemoval = true)` in lutece-core v8. Plugins implementing `QueryEventListener` need migration.

```java
// BEFORE
public class MyQueryListener implements QueryEventListener
{
    public MyQueryListener( )
    {
        QueryListenersService.getInstance( ).registerQueryListener( this );
    }
    @Override
    public void processQueryEvent( QueryEvent event ) { ... }
}

// AFTER
@ApplicationScoped
public class MyQueryListener
{
    public void processQueryEvent( @Observes QueryEvent event )
    {
        // handle query event
    }
}
```

---

## Reference

See the forms plugin for a complete v8 event implementation:
- **Listener**: `~/.lutece-references/lutece-form-plugin-forms/src/java/fr/paris/lutece/plugins/forms/service/listener/FormResponseEventListener.java`
- **Firing**: `~/.lutece-references/lutece-form-plugin-forms/src/java/fr/paris/lutece/plugins/forms/service/FormService.java` (search for `fireAsync`)
