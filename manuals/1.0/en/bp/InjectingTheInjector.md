# Use the Injector as little as possible (preferably only once)

Guice has a [built-in](BuiltInBindings) binding for the `Injector` but it should
be used sparsely.

Don't pass injectors into other injected objects through the constructor (which
is also called "injecting the injector"). You should declare your dependencies
statically.

Injecting the injector makes it impossible for Guice to know ahead-of-time that
your Dependency Graph is complete, because it lets folks get instances directly
from the injector. So long as nothing injects the injector, then Guice will 100%
fail at `Guice.createInjector` time if any dependency isn't configured
correctly. However, if something injects the injector, then Guice might fail at
runtime (when the code lazily calls `injector.getInstance`) with missing
bindings error.
