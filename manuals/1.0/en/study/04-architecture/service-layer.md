---
layout: docs-en
title: Service Layer
category: Manual
permalink: /manuals/1.0/en/study/04-architecture/service-layer.html
---
# Service Layer: Coordinating Business Logic

## Problem

Business logic is embedded directly in the controller. Consider an endpoint that processes orders. Business rules, validation, and inventory checks are mixed into the code that handles the HTTP request. The controller is bloated with domain logic and can no longer be reused:

```php
class OrderController
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private InventoryServiceInterface $inventoryService,
        private PaymentGatewayInterface $paymentGateway
    ) {}

    public function createOrder(Request $request): Response
    {
        // Validation mixed with the HTTP layer
        if (!$request->has('items') || empty($request->get('items'))) {
            return new Response('Items required', 400);
        }

        // Business logic embedded in the controller!
        $order = new Order($request->get('customer_id'));
        foreach ($request->get('items') as $itemData) {
            if (!$this->inventoryService->isAvailable($itemData['product_id'], $itemData['quantity'])) {
                return new Response('Insufficient inventory', 400);
            }
            $order->addItem($itemData['product_id'], $itemData['quantity']);
        }

        $this->paymentGateway->charge($order->getTotal());
        $this->orderRepository->save($order);

        return new Response('Order created', 201);
    }
}
```

## Why It Is a Problem

This creates a fundamental coupling between the presentation layer and the business logic. If you want to use order processing from a CLI command, an API endpoint, or a background job, you cannot, because the business logic is trapped in the HTTP controller. You cannot test validation, inventory checks, or payment processing on their own—you need a full HTTP request.

The controller violates the single responsibility principle by handling both HTTP-related tasks and business rules. Changing request mapping from a JSON API to GraphQL should not affect the business logic. Here, however, they are inseparably coupled. When multiple endpoints need order processing, you have no choice but to duplicate the logic or share it between controllers—both are anti-patterns.

## Solution: Service Layer

The Service Layer pattern solves this problem by separating the business logic from the presentation layer. The controller stays simple and handles only request mapping, the service coordinates the business rules, and the repository handles data access:

```php
// Service Layer - coordinates the business logic
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private InventoryServiceInterface $inventoryService,
        private PaymentGatewayInterface $paymentGateway
    ) {}

    public function createOrder(int $customerId, array $items): Order
    {
        $this->validateItems($items);

        $order = new Order($customerId);
        foreach ($items as $item) {
            $this->validateInventory($item['product_id'], $item['quantity']);
            $order->addItem($item['product_id'], $item['quantity']);
        }

        // Persist the pending order first: a charge must never succeed without a stored order
        $this->orderRepository->save($order);

        $this->paymentGateway->charge($order->getTotal());

        // Mark the order paid only after the gateway confirms
        $order->markAsConfirmed();
        $this->orderRepository->save($order);

        return $order;
    }

    private function validateItems(array $items): void
    {
        if (empty($items)) {
            throw new InvalidArgumentException('Items required');
        }
    }

    private function validateInventory(int $productId, int $quantity): void
    {
        if (!$this->inventoryService->isAvailable($productId, $quantity)) {
            throw new InvalidArgumentException('Insufficient inventory');
        }
    }
}

// Thin Controller - only HTTP mapping
class OrderController
{
    public function __construct(private OrderService $orderService) {}

    public function createOrder(Request $request): Response
    {
        $customerId = $request->get('customer_id');
        $items = $request->get('items');

        // Reject malformed input before the typed service call
        if (!is_numeric($customerId) || !is_array($items)) {
            return new Response('Invalid request', 400);
        }

        try {
            $order = $this->orderService->createOrder((int) $customerId, $items);
            return new Response('Order created', 201);
        } catch (InvalidArgumentException $e) {
            return new Response($e->getMessage(), 400);
        }
    }
}
```

A database transaction cannot undo an external payment, so the pending order is stored before the gateway is called. If the process stops between those two steps, that stored pending order is the record to reconcile: the charge must be idempotent (keyed by the order ID, for example), or the failure must be compensated with a refund.

## The Essence of the Pattern

The Service Layer pattern creates a clear separation of responsibilities: the controller handles HTTP requests and responses. The service coordinates the business logic. The repository handles data access. Each layer knows a single concern.

```
Before: Controller → business logic + data access
After:  Controller → Service → Repository
```

Why does this matter? When switching from REST to GraphQL, you do not touch the service—you just write a new controller. When adding a CLI command, you reuse the service—no duplication of business logic. When testing order processing, you test the service without HTTP—no need to mock the entire HTTP context. The business logic is written once and can be used from anywhere. Each layer is independently testable and replaceable.

## When to Use Service Layer

Use Service Layer when the same business logic must be accessible from multiple entry points. This includes order processing, user registration, and payment processing accessed from REST APIs, GraphQL, CLI commands, and background jobs. When the business logic is complex and needs to coordinate multiple repositories and services, the service layer encapsulates that coordination.

