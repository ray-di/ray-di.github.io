---
layout: docs-en
title: Repository Pattern
category: Manual
permalink: /manuals/1.0/en/study/04-architecture/repository-pattern.html
---
# Repository Pattern: Separating Data Access

## Problem

Data access code is mixed directly into the business logic. Consider an order service that needs to persist orders. The service contains SQL queries, schema knowledge, and database-specific details alongside the business rules:

```php
class OrderService
{
    public function __construct(private PDO $database) {}

    public function processOrder(Order $order): void
    {
        // Business logic and SQL mixed together!
        $stmt = $this->database->prepare(
            'INSERT INTO orders (customer_id, total, status) VALUES (?, ?, ?)'
        );
        $stmt->execute([
            $order->getCustomerId(),
            $order->getTotal(),
            $order->getStatus()
        ]);

        $orderId = $this->database->lastInsertId();

        foreach ($order->getItems() as $item) {
            $stmt = $this->database->prepare(
                'INSERT INTO order_items (order_id, product_id, quantity) VALUES (?, ?, ?)'
            );
            $stmt->execute([$orderId, $item->getProductId(), $item->getQuantity()]);
        }
    }
}
```

## Why It Is a Problem

This creates a fundamental coupling between the business logic and data storage. The service knows table names, column names, and SQL syntax. When you change from MySQL to MongoDB, you have to rewrite the service. Testing order processing requires a real database and test data.

The service violates the single responsibility principle by handling both domain behavior and the persistence mechanism. The query logic cannot be reused—every service that needs orders has to write its own SQL. A schema change ripples through every service method that touches orders.

## Solution: The Repository Pattern

The Repository pattern solves this problem by encapsulating data access behind a collection-like interface. Services work with domain objects through repository methods. The database details are hidden inside the repository implementation:

```php
// Repository interface - abstracts data access
interface OrderRepositoryInterface
{
    public function save(Order $order): void;
    public function findById(int $id): ?Order;
    public function findByCustomer(int $customerId): array;
}

// Implementation - hides the database details
class MySQLOrderRepository implements OrderRepositoryInterface
{
    public function __construct(private PDO $database) {}

    public function save(Order $order): void
    {
        if ($order->getId() === null) {
            $this->insert($order);
        } else {
            $this->update($order);
        }
    }

    public function findById(int $id): ?Order
    {
        $stmt = $this->database->prepare('SELECT * FROM orders WHERE id = ?');
        $stmt->execute([$id]);
        $data = $stmt->fetch();

        return $data ? $this->hydrate($data) : null;
    }

    public function findByCustomer(int $customerId): array
    {
        $stmt = $this->database->prepare(
            'SELECT * FROM orders WHERE customer_id = ? ORDER BY id'
        );
        $stmt->execute([$customerId]);

        return array_map(fn (array $data): Order => $this->hydrate($data), $stmt->fetchAll());
    }

    private function insert(Order $order): void { /* SQL INSERT logic */ }
    private function update(Order $order): void { /* SQL UPDATE logic */ }
    private function hydrate(array $data): Order { /* convert the array into an Order */ }
}

// Clean business logic - no database knowledge!
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository
    ) {}

    public function processOrder(Order $order): void
    {
        $this->orderRepository->save($order);
    }
}
```

## The Essence of the Pattern

The Repository pattern creates a clear separation: the service knows *what* it needs (save, find, delete), and the repository knows *how* to do it (SQL, MongoDB, cache). The interface defines operations as if you were working with an in-memory collection.

```
Before: Service → SQL → Database
After:  Service → Repository Interface → Implementation → Database
```

Why does this matter? When switching from MySQL to MongoDB, you change only the repository implementation. When adding caching, you create a `CachingOrderRepository` decorator. When testing the business logic, you mock the repository interface without a database. Each data access concern has a single place—the repository that implements it.

## When to Use the Repository Pattern

Use the Repository pattern when you have persistent domain objects accessed by multiple services. This includes entities such as orders, customers, and products that need queries, saves, and complex retrieval logic. Repositories excel when you need to abstract the database away from the business logic or switch storage implementations.

When data access logic is reusable, repositories provide value. If three services need to find orders by customer, one repository method serves all of them. When tests need a database abstraction, repositories make the business logic testable without fixtures.

## Granularity of Repository Interfaces

There are two approaches to designing repository interfaces.

### The general approach - a single interface grouping CRUD

```php
interface OrderRepositoryInterface
{
    public function findById(int $id): ?Order;
    public function findByCustomer(int $customerId): array;
    public function save(Order $order): void;
    public function delete(Order $order): void;
}
```

The basic purpose of the Repository pattern is to separate data access from the business logic. Grouping CRUD operations in one interface achieves this separation. Many applications take this approach.

### The ISP approach - toward code with clearer intent

```php
interface OrderReaderInterface
{
    public function findById(int $id): ?Order;
    public function findByCustomer(int $customerId): array;
}

interface OrderWriterInterface
{
    public function save(Order $order): void;
    public function delete(Order $order): void;
}
```

Following the interface segregation principle (ISP), separate reading from writing. A class that depends on `OrderReaderInterface` can be understood at the dependency level to only read. Without looking at the implementation, the intent is clear from the dependencies. Read-only classes can also be designed as immutable classes, making the code more predictable and safer.

**Decision criteria**: Start with the general approach. Consider the ISP approach when you want to narrow the capabilities of the interface a client depends on to the minimum necessary. Narrow the breadth of dependencies, so that a report service depends only on read operations and batch processing depends only on write operations.

## SOLID Principles

The Repository pattern enforces the **single responsibility principle** by separating data access from the business logic. It supports the **open/closed principle**—you switch from MySQL to MongoDB by changing only the repository binding, not the business services. It upholds the **Liskov substitution principle** because every repository implementation is interchangeable through the interface. It illustrates the **dependency inversion principle** by depending on the repository interface rather than concrete PDO, MongoDB, or cache implementations.

## Testing

Repositories dramatically simplify testing. Without a repository, testing order processing requires database setup, fixtures, transactions, and cleanup after every test. Every test needs a real database connection. With a repository, you mock the repository interface. Testing order processing needs only the repository mock. The scope of testing shrinks from database infrastructure to zero external dependencies.

## Key Points

The Repository pattern separates data access from the business logic through a collection-like interface. Use it when multiple services access the same persistent entity and you need database abstraction or testability. Repositories handle CRUD operations, and the business logic stays in the services. Avoid generic repositories—create type-specific repositories that provide domain-relevant query methods. This pattern makes it possible to switch implementations from MySQL to MongoDB to caching without touching the business code.

---

**Next:** [Service Layer](service-layer.html) - Coordinating business logic

**Previous:** [Adapter Pattern](adapter-pattern.html)
