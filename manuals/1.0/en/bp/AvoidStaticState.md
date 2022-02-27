---
layout: docs-en
title: AvoidStaticState
category: Manual
permalink: /manuals/1.0/en/bp/avoid_static_state.html
---
# Avoid static state

Static state and testability are enemies. Your tests should be fast and free of
side-effects. But non-constant values held by static fields are a pain to
manage. It's tricky to reliably tear down static singletons that are mocked by
tests, and this interferes with other tests.

`requestStaticInjection()` is a *crutch*. Guice includes this API to ease
migration from a statically-configured application to a dependency-injected one.
New applications developed with Guice should not use this API.

Although *static state* is bad, there's nothing wrong with the static *keyword*.
Static classes are okay (preferred even!) and for pure functions (sorting, math,
etc.), static is just fine.
