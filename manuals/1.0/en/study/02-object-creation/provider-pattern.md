---
layout: docs-en
title: Provider Pattern
category: Manual
permalink: /manuals/1.0/en/study/02-object-creation/provider-pattern.html
---
# Provider Pattern: Separating Complex Initialization

## Problem

Have you ever needed complex initialization logic to create an object? Consider a database connection. It takes many steps: setting connection parameters, configuring the error mode, specifying the character set, setting the time zone, and more. Writing that logic in the constructor bloats the class:

```php
class DatabaseConnection
{
    public function __construct(
        private string $host,
        private string $database,
        private string $username,
        private string $password
    ) {
        // Problem: the constructor does a lot of work
        $this->connection = new PDO(
            "mysql:host={$host};dbname={$database}",
            $username,
            $password
        );
        $this->connection->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $this->connection->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        $this->connection->exec("SET NAMES utf8mb4");
        $this->connection->exec("SET time_zone = '+00:00'");

        if ($_ENV['DB_PROFILING']) {
            $this->connection->setAttribute(PDO::ATTR_STATEMENT_CLASS, [ProfilingStatement::class]);
        }
        // more configuration steps...
    }
}
```

## Why it's a problem

This creates a fundamental conflict between a simple constructor and complex initialization. A constructor should only assign dependencies, not execute logic. But this constructor performs connection setup, attribute configuration, and conditional initialization. It cannot be tested without a real database.

The constructor has two distinct responsibilities: assigning dependencies and environment-specific initialization. Changing the initialization logic requires changing the constructor, which makes the class fragile and hard to maintain.

## Solution: The Provider pattern

The Provider pattern solves this by separating initialization from construction. A dedicated provider handles the complex setup, and the constructor stays simple. Ray.Di calls the provider's `get()` method to perform initialization and returns the configured object:

```php
use Ray\Di\ProviderInterface;

// The provider handles complex initialization
class DatabaseConnectionProvider implements ProviderInterface
{
    public function __construct(
        private DatabaseConfigInterface $config
    ) {}

    public function get(): DatabaseConnection
    {
        $pdo = new PDO(
            $this->config->getDsn(),
            $this->config->getUsername(),
            $this->config->getPassword()
        );

        // Multi-step initialization here, not in the constructor
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        $pdo->exec("SET NAMES utf8mb4");
        $pdo->exec("SET time_zone = '+00:00'");

        if ($this->config->isProfiling()) {
            $pdo->setAttribute(PDO::ATTR_STATEMENT_CLASS, [ProfilingStatement::class]);
        }

        return new DatabaseConnection($pdo);
    }
}

// The constructor stays clean - assignment only
class DatabaseConnection
{
    public function __construct(private PDO $pdo) {}

    public function query(string $sql, array $params = []): array
    {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }
}
```

Configuring the provider binding:
```php
use Ray\Di\Scope;

$this->bind(DatabaseConnection::class)
     ->toProvider(DatabaseConnectionProvider::class)
     ->in(Scope::SINGLETON);
```

## The essence of the pattern

The Provider pattern creates a clear separation: the constructor receives "what" (dependencies), and the provider controls "how" (initialization). The DI container calls the provider, the provider performs the complex setup, and then returns the configured object.

```
DI container ──> Provider.get() ──> multi-step initialization ──> object
                                   (conditional logic,
                                    environment configuration)
```

Why does this matter? When you switch from the development environment to production, you change only the configuration object. When you add profiling, you modify only the provider. When you tune the connection pool, you do not touch the domain class. Each change has a single home. The domain object's constructor stays simple, focused on assigning dependencies.

## When to use the Provider pattern

Use the Provider pattern when object creation requires multi-step initialization. This includes environment-based conditional configuration, staged setup where order matters, and initialization that needs other dependencies.

Providers excel at environment-specific configuration. The development environment needs a different connection timeout than production. The test environment needs a different retry policy than staging. Providers centralize these variations in one place.

## Common mistake: stateful providers

Providers should be stateless. A frequently seen anti-pattern is caching an instance inside the provider:

```php
// ❌ Bad example - the provider manages the instance lifecycle
class CacheProvider implements ProviderInterface
{
    private ?Cache $instance = null;

    public function get(): Cache
    {
        if ($this->instance === null) {
            $this->instance = new Cache();
        }
        return $this->instance; // do not do this!
    }
}

// ✅ Good example - use scope for lifecycle management
use Ray\Di\Scope;

$this->bind(CacheInterface::class)
     ->toProvider(CacheProvider::class)
     ->in(Scope::SINGLETON); // DI handles the lifecycle
```

Let the DI container manage object lifecycles through scopes. The DI container handles concurrency and caching correctly. Each provider call either creates a new object or returns a cached instance—the scope decides, not your code. Providers should focus only on construction and initialization.

## Provider vs. Factory

Providers and factories solve different problems:

| Aspect | Provider | Factory |
|-----|----------|---------|
| Purpose | Complex initialization | Runtime parameters + DI |
| Caller | DI container | Your code |
| Parameters | None (uses injected dependencies) | Runtime parameters |
| Use case | Environment-specific setup | Objects that need runtime data |

Providers take no parameters. The DI container calls them while building the object graph. Factories receive runtime parameters and are called by your code when needed.

## SOLID principles

The Provider pattern enforces the **single responsibility principle** by separating initialization from domain logic. It supports the **open/closed principle** because you modify only the provider without touching the domain class. It upholds the **dependency inversion principle** by depending on a provider interface rather than concrete initialization logic.

## Testing

Providers allow initialization logic to be tested independently. Without a provider, testing environment-specific setup requires mocking PDO, the database connection, and the configuration reader. With a provider, you can test with nothing more than different configuration objects. The surface under test shrinks dramatically.

Create a provider with production configuration and verify that the production settings are applied. Create another provider with development configuration and verify that the development settings are applied. No complex mocks are needed. Domain objects stay simple, and no environment-specific test cases are required.

## Key points

The Provider pattern handles complex object initialization outside the constructor. Use it for multi-step setup, conditional configuration, and environment-specific initialization. Keep providers stateless and let DI manage object lifecycles. Providers differ from factories: no runtime parameters, called by DI, focused on initialization complexity.

---

**Next:** [Null Object Pattern](null-object-pattern.html) - Handling optional dependencies

**Previous:** [Factory Pattern](factory-pattern.html)
