---
layout: docs-en
title: Builtin Bindings
category: Manual
permalink: /manuals/1.0/en/builtin_bindings.html
---
# Built-in Bindings

_More bindings that you can use_

**NOTE**: It's very rare that you'd need to use those built-in bindings.

## The Injector

In framework code, sometimes you don't know the type you need until runtime. In
this rare case you should inject the injector. Code that injects the injector
does not self-document its dependencies, so this approach should be done
sparingly.

## Providers

For every type Ray.Di knows about, it can also inject a Provider of that type.
[Injecting Providers](injecting_provider.html) describes this in detail.

## Multi-bundling

Multi bindinga allows multiple implementations to be injected for a type.
It is explained in detail in [MultiBindings](multi_bindings.html).
