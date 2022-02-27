---
layout: docs-en
title: ModulesShouldBeFastAndSideEffectFree
category: Manual
permalink: /manuals/1.0/en/bp/modules_should_be_fast_and_side_effect_free.html
---
# Modules should be fast and side-effect free

Rather than using an external XML file for configuration, Guice modules are
written using regular Java code. Java is familiar, works with your IDE, and
survives refactoring.

But the full power of the Java language comes at a cost: it's easy to do _too
much_ in a module. It's tempting to connect to a database connection or to start
an HTTP server in your Guice module. Don't do this! Doing heavy-lifting in a
module poses problems:

*   **Modules start up, but they don't shut down.** Should you open a database
    connection in your module, you won't have any hook to close it.
*   **Modules should be tested.** If a module opens a database as a course of
    execution, it becomes difficult to write unit tests for it.
*   **Modules can be overridden.** Guice modules support
    [overrides](http://google.github.io/guice/api-docs/latest/javadoc/com/google/inject/util/Modules.html#override\(com.google.inject.Module...\)),
    allowing a production service to be substituted with a lightweight or test
    one. When the production service is created as a part of module execution,
    such overrides are ineffective.

Rather than doing work in the module itself, define an interface that can do the
work at the proper level of abstraction. In our applications we use this
interface:

```java
public interface Service {
  /**
   * Starts the service. This method blocks until the service has completely started.
   */
  void start() throws Exception;

  /**
   * Stops the service. This method blocks until the service has completely shut down.
   */
  void stop();
}
```

After creating the Injector, we finish bootstrapping our application by starting
its services. We also add shutdown hooks to cleanly release resources when the
application is stopped.

```java
  public static void main(String[] args) throws Exception {
    Injector injector = Guice.createInjector(
        new DatabaseModule(),
        new WebserverModule(),
        ...
    );

    Service databaseConnectionPool = injector.getInstance(
        Key.get(Service.class, DatabaseService.class));
    databaseConnectionPool.start();
    addShutdownHook(databaseConnectionPool);

    Service webserver = injector.getInstance(
        Key.get(Service.class, WebserverService.class));
    webserver.start();
    addShutdownHook(webserver);
  }
```
