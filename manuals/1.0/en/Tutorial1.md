---
layout: docs-en
title: Tutorial1
category: Manual
permalink: /manuals/1.0/en/tutorial1.html
---
# Ray.Di Tutorial 1
In this tutorial, you will learn the basics of the DI pattern and how to start a Ray.Di project. We will change from a non-di code to a manual DI code, then to a code using Ray.Di to add functionality.

## Preparation
Create a project for the tutorial.



```
mkdir ray-tutorial
cd ray-tutorial
composer self-update
composer init --name=ray/tutorial --require=ray/di:^2 --autoload=src -n
composer update
```

Create `src/Greeter.php`.
A program that greets `$users` one after another.

```php
<?php
namespace Ray\Tutorial;

class Greeter
{
    public function sayHello(): void
    {
        $users = ['DI', 'AOP', 'REST'];
        foreach ($users as $user) {
            echo 'Hello ' . $user . '!' . PHP_EOL;
        }
    }
}
```

Prepare a script in `bin/run.php` to run it.

```php
<?php
use Ray\Tutorial\Greeter;

require dirname(__DIR__) . '/vendor/autoload.php';

(new Greeter)->sayHello();
```

Let's run it.

```php
php bin/run.php

Hello DI!
Hello AOP!
Hello REST!
```

## Dependency pull

Consider making `$users` variable.

For example, a global variable?

```diff
-       $users = ['DI', 'AOP', 'REST'];
+       $users = $GLOBALS['users'];
```

Too wild. Let's consider other ways.

```php
define("USERS", ['DI', 'AOP', 'REST']);

$users = USERS;
```
```php
class User
{
    public const NAMES = ['DI', 'AOP', 'REST'];
};

$users = User::NAMES;
```

```php
$users = Config::get('users')
```

It is getting the necessary dependencies from the outside, It's "dependency pull" and in the end it is the same global as the `$GLOBALS` variable. It makes the coupling between objects tight and difficult to test.

## Dependency Injection

The DI pattern is one in which dependencies are injected from other sources, rather than being obtained from the code itself.

```php
class Greeter
{
    public function __construct(
        private readonly Users $users
    ) {}

    public function sayHello(): void
    {
        foreach ($this->users as $user) {
            echo 'Hello ' . $user . '!' . PHP_EOL;
        }
    }
}
```

Inject not only the data you need, but also the output as a separate service.

```diff
    public function __construct(
-       private readonly Users $users
+       private readonly Users $users,
+       private readonly PrinterInterface $printer
    ) {}

    public function sayHello()
    {
        foreach ($this->users as $user) {
-            echo 'Hello ' . $user . '!' . PHP_EOL;
+            ($this->printer)($user);
        }
    }
```

Create the following classes

`src/Users.php`

```php
<?php
namespace Ray\Tutorial;

use ArrayObject;

final class Users extends ArrayObject
{
}
```

`src/PrinterInterface.php`

```php
<?php
namespace Ray\Tutorial;

interface PrinterInterface
{
    public function __invoke(string $user): void;
}
```

`src/Printer.php`

```php
<?php
namespace Ray\Tutorial;

class Printer implements PrinterInterface
{
    public function __invoke(string $user): void
    {
        echo 'Hello ' . $user . '!' . PHP_EOL;
    }
}
```

`src/GreeterInterface.php`

```php
<?php
namespace Ray\Tutorial;

interface GreeterInterface
{
    public function sayHello(): void;
}
```

`src/CleanGreeter.php`

```php
<?php
namespace Ray\Tutorial;

class CleanGreeter implements GreeterInterface
{
    public function __construct(
        private readonly Users $users,
        private readonly PrinterInterface $printer
    ) {}

    public function sayHello(): void
    {
        foreach ($this->users as $user) {
            ($this->printer)($user);
        }
    }
}
```

## Manual DI

Create and run a script `bin/run_di.php` to do this.

