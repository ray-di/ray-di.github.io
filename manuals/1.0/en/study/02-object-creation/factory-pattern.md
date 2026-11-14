---
layout: docs-en
title: Factory Pattern
category: Manual
permalink: /manuals/1.0/en/study/02-object-creation/factory-pattern.html
---
# Factory Pattern: Combining Runtime Parameters with Dependency Injection

## Problem

You need to create objects that require both DI-managed dependencies and runtime parameters. Consider an order processing service. It has to create an Order object from customer data supplied at runtime. The Order itself also needs injected dependencies such as a validator and a calculator:

```php
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository
    ) {}

    public function createOrder(Customer $customer, array $items): Order
    {
        // Problem: how do we provide both runtime data and DI dependencies?
        $order = new Order(
            $customer,           // runtime parameter
            $items,              // runtime parameter
            ???                  // OrderValidator (needs DI)
            ???                  // PriceCalculator (needs DI)
        );

        $this->orderRepository->save($order);
    }
}
```

## Why it's a problem

This creates a fundamental tension between two needs: passing runtime data and injecting dependencies. The service layer should not know about Order's internal dependencies. That violates separation of concerns and makes testing harder. When testing the service, you cannot mock Order's dependencies. A change to Order's constructor ripples through every service that creates orders.

The service handles two distinct responsibilities: coordinating business logic and wiring dependencies. This coupling makes the code fragile and hard to maintain.

## Solution: The Factory pattern

The Factory pattern solves this by delegating object creation to a dedicated factory, which dependency injection can then manage:

```php
// Factory interface
interface OrderFactoryInterface
{
    public function create(Customer $customer, array $items): Order;
}

// The factory implementation receives its dependencies through DI
class OrderFactory implements OrderFactoryInterface
{
    public function __construct(
        private OrderValidatorInterface $validator,
        private PriceCalculatorInterface $calculator
    ) {}

    public function create(Customer $customer, array $items): Order
    {
        // runtime data from the caller ↓  DI dependencies from the constructor ↓
        return new Order($customer, $items, $this->validator, $this->calculator);
    }
}

// The service layer stays clean
class OrderService
{
    public function __construct(
        private OrderFactoryInterface $orderFactory,
        private OrderRepositoryInterface $orderRepository
    ) {}

    public function createOrder(Customer $customer, array $items): Order
    {
        $order = $this->orderFactory->create($customer, $items);
        $this->orderRepository->save($order);
        return $order;
    }
}
```

Configuring the factory binding:
```php
$this->bind(OrderFactoryInterface::class)->to(OrderFactory::class);
```

## The essence of the pattern

The Factory pattern creates a clear separation: runtime parameters flow through the method call, and dependencies flow through the constructor. The factory receives "what to create" (runtime data) and knows "how to create it" (wiring the dependencies).

```
Runtime params ────┐
                   ├──> Factory ──> Object with dependencies
DI dependencies ───┘
```

Why does this matter? When runtime needs change (a new customer type, a new order flow), you modify only the factory call. When dependencies change (a new validator, a different calculator), you modify only the factory constructor. Each change has a single, clear home. The service layer focuses purely on business logic and delegates the mechanics of object construction to a component designed for exactly that.

## When to use the Factory pattern

Use the Factory pattern when an object needs both DI dependencies and runtime parameters. This situation is common in domain-driven design, where entities need both behavioral dependencies (services, validators) and runtime-only data (IDs, values).

Factories are also valuable when object creation involves complex logic. Multi-step initialization, validation, conditional construction—centralizing complex creation logic in one place makes it reusable and testable.

## From static methods to DI-managed factories

Using static factory methods (`Order::create()`) is not uncommon, but you should migrate to DI-managed factories:

```php
// ❌ Bad example - the static method constructs its own dependency
class Order
{
    public static function create(Customer $customer, array $items): self
    {
        $validator = new OrderValidator(); // hard-coded dependency!
        return new self($customer, $items, $validator);
    }
}

// ✅ Good example - the factory receives its dependencies through DI
class OrderFactory implements OrderFactoryInterface
{
    public function __construct(private OrderValidatorInterface $validator) {}

    public function create(Customer $customer, array $items): Order
    {
        return new Order($customer, $items, $this->validator);
    }
}
```

A static method can receive dependencies through its parameters—the problem here is that `Order::create()` constructs `OrderValidator` internally. The dependency stays hidden: the container cannot supply it, and a test cannot replace it. Static dispatch also keeps the object outside the DI-managed graph, so it cannot take part in AOP or scoping. It is the hidden construction, not the `static` keyword, that violates the dependency inversion principle.

## SOLID principles

The Factory pattern supports several SOLID principles. By separating object creation from business logic, it enforces the **single responsibility principle**. By letting you add new object types by creating a new factory rather than modifying existing code, it enables the **open/closed principle**. Most importantly, by depending on a factory interface rather than a concrete implementation, it upholds the **dependency inversion principle**.

## Testing

Factories dramatically simplify testing. Without a factory, testing OrderService requires mocking OrderValidator and PriceCalculator. With a factory, you mock only OrderFactoryInterface. The surface under test shrinks from three interfaces to one.

Tests create a mock factory that returns preconfigured objects. This lets you test the service's business logic in isolation. The factory itself can be tested independently, verifying that it assembles its dependencies correctly.

## Key points

The Factory pattern bridges the gap between runtime parameters and dependency injection. Use it when an object needs both kinds of input. Keep factories focused on object creation; do not put business logic in them. Avoid static factory methods that bypass dependency injection. A well-designed factory makes code more testable, more maintainable, and more aligned with SOLID principles.

---

**Next:** [Provider Pattern](provider-pattern.html) - When initialization is complex

**Previous:** [Ray.Di Fundamentals](../01-foundations/raydi-fundamentals.html)
