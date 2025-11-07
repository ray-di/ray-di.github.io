---
layout: docs-en
title: Provider Pattern - Object Creation Patterns
category: Manual
permalink: /manuals/1.0/en/tutorial/02-object-creation-patterns/provider-pattern.html
---

# Provider Pattern - Object Creation Patterns

## Learning Objectives

- Understand challenges when complex initialization logic is needed
- Learn how to encapsulate initialization with the Provider Pattern
- Understand the difference from Factory Pattern

## The Problem: Constructor Bloat from Complex Initialization

When object creation requires reading environment variables, multiple configurations, or conditional logic, constructors become bloated.

```php
class DatabaseConnection
{
    public function __construct()
    {
        // ❌ Problem: Initialization logic is too complex
        $host = getenv('DB_HOST') ?: 'localhost';
        $port = getenv('DB_PORT') ?: '3306';
        $dsn = "mysql:host={$host};port={$port};...";

        $this->pdo = new PDO($dsn, getenv('DB_USER'), getenv('DB_PASS'));
        $this->pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $this->pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

        // Connection pooling, logging configuration...
    }
}
```

### Why This Is a Problem

1. **Logic Execution in Constructor**
   - Constructors should only perform assignments
   - Complex logic is difficult to test

2. **Environment-Dependent Configuration**
   - Direct access to environment variables
   - Hard to use different configurations in tests

3. **Mixed Concerns**
   - "Using connection" and "initializing connection" are mixed
   - Single Responsibility Principle violation

## Solution: Provider Pattern

**Provider's Role**: Encapsulate complex initialization logic

```php
// 1. Simple Entity Class
class DatabaseConnection
{
    public function __construct(
        private PDO $pdo  // Keep it simple!
    ) {}

    public function query(string $sql, array $params = []): array
    {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }
}

// 2. Provider handles complex initialization
class DatabaseConnectionProvider implements ProviderInterface
{
    public function get(): DatabaseConnection
    {
        // Consolidate complex initialization logic here
        $dsn = $this->buildDsn();
        $username = getenv('DB_USER') ?: 'root';
        $password = getenv('DB_PASS') ?: '';

        $pdo = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);

        return new DatabaseConnection($pdo);
    }

    private function buildDsn(): string
    {
        return sprintf(
            "mysql:host=%s;port=%s;dbname=%s",
            getenv('DB_HOST') ?: 'localhost',
            getenv('DB_PORT') ?: '3306',
            getenv('DB_NAME') ?: 'app'
        );
    }
}

// 3. Bind in DI Module
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(DatabaseConnection::class)
            ->toProvider(DatabaseConnectionProvider::class)
            ->in(Singleton::class);
    }
}
```

## Pattern Essence

```
Regular DI:
DI Container → New Object (simple constructor)

Provider Binding:
DI Container → Provider.get() → Complex initialization → New Object
```

### What Provider Solves

1. **Separation of Concerns**
   - Entity: Business logic
   - Provider: Complex initialization

2. **Keep Constructors Simple**
   - Constructor only for assignments
   - Logic goes in provider

3. **Environment-Specific Switching**
   ```php
   // Development environment
   class DevDatabaseConnectionProvider implements ProviderInterface
   {
       public function get(): DatabaseConnection
       {
           return new DatabaseConnection(new PDO('sqlite::memory:'));
       }
   }

   // Production environment
   class ProdDatabaseConnectionProvider implements ProviderInterface
   {
       public function get(): DatabaseConnection
       {
           // Complex production configuration
       }
   }
   ```

## Difference Between Factory and Provider

| Feature | Factory Pattern | Provider Pattern |
|---------|----------------|------------------|
| **Purpose** | Inject runtime parameters | Encapsulate complex initialization |
| **Parameters** | Determined at runtime | Determined at configuration time |
| **Creation Frequency** | Created as needed | Usually singleton |
| **Ray.Di** | Factory class | `toProvider()` binding |

## Decision Criteria

```
Object creation needed
│
├─ Runtime parameters required?
│  ├─ YES → Factory Pattern
│  └─ NO  ↓
│
├─ Complex initialization?
│  ├─ YES → ✅ Provider binding
│  └─ NO  → Regular DI binding
```

### When to Use Provider

| Situation | Example |
|-----------|---------|
| **Reading environment variables** | Database connection, API configuration |
| **Multi-stage configuration** | Client initialization, config assembly |
| **Conditional logic** | Different implementations per environment |
| **External resource connection** | DB, filesystem, API |

## Common Anti-patterns

### Stateful Provider

```php
// ❌ Provider holds state
class DatabaseConnectionProvider implements ProviderInterface
{
    private ?DatabaseConnection $instance = null;  // State holding

    public function get(): DatabaseConnection
    {
        if ($this->instance === null) {
            $this->instance = $this->createConnection();
        }
        return $this->instance;
    }
}

// ✅ Manage singleton with scope
$this->bind(DatabaseConnection::class)
    ->toProvider(DatabaseConnectionProvider::class)
    ->in(Singleton::class);  // Ray.Di manages singleton
```

**Why it's a problem**: Unclear scope management responsibility, duplicates DI container functionality

### Misuse of Runtime Parameters

```php
// ❌ Use factory if runtime parameters are needed
class OrderProcessorProvider implements ProviderInterface
{
    public function get(): OrderProcessor
    {
        $orderId = $_GET['order_id'];  // Global variable reference
        return new OrderProcessor($orderId, ...);
    }
}

// ✅ Use Factory Pattern
interface OrderProcessorFactoryInterface
{
    public function create(int $orderId): OrderProcessor;
}
```

**Why it's a problem**: Confuses provider and factory responsibilities

## Relationship with SOLID Principles

- **SRP**: Provider is responsible only for "complex initialization"
- **DIP**: Depends on interfaces, hides initialization details
- **OCP**: Create different providers for different environments to extend

## Summary

### Provider Pattern Core

- **Encapsulate complex initialization**: Keep constructors simple
- **Environment-specific configuration**: Different providers for dev/prod
- **Testability**: Switch to in-memory implementation

### Selection Guide

- **Runtime parameters** → Factory Pattern
- **Complex initialization** → Provider binding
- **Simple dependencies** → Regular DI binding

### Next Steps

Now that you understand object creation patterns, let's learn how to switch behavior at runtime.

**Continue to:** [Strategy Pattern](../03-behavior-patterns/strategy-pattern.html)

---

The Provider Pattern keeps entity classes simple by **encapsulating initialization complexity**.
