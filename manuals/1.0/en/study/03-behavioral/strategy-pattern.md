---
layout: docs-en
title: Strategy Pattern
category: Manual
permalink: /manuals/1.0/en/study/03-behavioral/strategy-pattern.html
---
# Strategy Pattern: Switchable Behavior

## Problem

Every time you add an algorithm, the conditionals multiply. Consider a service that calculates shipping costs. Each new shipping method adds another branch. Every new business requirement bloats the method:

```php
class ShippingService
{
    public function calculateCost(Order $order): Money
    {
        $method = $order->getShippingMethod();

        if ($method === 'standard') {
            return Money::of(10.00);
        } elseif ($method === 'express') {
            $cost = Money::of(25.00);
            if ($order->getWeight() > 10) {
                $cost = $cost->add(Money::of(15.00));
            }
            return $cost;
        }
        // Every new shipping method adds another condition!
    }
}
```

## Why it is a problem

This creates a fundamental tension between adding features and keeping things stable. Every new shipping method requires changing existing code, which violates the open/closed principle (OCP: Open/Closed Principle). When you add next-day delivery, you cannot avoid touching the code that handles standard and express shipping. Testing becomes difficult—you need one huge test that covers every algorithm at once.

By managing several algorithms, this class violates the single responsibility principle. To understand the code, you must parse every shipping method at the same time. Every change risks breaking existing features.

## Solution: the Strategy pattern

The Strategy pattern solves this problem by replacing conditionals with polymorphism. Each shipping method becomes an independent class that implements a common interface. The service delegates the choice of algorithm to the strategies:

```php
// Strategy interface
interface ShippingStrategyInterface
{
    public function calculateCost(Order $order): Money;
    public function supports(string $method): bool;
}

// Concrete strategy implementation
class ExpressShipping implements ShippingStrategyInterface
{
    public function calculateCost(Order $order): Money
    {
        $cost = Money::of(25.00);
        if ($order->getWeight() > 10) {
            $cost = $cost->add(Money::of(15.00));
        }
        return $cost;
    }

    public function supports(string $method): bool
    {
        return $method === 'express';
    }
}

// Context - uses strategies through polymorphism
class ShippingService
{
    public function __construct(
        private array $strategies // ShippingStrategyInterface[]
    ) {}

    public function calculateCost(Order $order): Money
    {
        foreach ($this->strategies as $strategy) {
            if ($strategy->supports($order->getShippingMethod())) {
                return $strategy->calculateCost($order);
            }
        }
        throw new InvalidArgumentException('Unknown shipping method');
    }
}
```

## The essence of the pattern

The Strategy pattern produces a clear separation: instead of one class knowing every algorithm, each algorithm knows only itself. The service receives a collection of strategies and queries each one's `supports()` method until it finds a match.

```
Before: one class, many conditionals (if/else)
After: many classes, one interface (polymorphism)
```

Why does this matter? When you add next-day delivery, you create a new class without touching the existing shipping methods. Changing the express shipping logic does not affect standard shipping. To test next-day delivery, you test that class alone. Each change has a single place. Each shipping method decides its own behavior—polymorphism eliminates the conditional chain.

## When to use the Strategy pattern

Use the Strategy pattern when you have several algorithms for the same operation and must choose among them at runtime. That includes payment processing (credit card, PayPal, cryptocurrency), discount calculation (percentage, fixed amount, tiered), and any scenario where conditionals multiply with each new variant.

Strategies shine when the algorithms are related but their implementations differ. Each shipping method calculates cost differently, yet all share the same interface. The pattern separates algorithm logic from client code and makes both independently testable and maintainable.

## Common mistake: strategy selection in the client

A common anti-pattern is for the client to take responsibility for choosing the strategy:

```php
// ❌ Bad example - the client decides which strategy to use
class OrderService
{
    public function processPayment(Order $order)
    {
        if ($order->getPaymentMethod() === 'credit_card') {
            $strategy = $this->creditCardStrategy;
        } else {
            $strategy = $this->paypalStrategy;
        }
        $strategy->process($order);
    }
}

// ✅ Good example - the strategy decides via supports()
class PaymentService
{
    public function __construct(private array $strategies) {}

    public function processPayment(Order $order)
    {
        foreach ($this->strategies as $strategy) {
            if ($strategy->supports($order->getPaymentMethod())) {
                return $strategy->process($order);
            }
        }
        throw new InvalidArgumentException('Unknown payment method');
    }
}
```

The client should not know about concrete strategy implementations. Doing so defeats the purpose—you have only moved the conditionals from one place to another. Encapsulate strategy selection inside the service using the `supports()` method. Let each strategy decide whether it can handle the request.

## SOLID principles

The Strategy pattern enforces the **single responsibility principle** by giving each strategy one algorithm to manage. It supports the **open/closed principle**—you can add a new shipping method by creating a new strategy class without changing the shipping service. It upholds the **Liskov substitution principle** because every strategy is interchangeable through the common interface. It illustrates the **dependency inversion principle** by depending on the strategy interface rather than concrete implementations.

## Testing

Strategies simplify testing dramatically. Without strategies, testing the shipping service requires one huge test that covers every shipping method together. Any change means retesting everything. With strategies, you can test each shipping method independently. Testing standard shipping needs only the StandardShipping class. The test target shrinks from one complex integration test to several simple unit tests.

## Key points

The Strategy pattern replaces conditionals with polymorphism. Use it when you have several algorithms for the same operation and must choose among them at runtime. Each strategy is independent, testable, and reusable. Keep strategies stateless—do not give them mutable internal state that accumulates across calls. That preserves thread safety and makes them safe to share across multiple requests. Pass the data they need as method arguments and return results as return values. Encapsulate strategy selection inside the service rather than pushing it to the client. The pattern follows the open/closed principle: you can add new strategies without modifying existing code.

---

**Next:** [Decorator Pattern & AOP](decorator-aop.html) - Separating cross-cutting concerns

**Previous:** [Null Object Pattern](../02-object-creation/null-object-pattern.html)
