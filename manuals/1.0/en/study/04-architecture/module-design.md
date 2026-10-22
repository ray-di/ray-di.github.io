---
layout: docs-en
title: Module Design
category: Manual
permalink: /manuals/1.0/en/study/04-architecture/module-design.html
---
# Module Design: Organizing DI Configuration

## Problem

The DI configuration is managed in one enormous module. As the application grows, all the bindings become mixed together. Bindings for user management, order processing, payment, and notification all live in the same file. Because the configuration is not organized, developers cannot find the relevant configuration:

```php
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // User management bindings
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(UserServiceInterface::class)->to(UserService::class);
        
        // Order processing bindings
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        
        // Payment bindings
        $this->bind(PaymentGatewayInterface::class)->to(StripeGateway::class);
        $this->bind(PaymentServiceInterface::class)->to(PaymentService::class);
        
        // Notification bindings
        $this->bind(NotificationServiceInterface::class)->to(EmailNotificationService::class);
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
        
        // 50 more bindings... all mixed together!
    }
}
```

## Why It Is a Problem

This creates a fundamental organizational problem between feature cohesion and configuration maintainability. When understanding the order feature, you have to read past the user, payment, and notification configuration to find the relevant bindings. When changing the payment gateway from Stripe to PayPal, you have to search the entire application configuration to find the line to change.

The module violates the single responsibility principle by managing multiple concerns. Even if you want to test only the order feature during development, all the bindings for users, payment, and notification are active—you cannot enable features selectively. Every configuration change risks touching an enormous module that affects every feature.

## Solution: Feature-Based Modules

The Module Design pattern solves this problem by organizing bindings by feature. Each feature has its own module that encapsulates the related configuration. The application module combines these small, focused modules:

```php
// User management module - only user-related bindings
class UserModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(UserServiceInterface::class)->to(UserService::class);
    }
}

// Order processing module - only order-related bindings
class OrderModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        $this->bind(ShippingServiceInterface::class)->to(ShippingService::class);
    }
}

// Payment module - only payment-related bindings
class PaymentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(PaymentGatewayInterface::class)->to(StripeGateway::class);
        $this->bind(PaymentServiceInterface::class)->to(PaymentService::class);
    }
}

// Application module - combines the feature modules
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new UserModule());
        $this->install(new OrderModule());
        $this->install(new PaymentModule());
    }
}
```

## The Essence of the Pattern

The Module Design pattern creates a clear organizational separation: instead of one module knowing all the configuration, each module knows one feature. Features can be developed, tested, and enabled independently. The `install()` method makes module composition possible.

```
Before: one module, all bindings (chaos)
After:  many modules, grouped by feature (organized)
```

Why does this matter? When changing the payment gateway, you touch only `PaymentModule`—it does not affect other features. When testing order processing, you install only `OrderModule`—there are no unnecessary dependencies. When a new developer learns about user management, they read `UserModule`—no need to sift through 50 bindings. Each feature has a single place for its configuration. Modules follow the same boundaries as the code—`UserService` has `UserModule`, and `OrderService` has `OrderModule`.

## When to Use Module Design

Use Module Design when the application has clear feature boundaries. This includes features with independent configuration, such as user management, order processing, payment, and notification. Module design is essential for microservice architectures, plugin systems, and applications that need to enable features selectively in different environments.

Modules excel when the configuration has grown large and chaotic. If a DI module has more than 50 bindings, split it into smaller feature modules. When teams develop features independently, modules prevent merge conflicts—each team works on its own module. When features are optional, modules make them selectively installable.

## Common Mistake: Modules by Layer

A frequently seen anti-pattern is organizing modules by layer rather than by feature:

```php
// ❌ Bad example - modules by layer (horizontal slices)
class RepositoryModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(PaymentRepositoryInterface::class)->to(MySQLPaymentRepository::class);
        // All repositories, regardless of feature
    }
}

class ServiceModule extends AbstractModule
{
    protected function configure(): void
    {
        // All services, regardless of feature
    }
}

// ✅ Good example - modules by feature (vertical slices)
class OrderModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        $this->bind(ShippingServiceInterface::class)->to(ShippingService::class);
        // All layers of one feature
    }
}
```

Modules by layer destroy feature cohesion. When understanding the order feature, you have to read `RepositoryModule`, `ServiceModule`, and the controller module. You cannot disable the order feature—everything is scattered across three modules. Organize modules by feature—each module contains all layers of one feature: repositories, services, controllers, and so on. Modules follow domain boundaries, not technical layers.

## SOLID Principles

The Module Design pattern enforces the **single responsibility principle** by making each module manage the configuration of a single feature. It supports the **open/closed principle**—you can add a feature by creating a new module without changing existing modules. Feature modules are also uniform in shape: each one is an `AbstractModule` with a `configure()` method, so `AppModule` composes them without knowing their contents.

## Testing

Modules dramatically simplify testing. Without modules, testing order processing requires installing the bindings of the entire application, even those unrelated to orders. Every test needs every dependency—there is no selective enabling. With modules, you install only the relevant modules. Testing order processing needs only `OrderModule`. The scope of testing shrinks from a monolithic configuration with 50 bindings to a focused feature module with 5 bindings.

## Key Points

Module Design organizes DI configuration by feature. Use it for applications with clear feature boundaries or applications with more than 50 bindings. Each feature has its own module—`UserModule`, `OrderModule`, `PaymentModule`. The application module combines these modules using `install()`. Organize modules by feature, not by layer—each module contains all layers of one feature (repository, service, controller). This pattern makes the configuration discoverable, lets features be developed independently, and keeps tests focused.

---

**Previous:** [Service Layer](service-layer.html)

---

**🎉 Congratulations!** You have completed the Ray.Di Study tutorial.

You now understand:

- **when** to use each pattern (decision criteria)
- **why** a pattern solves a specific problem
- **how** to implement the pattern with Ray.Di
- **what** to avoid (anti-patterns)

**Next steps:**

- Practice these patterns in your own projects
- Read the detailed feature reference in the [Ray.Di manual](../../)
- Explore advanced examples on [Ray.Di GitHub](https://github.com/ray-di/Ray.Di)
