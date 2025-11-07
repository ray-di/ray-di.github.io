---
layout: docs-en
title: Decorator Pattern/AOP - Cross-Cutting Concerns
category: Manual
permalink: /manuals/1.0/en/tutorial/03-behavior-patterns/decorator-pattern-aop.html
---

# Decorator Pattern/AOP - Cross-Cutting Concerns

## Learning Objectives

- Understand problems with scattered cross-cutting concerns
- Learn differences between Decorator Pattern and AOP
- Understand how to declaratively add features with Ray.Di interceptors

## The Problem: Scattered Cross-Cutting Concerns

Common processing like logging, transactions, and caching gets mixed with business logic.

```php
class OrderService
{
    public function processOrder(Order $order): void
    {
        // ❌ Problem: Business logic mixed with cross-cutting concerns
        $this->logger->info("Starting order processing");

        $this->db->beginTransaction();
        try {
            // Business logic (essence)
            $this->orderRepository->save($order);
            $this->paymentService->processPayment($order);

            $this->db->commit();
            $this->logger->info("Order processed successfully");
        } catch (Exception $e) {
            $this->db->rollback();
            $this->logger->error("Order processing failed: " . $e->getMessage());
            throw $e;
        }
    }

    public function cancelOrder(int $orderId): void
    {
        // Same logging and transaction code duplicated...
        $this->logger->info("Starting order cancellation");
        $this->db->beginTransaction();
        try {
            // Business logic
            $this->db->commit();
        } catch (Exception $e) {
            $this->db->rollback();
            throw $e;
        }
    }
}
```

### Why This Is a Problem

1. **Mixed Concerns**
   - Business logic buried and hard to read
   - Logging and transaction code duplicated

2. **Single Responsibility Principle Violation**
   - `OrderService` has multiple responsibilities
   - Multiple reasons to change

3. **Reduced Maintainability**
   - Changing log format = modifying all methods
   - Adding new cross-cutting concerns is difficult

## Solution: AOP (Aspect-Oriented Programming)

**AOP's Role**: Separate cross-cutting concerns from business logic

```php
// 1. Attribute Definitions
#[Attribute(Attribute::TARGET_METHOD)]
class Transactional {}

#[Attribute(Attribute::TARGET_METHOD)]
class Loggable {}

// 2. Interceptor Implementations
class TransactionalInterceptor implements MethodInterceptor
{
    public function __construct(
        private DatabaseConnection $db
    ) {}

    public function invoke(MethodInvocation $invocation): mixed
    {
        $this->db->beginTransaction();
        try {
            $result = $invocation->proceed();
            $this->db->commit();
            return $result;
        } catch (Exception $e) {
            $this->db->rollback();
            throw $e;
        }
    }
}

class LoggableInterceptor implements MethodInterceptor
{
    public function __construct(
        private LoggerInterface $logger
    ) {}

    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $class = get_class($invocation->getThis());

        $this->logger->info("Method started: {$class}::{$method->getName()}");

        try {
            $result = $invocation->proceed();
            $this->logger->info("Method completed: {$class}::{$method->getName()}");
            return $result;
        } catch (Exception $e) {
            $this->logger->error("Method failed: {$class}::{$method->getName()}", [
                'error' => $e->getMessage()
            ]);
            throw $e;
        }
    }
}

// 3. AOP Module Configuration
class AopModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Transactional::class),
            [TransactionalInterceptor::class]
        );

        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Loggable::class),
            [LoggableInterceptor::class]
        );
    }
}

// 4. Clean Business Logic
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private PaymentServiceInterface $paymentService
    ) {}

    #[Transactional]
    #[Loggable]
    public function processOrder(Order $order): void
    {
        // ✅ Business logic only
        $this->orderRepository->save($order);
        $this->paymentService->processPayment($order);
    }

    #[Transactional]
    #[Loggable]
    public function cancelOrder(int $orderId): void
    {
        $order = $this->orderRepository->findById($orderId);
        $order->cancel();
        $this->orderRepository->save($order);
    }
}
```

## Pattern Essence

```
Normal Method Call:
Client → Service.method() → Business Logic

AOP Method Call:
Client → Interceptor 1 (Logging)
         → Interceptor 2 (Transaction)
            → Service.method() → Business Logic
         ← Interceptor 2 (Commit/Rollback)
      ← Interceptor 1 (Log Result)
```

### What AOP Solves

1. **Separation of Concerns**
   - Business logic: `OrderService`
   - Transaction management: `TransactionalInterceptor`
   - Logging: `LoggableInterceptor`

