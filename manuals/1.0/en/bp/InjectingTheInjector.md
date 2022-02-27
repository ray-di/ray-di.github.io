---
layout: docs-en
title: InjectingTheInjector
category: Manual
permalink: /manuals/1.0/en/bp/injecting_the_injector.html
---
# Use the Injector as little as possible (preferably only once)

Guice has a [built-in](BuiltInBindingsl) binding for the `Injector` but it should be used sparsely.

Don't pass injectors into other injected objects through the constructor (which is also called "injecting the injector"). You should declare your dependencies statically.

Injecting the injector makes it impossible for Ray.Di to know ahead-of-time that your Dependency Ray.Di is complete, because it lets folks get instances directly from the injector. So long as nothing injects the injector, then Ray.Di will 100% fail at `new Injector` time if any dependency isn't configured correctly. However, if something injects the injector, then Guice might fail at runtime (when the code lazily calls `getInstance()`) with missing bindings error.
