---
layout: docs-en
title: Repository Pattern - Architecture Patterns
category: Manual
permalink: /manuals/1.0/en/tutorial/04-architecture-patterns/repository-pattern.html
---

# Repository Pattern - Architecture Patterns

## Learning Objectives

- Understand mixed data access logic and business logic
- Learn how to separate domain and infrastructure with Repository Pattern
- Understand importance in Domain-Driven Design (DDD)

## The Problem: Scattered Data Access Logic

SQL and database operations are written directly in business logic.

```php
class OrderService
{
    public function __construct(
        private PDO $pdo
    ) {}

    public function processOrder(int $orderId): void
    {
        // ❌ Problem: Business logic mixed with data access
        $stmt = $this->pdo->prepare('SELECT * FROM orders WHERE id = ?');
        $stmt->execute([$orderId]);
        $orderData = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$orderData) {
            throw new OrderNotFoundException();
        }

        // Business logic
        $orderData['status'] = 'processing';
        $orderData['processed_at'] = date('Y-m-d H:i:s');

        // Data update
        $stmt = $this->pdo->prepare(
            'UPDATE orders SET status = ?, processed_at = ? WHERE id = ?'
        );
        $stmt->execute([
            $orderData['status'],
            $orderData['processed_at'],
            $orderId
        ]);
    }
}
```

### Why This Is a Problem

1. **Single Responsibility Principle Violation**
   - `OrderService` handles both business logic and data access
   - SQL and business rules are mixed

2. **Testing Difficulty**
   - Business logic testing requires actual database
   - Unit tests are slow

3. **Strong Coupling to Database Technology**
   - MySQL to PostgreSQL change = modify all services
   - Migrating to ORM is difficult

## Solution: Repository Pattern

**Repository's Role**: Abstract data access and treat it like a collection

```php
// 1. Domain Model (Business Rules)
class Order
{
    public function __construct(
        private int $id,
        private int $userId,
        private OrderStatus $status,
        private ?DateTimeImmutable $processedAt = null
    ) {}

    // Business logic
    public function process(): void
    {
        if ($this->status === OrderStatus::Cancelled) {
            throw new InvalidOperationException();
        }
        $this->status = OrderStatus::Processing;
        $this->processedAt = new DateTimeImmutable();
    }

    public function getId(): int { return $this->id; }
    public function getStatus(): OrderStatus { return $this->status; }
}

// 2. Repository Interface (Domain Layer)
interface OrderRepositoryInterface
{
    public function findById(int $id): ?Order;
    public function save(Order $order): void;
}

// 3. Repository Implementation (Infrastructure Layer)
class MySQLOrderRepository implements OrderRepositoryInterface
{
    public function __construct(
        private PDO $pdo
    ) {}

    public function findById(int $id): ?Order
    {
        $stmt = $this->pdo->prepare('SELECT * FROM orders WHERE id = ?');
        $stmt->execute([$id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);

        return $data ? $this->hydrate($data) : null;
    }

    public function save(Order $order): void
    {
        $data = $this->extract($order);

        if ($this->exists($order->getId())) {
            $this->update($data);
        } else {
            $this->insert($data);
        }
    }

    /** Database row → Domain object */
    private function hydrate(array $data): Order
    {
        return new Order(
            id: (int) $data['id'],
            userId: (int) $data['user_id'],
            status: OrderStatus::from($data['status']),
            processedAt: $data['processed_at']
                ? new DateTimeImmutable($data['processed_at'])
                : null
        );
    }

    /** Domain object → Database row */
    private function extract(Order $order): array
    {
        return [
            'id' => $order->getId(),
            'user_id' => $order->getUserId(),
            'status' => $order->getStatus()->value,
            'processed_at' => $order->getProcessedAt()?->format('Y-m-d H:i:s')
        ];
    }
}

// 4. Clean Service Layer
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository
    ) {}

    public function processOrder(int $orderId): void
    {
        // ✅ Doesn't know data access details
        $order = $this->orderRepository->findById($orderId);

        if (!$order) {
            throw new OrderNotFoundException();
        }

        // Business logic
        $order->process();

        // Persistence (repository handles details)
        $this->orderRepository->save($order);
    }
}
```

## Pattern Essence

```
Layered Architecture:
┌────────────────────┐
│  Application Layer │ ← OrderService (business logic coordination)
├────────────────────┤
│    Domain Layer    │ ← Order, OrderRepositoryInterface
├────────────────────┤
│ Infrastructure     │ ← MySQLOrderRepository (data access)
└────────────────────┘

Dependency Direction:
Application → Domain ← Infrastructure
              ↑
         Interface
```

