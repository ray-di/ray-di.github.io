---
layout: docs-en
title: Strategy Pattern - Behavior Patterns
category: Manual
permalink: /manuals/1.0/en/tutorial/03-behavior-patterns/strategy-pattern.html
---

# Strategy Pattern - Behavior Patterns

## Learning Objectives

- Understand problems with conditional behavior switching
- Learn how to encapsulate algorithms with Strategy Pattern
- Understand how to use Ray.Di's annotated bindings (Named)

## The Problem: Proliferation of Conditional Logic

When you need to select different processing at runtime, conditional branches proliferate.

```php
class OrderService
{
    public function processPayment(Order $order, string $method): void
    {
        // ❌ Problem: Switching behavior with conditionals
        if ($method === 'credit_card') {
            $stripe = new StripeClient(getenv('STRIPE_KEY'));
            $stripe->charge($order->getTotal(), $order->getToken());
        } elseif ($method === 'paypal') {
            $paypal = new PayPalClient(getenv('PAYPAL_ID'));
            $paypal->createPayment($order->getTotal(), $order->getToken());
        } elseif ($method === 'bank_transfer') {
            $bank = new BankTransferService();
            $bank->initiateTransfer($order->getTotal(), $order->getAccount());
        }
        // Adding new payment methods → more branches
    }
}
```

### Why This Is a Problem

1. **Open-Closed Principle Violation**
   - Adding new payment method = modifying existing code
   - `OrderService` has multiple reasons to change

2. **Testing Difficulty**
   - Must initialize all payment gateways
   - Need test cases for every conditional branch

3. **Unclear Dependencies**
   - Don't know which dependencies are needed until runtime
   - Depends on all external services

## Solution: Strategy Pattern

**Strategy's Role**: Encapsulate algorithms (behaviors) and make them switchable at runtime

```php
// 1. Strategy Interface
interface PaymentStrategyInterface
{
    public function processPayment(Order $order): PaymentResult;
}

// 2. Strategy Implementations
class CreditCardPaymentStrategy implements PaymentStrategyInterface
{
    public function __construct(
        private StripeClient $client
    ) {}

    public function processPayment(Order $order): PaymentResult
    {
        $charge = $this->client->charge($order->getTotal(), $order->getToken());
        return new PaymentResult($charge->status === 'succeeded', $charge->id);
    }
}

class PayPalPaymentStrategy implements PaymentStrategyInterface
{
    public function __construct(
        private PayPalClient $client
    ) {}

    public function processPayment(Order $order): PaymentResult
    {
        $payment = $this->client->createPayment($order->getTotal(), $order->getToken());
        return new PaymentResult($payment->state === 'approved', $payment->id);
    }
}

// 3. Annotated Bindings with Ray.Di
class PaymentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(PaymentStrategyInterface::class)
            ->annotatedWith('credit_card')
            ->to(CreditCardPaymentStrategy::class);

        $this->bind(PaymentStrategyInterface::class)
            ->annotatedWith('paypal')
            ->to(PayPalPaymentStrategy::class);
    }
}

// 4. Strategy Factory
class PaymentStrategyFactory
{
    public function __construct(
        #[Named('credit_card')] private PaymentStrategyInterface $creditCard,
        #[Named('paypal')] private PaymentStrategyInterface $paypal
    ) {}

    public function getStrategy(string $method): PaymentStrategyInterface
    {
        return match($method) {
            'credit_card' => $this->creditCard,
            'paypal' => $this->paypal,
            default => throw new InvalidPaymentMethodException($method)
        };
    }
}

// 5. Client Code
class OrderService
{
    public function __construct(
        private PaymentStrategyFactory $factory
    ) {}

    public function processPayment(Order $order, string $method): void
    {
        // ✅ Delegate to Strategy Pattern
        $strategy = $this->factory->getStrategy($method);
        $result = $strategy->processPayment($order);

        if ($result->isSuccess()) {
            $order->markAsPaid($result->getTransactionId());
        } else {
            throw new PaymentFailedException();
        }
    }
}
```

## Pattern Essence

```
Conditional Approach:
Service → if/else → Direct use of concrete classes

Strategy Pattern:
Service → Factory → Strategy Interface → Concrete Implementation
         (Runtime)   (DI)                 (Polymorphism)
```

### What Strategy Solves

1. **Open-Closed Principle Compliance**
   ```php
   // Add new payment method
   class ApplePayStrategy implements PaymentStrategyInterface { ... }

   // Just add binding in module (no existing code change)
   $this->bind(PaymentStrategyInterface::class)
       ->annotatedWith('apple_pay')
       ->to(ApplePayStrategy::class);
   ```

