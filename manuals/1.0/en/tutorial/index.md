---
layout: docs-en
title: Complete Tutorial
category: Manual
permalink: /manuals/1.0/en/tutorial.html
---

# Ray.Di Complete Tutorial: Building a Real-World E-commerce Platform

Welcome to the comprehensive Ray.Di tutorial! This tutorial will guide you through building a real-world e-commerce platform while learning all aspects of dependency injection, design patterns, and aspect-oriented programming with Ray.Di.

## 🎯 What You'll Learn

- **Dependency Injection Principles**: Understanding DI, IoC, and SOLID principles
- **Ray.Di Fundamentals**: All binding types, scopes, and advanced features  
- **Real-World Application**: Building a complete e-commerce platform
- **Design Patterns**: Factory, Strategy, Observer, and more with DI
- **Aspect-Oriented Programming**: Cross-cutting concerns and interceptors
- **Testing Strategies**: Unit testing, mocking, and integration testing
- **Best Practices**: Performance, troubleshooting, and maintainable code

## 📋 Tutorial Structure

Each section is designed to be independent - you can start anywhere based on your needs!

### 🔰 Part 1: Foundations
- [Dependency Injection Principles](01-foundations/dependency-injection-principles.md)
- [SOLID Principles in Practice](01-foundations/solid-principles.md)  
- [Ray.Di Fundamentals](01-foundations/raydi-fundamentals.md)

### 🏗️ Part 2: Basic Bindings
- [Instance Bindings](02-basic-bindings/instance-bindings.md)
- [Class Bindings](02-basic-bindings/class-bindings.md)
- [Provider Bindings](02-basic-bindings/provider-bindings.md)

### 🚀 Part 3: Advanced Bindings
- [Conditional Bindings](03-advanced-bindings/conditional-bindings.md)
- [Multibindings](03-advanced-bindings/multibindings.md)
- [Assisted Injection](03-advanced-bindings/assisted-injection.md)

### ♻️ Part 4: Scopes & Lifecycle
- [Singleton Scope](04-scopes-lifecycle/singleton-scope.md)
- [Request Scope](04-scopes-lifecycle/request-scope.md)
- [Custom Scopes](04-scopes-lifecycle/custom-scopes.md)

### 🎭 Part 5: AOP & Interceptors
- [Aspect-Oriented Programming](05-aop-interceptors/aspect-oriented-programming.md)
- [Method Interceptors](05-aop-interceptors/method-interceptors.md)
- [Common Cross-cutting Concerns](05-aop-interceptors/common-crosscutting-concerns.md)

### 🛒 Part 6: Real-World Examples
- [Web Application Architecture](06-real-world-examples/web-application/)
- [Data Access Layer](06-real-world-examples/data-access/)
- [Authentication & Authorization](06-real-world-examples/authentication/)
- [Logging & Audit System](06-real-world-examples/logging-audit/)

### 🧪 Part 7: Testing Strategies
- [Unit Testing with DI](07-testing-strategies/unit-testing-with-di.md)
- [Mocking Dependencies](07-testing-strategies/mocking-dependencies.md)
- [Integration Testing](07-testing-strategies/integration-testing.md)

### 💎 Part 8: Best Practices
- [Design Patterns with DI](08-best-practices/design-patterns.md)
- [Performance Considerations](08-best-practices/performance-considerations.md)
- [Troubleshooting Guide](08-best-practices/troubleshooting.md)

## 🛒 Case Study: E-commerce Platform

Throughout this tutorial, we'll build **"ShopSmart"** - a complete e-commerce platform featuring:

- **User Management**: Registration, authentication, profiles
- **Product Catalog**: Categories, inventory, search
- **Order Processing**: Cart, checkout, payment
- **Administration**: Analytics, reporting, management
- **Infrastructure**: Caching, logging, monitoring

