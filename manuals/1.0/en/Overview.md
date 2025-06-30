---
layout: docs-en
title: Overview
category: Manual
permalink: /manuals/1.0/en/index.html
---

<img src="/images/logo.svg" alt="Ray.Di logo" width="200" height="200">

# Overview

Ray.Di is a dependency injection (DI) framework for PHP. It automatically resolves object dependencies and enables flexible object graph construction according to the context.

## Core Features

### Dependency Resolution at Compile Time

- Resolves dependencies by describing overall rules rather than individual object assembly (autowiring)
- Detects dependency issues before execution
- Minimizes runtime overhead through code generation

### Flexible Object Graph Construction

- Enables various contexts through the combination of independent modules
- Allows dependency resolution according to the injected object; for example, changing dependencies based on the target method's attributes or the object's state (CDI: Contexts and Dependency Injection)
- Injects different implementations of the same interface using `Qualifier`
- Supports injection of lazily instantiated objects

### Explicit Dependency Description

- Describes dependency generation using raw PHP code
- Utilizes attributes for self-documented dependency definitions
- Separates cross-cutting concerns through integration with AOP

## Stability and Reliability

Since the release of version 2.0 in 2015, Ray.Di has expanded its features along with the evolution of PHP while maintaining backward compatibility by following semantic versioning.

## Google Guice and Ray.Di

Ray.Di is a PHP DI framework inspired by [Google Guice](https://github.com/google/guice). Based on the proven API design of Google Guice, it aims for PHP-like evolution. Most of the documents on this site are also quoted from Google Guice.

---

Using dependency injection offers many benefits, but doing it manually requires writing a lot of boilerplate code. Ray.Di is a framework that allows you to use dependency injection without writing such cumbersome code. For more details, please see the [Motivation](motivation.html) page.

In short, Ray.Di eliminates the need to use factories or `new` in your PHP code. While you may still need to write factories, your code does not directly depend on them. Your code becomes easier to modify, unit test, and reuse in other contexts.
