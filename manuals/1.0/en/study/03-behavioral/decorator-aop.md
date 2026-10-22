---
layout: docs-en
title: Decorator Pattern & AOP
category: Manual
permalink: /manuals/1.0/en/study/03-behavioral/decorator-aop.html
---
# Decorator Pattern and AOP: Separating Cross-Cutting Concerns

## Problem

Cross-cutting concerns are scattered throughout the business logic. Consider an order service that needs logging, transaction management, and cache invalidation. Infrastructure code overwhelms the actual business logic:

```php
class OrderService
{
    public function processOrder(Order $order): void
    {
        $this->logger->info("Processing order: {$order->getId()}");

        try {
            $this->db->beginTransaction();

            // The actual business logic (just two lines!)
            $this->orderRepository->save($order);
            $this->inventoryService->reserve($order->getItems());

            $this->db->commit();
        } catch (Exception $e) {
            $this->db->rollback();
            $this->logger->error("Order failed: {$e->getMessage()}");
            throw $e;
        }

        $this->cache->delete("order_{$order->getId()}");
        $this->logger->info("Order processed");
    }
}
```

## Why it is a problem

This creates a fundamental collision between business logic and infrastructure concerns. The method processes orders while also managing logging, transactions, and caching. Changing the log format forces you to touch the business logic. Testing order processing requires mocks for the logger, the database, and the cache.

The code duplicates infrastructure patterns in every service method. Methods that need transactions repeat the same try-catch-commit-rollback pattern. Methods that need logging repeat the same info-error pattern. The business logic—the two lines of actual domain behavior—is buried in twelve lines of infrastructure noise.

## Solution: the Decorator pattern

The Decorator pattern solves this problem by separating business logic from cross-cutting concerns. The core service contains only domain logic. Decorators wrap the service and add infrastructure behavior independently:

```php
// Core interface
interface OrderServiceInterface
{
    public function processOrder(Order $order): void;
}

// Pure business logic - no infrastructure!
class OrderService implements OrderServiceInterface
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private InventoryServiceInterface $inventoryService
    ) {}

    public function processOrder(Order $order): void
    {
        $this->orderRepository->save($order);
        $this->inventoryService->reserve($order->getItems());
    }
}

// A decorator wraps the service and adds logging
class LoggingOrderServiceDecorator implements OrderServiceInterface
{
    public function __construct(
        private OrderServiceInterface $inner,
        private LoggerInterface $logger
    ) {}

    public function processOrder(Order $order): void
    {
        $this->logger->info("Processing order: {$order->getId()}");
        try {
            $this->inner->processOrder($order);
            $this->logger->info("Order processed");
        } catch (Exception $e) {
            $this->logger->error("Order failed: {$e->getMessage()}");
            throw $e;
        }
    }
}
```

You can create similar decorators for transactions, caching, and other cross-cutting concerns. Each decorator wraps the core service independently.

## From Decorator to AOP

Wrapping services by hand with decorators is tedious. AOP automates decorator application through attributes. Instead of explicit wrapping, you declare a concern with an attribute and let Ray.Di apply it:

```php
// Marker attributes
#[Attribute(Attribute::TARGET_METHOD)]
final class Log {}

#[Attribute(Attribute::TARGET_METHOD)]
final class Transactional {}

// Define an interceptor (an automated decorator)
class LoggingInterceptor implements MethodInterceptor
{
    public function __construct(private LoggerInterface $logger) {}

    public function invoke(MethodInvocation $invocation): mixed
    {
        $this->logger->info("Calling: {$invocation->getMethod()->getName()}");
        $result = $invocation->proceed();
        $this->logger->info("Completed");
        return $result;
    }
}

class TransactionalInterceptor implements MethodInterceptor
{
    public function __construct(private TransactionManager $transactions) {}

    public function invoke(MethodInvocation $invocation): mixed
    {
        $this->transactions->begin();
        try {
            $result = $invocation->proceed();
            $this->transactions->commit();
            return $result;
        } catch (\Throwable $e) {
            $this->transactions->rollback();
            throw $e;
        }
    }
}

// Apply them with attributes
class OrderService
{
    #[Log]
    #[Transactional]
    public function processOrder(Order $order): void
    {
        $this->orderRepository->save($order);
        $this->inventoryService->reserve($order->getItems());
    }
}
```

