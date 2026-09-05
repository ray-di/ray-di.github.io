---
layout: docs-en
title: Performance boost
category: Manual
permalink: /manuals/1.0/en/performance_boost.html
---
# Performance boost

Injectors that know all dependency bindings can compile simple PHP factory code from those bindings and provide the best performance. Injectors that don't use anonymous functions for bindings can be serialized, which can improve performance.

In any case, there is no need to initialize the container for every request in production.

## Script injector

`ScriptInjector` generates raw factory code for better performance and to clarify how the instance is created.

```php

use Ray\Di\ScriptInjector;
use Ray\Compiler\DiCompiler;
use Ray\Compiler\Exception\NotCompiled;

try {
    $injector = new ScriptInjector($tmpDir);
    $instance = $injector->getInstance(ListerInterface::class);
} catch (NotCompiled $e) {
    $compiler = new DiCompiler(new ListerModule, $tmpDir);
    $compiler->compile();
    $instance = $injector->getInstance(ListerInterface::class);
}
```
Once an instance has been created, You can view the generated factory files in `$tmpDir`

## Warming up singletons on coroutine runtime servers

The reflective `Injector` keeps its resolution state — the chain of indexes being resolved and the current injection point — for the whole process. When a coroutine suspends inside a provider (waiting for a connection from a pool, say), another coroutine enters that state and a request fails with a `CircularDependency` whose chain is not circular. Coroutine servers run on the compiled injector.

Compilation also generates `singletons.json`, a list of singleton bindings that can be instantiated without caller context. `CompiledInjector::warmup()` instantiates them all eagerly:

```php
use Ray\Compiler\CompiledInjector;

$injector = new CompiledInjector($tmpDir);
$injector->warmup(); // call once at worker startup
```

In a long-lived or coroutine runtime (Swoole, OpenSwoole), lazy singleton initialization can race when construction yields, producing duplicate instances. Calling `warmup()` before concurrent request handling begins removes that window. This is only needed for runtimes that handle requests concurrently within one process. Standard PHP-FPM workers process one request at a time, so no warm-up is required there.

An injection-point-dependent singleton would capture whichever consumer constructs it first, making the shared instance order-dependent. Such bindings must use prototype scope or remove the injection-point dependency.

- Compilation throws `SingletonRequiresInjectionPoint` for an injection-point-dependent singleton.
- `warmup()` throws `SingletonsFileNotFound` when `$tmpDir` holds no `singletons.json`. Compile again with the current Ray.Compiler.

## Cache injector

The injector is serializable, so the container can be preserved across requests.

```php

// save
$injector = new Injector(new ListerModule);
$cachedInjector = serialize($injector);

// load
$injector = unserialize($cachedInjector);
$lister = $injector->getInstance(ListerInterface::class);

```

However, `unserialize()` reconstructs the container on every process, and the cost scales with the binding set. On one production application with ~600 compiled scripts, a cold php-fpm request paid ~29 ms for the serialized injector and ~5 ms for the compiled one (about 6×); in a warm worker the gap shrinks to a few milliseconds. See [Performance & OPcache](https://github.com/ray-di/Ray.Compiler/blob/1.x/docs/performance.md) for the setup.
