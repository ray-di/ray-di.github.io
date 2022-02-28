---
layout: docs-en
title: DontReuseAttributes
category: Manual
permalink: /manuals/1.0/en/bp/dont_reuse_annotations.html
---
# Don't reuse binding attribute (aka `#[Attribute]`)

Sometimes, of course, it makes sense to bind some highly-related bindings with the same attributes. E.g. `#[ServerName]`

That said, most binding attributes should only qualify one binding. And you should definitely not reuse a binding attributes for *unrelated* bindings.

When in doubt, don't reuse attributes: creating one is straightfoward!

To avoid some boilerplate, sometimes it makes sense to use attribute parameters to create distinct annotation instances from a single declaration. For example:

```php
enum Thing
{
    case FOO;
    case BAR;
    case BAZ;
}

#[Attribute, \Ray\Di\Di\Qualifier]
final class MyThing
{
    public function __construct(
        public readonly Thing $value
    ) {}
}
```

You can then use `#[MyThing(Thing::FOO)]`, `#[MyThing(Thing::BAR)]`, and `#[MyThing(Thing::BAZ)]` rather than defining each of them as separate annotation types.