```php
<?php

use Ray\Tutorial\CleanGreeter;
use Ray\Tutorial\Printer;
use Ray\Tutorial\Users;

require dirname(__DIR__) . '/vendor/autoload.php';

$greeter = new CleanGreeter(
    new Users(['DI', 'AOP', 'REST']),
    new Printer
);

$greeter->sayHello();
```

While the number of files may seem to increase in number and overall complexity, the individual scripts are so simple that it is difficult to make them any simpler. Each class has only one responsibility [^srp], relies on abstractions rather than implementations [^dip], and is easy to test, extend, and reuse.

[^srp]: [Single Responsibility Principle (SRP)](https://ja.wikipedia.org/wiki/SOLID)
[^dip]: [Dependency Inversion Principle (DIP)](https://ja.wikipedia.org/wiki/%E4%BE%9D%E5%AD%98%E6%80%A7%E9%80%86%E8%BB%A2%E3%81%AE%E5%8E%9F%E5%89%87)

### Compile Time and Runtime

Code under `bin/` constitutes a dependency at **compile time**, while code under `src/` is executed at **run time**. PHP is a scripting language, but this distinction between compile time and run time can be considered.

### Constructor Injection

DI code passes dependencies externally and receives them in the constructor.

```php
$instance = new A(
    new B,
    new C(
        new D(
            new E, new F, new G
        )
    )
);
```

B and C needed to generate A are passed to the constructor from outside A (without being obtained from inside A); D to generate C, E,F,G to generate D... and dependencies require other dependencies, and objects generate an object graph [^og] containing dependent objects.

As the size of the project grows, manual DI using such factory code becomes a reality with problems such as deep nested dependency resolution, instance management such as singletons, reusability, and maintainability. Ray.Di solves that dependency problem.

[^og]: "In computer science, object-oriented applications have a complex network of interrelated objects. Objects are connected to each other either by being owned by one object or by containing other objects (or their references). This object net is called an object graph." [Object Graph](https://en.wikipedia.org/wiki/Object_graph)

### Module

A module is a set of bindings. There are several types of binding, but here we will use the most basic, link binding, which binds an interface to a class, and instance binding, which binds to an actual instance, such as a value object.

Create `src/AppModule.php`.

```php
<?php
namespace Ray\Tutorial;

use Ray\Di\AbstractModule;

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(Users::class)->toInstance(new Users(['DI', 'AOP', 'REST']));
        $this->bind(PrinterInterface::class)->to(Printer::class);
        $this->bind(GreeterInterface::class)->to(CleanGreeter::class);
    }
}
```

Create and run `bin/run_di.php` to run.

```php
<?php

use Ray\Di\Injector;
use Ray\Tutorial\AppModule;
use Ray\Tutorial\GreeterInterface;

require dirname(__DIR__) . '/vendor/autoload.php';

$module = new AppModule();
$injector = new Injector($module);
$greeter = $injector->getInstance(GreeterInterface::class);
$greeter->sayHello();
```

Did it work? If something is wrong, please compare it with [tutorial1](https://github.com/ray-di/tutorial1/tree/master/src).

## Dependency Replacement

Sometimes you want to change the bindings depending on the context of execution, such as only for unit testing, only for development, and so on.

For example, suppose you have a test-only binding `src/TestModule.php`.

```php
<?php

namespace Ray\Tutorial;

use Ray\Di\AbstractModule;

final class TestModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(Users::class)->toInstance(new Users(['TEST1', 'TEST2']));
    }
}
```

Modify the `bin/run_di.php` script to override this binding.

```diff
use Ray\Tutorial\AppModule;
+use Ray\Tutorial\TestModule;
use Ray\Tutorial\GreeterInterface;

require dirname(__DIR__) . '/vendor/autoload.php';

$module = new AppModule();
+$module->override(new TestModule());
```

Let's run it.

```
Hello TEST1!
Hello TEST2!
```

## Dependency on Dependency

Next, the greeting message, which is now fixed and retained in the Printer, is also changed to be injected to support multiple languages.

Create `src/IntlPrinter.php`.

```php
<?php
namespace Ray\Tutorial;

use Ray\Di\Di\Named;

class IntlPrinter implements PrinterInterface
{
    public function __construct(
        #[Message] private string $message
    ){}

    public function __invoke(string $user): void
    {
        printf($this->message, $user);
    }
}
```

The constructor takes a message string for the greeting, but to identify this bundle [attribute bundle](https://ray-di.github.io/manuals/1.0/ja/binding_attributes.html) for the `#[Message]`attribute, `src/Message.php`.

```php
<?php
namespace Ray\Tutorial;

use Attribute;
use Ray\Di\Di\Qualifier;

#[Attribute, Qualifier]
class Message
{
}
```

Change the binding.

```diff
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(Users::class)->toInstance(new Users(['DI', 'AOP', 'REST']));
-       $this->bind(PrinterInterface::class)->to(Printer::class);
+       $this->bind(PrinterInterface::class)->to(IntlPrinter::class);
+       $this->bind()->annotatedWith(Message::class)->toInstance('Hello %s!' . PHP_EOL);
        $this->bind(GreeterInterface::class)->to(CleanGreeter::class);
    }
}
```

Run it to make sure it does not change.

Then try the error. Comment out the `Message::class` binding in the `configure()` method.

```diff
-        $this->bind()->annotatedWith(Message::class)->toInstance('Hello %s!' . PHP_EOL);
+        // $this->bind()->annotatedWith(Message::class)->toInstance('Hello %s!' . PHP_EOL);
```

This means that Ray.Di does not know what to inject into the dependencies attributed as `#[Message]`.

When I run it, I get the following error

```
PHP Fatal error:  Uncaught exception 'Ray\Di\Exception\Unbound' with message '-Ray\Tutorial\Message'
- dependency '' with name 'Ray\Tutorial\Message' used in /tmp/tutorial/src/IntlPrinter.php:8 ($message)
- dependency 'Ray\Tutorial\PrinterInterface' with name '' /tmp/tutorial/src/CleanGreeter.php:6 ($printer)
```

This is an error that `$message` in `IntlPrinter.php:8` cannot resolve its dependency, so `$printer` in `CleanGreeter.php:6` which depends on it also cannot resolve its dependency and the injection failed. Thus, when a dependency of a dependency cannot be resolved, the nesting of that dependency is also displayed.

Finally, let's create the following bundle as `src/SpanishModule.php` and overwrite it in the same way as TestModule.

```php
<?php
namespace Ray\Tutorial;

use Ray\Di\AbstractModule;

class SpanishModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind()->annotatedWith(Message::class)->toInstance('¡Hola %s!' . PHP_EOL);
    }
}
```

```diff
use Ray\Tutorial\AppModule;
-use Ray\Tutorial\TestModule;
+use Ray\Tutorial\SpanishModule;
use Ray\Tutorial\GreeterInterface;

require dirname(__DIR__) . '/vendor/autoload.php';

$module = new AppModule();
-$module->override(new TestModule());
+$module->override(new SpanishModule());
```

Have you changed to the Spanish greeting as follows?

```
¡Hola DI!
¡Hola AOP!
¡Hola REST!
```

## Summary

We have seen the basics of the DI pattern and Ray.Di.
Dependencies are not acquired, but injected recursively from the outside, creating an object graph.

At compile time, the relationship building between objects through dependency binding is complete, and at the runtime, the running code depends only on the interface. By following the DI pattern, the SRP principle [^srp] and the DIP principle [^dip] can be followed by nature.

The responsibility of securing dependencies has been removed from the code, making it loosely coupled and simple. The code is stable yet flexible, open to extensions but closed to modifications. [^ocp]

[^ocp]: [OCP](https://ja.wikipedia.org/wiki/%E9%96%8B%E6%94%BE/%E9%96%89%E9%8E%96%E5%8E%9F%E5%89%87)

---
