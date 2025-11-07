---
layout: docs-en
title: Service Layer - Architecture Patterns
category: Manual
permalink: /manuals/1.0/en/tutorial/04-architecture-patterns/service-layer.html
---

# Service Layer - Architecture Patterns

## Learning Objectives

- Understand Fat Controller problems
- Learn how to coordinate business logic with Service Layer
- Understand transaction boundary management

## The Problem: Business Logic Scattered in Controllers

Business logic is written directly in controllers and cannot be reused.

```php
class OrderController
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private UserRepositoryInterface $userRepository,
        private PaymentGatewayInterface $paymentGateway,
        private EmailServiceInterface $emailService,
        private InventoryServiceInterface $inventoryService
    ) {}

    public function createOrder(Request $request): Response
    {
        // ❌ Problem: Business logic written directly in controller
        try {
            // User validation
            $user = $this->userRepository->findById($request->get('user_id'));
            if (!$user) {
                return new Response('User not found', 404);
            }

            // Inventory check
            foreach ($request->get('items') as $item) {
                if (!$this->inventoryService->isAvailable($item['product_id'], $item['quantity'])) {
                    return new Response('Insufficient inventory', 400);
                }
            }

            // Order creation
            $order = new Order($user->getId(), $request->get('items'), $total);
            $this->orderRepository->save($order);

            // Payment processing
            $result = $this->paymentGateway->charge($total, $request->get('token'));
            if (!$result->isSuccess()) {
                $this->orderRepository->delete($order);
                return new Response('Payment failed', 400);
            }

            // Inventory update
            $this->inventoryService->updateInventory($request->get('items'));

            // Email sending
            $this->emailService->sendOrderConfirmation($user, $order);

            return new Response('Order created', 201);
        } catch (Exception $e) {
            return new Response('Internal server error', 500);
        }
    }
}
```

### Why This Is a Problem

1. **Fat Controller**
   - Controller grows to over 100 lines
   - HTTP layer and business logic are mixed

2. **Cannot Reuse**
   - Same business logic can't be used in CLI or batch
   - Code duplication

3. **Testing Difficulty**
   - Business logic testing requires HTTP requests
   - Tests are slow

4. **Lack of Transaction Management**
   - Order saved when payment fails
   - Data consistency not guaranteed

## Solution: Introducing Service Layer

**Service Layer's Role**: Coordinate business logic and manage transaction boundaries

```php
// 1. Service Layer Interface
interface OrderServiceInterface
{
    public function createOrder(CreateOrderCommand $command): Order;
}

// Command Object (encapsulates input data)
class CreateOrderCommand
{
    public function __construct(
        public readonly int $userId,
        public readonly array $items,
        public readonly string $paymentToken
    ) {}
}

// 2. Service Layer Implementation
class OrderService implements OrderServiceInterface
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private UserRepositoryInterface $userRepository,
        private PaymentGatewayInterface $paymentGateway,
        private InventoryServiceInterface $inventoryService,
        private EmailServiceInterface $emailService
    ) {}

    #[Transactional]  // Transaction management with AOP
    public function createOrder(CreateOrderCommand $command): Order
    {
        // Step 1: Validation
        $user = $this->userRepository->findById($command->userId);
        if (!$user) {
            throw new UserNotFoundException();
        }

        $this->validateInventory($command->items);

        // Step 2: Order creation
        $total = $this->calculateTotal($command->items);
        $order = new Order($command->userId, $command->items, $total);
        $this->orderRepository->save($order);

        // Step 3: Payment processing
        $result = $this->paymentGateway->charge($total, $command->paymentToken);
        if (!$result->isSuccess()) {
            throw new PaymentFailedException();
        }

        // Step 4: Inventory update
        $this->inventoryService->updateInventory($command->items);

        // Step 5: Notification
        $this->emailService->sendOrderConfirmation($user, $order);

        return $order;
    }

    private function validateInventory(array $items): void
    {
        foreach ($items as $item) {
            if (!$this->inventoryService->isAvailable($item['product_id'], $item['quantity'])) {
                throw new InsufficientInventoryException();
            }
        }
    }

    private function calculateTotal(array $items): float
    {
        // Calculation logic
    }
}

// 3. Thin Controller
class OrderController
{
    public function __construct(
        private OrderServiceInterface $orderService
    ) {}

    public function createOrder(Request $request): Response
    {
        // ✅ Keep controller thin
        try {
            $command = new CreateOrderCommand(
                $request->get('user_id'),
                $request->get('items'),
                $request->get('payment_token')
            );

            $order = $this->orderService->createOrder($command);

            return new JsonResponse([
                'order_id' => $order->getId(),
                'status' => $order->getStatus()->value
            ], 201);
        } catch (UserNotFoundException $e) {
            return new JsonResponse(['error' => 'User not found'], 404);
        } catch (InsufficientInventoryException $e) {
            return new JsonResponse(['error' => $e->getMessage()], 400);
        } catch (PaymentFailedException $e) {
            return new JsonResponse(['error' => 'Payment failed'], 400);
        }
    }
}
```

