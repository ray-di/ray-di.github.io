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

## Cache injector

The injector is serializable.
It also boosts the performance.

```php

// save
$injector = new Injector(new ListerModule);
$cachedInjector = serialize($injector);

// load
$injector = unserialize($cachedInjector);
$lister = $injector->getInstance(ListerInterface::class);

```

## CachedInjectorFactory

The `CachedInejctorFactory` can be used in a hybrid of the two injectors to achieve the best performance in both development and production.

The injector is able to inject singleton objects **beyond the request**, greatly increasing the speed of testing. Successive PDO connections also do not run out of connection resources in the test.

See [CachedInjectorFactory](https://github.com/ray-di/Ray.Compiler/issues/75) for more information.

## Attribute Reader

When not using Doctrine annotations, you can improve performance during development by using only PHP8 attribute readers.

Register it as an autoloader in the `composer.json` 

```json
  "autoload": {
    "files": [
      "vendor/ray/aop/attribute_reader.php"
    ]
```

Or set in bootstrap script.

```php
declare(strict_types=1);

use Koriym\Attributes\AttributeReader;
use Ray\ServiceLocator\ServiceLocator;

ServiceLocator::setReader(new AttributeReader());
```
