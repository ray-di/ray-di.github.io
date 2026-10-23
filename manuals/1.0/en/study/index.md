---
layout: docs-en
title: Ray.Di Study
category: Manual
permalink: /manuals/1.0/en/study.html
---

# Ray.Di Study: Practical Object-Oriented Design Patterns

This study teaches **which pattern solves which problem**. Using Ray.Di, you will deepen your practical understanding of SOLID principles and design patterns, and build the judgement to create maintainable and extensible architectures.

## Learning focus

- **From problem to pattern**: Solve problems such as tight coupling, bloated controllers, and mixed data access with the right pattern
- **Decision criteria**: Learn when to use a Factory, when to use a Strategy, and when to use a Repository
- **Practical SOLID**: Understand single responsibility, open/closed, and dependency inversion through real code
- **Architecture design**: Layer separation, separation of concerns, and module design
- **Compile-time decisions**: Replace runtime `if` statements (`$_ENV` checks, type checks) with DI bindings to reduce code paths and achieve the open/closed principle

> This tutorial focuses on learning design patterns. For the Ray.Di feature reference, see the [manual](index.html).

## Tutorial structure

### Part 1: Foundations - Why DI matters

**Problem:** Tight coupling, hard to test, fragile to change
**What you learn:** How dependency injection and SOLID principles solve these problems

- [Dependency Injection Principles](study/01-foundations/dependency-injection-principles.html) - Inversion of control and loose coupling
- [SOLID Principles in Practice](study/01-foundations/solid-principles.html) - Understanding the five principles through real code
- [Ray.Di Fundamentals](study/01-foundations/raydi-fundamentals.html) - Bringing Google Guice's ideas to PHP

### Part 2: Object creation patterns

**Problem:** Bloated constructors, runtime parameters, optional dependencies
**What you learn:** Decision criteria for separating object creation responsibilities

- [Factory Pattern](study/02-object-creation/factory-pattern.html) - When to use: when object creation needs runtime parameters
- [Provider Pattern](study/02-object-creation/provider-pattern.html) - When to use: when initialization is complex
- [Null Object Pattern](study/02-object-creation/null-object-pattern.html) - When to use: when handling optional dependencies without null checks

### Part 3: Behavioral patterns

**Problem:** Exploding conditionals, scattered cross-cutting concerns
**What you learn:** How to make behavior switchable and separate concerns

- [Strategy Pattern](study/03-behavioral/strategy-pattern.html) - When to use: when switching algorithms at runtime
- [Decorator Pattern & AOP](study/03-behavioral/decorator-aop.html) - When to use: when separating logging, transactions, and similar concerns

### Part 4: Architecture patterns

**Problem:** Mixed data access, bloated controllers, bloated DI configuration
**What you learn:** Architecture design that separates layers and clarifies responsibilities

- [Adapter Pattern](study/04-architecture/adapter-pattern.html) - When to use: when adapting an external API or library
- [Repository Pattern](study/04-architecture/repository-pattern.html) - When to use: when separating data access from business logic
- [Service Layer](study/04-architecture/service-layer.html) - When to use: when coordinating business logic
- [Module Design](study/04-architecture/module-design.html) - When to use: when DI configuration has more than 50 bindings

## Learning approach

Each section follows a consistent structure:

1. **Problem** - A concrete issue in real code (10-20 lines)
2. **Why it matters** - Impact on maintainability, testability, and extensibility
3. **Solution** - The core implementation of the pattern (30-50 lines)
4. **The essence of the pattern** - Visual understanding through diagrams
5. **Decision criteria** - When to use this pattern and when not to
6. **Anti-patterns** - Common mistakes and why they happen
7. **Relation to SOLID** - The principles this pattern realizes

## Where to start

**For OOP beginners**
Recommended order: [Dependency Injection Principles](study/01-foundations/dependency-injection-principles.html) → [SOLID Principles](study/01-foundations/solid-principles.html) → [Factory Pattern](study/02-object-creation/factory-pattern.html)

**For experienced developers**
You can start anywhere. Each section is independent.

**For architects**
Recommended: [SOLID Principles](study/01-foundations/solid-principles.html) → [Architecture patterns](study/04-architecture/repository-pattern.html)

## Key patterns covered

| Pattern | Problem it solves | When to use it |
|---------|-------------------|----------------|
| **Factory** | Mixing runtime parameters with DI dependencies | When object creation needs runtime values |
| **Provider** | Bloated constructors | When complex initialization logic is needed |
| **Null Object** | Scattered null and environment checks | When optional dependencies vary by environment |
| **Strategy** | Exploding conditionals | When switching algorithms at runtime |
| **Decorator/AOP** | Scattered cross-cutting concerns | When separating logging, transactions, and similar concerns |
| **Adapter** | Mismatch between an external API and the application | When adapting an external service to the application |
| **Repository** | Mixed data access | When separating data access from business logic |
| **Service Layer** | Bloated controllers | When coordinating business logic |
| **Module Design** | Bloated DI configuration | When there are more than 50 bindings |

## Prerequisites

- A basic understanding of OOP
- Knowledge of interfaces

## Additional resources

- [Ray.Di manual](index.html) - Feature reference
- [Ray.Di GitHub](https://github.com/ray-di/Ray.Di)
- [Design Patterns in PHP](https://designpatternsphp.readthedocs.io/)

---

**Start:** [Dependency Injection Principles](study/01-foundations/dependency-injection-principles.html)

> Design patterns are not something to memorize - understanding the decision criteria is what matters. This tutorial will help you develop the judgement to choose the right pattern for each situation.