## Pattern Essence

```
Layered Architecture:
┌─────────────────────┐
│  Presentation Layer │ ← OrderController (thin)
├─────────────────────┤
│  Application Layer  │ ← OrderService (business logic coordination)
├─────────────────────┤
│     Domain Layer    │ ← Order, User (business rules)
├─────────────────────┤
│ Infrastructure      │ ← Repositories, Email, Payment
└─────────────────────┘

Separation of Responsibilities:
- Controller: HTTP processing, exception handling
- Service: Business logic coordination, transaction boundaries
- Domain: Business rules
- Infrastructure: Integration with external systems
```

### What Service Layer Solves

1. **Clear Responsibilities**
   - Controller: HTTP request/response
   - Service: Business logic coordination
   - Repository: Data access

2. **Improved Reusability**
   ```php
   // HTTP endpoint
   class OrderController
   {
       public function createOrder(Request $request): Response
       {
           $order = $this->orderService->createOrder($command);
       }
   }

   // CLI command
   class CreateOrderCommand extends Command
   {
       protected function execute(InputInterface $input, OutputInterface $output): int
       {
           $order = $this->orderService->createOrder($command);  // Reuse
       }
   }
   ```

3. **Clear Transaction Boundaries**
   - Declare transaction boundaries with `#[Transactional]` attribute
   - Automatic rollback on payment failure

## Decision Criteria

```
Processing needed
│
├─ Multiple repositories/services needed?
│  ├─ YES → ✅ Application layer (Service)
│  └─ NO  ↓
│
├─ Business rule validation?
│  ├─ YES → Domain layer (Entity)
│  └─ NO  ↓
│
├─ Data access?
│  ├─ YES → Infrastructure layer (Repository)
│  └─ NO  → Presentation layer (Controller)
```

### What to Include in Service Layer

| Content | Reason |
|---------|--------|
| **Use case implementation** | Coordinate entire business flow |
| **Transaction boundaries** | Guarantee data consistency |
| **Multiple entity coordination** | Combine repositories and domain services |
| **External service integration** | Payment, email, notification, etc. |

### What Not to Include in Service Layer

| Content | Alternative Location |
|---------|---------------------|
| **HTTP request processing** | Controller (Presentation layer) |
| **Business rules** | Entity (Domain layer) |
| **Data access details** | Repository (Infrastructure layer) |

## Common Anti-patterns

### Anemic Domain Model

```php
// ❌ Domain model only has data
class Order
{
    public int $id;
    public int $userId;
    public string $status;
    // No business logic
}

// All logic in service
class OrderService
{
    public function cancelOrder(int $orderId): void
    {
        $order = $this->repository->findById($orderId);
        if ($order->status === 'completed') {  // Business rule leaks to service
            throw new InvalidOperationException();
        }
        $order->status = 'cancelled';
        $this->repository->save($order);
    }
}

// ✅ Rich Domain Model
class Order
{
    public function cancel(): void
    {
        // Business rules in domain
        if ($this->status === OrderStatus::Completed) {
            throw new InvalidOperationException();
        }
        $this->status = OrderStatus::Cancelled;
    }
}

class OrderService
{
    public function cancelOrder(int $orderId): void
    {
        $order = $this->repository->findById($orderId);
        $order->cancel();  // Delegate business rules to domain
        $this->repository->save($order);
    }
}
```

**Why it's a problem**: Business rules scattered in service layer, domain model meaningless

### God Service

```php
// ❌ Massive service that handles everything
class OrderService
{
    public function createOrder() {}
    public function cancelOrder() {}
    public function updateShipping() {}
    public function processRefund() {}
    public function generateInvoice() {}
    public function sendReminder() {}
    // 100 methods...
}

// ✅ Separate services by responsibility
class OrderService
{
    public function createOrder() {}
    public function cancelOrder() {}
}

class OrderShippingService
{
    public function updateShipping() {}
}

class OrderBillingService
{
    public function processRefund() {}
    public function generateInvoice() {}
}
```

**Why it's a problem**: Single Responsibility Principle violation, large change impact scope

## Relationship with SOLID Principles

- **SRP**: Service responsible for only one use case or related use cases
- **DIP**: Service depends on interfaces, eliminates dependency on concrete implementations

## Summary

### Service Layer Core

- **Business logic coordination**: Combine multiple repositories/services
- **Transaction boundaries**: Guarantee data consistency
- **Thin controllers**: Separate HTTP layer from business logic

### Pattern Benefits

- ✅ Reuse business logic across multiple interfaces (HTTP, CLI)
- ✅ Easy testing (no HTTP layer needed)
- ✅ Clear transaction management
- ✅ Improved maintainability

### Next Steps

As the final architecture pattern, let's learn module design.

**Continue to:** [Module Design](module-design.html)

---

The Service Layer forms **the core of the application**. By properly placing business logic and clarifying each layer's responsibilities, you can achieve highly maintainable and testable architecture.
