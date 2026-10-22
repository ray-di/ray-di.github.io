---
layout: docs-en
title: Adapter Pattern
category: Manual
permalink: /manuals/1.0/en/study/04-architecture/adapter-pattern.html
---
# Adapter Pattern: Adapting an External API

## Problem

Using a third-party API or external service directly creates tight coupling to that API. Consider the case where you use Stripe as a payment service. What happens if the service layer calls the Stripe SDK directly?

```php
class OrderService
{
    public function processPayment(Order $order): void
    {
        // Use the Stripe API directly
        $stripe = new \Stripe\StripeClient($_ENV['STRIPE_SECRET_KEY']);

        try {
            $charge = $stripe->charges->create([
                'amount' => $order->getTotal() * 100, // Stripe uses the smallest currency unit
                'currency' => 'jpy',
                'source' => $order->getPaymentToken(),
                'description' => "Order {$order->getId()}"
            ]);

            $order->setPaymentId($charge->id);
            $order->setStatus('paid');
        } catch (\Stripe\Exception\CardException $e) {
            throw new PaymentFailedException($e->getMessage());
        }

        $this->orderRepository->save($order);
    }
}
```

## Why It Is a Problem

This design has a fundamental problem. The business logic knows too much about the concrete implementation details of Stripe. Stripe handles amounts in the smallest currency unit, throws specific exception types, and accepts payment information through a `source` parameter—all of this is Stripe-specific knowledge.

What if you want to switch to PayPal? You would need to rewrite `OrderService`, fix every test, and implement different error handling. It is also difficult to test without calling the real Stripe API. To create a mock, you need to know the internal implementation details of Stripe.

The problem with this code is that `OrderService`, which should focus on business logic, is exposed to the complexity of an external API. The complexity of integrating with the external API leaks into the entire application.

## Solution: The Adapter Pattern

The Adapter pattern solves this problem by adapting an external API to an interface of the application's own. This pattern bridges incompatible interfaces and aims to **hide the complexity from the client**.

### Structure of the Adapter Pattern

The Adapter pattern consists of three elements:

1. **Target** - the interface the application expects
2. **Adaptee** - the existing external API (not compatible with the Target)
3. **Adapter** - the translation layer that bridges the Target and the Adaptee

```
Client (OrderService)
    ↓ depends on
Target (PaymentGatewayInterface)
    ↓ implemented by
Adapter (StripeAdapter)
    ↓ delegates to
Adaptee (Stripe\StripeClient)
```

The client calls methods on the Target abstraction. The Adapter class is a class that implements the Target abstraction. When the client calls a Target method, the intent is to call a method on the Adaptee class, but the Adaptee class is not compatible with the Target, so that call cannot be made directly.

The Adapter class therefore sits between the two and translates the Target method call into an Adaptee method call, allowing the desired processing to be performed.

### Implementation Example

```php
// Target - the application's own interface
interface PaymentGatewayInterface
{
    public function charge(Money $amount, PaymentToken $token): PaymentResult;
}

// Domain value object
class PaymentResult
{
    public function __construct(
        public readonly string $transactionId,
        public readonly bool $successful,
        public readonly ?string $errorMessage = null
    ) {}
}

// Adapter - bridges the Target and the Adaptee
class StripeAdapter implements PaymentGatewayInterface
{
    public function __construct(
        private \Stripe\StripeClient $stripe  // Adaptee
    ) {}

    public function charge(Money $amount, PaymentToken $token): PaymentResult
    {
        try {
            // Translate into an Adaptee call (encapsulating the complexity)
            $charge = $this->stripe->charges->create([
                'amount' => $amount->getMinorUnits(), // already the API's smallest currency unit
                'currency' => strtolower($amount->getCurrency()->getCode()),
                'source' => $token->getValue(),
                'description' => $token->getDescription()
            ]);

            // Convert the Adaptee result into the Target format
            return new PaymentResult(
                transactionId: $charge->id,
                successful: true
            );
        } catch (\Stripe\Exception\CardException $e) {
            // Convert the Stripe-specific exception into a domain result
            return new PaymentResult(
                transactionId: '',
                successful: false,
                errorMessage: $e->getMessage()
            );
        }
    }
}

// Client - clean business logic
class OrderService
{
    public function __construct(
        private PaymentGatewayInterface $paymentGateway,  // depends on the Target
        private OrderRepositoryInterface $orderRepository
    ) {}

    public function processPayment(Order $order): void
    {
        // No Stripe-specific knowledge required
        $result = $this->paymentGateway->charge(
            $order->getTotal(),
            $order->getPaymentToken()
        );

        if (!$result->successful) {
            throw new PaymentFailedException($result->errorMessage);
        }

        $order->markAsPaid($result->transactionId);

        $this->orderRepository->save($order);
    }
}
```