The attributes take effect only once the interceptors are bound to them in a module:

```php
use Ray\Di\AbstractModule;

class OrderModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Log::class),
            [LoggingInterceptor::class]
        );

        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Transactional::class),
            [TransactionalInterceptor::class]
        );
    }
}
```

## The essence of the pattern

The Decorator pattern creates layers of behavior around a core object. Each decorator implements the same interface and wraps another implementation. AOP automates this by detecting attributes and applying decorators (called interceptors) automatically.

```
Manual: Service → TransactionDecorator → LoggingDecorator → Client
AOP: Service + #[Attributes] → Ray.Di generates the wrapper → Client
```

Why does this matter? When you add caching to five services, you add one attribute to each method instead of writing five decorators. When you change the log format, you change one interceptor instead of updating every service. When you test the business logic, you test the core service without infrastructure dependencies. Each concern lives in one place—the decorator or interceptor that implements it.

## When to use Decorator/AOP

Use the Decorator pattern or AOP when multiple classes need the same cross-cutting concern. That includes logging, transaction management, caching, security checks, and performance monitoring—concerns orthogonal to business logic that apply broadly across the application.

Decorators shine when you need to combine several behaviors or switch them by environment. In development you might skip caching but enable verbose logging. In production you might enable caching and transactions but reduce logging. With decorators, you can combine these behaviors without changing the business logic.

## When to avoid Decorator

Avoid decorators for concerns that are not cross-cutting. If only one class needs a behavior, inject it as a dependency. If the behavior is core business logic tightly coupled to the purpose of the method, make it explicit in the service rather than hiding it in a decorator. Do not use AOP for domain calculations, validation, or workflows—those belong in visible, testable service methods.

## Common mistake: business logic in an interceptor

A common anti-pattern is placing business logic inside an interceptor:

```php
// ❌ Bad example - business logic inside an interceptor
class ValidationInterceptor implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation): mixed
    {
        $order = $invocation->getArguments()[0];
        if ($order->getTotal() > 10000) {
            $order->applyFraudCheck(); // Business logic does not belong here!
        }
        return $invocation->proceed();
    }
}

// ✅ Good example - explicit business logic in the service
class OrderService
{
    public function processOrder(Order $order): void
    {
        if ($order->getTotal() > 10000) {
            $this->fraudChecker->check($order); // Visible and testable
        }
        $this->orderRepository->save($order);
    }
}
```

Interceptors handle infrastructure concerns—logging, transactions, caching, metrics. Services handle business rules. Mixing them ruins the separation. If fraud detection lives in an interceptor, a developer reading the service code cannot see it. Business rules should be explicit and discoverable in domain services, not hidden in framework-level interceptors.

## SOLID principles

The Decorator pattern enforces the **single responsibility principle** by separating business logic from cross-cutting concerns. It supports the **open/closed principle**—you can add new interceptors without modifying the business service. It upholds the **dependency inversion principle** by depending on the service interface rather than a concrete implementation, which lets decorators wrap any implementation transparently.

## Testing

Decorators simplify testing dramatically. Without decorators, testing order processing requires mocks for the repository, the inventory service, the logger, the database, and the cache—five infrastructure mocks plus the domain logic. With decorators, you test the core service with only its domain dependencies. Testing order processing needs only mocks for the repository and inventory. The test target shrinks from five infrastructure concerns to zero.

## Key points

The Decorator pattern wraps an object to add behavior without modifying it. AOP automates decorator application through attributes, making Ray.Di interceptors a declarative implementation of the Decorator pattern. Use decorators for cross-cutting concerns such as logging, transactions, caching, and security—never for business logic. This separation keeps business logic clean, testable, and focused on domain behavior. Interceptors handle infrastructure. Services handle business rules.

---

**Next:** [Adapter Pattern](../04-architecture/adapter-pattern.html) - Adapting external APIs

**Previous:** [Strategy Pattern](strategy-pattern.html)
