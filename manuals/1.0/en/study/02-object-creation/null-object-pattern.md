---
layout: docs-en
title: Null Object Pattern
category: Manual
permalink: /manuals/1.0/en/study/02-object-creation/null-object-pattern.html
---
# Null Object Pattern: Handling Optional Dependencies

## Problem

In classes with optional dependencies, null checks scatter throughout the code. Consider an order service where the logger may or may not be configured:

```php
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private ?LoggerInterface $logger = null,
        private ?NotificationServiceInterface $notifier = null
    ) {}

    public function processOrder(Order $order): void
    {
        if ($this->logger !== null) {  // null check
            $this->logger->info("Processing order: {$order->getId()}");
        }

        $this->orderRepository->save($order);

        if ($this->notifier !== null) {  // null check
            $this->notifier->send(new OrderConfirmation($order));
        }

        if ($this->logger !== null) {  // null check
            $this->logger->info("Order processed successfully");
        }
    }
}
```

## Why it's a problem

This creates a fundamental mixing of business logic and existence checks for infrastructure. Three lines of business logic come with three null checks. Complexity grows in proportion to the number of optional dependencies, and the same null checks must be repeated in every method.

**Combinatorial explosion of code paths**: each null check splits the code path in two. Two optional dependencies mean four code paths (2²). Tests must cover all of them, and the more paths there are, the more places bugs can hide. With Null Object there is one path, and coverage is naturally 100%. **Fewer paths mean a more stable program.**

Worse, many developers use environment checks in if statements instead of null checks:

```php
// ❌ Even worse example: checking context with an if statement
class OrderService
{
    public function processOrder(Order $order): void
    {
        $this->orderRepository->save($order);

        // an environment check mixed into business logic!
        if ($_ENV['APP_ENV'] === 'production') {
            $this->notifier->send(new OrderConfirmation($order));
        }
    }
}
```

This embeds environment-dependent code directly in business logic, making testing extremely difficult. You cannot test it without manipulating `$_ENV`, and the same environment check must be repeated in every method.

## Solution: The Null Object pattern

The Null Object pattern solves this by providing an implementation that does nothing. Instead of an optional dependency, you always inject a valid object. When the dependency is not needed, you use a Null Object—an object that implements the interface but does nothing.

The key is to **inject a context-appropriate implementation through DI bindings instead of checking context with if statements**:

```php
// Null Object implementation - satisfies the interface but does nothing
class NullLogger implements LoggerInterface
{
    public function info(string $message): void {}
    public function error(string $message): void {}
}

class NullNotificationService implements NotificationServiceInterface
{
    public function send(Notification $notification): void {}
}

// Bind per environment in the DI module
class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        // Use Null Objects in development
        $this->bind(LoggerInterface::class)->to(NullLogger::class);
        $this->bind(NotificationServiceInterface::class)->to(NullNotificationService::class);
    }
}

class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        // Use real implementations in production
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
        $this->bind(NotificationServiceInterface::class)->to(EmailNotificationService::class);
    }
}

// ✅ Null checks and environment checks disappear completely from the code!
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private LoggerInterface $logger,           // always present
        private NotificationServiceInterface $notifier  // always present
    ) {}

    public function processOrder(Order $order): void
    {
        // No if statements needed - DI bindings decide whether it runs
        $this->logger->info("Processing order: {$order->getId()}");
        $this->orderRepository->save($order);
        $this->notifier->send(new OrderConfirmation($order));
        // Development: NullNotificationService = does nothing
        // Production: EmailNotificationService = sends email
    }
}
```

## Ray.Di's toNull() method

Ray.Di provides a convenient `toNull()` method, so you do not have to create Null Object classes by hand. Ray.Di generates a Null Object from the interface automatically:

```php
class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(InventoryServiceInterface::class)->to(InventoryService::class);

        // toNull() generates the Null Object automatically
        $this->bind(LoggerInterface::class)->toNull();
        $this->bind(CacheInterface::class)->toNull();
        $this->bind(NotificationServiceInterface::class)->toNull();
    }
}
```

With `toNull()`, Ray.Di:
1. Analyzes all methods of the interface
2. Generates a Null Object class that does nothing (returns nothing)
3. Binds an instance of that Null Object

This removes the need to write Null Object classes by hand, and the Null Object is updated automatically when the interface changes.

