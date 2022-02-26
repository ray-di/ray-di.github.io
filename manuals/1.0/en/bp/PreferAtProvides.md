# Prefer `@Provides` methods over the binding DSL

Many usages of the DSL are unclear to readers who are not Guice experts. Things
like scoped bindings behave in ways that are easy to misunderstand where the
`@Provides` implementation is more clear.

Consider this example:

```java
bind(Foo.class).to(FooImpl.class).in(Singleton.class);
bind(Foo2.class).to(FooImpl.class).in(Singleton.class);
```

Will `Foo` and `Foo2` bind to the same instance of `FooImpl`? That depends on
whether `FooImpl` is annotated with `@Singleton`, which readers can't discern
from looking at the DSL. If it is annotated then there will be one common
instance, if not there will be two separate instances, despite the use of
`Singleton` scopes.

Binding generic types can similarly be opaque and confusing when expressed with
the DSL, but are very clear in `@Provides` methods.

That said, there are times where the DSL version is more readable than the
equivalent providers. For instance a simple `bind(Foo.class).to(FooImpl.class);`
statement is less boilerplate than the equivalent `@Provides` method.
Readability and clarity should be the primary concern when choosing between
different approaches.
