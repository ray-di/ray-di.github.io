---
layout: docs-en
title: Factory Pattern - Object Creation Patterns
category: Manual
permalink: /manuals/1.0/en/tutorial/02-object-creation-patterns/factory-pattern.html
---

# Factory Pattern - Object Creation Patterns

## Learning Objectives

- Understand challenges of object creation requiring runtime parameters
- Learn how the Factory Pattern complements DI's limitations
- Decide when to use Factory vs Provider patterns

## The Problem: Mixing Runtime Parameters with Configuration-Time Dependencies

DI containers build the dependency graph at configuration time. But what if you need parameters that are only known at runtime?

```php
class OrderProcessor
{
    public function __construct(
        private int $orderId,              // ← Runtime parameter (user input)
        private PaymentServiceInterface $paymentService,  // ← Configuration-time dependency (DI)
        private InventoryServiceInterface $inventoryService
    ) {}
}

// ❌ Problem: DI container doesn't know orderId
$processor = $injector->getInstance(OrderProcessor::class);  // How to pass orderId?
```

### Why This Is a Problem

1. **Different Nature of Dependencies**
   - `PaymentService`: Determined at application startup (configuration)
   - `orderId`: Determined by user request (runtime)

2. **DI's Limitation**
   - DI container knows "what to inject"
   - But "which value to inject" is unknown until runtime

3. **Temptation for Anti-patterns**
   ```php
   // Pass via setter? → Mutable state, unclear dependencies
   $processor->setOrderId($orderId);

   // Service Locator? → Loses DI benefits
   $processor = new OrderProcessor($orderId, $container->get(...), ...);
   ```

## Solution: Factory Pattern

**Factory's Role**: Bridge between runtime parameters and configuration-time dependencies

```php
// 1. Factory Interface
interface OrderProcessorFactoryInterface
{
    public function create(int $orderId): OrderProcessor;
}

// 2. Factory Implementation (injects configuration-time dependencies)
class OrderProcessorFactory implements OrderProcessorFactoryInterface
{
    public function __construct(
        private PaymentServiceInterface $paymentService,
        private InventoryServiceInterface $inventoryService
    ) {}

    public function create(int $orderId): OrderProcessor
    {
        return new OrderProcessor(
            $orderId,                  // Runtime parameter
            $this->paymentService,     // Configuration-time dependency
            $this->inventoryService
        );
    }
}

// 3. Usage
class OrderController
{
    public function __construct(
        private OrderProcessorFactoryInterface $factory  // Inject factory
    ) {}

    public function processOrder(Request $request): void
    {
        $orderId = $request->get('order_id');
        $processor = $this->factory->create($orderId);  // ✅ Create at runtime
        $processor->process();
    }
}
```

## Pattern Essence

```
Runtime Parameter Flow:
Request → Controller → Factory.create(param) → New Object

Configuration-Time Dependency Flow:
DI Container → Factory.__construct(deps) → Factory.create() → New Object
```

### What Factory Solves

1. **Separation of Responsibilities**
   - Controller: Obtains runtime parameters
   - Factory: Object creation
   - DI Container: Resolves configuration-time dependencies

2. **Testability**
   - Factory can be swapped with test implementation
   - Test without starting actual services

3. **Clear Dependencies**
   - All dependencies received via constructor
   - Immutable after construction

## Decision Criteria

### When to Use Factory Pattern

| Situation | Reason |
|-----------|--------|
| **Runtime parameters needed** | User input, request data |
| **Multiple instances of same type** | Different parameters in loops |
| **Conditional creation** | Different types based on runtime conditions |

### When to Consider Other Patterns

| Situation | Alternative Pattern |
|-----------|-------------------|
| **No runtime parameters** | Direct DI |
| **Complex initialization only** | Provider binding |
| **Singleton** | Scope configuration |

### Decision Flow

```
Object creation needed
│
├─ Runtime parameters required?
│  ├─ YES → ✅ Factory Pattern
│  └─ NO  → Next question
│
├─ Complex initialization?
│  ├─ YES → Provider Pattern (next section)
│  └─ NO  → Regular DI binding is sufficient
```

## Common Anti-patterns

### God Factory

```php
// ❌ Generic factory that creates anything
interface GenericFactoryInterface
{
    public function create(string $class, array $params): object;
}

// ✅ Type-safe dedicated factory
interface OrderProcessorFactoryInterface
{
    public function create(int $orderId): OrderProcessor;
}
```

**Why it's a problem**: Loss of type safety, unclear interface contract

### Business Logic in Factory

```php
// ❌ Factory has business logic
public function create(int $orderId): OrderProcessor
{
    $order = $this->repository->find($orderId);
    if ($order->getTotal() > 10000) {  // Business rule
        $this->notify($order);
    }
    return new OrderProcessor(...);
}

// ✅ Factory only creates
public function create(int $orderId): OrderProcessor
{
    return new OrderProcessor($orderId, $this->service, ...);
}
```

**Why it's a problem**: Single Responsibility Principle violation, unclear factory responsibility

## Relationship with SOLID Principles

- **SRP**: Factory is responsible only for "object creation"
- **OCP**: Adding new types doesn't modify existing code
- **DIP**: Depends on interfaces, eliminates dependency on concrete classes

## Summary

### Factory Pattern Core

- **Complements DI container's limitations**: Handles runtime parameters
- **Clear responsibilities**: Separates creation logic
- **Testability**: Factory can be swapped

### Next Steps

If your challenge is **complex initialization logic** rather than runtime parameters, the Provider Pattern is appropriate.

**Continue to:** [Provider Pattern](provider-pattern.html)

---

The Factory Pattern clarifies the boundary between **configuration-time** and **runtime**. Understanding this is key to mastering DI.
