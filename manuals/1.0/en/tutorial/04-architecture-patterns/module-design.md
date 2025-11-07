---
layout: docs-en
title: Module Design - Architecture Patterns
category: Manual
permalink: /manuals/1.0/en/tutorial/04-architecture-patterns/module-design.html
---

# Module Design - Architecture Patterns

## Learning Objectives

- Understand DI configuration bloat problems
- Learn how to split configuration by concern with modules
- Understand module configuration per environment

## The Problem: Bloated DI Configuration

Writing all bindings in one module makes management difficult.

```php
class ApplicationModule extends AbstractModule
{
    protected function configure(): void
    {
        // ❌ Problem: Database, services, external APIs, environment branches all mixed

        // Database related
        $this->bind(PDO::class)->toProvider(PDOProvider::class)->in(Singleton::class);
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);

        // Service layer
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);

        // External services
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
        $this->bind(PaymentGatewayInterface::class)->to(StripePaymentGateway::class);

        // Environment branching
        if (getenv('APP_ENV') === 'production') {
            $this->bind(CacheInterface::class)->to(RedisCache::class);
        } else {
            $this->bind(CacheInterface::class)->to(ArrayCache::class);
        }

        // Continues for 100 more lines...
    }
}
```

### Why This Is a Problem

1. **Unclear Responsibilities**
   - Database, external services, environment config all mixed
   - Massive module with over 300 lines

2. **Reduced Maintainability**
   - Difficult to find related bindings
   - Unclear change impact scope

3. **Difficult to Reuse**
   - Can't use just some features in another project
   - Test configuration mixed with production configuration

## Solution: Module Splitting

**Module's Role**: Split DI configuration by concern and combine for use

### Approach 1: Split by Layer

```php
// 1. Database Layer Module
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(PDO::class)->toProvider(PDOProvider::class)->in(Singleton::class);
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
    }
}

// 2. Service Layer Module
class ServiceModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        $this->bind(UserServiceInterface::class)->to(UserService::class);
    }
}

// 3. AOP Layer Module
class AopModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Transactional::class),
            [TransactionalInterceptor::class]
        );
    }
}

// 4. Combination
class ApplicationModule extends AbstractModule
{
    protected function configure(): void
    {
        // ✅ Combine modules
        $this->install(new DatabaseModule());
        $this->install(new ServiceModule());
        $this->install(new AopModule());
    }
}
```

### Approach 2: Split by Environment

```php
// 1. Common Module
class CommonModule extends AbstractModule
{
    protected function configure(): void
    {
        // Bindings common to all environments
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);

        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Transactional::class),
            [TransactionalInterceptor::class]
        );
    }
}

// 2. Development Environment Module
class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new CommonModule());

        // Development-specific bindings
        $this->bind(PDO::class)->toProvider(SQLitePDOProvider::class);
        $this->bind(CacheInterface::class)->to(ArrayCache::class);
        $this->bind(EmailServiceInterface::class)->to(LogEmailService::class);
    }
}

// 3. Production Environment Module
class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new CommonModule());

        // Production-specific bindings
        $this->bind(PDO::class)->toProvider(MySQLPDOProvider::class)->in(Singleton::class);
        $this->bind(CacheInterface::class)->to(RedisCache::class)->in(Singleton::class);
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
    }
}

// 4. Environment-Specific Module Selection
class Application
{
    public function __construct()
    {
        $module = match(getenv('APP_ENV')) {
            'production' => new ProductionModule(),
            'development' => new DevelopmentModule(),
            default => throw new InvalidEnvironmentException()
        };

        $this->injector = new Injector($module);
    }
}
```

## Pattern Essence

```
Bloated Module:
ApplicationModule
├─ Database configuration
├─ Service configuration
├─ External API configuration
├─ Environment branching
└─ 300 lines...

After Module Splitting:
Split by Layer               Split by Environment
├── DatabaseModule          ├── CommonModule
├── ServiceModule           ├── DevelopmentModule
├── PaymentModule           ├── ProductionModule
└── AopModule               └── TestModule

ApplicationModule
└── Combine with install()
```

### What Module Splitting Solves

1. **Separation of Concerns**
   - Database: DatabaseModule
   - Business logic: ServiceModule
   - Cross-cutting concerns: AopModule

2. **Environment-Specific Configuration Management**
   - Development: SQLite, memory cache, log email
   - Production: MySQL, Redis, SMTP

3. **Improved Reusability**
   ```php
   // Project A uses all
   $this->install(new DatabaseModule());
   $this->install(new PaymentModule());

   // Project B uses only some
   $this->install(new DatabaseModule());
   // PaymentModule not needed
   ```

## Decision Criteria

```
Module bloat
│
├─ Over 100 lines?
│  ├─ YES → Multiple concerns?
│  │         ├─ YES → ✅ Split by layer
│  │         └─ NO  → Differs by environment?
│  │                   ├─ YES → ✅ Split by environment
│  │                   └─ NO  → Keep as is
│  └─ NO  ↓
│
├─ Want to reuse?
│  ├─ YES → ✅ Split by reuse unit
│  └─ NO  → Keep as is
```

### When to Split Modules

| Situation | Reason |
|-----------|--------|
| **Clearly different concerns** | Database, email, payment, etc. |
| **Different implementations per environment** | Production, development, test |
| **Over 100 lines of bindings** | Split for maintainability |

### When Module Splitting Is Excessive

| Situation | Alternative |
|-----------|------------|
| **5 or fewer bindings** | One module is sufficient |
| **Closely related bindings** | Don't split, keep in one module |
| **Won't reuse** | Splitting unnecessary |

## Common Anti-patterns

### Over-Splitting

```php
// ❌ Many modules with 1 binding each
class UserRepositoryModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
    }
}

class OrderRepositoryModule extends AbstractModule  // 50 modules...
{
    protected function configure(): void
    {
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
    }
}

// ✅ Group related bindings
class RepositoryModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
    }
}
```

**Why it's a problem**: Too many modules make management difficult, excessive file count

### Hardcoded Environment Detection

```php
// ❌ Environment detection in module
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        if (getenv('APP_ENV') === 'production') {
            $this->bind(PDO::class)->toProvider(MySQLPDOProvider::class);
        } else {
            $this->bind(PDO::class)->toProvider(SQLitePDOProvider::class);
        }
    }
}

// ✅ Separate modules per environment
class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new CommonModule());
        $this->bind(PDO::class)->toProvider(MySQLPDOProvider::class);
    }
}

class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new CommonModule());
        $this->bind(PDO::class)->toProvider(SQLitePDOProvider::class);
    }
}
```

**Why it's a problem**: Unclear module responsibility, environment differences dispersed

## Relationship with SOLID Principles

- **SRP**: Module responsible for only one concern
- **OCP**: Adding new modules doesn't modify existing modules
- **DIP**: Module depends on interfaces, eliminates dependency on concrete implementations

## Summary

### Module Design Core

- **Split by concern**: Database, services, AOP, etc.
- **Split by environment**: Production, development, test
- **Combine with install()**: Flexible configuration

### Pattern Benefits

- ✅ DI configuration organized and easy to find
- ✅ Environment differences are clear
- ✅ Reusable components
- ✅ Easy to create test configurations

### Next Steps

You've now learned the main patterns of Ray.Di. In Part 5 onwards, learn AOP details, real-world examples, testing strategies, and best practices.

**Continue to:** [Aspect-Oriented Programming](/manuals/1.0/en/tutorial/05-aop-interceptors/aspect-oriented-programming.html)

---

Module design **determines DI container configuration maintainability**. By properly splitting and combining, you can achieve flexible and reusable configuration.
