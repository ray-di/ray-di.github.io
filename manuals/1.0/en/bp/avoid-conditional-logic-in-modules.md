---
layout: docs-en
title: AvoidConditionalLogicInModules
category: Manual
permalink: /manuals/1.0/en/bp/avoid-conditional-logic-in-modules.html
---
# Avoid conditional logic in modules

It’s tempting to create modules that have moving parts and can be configured to
operate differently for different environments:

```php
class FooModule extends AbstractModule
{
  public function __construct(
    private readonly ?string $fooServer
  }{}

  protected function configure(): void
  {
    if ($this->fooServer != null) {
        $this->bind(String::class)->annotatedWith(ServerName::class)->toInstance($this->fooServer);
        $this->bind(FooService::class)->to(RemoteFooService::class);
    } else {
        $this->bind(FooService::class)->to(InMemoryFooService::class);
    }
  }
}
```

Conditional logic in itself isn't too bad. But problems arise when
configurations are untested. In this example, the`InMemoryFooService` is used
for development and `RemoteFooService` is used in production. But without
testing this specific case, it's impossible to be sure that `RemoteFooService`
works in the integrated application.

To overcome this, **minimize the number of distinct configurations** in your
applications. If you split production and development into distinct modules, it
is easier to be sure that the entire production codepath is tested. In this
case, we split `FooModule` into `RemoteFooModule` and `InMemoryFooModule`. This
also prevents production classes from having a compile-time dependency on test
code.

Another, related, issue with the example above: sometimes there's a binding for
`#[ServerName]`, and sometimes that binding is not there. You should avoid
sometimes binding a key, and other times not.
