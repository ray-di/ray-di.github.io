# Organize modules by feature, not by class type

Group bindings into features. Ideally it should be possible to enable/disable an
entire working feature by simply installing or not installing a single module in
the injector.

For example, don't just make a `FiltersModule` that has bindings for all the
classes that implement `Filter` in it, and a `GraphsModule` that has all the
classes that implement `Graph`, etc. Instead, try to organize modules by
feature, for example an `AuthenticationModule` that authenticates requests made
to your server, or a `FooBackendModule` that lets your server make requests to
the Foo backend.

This principle is also known as "organize modules vertically, not horizontally".