Configuration in the DI container:

```php
$this->bind(PaymentGatewayInterface::class)->to(StripeAdapter::class);
```

## The Essence of the Pattern

### Real-world analogy: a USB adapter

Consider wanting to use a USB Type-A mouse with a laptop that only has a USB Type-C port:

- **Target**: the USB Type-C port (the interface the PC expects)
- **Adaptee**: the USB Type-A mouse (an existing device that is not compatible)
- **Adapter**: a USB Type-C to Type-A conversion adapter

The adapter absorbs the difference between the two. The PC only communicates over Type-C, and the mouse only understands Type-A. With the adapter in between, the two can work together without knowing about each other.

This is exactly the role of the Adapter pattern: bridging incompatible interfaces and **hiding the complexity from the client**.

### Purpose of the pattern

The purpose of the Adapter pattern is to **hide the complexity from the client**. Integrating with an external API often involves a lot of complex translation work:

- Converting data formats (decimal amounts to minor units, arrays to objects)
- Unifying error handling (exceptions to result objects)
- Absorbing differences in communication style (synchronous to asynchronous, REST to GraphQL)
- Handling authentication and authorization

By encapsulating this complexity in the Adapter class, the client code becomes simpler and no longer needs to depend on the details of the external API.

Whether the translation is simple or complex, applying the Adapter pattern is generally easy. Do not be surprised if a complex translation is required. After all, the very purpose of the Adapter pattern is to make that complexity invisible to the client.

```
External API (Stripe) → Adapter → Application interface
  (their language)     (translator)  (our language)
  (complex)          (hides complexity) (simple)
```

Why does this matter? When switching from Stripe to PayPal, you do not touch `OrderService` at all. You just create a new `PayPalAdapter` and change the binding. In tests, you inject a `MockPaymentGateway`. Changes to the external API are isolated inside the Adapter class. Each kind of change has a clear place to live.

## When to Use the Adapter Pattern

Use the Adapter pattern when integrating external services or third-party APIs. This includes external systems that the application does not control, such as payment gateways, email services, cloud storage, social media posting, and map services.

Adapters are also useful for bridging legacy code and new code. When an old system has its own interface, you can use it from new code through an Adapter. You can integrate it into a new architecture without rewriting the existing system.

They are also valuable when you need different implementations per environment. Use `LocalFileAdapter` in development and `S3Adapter` in production. Use `InMemoryAdapter` in tests to avoid real calls to external services.

When complex translation or integration logic is required, the Adapter is the ideal place to encapsulate that complexity. You can keep the client code simple while concentrating the necessary translation work in one place.

## The Repository Pattern Is Also a Kind of Adapter

In fact, the Repository pattern can be seen as a special case of the Adapter pattern. Its structure is **Target** (a collection-like interface), **Adapter** (such as `MySQLRepository`), and **Adaptee** (such as PDO or Eloquent), and it adapts a database API to the domain model. A Repository is an Adapter that "makes a database look like an object collection." Understanding it from this perspective makes the power of the Adapter pattern clearer.

## SOLID Principles

The Adapter pattern enforces the **single responsibility principle**. It separates the integration logic for an external API from the business logic. Each Adapter has the single responsibility of integrating with one external service.

It supports the **open/closed principle**. By creating a new Adapter, you can add a new service without changing existing code. Migrating from Stripe to PayPal is completed simply by adding a new `PayPalAdapter` and changing the binding.

Most importantly, it embodies the **dependency inversion principle**. You depend on an interface defined by the application, not on a concrete external SDK. The direction of the dependency is inverted: the external service adapts to the application, not the other way around.

## Testing

Adapters dramatically simplify testing. Without an Adapter, testing `OrderService` requires a real Stripe API key, tests fail because of network problems, and downtime of the external service halts the entire CI/CD pipeline.

With an Adapter, you just mock `PaymentGatewayInterface`. You can create a `FakePaymentGateway` for tests and easily simulate success or failure. The Adapter itself can also be tested independently. The scope of testing shrinks from the complexity of the external API to the simplicity of the domain interface.

## Key Points

The Adapter pattern bridges incompatible interfaces. Its purpose is to hide the complexity of integrating with an external system from the client.

It consists of three elements: the Target (the application's interface), the Adaptee (the external API), and the Adapter (the translation layer that bridges them).

Use it for third-party APIs, legacy code, and environment-specific implementations. The Adapter is the ideal place to encapsulate complex translation work. That is precisely why the Adapter exists.

A Repository is effectively an Adapter too—it can be seen as a special Adapter that adapts a database API to the domain model.

---

**Next:** [Repository Pattern](repository-pattern.html) - Separating data access (a special case of Adapter)

**Previous:** [Decorator Pattern & AOP](../03-behavioral/decorator-aop.html)
