---
layout: docs-ja
title: Injections
category: Manual
permalink: /manuals/1.0/ja/injections.html
---
# Injections
_How Ray.Di initializes your objects_

The dependency injection pattern separates behaviour from dependency resolution.
Rather than looking up dependencies directly or from factories, the pattern
recommends that dependencies are passed in. The process of setting dependencies
into an object is called *injection*.

## Constructor Injection

Constructor injection combines instantiation with injection. This constructor should accept class dependencies as parameters. Most constructors will then assign the parameters to properties. You do not need `#[Inject]` attribute in constructor.

```php
public function __construct(DbInterface $db)
{
    $this->db = $db;
}
```

## Setter Injection

Ray.Di can inject methods that have the `#[Inject]` attribute. Dependencies take the form of parameters, which the injector resolves before invoking the method. Injected methods may have any number of parameters, and the method name does not impact injection.

```php
use Ray\Di\Di\Inject;
```

```php
#[Inject]
public function setDb(DbInterface $db)
{
    $this->db = $db;
}
```

## Property Injection

Ray.Di does not support property injection.

## Assisted Injection

It is also possible to inject dependencies directly in the invoke method parameter(s). When doing this, add the dependency to the end of the arguments and add `#[Assisted]` to the parameter(s). You need `null` default for that parameter.

```php
use Ray\Di\Di\Assisted;
```

```php
public function doSomething(string $id, #[Assisted] DbInterface $db = null)
{
    $this->db = $db;
}
```

You can also provide dependency which depends on other dynamic parameter in method invocation. `MethodInvocationProvider` provides [MethodInvocation](https://github.com/ray-di/Ray.Aop/blob/2.x/src/MethodInvocation.php) object.

```php
class HorizontalScaleDbProvider implements ProviderInterface
{
    public function __construct(
        private readonly MethodInvocationProvider $invocationProvider
    ){}

    public function get()
    {
        $methodInvocation = $this->invocationProvider->get();
        [$id] = $methodInvocation->getArguments()->getArrayCopy();
        
        return UserDb::withId($id); // $id for database choice.
    }
}
```