2. **Single Responsibility Principle Compliance**
   - `CreditCardStrategy`: Credit card payment only
   - `OrderService`: Order processing coordination only

3. **Improved Testability**
   - Test each strategy independently
   - Swap with test strategies

## Ray.Di Annotated Bindings

**Challenge**: How to manage multiple implementations of the same interface?

```php
// ❌ Can't distinguish
$this->bind(PaymentStrategyInterface::class)->to(CreditCardStrategy::class);
$this->bind(PaymentStrategyInterface::class)->to(PayPalStrategy::class);  // Overwrite

// ✅ Distinguish with annotated bindings
$this->bind(PaymentStrategyInterface::class)
    ->annotatedWith('credit_card')  // Distinguish by name
    ->to(CreditCardStrategy::class);

$this->bind(PaymentStrategyInterface::class)
    ->annotatedWith('paypal')
    ->to(PayPalStrategy::class);

// Specify name at injection
public function __construct(
    #[Named('credit_card')] private PaymentStrategyInterface $creditCard,
    #[Named('paypal')] private PaymentStrategyInterface $paypal
) {}
```

## Decision Criteria

### When to Use Strategy Pattern

| Situation | Reason |
|-----------|--------|
| **Multiple ways of same operation** | Payment methods, shipping methods, calculation algorithms |
| **Growing conditional branches** | if/else or switch duplicated in multiple places |
| **Runtime switching** | Behavior changes based on user selection or configuration |

### When to Consider Other Patterns

| Situation | Alternative Pattern |
|-----------|-------------------|
| **Single behavior only** | Simple implementation is sufficient |
| **Static behavior** | Provider binding |
| **Cross-cutting concerns** | AOP/Interceptor |

### Decision Flow

```
Multiple ways of same operation exist?
│
├─ YES → Need runtime switching?
│         ├─ YES → ✅ Strategy Pattern
│         └─ NO  → Provider binding
│
└─ NO  → Strategy Pattern unnecessary
```

## Common Anti-patterns

### Stateful Strategy

```php
// ❌ Strategy holds state
class CreditCardStrategy implements PaymentStrategyInterface
{
    private array $processedOrders = [];  // State holding

    public function processPayment(Order $order): PaymentResult
    {
        $this->processedOrders[] = $order;  // NG
        // ...
    }
}

// ✅ Stateless strategy
class CreditCardStrategy implements PaymentStrategyInterface
{
    public function processPayment(Order $order): PaymentResult
    {
        // Only receive arguments and return result
        return new PaymentResult(...);
    }
}
```

**Why it's a problem**: Strategies should only hold pure behavior

### Dispersed Selection Logic

```php
// ❌ Selection logic dispersed in multiple places
class OrderService
{
    public function processPayment(Order $order, string $method): void
    {
        $strategy = match($method) {  // Selection logic
            'credit_card' => $this->creditCard,
            // ...
        };
    }
}

class InvoiceService
{
    public function generateInvoice(Order $order, string $method): void
    {
        $strategy = match($method) {  // Same selection logic duplicated
            'credit_card' => $this->creditCard,
            // ...
        };
    }
}

// ✅ Centralize selection logic in factory
class PaymentStrategyFactory
{
    public function getStrategy(string $method): PaymentStrategyInterface
    {
        // Consolidate selection logic in one place
    }
}
```

**Why it's a problem**: Changes to selection logic affect many places

## Relationship with SOLID Principles

- **OCP**: Adding new strategies doesn't modify existing code
- **SRP**: Each strategy is responsible for only one algorithm
- **LSP**: All strategies implement the same interface
- **DIP**: Client depends on abstraction (interface)

## Summary

### Strategy Pattern Core

- **Algorithm encapsulation**: Make behaviors switchable
- **Annotated bindings**: Manage multiple implementations of same interface
- **Factory**: Centralize strategy selection logic

### Pattern Benefits

- ✅ No existing code changes when adding new features (OCP)
- ✅ Each strategy can be tested independently
- ✅ Eliminate conditionals, improve readability
- ✅ Clear dependencies

### Next Steps

Now that you've learned behavior switching, let's learn how to handle cross-cutting concerns (logging, transactions).

**Continue to:** [Decorator Pattern/AOP](decorator-pattern-aop.html)

---

The Strategy Pattern achieves extensible and maintainable code by **replacing conditionals with polymorphism**.
