---
layout: docs-en
title: Don't reuse binding annotations
category: Manual
permalink: /manuals/1.0/en/bp/dont_reuse_annotations.html
---
# Don't reuse binding annotations (aka `@Qualifiers`)

Sometimes, of course, it makes sense to bind some highly-related bindings with
the same annotations. E.g. `@ServerName String` and `@ServerName CharSequence`.

That said, most binding annotations should only qualify one binding. And you
should definitely not reuse a binding annotation for *unrelated* bindings.

When in doubt, don't reuse annotations: creating one is straightfoward!

To avoid some boilerplate, sometimes it makes sense to use annotation parameters
to create distinct annotation instances from a single declaration. For example:

```java
enum Thing { FOO, BAR, BAZ }

@Qualifier
@Retention(RetentionPolicy.RUNTIME)
@interface MyThing {
  Thing value();
}
```

You can then use `@MyThing(FOO)`, `@MyThing(BAR)`, and `@MyThing(BAZ)` rather
than defining each of them as separate annotation types.

To construct `Annotation` object instances for parameterized annotations (e.g.
to use in constructing a `Key` object), you can use the
[auto annotation helper](https://github.com/google/auto/blob/master/value/userguide/howto.md#-use-autovalue-to-implement-an-annotation-type).
