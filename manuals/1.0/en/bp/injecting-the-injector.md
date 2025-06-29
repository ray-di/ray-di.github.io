---
layout: docs-en
title: InjectingTheInjector
category: Manual
permalink: /manuals/1.0/en/bp/injecting-the-injector.html
---
# Use the Injector as little as possible (preferably only once)

Ray.Di has a [built-in](../built-in-bindings.html) binding for the `Injector` but it should be used sparsely.

Don't pass injectors into other injected objects through the constructor (which is also called "injecting the injector"). You should declare your dependencies statically.

By injecting the injector, Ray.Di will not know in advance if the dependency can be resolved.
This is because you can get instances directly from the injector.
If the dependencies are not set up correctly and the injector is not injected, the dependency resolution failure can be detected in the compilation of Ray.Di.
However, if you are injecting an injector, Ray.Di may raise an `Unbound` exception at runtime (when the code executes `getInstance()` lazily) and the dependency resolution may fail.
