---
layout: docs-en
title: Untargeted Bindings
category: Manual
permalink: /manuals/1.0/en/untargeted-bindings.html
---
## Untargeted Bindings

You may create bindings without specifying a target. This is most useful for concrete classes. An untargetted binding informs the injector about a type, so it may prepare dependencies eagerly. Untargetted bindings have no -to- clause, like so:

```php
$this->bind(MyConcreteClass::class);
$this->bind(AnotherConcreteClass::class)->in(Scope::SINGLETON);
```

Note: Untargeted binding does not currently support the `annotatedWith()` clause.