### What Repository Solves

1. **Separation of Concerns**
   - Domain layer: Business rules and entities
   - Infrastructure layer: Database, external APIs

2. **Testability**
   ```php
   // In-memory repository for testing
   class InMemoryOrderRepository implements OrderRepositoryInterface
   {
       private array $orders = [];

       public function findById(int $id): ?Order
       {
           return $this->orders[$id] ?? null;
       }

       public function save(Order $order): void
       {
           $this->orders[$order->getId()] = $order;
       }
   }

   // Unit test
   $repository = new InMemoryOrderRepository();
   $service = new OrderService($repository);
   // Fast test, no database needed
   ```

3. **Database Technology Switching**
   ```php
   // Switch to PostgreSQL
   class PostgreSQLOrderRepository implements OrderRepositoryInterface
   {
       // Same interface, different implementation
   }

   // Switch in module
   $this->bind(OrderRepositoryInterface::class)
       ->to(PostgreSQLOrderRepository::class);
   ```

## Decision Criteria

```
Data access needed
│
├─ Complex business logic?
│  ├─ YES → Multiple data sources?
│  │         ├─ YES → ✅ Repository Pattern
│  │         └─ NO  → Test ease important?
│  │                   ├─ YES → ✅ Repository Pattern
│  │                   └─ NO  → ORM is sufficient
│  └─ NO  → Simple CRUD?
│            ├─ YES → Active Record
│            └─ NO  → ✅ Repository Pattern
```

### When to Use Repository Pattern

| Situation | Reason |
|-----------|--------|
| **Domain-Driven Design** | Separate business logic from infrastructure |
| **Multiple data sources** | MySQL, MongoDB, external APIs, etc. |
| **Test-Driven Development** | Fast tests with in-memory repository |
| **Complex queries** | Encapsulate queries with Specification pattern |

### When Repository Is Excessive

| Situation | Alternative |
|-----------|------------|
| **Simple CRUD** | Active Record pattern |
| **Small projects** | Direct ORM use |
| **Read-only** | Query service |

## Common Anti-patterns

### Leaky Abstraction

```php
// ❌ Returns PDOStatement (implementation detail leaks)
interface OrderRepositoryInterface
{
    public function findById(int $id): PDOStatement;
}

// ✅ Returns domain object
interface OrderRepositoryInterface
{
    public function findById(int $id): ?Order;
}
```

**Why it's a problem**: Interface depends on infrastructure details

### Generic Repository

```php
// ❌ Generic repository for all entities
interface GenericRepositoryInterface
{
    public function find(string $entityClass, int $id): ?object;
}

// ✅ Entity-specific repository
interface OrderRepositoryInterface
{
    public function findById(int $id): ?Order;
    public function findByUserId(int $userId): array;
}
```

**Why it's a problem**: Loss of type safety, can't express domain-specific operations

### Business Logic in Repository

```php
// ❌ Repository has business logic
class OrderRepository implements OrderRepositoryInterface
{
    public function save(Order $order): void
    {
        // Don't execute business logic in repository!
        if ($order->getTotal() > 10000) {
            $this->sendNotification($order);
        }
        $this->persist($order);
    }
}

// ✅ Repository for data access only
class OrderRepository implements OrderRepositoryInterface
{
    public function save(Order $order): void
    {
        $this->persist($order);  // Data access only
    }
}
```

**Why it's a problem**: Unclear responsibility, business rules leak to infrastructure layer

## Relationship with SOLID Principles

- **SRP**: Repository only for data access, service only for business logic
- **OCP**: Adding new data sources doesn't modify existing code
- **LSP**: All repository implementations implement the same interface
- **ISP**: Dedicated repository interface per entity
- **DIP**: Service layer depends on repository interface, not concrete implementation

## Summary

### Repository Pattern Core

- **Data access abstraction**: Domain layer doesn't know infrastructure details
- **Testability**: Fast tests with in-memory repository
- **Database technology switching**: No impact on service layer

### Pattern Benefits

- ✅ Business logic doesn't know data access details
- ✅ Database technology changes don't affect service layer
- ✅ Fast unit tests (in-memory implementation)
- ✅ Eliminate SQL query duplication

### Next Steps

Now that you've abstracted the data access layer, let's learn business logic coordination.

**Continue to:** [Service Layer](service-layer.html)

---

The Repository Pattern is **one of the core patterns of Domain-Driven Design**. It protects the domain model from infrastructure and keeps business logic clean.