Services excel when you need to separate the business logic from the presentation layer or test the business rules independently. When a controller is bloated with business logic, a service layer keeps the controller simple. When the business logic spans multiple domain objects, the service provides transaction boundaries and workflow coordination.

## Services and Object-Oriented Programming

Service Layer is a hybrid of object-oriented and procedural programming. Domain objects have behavior (object-oriented), while services are essentially procedural programming that operates on objects.

### Give domain objects their behavior

```php
// ✅ The domain object behaves autonomously (object-oriented)
class Order
{
    public function validate(): void
    {
        if (empty($this->items)) {
            throw new InvalidOrderException();
        }
    }

    public function markAsConfirmed(): void
    {
        if ($this->status !== 'pending') {
            throw new InvalidStateException();
        }
        $this->status = 'confirmed';
    }
}
```

Implement domain concepts (validation, state transitions, calculations) as methods on domain objects. `Order` is not merely a data container; it is responsible for managing its own state.

### Services focus on coordination

```php
// The service coordinates domain objects
class OrderService
{
    public function processOrder(Order $order): void
    {
        // Delegate the domain logic to Order
        $order->validate();

        // Coordinate with the inventory service
        if (!$this->inventoryService->reserve($order->getItems())) {
            throw new InsufficientInventoryException();
        }

        // Delegate the domain logic to Order
        $order->markAsConfirmed();

        // Coordinate with the repository
        $this->orderRepository->save($order);
    }
}
```

Services do not hold domain logic; they focus on coordinating domain objects and infrastructure. The validation logic is delegated to `Order.validate()`, and the state transition logic is delegated to `Order.markAsConfirmed()`. The service does not know *how* to validate or *how* to transition state. It only knows the procedure—*when* to validate and *when* to transition state.

### Avoid anemic domain models

```php
// ❌ Bad example - business logic in the service
class Order
{
    public function setStatus(string $status): void { }  // merely data
}

class OrderService
{
    public function confirmOrder(Order $order): void
    {
        // Business logic (the state transition rule) in the service
        if ($order->getStatus() !== 'pending') {
            throw new InvalidStateException();
        }
        $order->setStatus('confirmed');
    }
}
```

A domain object that has only getters and setters is called an "anemic domain model." The business logic—the state transition rule that an order cannot be confirmed unless it is pending—has leaked into the service. This rule belongs in the `markAsConfirmed()` method of the `Order` class.

**Principle**: Write domain logic in domain objects. Do not put business logic in services; have them focus on coordinating domain objects.

## Common Mistake: Fat Services

A frequently seen anti-pattern is cramming all the business logic into one enormous service:

```php
// ❌ Bad example - a single huge service handles everything
class OrderService
{
    public function createOrder(...) { }
    public function cancelOrder(...) { }
    public function refundOrder(...) { }
    public function shipOrder(...) { }
    public function trackShipment(...) { }
    public function calculateShipping(...) { }
    public function validateAddress(...) { }
    public function sendOrderEmail(...) { }
    // 12 methods, 500 lines...
}

// ✅ Good example - split services by feature
class OrderService
{
    public function createOrder(...) { }
    public function cancelOrder(...) { }
}

class ShippingService
{
    public function shipOrder(...) { }
    public function trackShipment(...) { }
    public function calculateCost(...) { }
}

class OrderNotificationService
{
    public function sendOrderConfirmation(...) { }
    public function sendShipmentNotification(...) { }
}
```

A service groups related business logic, but it should not contain everything. Shipping calculation is a different concern from order creation—it belongs in `ShippingService`. Notification is a different concern from the order workflow—it belongs in `NotificationService`. A service focuses on one domain entity or a closely related set of operations. If a service has more than 10 methods or exceeds 500 lines, split it into smaller services.

## SOLID Principles

The Service Layer pattern enforces the **single responsibility principle** by giving each service a single cohesive responsibility. The controller handles HTTP, the service handles business logic, and the repository handles data access. It supports the **open/closed principle**—you can add new controllers (REST, GraphQL, CLI) without changing the business logic. Finally, the **dependency inversion principle** holds: the service depends on interfaces such as `OrderRepositoryInterface` and `PaymentGatewayInterface`, not on MySQL or Stripe.

## Testing

Service Layer dramatically simplifies testing. Without a service, testing order processing requires a full HTTP request, routing, request parameter mapping, and response parsing—every test becomes a framework integration test. With a service, you test the business logic directly. Testing order processing needs only `OrderService` and mocked dependencies. The scope of testing shrinks from integration tests involving HTTP infrastructure to unit tests focused on business logic.

## Key Points

Service Layer separates the business logic from the presentation layer. Use it when multiple entry points (REST, GraphQL, CLI) need the same business logic, or when the business rules are complex and need independent testing. Keep controllers simple—map the request, call the service, return the response. The service coordinates the business logic—handling validation, workflows, and transaction boundaries. The repository handles data access. Do not cram all the business logic into one huge service—create focused services for each set of related operations.

---

**Next:** [Module Design](module-design.html) - Organizing DI configuration

**Previous:** [Repository Pattern](repository-pattern.html)
