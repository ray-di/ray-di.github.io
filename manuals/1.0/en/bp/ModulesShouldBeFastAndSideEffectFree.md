---
layout: docs-en
title: ModulesShouldBeFastAndSideEffectFree
category: Manual
permalink: /manuals/1.0/en/bp/modules_should_be_fast_and_side_effect_free.html
---
# Modules should be fast and side-effect free

Rather than using an external XML file for configuration, Ray.Di modules are
written using regular PHP code. PHP is familiar, works with your IDE, and
survives refactoring.

But the full power of the PHP language comes at a cost: it's easy to do _too
much_ in a module. It's tempting to connect to a database connection or to start
an HTTP server in your Ray.Di module. Don't do this! Doing heavy-lifting in a
module poses problems:

*   **Modules start up, but they don't shut down.** Should you open a database
    connection in your module, you won't have any hook to close it.
*   **Modules should be tested.** If a module opens a database as a course of
    execution, it becomes difficult to write unit tests for it.
*   **Modules can be overridden.** Ray.Di modules support
    `overrides`,
    allowing a production service to be substituted with a lightweight or test
    one. When the production service is created as a part of module execution,
    such overrides are ineffective.

Rather than doing work in the module itself, define an interface that can do the
work at the proper level of abstraction. In our applications we use this
interface:

```php
interface ServiceInterface
{
    /**
    * Starts the service. This method blocks until the service has completely started.
    */
    public function start(): void;
    
    /**
    * Stops the service. This method blocks until the service has completely shut down.
    */
    public function stop(): void;
}
```

After creating the Injector, we finish bootstrapping our application by starting
its services. We also add shutdown hooks to cleanly release resources when the
application is stopped.

```php
class Main
{
    public function __invoke()
        $injector = new Injector([
            new DatabaseModule(),
            new WebserverModule(),
            // ..
        ]);
        $databaseConnectionPool = $injector->getInstance(DatabaseService.class, Service.class);
        $databaseConnectionPool->start();
        $this->addShutdownHook($databaseConnectionPool);

        $webserver = $injector->getInstance(WebserverService.class, Service.class);
        $webserver->start();
        $this->addShutdownHook($webserver);
    );
}
```
