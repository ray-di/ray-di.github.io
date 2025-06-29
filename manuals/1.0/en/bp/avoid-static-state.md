---
layout: docs-en
title: AvoidStaticState
category: Manual
permalink: /manuals/1.0/en/bp/avoid-static-state.html
---
# Avoid static state

Static state and testability are enemies. Your tests should be fast and free of
side-effects. But non-constant values held by static fields are a pain to
manage. It's tricky to reliably tear down static singletons that are mocked by
tests, and this interferes with other tests.

Although *static state* is bad, there's nothing wrong with the static *keyword*.
Static classes are okay (preferred even!) and for pure functions (sorting, math,
etc.), static is just fine.
