---
layout: docs-en
title: DontReuseAnnotations
category: Manual
permalink: /manuals/1.0/en/bp/dont_reuse_annotations.html
---
# Don't reuse binding annotations (aka `#[Qualifiers]`)

Sometimes, of course, it makes sense to bind some highly-related bindings with
the same annotations. E.g. `#[ServerName]`

That said, most binding annotations should only qualify one binding. And you
should definitely not reuse a binding annotation for *unrelated* bindings.

When in doubt, don't reuse annotations: creating one is straightfoward!

To avoid some boilerplate, sometimes it makes sense to use annotation parameters
to create distinct annotation instances from a single declaration. For example:

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

You can then use `#[MyThing(FOO)]`, `#[MyThing(BAR)]`, and `#[MyThing(BAZ)]` rather
than defining each of them as separate annotation types.
