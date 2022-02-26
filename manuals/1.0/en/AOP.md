---
layout: docs-en
title: AOP
category: Manual
permalink: /manuals/1.0/en/aop.html
---
# Aspect Oriented Programing
_Intercepting methods with Guice_

To complement dependency injection, Guice supports *method interception*. This feature enables you to write code that is executed each time a _matching_ method is invoked. It's suited for cross cutting concerns ("aspects"), such as transactions, security and logging. Because interceptors divide a problem into aspects rather than objects, their use is called Aspect Oriented Programming (AOP).

Most developers won't write method interceptors directly; but they may see their use in integration libraries like [Warp Persist](http://www.wideplay.com/guicewebextensions2). Those that do will need to select the matching methods, create an interceptor, and configure it all in a module.

[Matcher](http://google.github.io/guice/api-docs/latest/javadoc/com/google/inject/matcher/Matcher.html) is a simple interface that either accepts or rejects a value. For Guice AOP, you need two matchers: one that defines which classes participate, and another for the methods of those classes. To make this easy, there's a [factory class](http://google.github.io/guice/api-docs/latest/javadoc/com/google/inject/matcher/Matchers.html) to satisfy the common scenarios.

[MethodInterceptors](http://aopalliance.sourceforge.net/doc/org/aopalliance/intercept/MethodInterceptor.html) are executed whenever a matching method is invoked. They have the opportunity to
inspect the call: the method, its arguments, and the receiving instance. They can perform their cross-cutting logic and then delegate to the underlying method. Finally, they may inspect the return value or exception and return. Since interceptors may be applied to many methods and will receive many calls, their implementation should be efficient and unintrusive.

## Example: Forbidding method calls on weekends

To illustrate how method interceptors work with Guice, we'll forbid calls to our pizza billing system on weekends. The delivery guys only work Monday thru Friday so we'll prevent pizza from being ordered when it can't be delivered! This example is structurally similar to use of AOP for authorization.

To mark select methods as weekdays-only, we define an annotation:

```php
#[Attribute(Attribute::TARGET_METHOD)]
final class NotOnWeekends
{
}
```

...and apply it to the methods that need to be intercepted:

```php
class BillingService implements BillingServiceInterface
{
    #[NotOnWeekends]
    public function chargeOrder(PizzaOrder $order, CreditCard $creditCard)
    {
```

Next, we define the interceptor by implementing the `MethodInterceptor` interface. When we need to call through to the underlying method, we do so by calling `$invocation->proceed()`:

```php

use Ray\Aop\MethodInterceptor;
use Ray\Aop\MethodInvocation;

class WeekendBlocker implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation)
    {
        $today = getdate();
        if ($today['weekday'][0] === 'S') {
            throw new \RuntimeException(
                $invocation->getMethod()->getName() . " not allowed on weekends!"
            );
        }
        return $invocation->proceed();
    }
}
```

Finally, we configure everything. In this case we match any class, but only the methods with our `#[NotOnWeekends]` attribute:

```php

use Ray\Di\AbstractModule;

class WeekendModule extends AbstractModule
{
    protected function configure()
    {
        $this->bind(BillingServiceInterface::class)->to(BillingService::class);
        $this->bindInterceptor(
            $this->matcher->any(),                           // any class
            $this->matcher->annotatedWith('NotOnWeekends'),  // #[NotOnWeekends] attributed method
            [WeekendBlocker::class]                          // apply WeekendBlocker interceptor
        );
    }
}

$injector = new Injector(new WeekendModule);
$billing = $injector->getInstance(BillingServiceInterface::class);
try {
    echo $billing->chargeOrder();
} catch (\RuntimeException $e) {
    echo $e->getMessage() . "\n";
    exit(1);
}
```
Putting it all together, (and waiting until Saturday), we see the method is intercepted and our order is rejected:

```php
RuntimeException: chargeOrder not allowed on weekends! in /apps/pizza/WeekendBlocker.php on line 14

Call Stack:
    0.0022     228296   1. {main}() /apps/pizza/main.php:0
    0.0054     317424   2. Ray\Aop\Weaver->chargeOrder() /apps/pizza/main.php:14
    0.0054     317608   3. Ray\Aop\Weaver->__call() /libs/Ray.Aop/src/Weaver.php:14
    0.0055     318384   4. Ray\Aop\ReflectiveMethodInvocation->proceed() /libs/Ray.Aop/src/Weaver.php:68
    0.0056     318784   5. Ray\Aop\Sample\WeekendBlocker->invoke() /libs/Ray.Aop/src/ReflectiveMethodInvocation.php:65
```

To disable the interceptor, bind NullInterceptor.

```php
use Ray\Aop\NullInterceptor;

protected function configure()
{
    // ...
    $this->bind(LoggerInterface::class)->to(NullInterceptor::class);
}
```


## Limitations

Behind the scenes, method interception is implemented by generating bytecode at
runtime. Guice dynamically creates a subclass that applies interceptors by
overriding methods. If you are on a platform that doesn't support bytecode
generation (such as Android), you should use
[Guice without AOP support](OptionalAOP).

This approach imposes limits on what classes and methods can be intercepted:

*   Classes must be public or package-private.
*   Classes must be non-final
*   Methods must be public, package-private or protected
*   Methods must be non-final
*   Instances must be created by Guice by an `@Inject`-annotated or no-argument
    constructor. It is not possible to use method interception on instances that
    aren't constructed by Guice.

## AOP Alliance

The method interceptor API implemented by Guice is a part of a public
specification called [AOP Alliance](http://aopalliance.sourceforge.net/). This
makes it possible to use the same interceptors across a variety of frameworks.