2. **DRY Principle Compliance**
   ```php
   // ❌ Before: Duplicated code in all methods
   public function processOrder() {
       $this->logger->info(...);
       $this->db->beginTransaction();
       try { ... } catch { ... }
   }

   // ✅ After: Declarative with no duplication
   #[Transactional]
   #[Loggable]
   public function processOrder() {
       // Business logic only
   }
   ```

3. **Testability**
   - Test business logic purely
   - Test interceptors individually

## Difference from Decorator Pattern

| Feature | Decorator Pattern | AOP (Interceptor) |
|---------|------------------|-------------------|
| **Scope** | Specific class | Many classes/methods |
| **Addition Method** | Explicitly wrap | Declaratively specify with attributes |
| **Modification Point** | One place only | Applicable to all methods |
| **Implementation** | Assemble in provider | Bind interceptor in module |

### Decorator Pattern Example

```php
// When adding functionality only to specific class
class LoggingOrderService implements OrderServiceInterface
{
    public function __construct(
        private OrderServiceInterface $inner,
        private LoggerInterface $logger
    ) {}

    public function processOrder(Order $order): void
    {
        $this->logger->info("Processing order");
        $this->inner->processOrder($order);
        $this->logger->info("Order processed");
    }
}

// Assemble in provider
class OrderServiceProvider implements ProviderInterface
{
    public function get(): OrderServiceInterface
    {
        $service = new OrderService(...);
        return new LoggingOrderService($service, $this->logger);
    }
}
```

## Decision Criteria

```
Feature addition needed
│
├─ Apply to many classes/methods?
│  ├─ YES → Unrelated to business logic?
│  │         ├─ YES → ✅ AOP (Interceptor)
│  │         └─ NO  → Decorator Pattern
│  └─ NO  ↓
│
├─ Specific class only?
│  ├─ YES → ✅ Decorator Pattern
│  └─ NO  → Regular implementation
```

### When to Use AOP

| Situation | Example |
|-----------|---------|
| **Cross-cutting concerns** | Logging, transactions, caching |
| **Declarative addition** | Simply add features with attributes |
| **Many methods** | All service layer methods etc. |

### When to Use Decorator

| Situation | Example |
|-----------|---------|
| **Specific class only** | Add feature to only some services |
| **Complex conditionals** | Behavior based on runtime state |
| **Explicit dependencies** | Better to see added features clearly |

## Common Anti-patterns

### Business Logic in Interceptor

```php
// ❌ Interceptor has business logic
class OrderProcessingInterceptor implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation): mixed
    {
        $order = $invocation->getArguments()[0];

        // Don't put business logic in interceptor!
        if ($order->getTotal() > 10000) {
            $this->notificationService->sendAlert($order);
        }

        return $invocation->proceed();
    }
}

// ✅ Interceptor for cross-cutting concerns only
class LoggableInterceptor implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation): mixed
    {
        $this->logger->info("Method called");
        $result = $invocation->proceed();
        $this->logger->info("Method completed");
        return $result;
    }
}
```

**Why it's a problem**: Unclear interceptor responsibility, business rules hidden

### Excessive Interceptors

```php
// ❌ Applying too many interceptors
#[Logging]
#[Caching]
#[Transactional]
#[Monitoring]
#[RateLimiting]
#[Authentication]
#[Authorization]
#[Validation]
public function processOrder(Order $order): void
{
    // Execution order unclear, performance issues
}

// ✅ Minimal necessary interceptors
#[Transactional]
#[Loggable]
public function processOrder(Order $order): void
{
    // Authentication/authorization in middleware layer
    // Validation in domain layer
}
```

**Why it's a problem**: Complex execution order, performance impact

## Relationship with SOLID Principles

- **SRP**: Complete separation of business logic and cross-cutting concerns
- **OCP**: Add new features with interceptors, no existing code changes
- **DIP**: Interceptors depend on abstractions, business logic doesn't know interceptors

## Summary

### AOP Pattern Core

- **Cross-cutting concern separation**: Complete separation from business logic
- **Declarative feature addition**: Specify cross-cutting concerns with attributes
- **Thorough DRY principle**: Manage duplicate code in one place

### Pattern Benefits

- ✅ Business logic is clean and readable
- ✅ Cross-cutting concerns managed in one place
- ✅ Testability greatly improved
- ✅ Easy to add new cross-cutting concerns

### Next Steps

Now that you understand behavior patterns, let's learn architecture patterns.

**Continue to:** [Repository Pattern](../04-architecture-patterns/repository-pattern.html)

---

AOP is one of Ray.Di's most powerful features. By **declaratively adding cross-cutting concerns**, you can keep business logic clean while achieving all necessary functionality.