This real-world example demonstrates how Ray.Di enables:
- **Modularity**: Clean separation of concerns
- **Testability**: Easy unit and integration testing  
- **Maintainability**: Loose coupling and high cohesion
- **Scalability**: Proper scope management and performance
- **Extensibility**: Plugin architecture and interceptors

## 🎓 Learning Paths

### For Beginners
1. Start with [Dependency Injection Principles](01-foundations/dependency-injection-principles.md)
2. Learn [Ray.Di Fundamentals](01-foundations/raydi-fundamentals.md)
3. Practice with [Basic Bindings](02-basic-bindings/)
4. Explore [Real-World Examples](06-real-world-examples/)

### For Experienced Developers
1. Jump to [Advanced Bindings](03-advanced-bindings/)
2. Master [AOP & Interceptors](05-aop-interceptors/)
3. Study [Design Patterns](08-best-practices/design-patterns.md)
4. Review [Best Practices](08-best-practices/)

### For Architects
1. Focus on [SOLID Principles](01-foundations/solid-principles.md)
2. Study [Scopes & Lifecycle](04-scopes-lifecycle/)
3. Examine [Web Application Architecture](06-real-world-examples/web-application/)
4. Review [Performance Considerations](08-best-practices/performance-considerations.md)

## 🔧 Prerequisites

- PHP 8.1+
- Composer
- Basic understanding of OOP concepts
- Familiarity with interfaces and abstract classes

## 🚀 Quick Start

```bash
# Clone the tutorial examples
git clone https://github.com/ray-di/tutorial-examples.git
cd tutorial-examples

# Install dependencies
composer install

# Run the first example
php examples/01-basics/hello-world.php
```

## 📖 Code Examples

All examples are:
- **Runnable**: Complete, working code
- **Progressive**: Building complexity step by step
- **Practical**: Based on real-world scenarios
- **Well-documented**: Extensive comments and explanations

## 🎯 Key Concepts Covered

### Dependency Injection Patterns
- Constructor Injection
- Method Injection  
- Property Injection
- Interface Segregation

### Design Principles
- **Single Responsibility**: One reason to change
- **Open/Closed**: Open for extension, closed for modification
- **Liskov Substitution**: Derived classes must be substitutable
- **Interface Segregation**: No forced dependencies on unused interfaces
- **Dependency Inversion**: Depend on abstractions, not concretions

### Ray.Di Features
- **Binding DSL**: Fluent configuration API
- **Scopes**: Singleton, prototype, request, session
- **Providers**: Factory patterns and lazy initialization
- **Interceptors**: AOP for cross-cutting concerns
- **Multibindings**: Sets and maps of implementations
- **Conditional Bindings**: Environment-specific configuration

### Software Architecture Patterns
- **Layered Architecture**: Presentation, business, data
- **Repository Pattern**: Data access abstraction
- **Service Layer**: Business logic coordination
- **Factory Pattern**: Object creation strategies
- **Strategy Pattern**: Interchangeable algorithms
- **Observer Pattern**: Event-driven programming
- **Decorator Pattern**: Behavior enhancement

## 💡 Tips for Success

1. **Run the Code**: Don't just read - execute the examples
2. **Experiment**: Modify examples to see different behaviors
3. **Ask Questions**: Check issues or discussions for help
4. **Practice**: Build your own examples using the patterns
5. **Review**: Come back to concepts as you gain experience

## 🤝 Contributing

Found an error or want to improve the tutorial?
- Open an issue on GitHub
- Submit a pull request
- Share your own examples

## 📚 Additional Resources

- [Ray.Di Documentation](../manuals/1.0/en/)
- [Ray.Di API Reference](https://github.com/ray-di/Ray.Di)
- [Dependency Injection in PHP](https://www.php-di.org/doc/)
- [Design Patterns in PHP](https://designpatternsphp.readthedocs.io/)

---

**Ready to master Ray.Di?** Choose your starting point above and begin your journey to better software architecture!