## The essence of the pattern

The Null Object pattern achieves **two important transformations**:

1. **From conditional existence to unconditional existence**: turn dependencies from something that "might exist" into something that "always exists"
2. **From conditionals in code to selection in DI configuration**: remove if statements from the code and let bindings decide behavior

```
Before:
if (logger != null) logger.log()           // null check
if ($_ENV['APP_ENV'] === 'prod') send()    // environment check

After:
logger.log()      // NullLogger does nothing; FileLogger writes to a file
notifier.send()   // NullNotifier does nothing; EmailNotifier sends email
```

Why does this matter?

**It embodies the essence of DI**: business logic describes "what to do," and DI bindings decide "how to do it." The code just writes `notifier.send()`, and DI decides at runtime, based on context (development/production), whether a notification is actually sent.

**Switching environments is easy**: to add a new environment (staging, test, local), you add a module without changing any code. Even if there are 1,000 environment-check if statements, the DI binding is in one place.

**Testing is easy**: instead of manipulating `$_ENV`, you bind the appropriate implementation in a test module. Business logic does not know about context and can focus purely on domain logic.

## When to use the Null Object pattern

Use the Null Object pattern for truly optional dependencies that do not affect business logic. These include logging, caching, metrics collection, notifications, and analytics—cases where the application works correctly when these services are absent.

Null Objects excel for dependencies that differ between environments. In development you may not send notifications, collect metrics, or call external APIs. In production, all of these are enabled. With Null Objects, you can switch environments through DI bindings without changing code.

## SOLID principles

The Null Object pattern enforces the **dependency inversion principle** by treating optional dependencies as required dependencies. Code always depends on interfaces, never on null. It supports the **single responsibility principle**—the service handles business logic, not existence checks for its dependencies. It upholds the **open/closed principle**—you can add new Null Object implementations through DI bindings without changing business logic.

## Key points

The Null Object pattern is the design decision to prefer **a null object over null**. Replace null checks (`if ($logger !== null)`) with an implementation that does nothing, reducing the code to a single path. Use it for truly optional dependencies such as logging, notifications, and metrics collection—cases where the application works correctly without these services.

Ray.Di's `toNull()` method generates Null Object classes automatically, eliminating the need for manual implementations. The pattern enables environment-specific behavior through DI bindings—injecting Null Objects in development and real implementations in production. Fewer code paths mean a more stable program.

## Advanced example: combining Null Object with AOP

Combining Null Objects with AOP produces an even more interesting pattern. The following is an advanced example:

```php
// 0. Attribute class (holds the table name)
#[Attribute(Attribute::TARGET_METHOD)]
class DbQuery
{
    public function __construct(public readonly string $table) {}
}

// 1. Define only the interface (no implementation class)
interface TodoQueryInterface
{
    #[DbQuery('todo_item')]
    public function item(string $id): Todo;
}

// 2. Bind the Null Object + apply the interceptor
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(TodoQueryInterface::class)->toNull();
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(DbQuery::class),
            [DbQueryInterceptor::class]
        );
    }
}

// 3. The interceptor intercepts the method call and executes SQL
class DbQueryInterceptor implements MethodInterceptor
{
    public function __construct(private readonly PDO $pdo) {}

    public function invoke(MethodInvocation $invocation): mixed
    {
        $attr = $invocation->getMethod()->getAttributes(DbQuery::class)[0]->newInstance();
        $sql = "SELECT * FROM {$attr->table} WHERE id = ?";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($invocation->getArguments());
        return $stmt->fetch();
    }
}

// Usage - an ordinary method call, but SQL actually runs
$todo = $todoQuery->item('123');
```

A Null Object is not only for "doing nothing"—combined with an interceptor, it becomes "a vessel that provides an implementation dynamically." The method signature becomes the API contract, the attribute provides metadata, and the interceptor executes the actual logic.

This pattern is used in [Ray.MediaQuery](https://github.com/ray-di/Ray.MediaQuery). If you are interested in the details, explore it after you have learned all the foundational patterns (Null Object, AOP, Repository). You should get a feel for the possibilities that combining patterns creates.

---

**Next:** [Strategy Pattern](../03-behavioral/strategy-pattern.html) - Switchable behavior

**Previous:** [Provider Pattern](provider-pattern.html)
