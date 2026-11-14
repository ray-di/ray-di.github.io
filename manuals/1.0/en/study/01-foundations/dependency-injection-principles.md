---
layout: docs-en
title: Dependency Injection Principles
category: Manual
permalink: /manuals/1.0/en/study/01-foundations/dependency-injection-principles.html
---

# Dependency Injection Principles

## Learning objectives

By the end of this section, you will understand:
- What dependency injection is, and that its primary purpose is building maintainable software
  - Testability is an important benefit of DI, but it is a secondary effect of the original goal of improving maintainability
- The problems DI solves in software design
- The core principle of inversion of control (IoC), and that DI is a concrete technique for realizing IoC
- How DI enables better software architecture
- The relationship between DI and the SOLID principles, and how DI improves your object-oriented programming skills

## The problem: tight coupling

Let's start with a common problem in software development. Suppose you are building an e-commerce platform and need to send order confirmation emails:

```php
class OrderService
{
    public function processOrder(Order $order): void
    {
        // Validate the order
        if (!$this->validateOrder($order)) {
            throw new InvalidOrderException();
        }
        
        // Save to the database
        $database = new MySQLDatabase();
        $database->save($order);
        
        // Send the confirmation email
        $emailService = new SMTPEmailService();
        $emailService->send(
            $order->getCustomerEmail(),
            'Order Confirmation',
            $this->generateOrderEmail($order)
        );
        
        // Log the transaction
        $logger = new FileLogger('/var/log/orders.log');
        $logger->info("Order {$order->getId()} processed successfully");
    }
}
```

### Problems

This code exhibits **tight coupling**. It has several problems that make the code hard to maintain:

1. **Hard dependencies**: `OrderService` directly creates `MySQLDatabase`, `SMTPEmailService`, and `FileLogger`
2. **Difficult testing**: Because it depends directly on concrete classes, they cannot be replaced with mock objects. There is no way to unit test it without actually sending email or writing to files
3. **Lack of flexibility**: It is hard to switch from MySQL to PostgreSQL, or from SMTP to SendGrid
4. **SOLID violations**: The class has more than one reason to change

## The solution: dependency injection

The key to solving these problems is to reconsider where the responsibility for creating objects belongs.

Dependency injection solves them by inverting control over object creation and management (inversion of control). In the earlier `OrderService` example, the object created its own dependencies with the `new` operator. This is called the Control Freak anti-pattern.

Control Freak is a state in which an object tries to take excessive control over the creation of its collaborators (dependencies). `OrderService` knows and tries to control implementation details such as "use MySQLDatabase," "send mail over SMTP," and "write logs to a file." As a result, `OrderService` ends up carrying not only its original responsibility (the business logic of order processing) but also the responsibility of constructing infrastructure.

DI eliminates this anti-pattern by having dependencies provided from the outside:

```php
interface DatabaseInterface
{
    public function save(Order $order): void;
}

interface EmailServiceInterface
{
    public function send(string $to, string $subject, string $body): void;
}

interface LoggerInterface
{
    public function info(string $message): void;
}

class OrderService
{
    public function __construct(
        private DatabaseInterface $database,
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}
    
    public function processOrder(Order $order): void
    {
        // Validate the order
        if (!$this->validateOrder($order)) {
            throw new InvalidOrderException();
        }
        
        // Save to the database
        $this->database->save($order);
        
        // Send the confirmation email
        $this->emailService->send(
            $order->getCustomerEmail(),
            'Order Confirmation',
            $this->generateOrderEmail($order)
        );
        
        // Log the transaction
        $this->logger->info("Order {$order->getId()} processed successfully");
    }
}
```

### Benefits achieved

1. **Loose coupling**: `OrderService` depends on abstractions, not on concrete implementations
2. **Testability**: Mock objects can easily be injected for testing
3. **Flexibility**: Implementations can be swapped without changing `OrderService`
4. **Single responsibility**: Each class has one reason to change
5. **Open/closed principle**: Open for extension, closed for modification
6. **Late binding**: The decision of which implementation to use can be deferred until application startup or configuration time
7. **Extensibility**: New features can be added without modifying existing code

## Inversion of control (IoC)

So far we have seen that dependency injection is a technique for "injecting dependencies from the outside." But why does it work? To understand the principle behind it, let's look at the concept of inversion of control (IoC).

Inversion of control means inverting where responsibility lies: who controls the creation and management of objects.

### Traditional programming: objects hold control

In ordinary object-oriented programming, an object creates and manages the dependencies it needs:

```
Object A takes the initiative
  ↓
Object A decides "I need object B"
  ↓
Object A creates object B with new
  ↓
Object A manages the lifecycle of object B
  ↓
Object A knows the concrete type of object B (such as MySQLDatabase)
```

At first glance this seems natural, but object A has to know implementation details—"how to create it"—which produces tight coupling.

### IoC: transfer control to a container

With inversion of control, the responsibility for creating and managing objects is handed to an external container (the DI container):

```
The DI container takes the initiative
  ↓
The container understands from the constructor type declarations that "object A needs object B"
  ↓
The container decides "the implementation of object B" from the Module (binding configuration)
  ↓
The container creates object B
  ↓
The container injects object B into object A
  ↓
Object A knows only the interface of object B (not its concrete type)
```

Through this "inversion," object A declares what it needs in its constructor type declarations, and leaves how to create it and which implementation to use to the container and the Module configuration. This is the essence of **inversion of control**.

### Example: before and after IoC

Let's look at concrete code.

**Before IoC (the object creates its own dependencies):**
```php
class UserService
{
    private $repository;

    public function __construct()
    {
        // ❌ UserService knows the concrete implementation "MySQLUserRepository"
        // ❌ UserService controls when and how it is created
        $this->repository = new MySQLUserRepository();
    }
}
```

With this approach, `UserService` has to know implementation details such as "use MySQL." If you want to switch to PostgreSQL, you must modify this class itself.

**After IoC (dependencies are injected from the outside):**
```php
class UserService
{
    public function __construct(
        private UserRepositoryInterface $repository // ✅ Knows only the interface
    ) {
        // ✅ The constructor simply receives it
        // ✅ The container controls creation and injection
        // ✅ UserService declares only "what" it needs, and does not know "how"
    }
}
```

With this approach, `UserService` only declares that it needs "something that implements `UserRepositoryInterface`." Whether `MySQLUserRepository` or `PostgreSQLUserRepository` is actually injected is decided by external configuration (the DI container). Control has been inverted.

## Pure DI and the composition root

Now that you understand the principle of inversion of control, let's look at how dependencies are actually assembled.

The principles of DI can be practiced without a DI container (a framework such as Ray.Di). This is called Pure DI.

### Example of Pure DI

```php
// Pure DI: wire dependencies by hand without a DI container
$database = new MySQLDatabase('localhost', 'myapp', 'user', 'pass');
$emailService = new SMTPEmailService('smtp.example.com', 587);
$logger = new FileLogger('/var/log/app.log');

$orderService = new OrderService($database, $emailService, $logger);
```

This manual wiring works well enough for small applications. As the application grows, however, maintainability problems become apparent.

For example, suppose you want to change the `LoggerInterface` implementation used throughout the application from `FileLogger` to `CloudLogger`. With Pure DI, you must find every `new FileLogger()` and rewrite it to `new CloudLogger()`. Pure DI still centralizes assembly in a single composition root, so those edits stay in one file—but you must edit each of the 100 wiring lines there. Miss even one, and different loggers will be mixed in production. Scattering the wiring across many places instead—one per feature or framework hook—is the anti-pattern that makes Pure DI painful, and it defeats the purpose of having a composition root.

Furthermore, manually managing objects that should be treated as singletons (such as database connections) is difficult. Developers must always be aware of where to reuse the same instance and where to create a new one, and implement it correctly. This is a breeding ground for human error.

### Composition root

The **composition root** is the single place at the application entry point where all dependencies are assembled. This concept is the same whether you use Pure DI or a DI container:

```php
// index.php - the composition root
require_once 'vendor/autoload.php';

use Ray\Di\Injector;

// DI container configuration (composition root)
$injector = new Injector(new AppModule());

// Get the root object of the application
$app = $injector->getInstance(Application::class);

// Run the application
$app->run();
```

**Important principles:**

Place the composition root in the outermost layer of the application—the entry point (such as `index.php` or `bootstrap.php`). Business logic and domain-layer code should avoid holding direct references to the DI container. Creating objects with the `new` operator anywhere other than the composition root is also discouraged (the Factory pattern for cases that need runtime parameters is the exception).

### The role of the DI container

A DI container (Ray.Di) automates this manual wiring work and provides additional value.

It reads interfaces from constructor type declarations and automatically injects the appropriate implementation based on the bindings configured in Modules. With this automatic wiring, developers do not need to write dependency assembly code.

It manages scopes such as singleton and prototype, controlling whether the same instance should be reused or a new instance should be created each time. This lets you manage object lifecycles consistently.

It detects binding inconsistencies and circular dependencies at application startup, so problems are found before execution. Detecting problems at startup rather than at runtime prevents unexpected errors in production.

It can compile the resolved dependency graph into optimized PHP code. Compilation is optional: the default `Injector` resolves bindings at runtime, while the compiled path uses `DiCompiler` to generate factories and `ScriptInjector` to load them (`ray/compiler`). Ray.Di achieves both flexibility during development and performance in production.

```php
// Pure DI (manual) - changing the logger implementation is painful
$database = new MySQLDatabase('localhost', 'shop', 'user', 'pass');
$emailService = new SMTPEmailService('smtp.example.com', 587);
$logger = new FileLogger('/var/log/orders.log'); // Change this and...
$orderService = new OrderService($database, $emailService, $logger);
// ...you must change every place in the application

// DI container (automated) - a single change is enough
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // Changing only this line affects the whole application
        $this->bind(LoggerInterface::class)->to(CloudLogger::class);
    }
}

$injector = new Injector(new AppModule());
$orderService = $injector->getInstance(OrderService::class);
// All dependencies are resolved automatically, and a consistent logger is injected
```

A DI container is a tool that preserves the principles of Pure DI while making implementation changes a single configuration change, managing complexity, and dramatically improving maintainability.

### Switching modules per environment

An important DI principle: **business logic knows nothing about the environment. The environment changes only the bindings.**

Even when production, staging, and development environments need different implementations, the business logic code does not change at all. You simply prepare a different module for each environment and select the appropriate one at the entry point:

```php
// Module for production
class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(LoggerInterface::class)->to(CloudLogger::class);
        $this->bind(CacheInterface::class)->to(RedisCache::class);
    }
}

// Module for development
class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
        $this->bind(CacheInterface::class)->to(ArrayCache::class);
    }
}

// Entry point (index.php)
$module = $_ENV['APP_ENV'] === 'production'
    ? new ProductionModule()
    : new DevelopmentModule();

$injector = new Injector($module);
$app = $injector->getInstance(Application::class);
$app->run();
```

Business logic such as `OrderService` and `UserService` depends only on `LoggerInterface` and `CacheInterface`; it does not know whether the implementation is `CloudLogger` or `FileLogger`. Differences between environments are absorbed solely by module selection at the entry point.

**Important principle: do not bring environment variables or conditional branching into modules or Providers**

References to environment variables (`$_ENV` or `getenv()`) and environment-dependent conditional branching should be limited to module selection at the entry point (composition root). You must not reference environment variables inside modules or Providers, or write conditionals such as `if ($_ENV['APP_ENV'] === 'production')`.

The Google Guice documentation, [Avoid Conditional Logic in Modules](https://github.com/google/guice/wiki/AvoidConditionalLogicInModules), states this principle clearly as well. Bringing environment-dependent conditionals into a module raises cyclomatic complexity and increases the number of code paths. The more conditionals you add, the harder it becomes to test every path, and you create conditions that "run only in production" or "run only in development." Code tested in only one environment becomes a breeding ground for bugs that occur only in production.

Instead, create a dedicated module for each environment and select the appropriate one at the entry point. Because each module has no conditional branching, its cyclomatic complexity is low (ideally 1), and test coverage naturally approaches 100%. Every environment configuration becomes explicit and fully testable.

## Types of dependency injection

There are several patterns for injecting dependencies. It is important to understand the characteristics of each and use them appropriately.

### 1. Constructor injection (recommended)

```php
class ProductService
{
    public function __construct(
        private ProductRepositoryInterface $repository,
        private CacheInterface $cache
    ) {}
}
```

**Advantages:**
- Dependencies are explicit and mandatory
- Immutable after construction
- Fails fast when a dependency is missing

### 2. Method injection

```php
use Ray\Di\Di\Inject;

class ProductService
{
    private LoggerInterface $logger;

    public function __construct(
        private ProductRepositoryInterface $repository
    ) {}

    #[Inject]
    public function setLogger(LoggerInterface $logger): void
    {
        $this->logger = $logger;
    }

    public function findProduct(int $id): Product
    {
        $this->logger->info("Finding product: $id");
        return $this->repository->find($id);
    }
}
```

**Use cases:**
- Optional dependencies
- Dependencies that differ per call (assisted injection with `#[Assisted]`)

### 3. Property injection (not supported by Ray.Di)

```php
class ProductService
{
    public LoggerInterface $logger; // Injected directly here
}
```

**Important: Ray.Di does not support property injection.**

This is a deliberate limitation based on Ray.Di's design philosophy. Property injection has the following problems:

1. **It allows objects to exist in an incomplete state**: With constructor injection, an object is not constructed until all dependencies are satisfied. With property injection, however, the object exists before its dependencies are injected, and there is a risk that an object in an incomplete state will be used.

2. **The mandatory nature of dependencies is unclear**: The constructor signature makes mandatory dependencies explicit, but with property injection it is unclear whether a dependency is optional or mandatory.

3. **It breaks immutability**: With property injection, dependencies can be changed afterward, reducing the predictability of the object. Constructor injection guarantees that dependencies do not change after the object is constructed.

Google Guice also has a [discussion](https://github.com/google/guice/wiki/InjectionPoints#field-injection) on why property injection (field injection) should be avoided, and it states explicitly that "field injection should be avoided and constructor injection preferred."

Ray.Di instead strongly recommends constructor injection. As a result, objects are always constructed in a complete state, dependencies are explicit, and immutability is preserved.

## DI design philosophy: designing for change

So far we have looked at the technical aspects of dependency injection—inversion of control, Pure DI, and the types of injection. But the true value of DI is not only in its technical mechanisms. DI brings about a fundamental shift in how we think about software development.

Dependency injection is not merely a testing technique. It is a design philosophy for controlling complexity and change.

### Viewing a program as an object graph

Traditional programming has viewed code as "a collection of instructions." With DI, however, a program is viewed as an object graph—a network of dependencies among objects. Class A depends on class B, and class B depends on class C. This graph of dependencies is the true structure of the software.

```
// View as a collection of instructions
$pool = new ConnectionPool();
$database = new MySQLDatabase($pool);
$emailService = new SMTPEmailService();
$logger = new FileLogger();
$service = new OrderService($database, $emailService, $logger);

// View as an object graph
OrderService → DatabaseInterface → ConnectionPoolInterface
            → EmailServiceInterface
            → LoggerInterface
```

What matters is that this object graph maintains acyclicity (ADP: Acyclic Dependencies Principle) while having a loosely coupled structure. Software can be described as the design of an object graph that satisfies these properties. A directed acyclic graph (DAG) with no circular dependencies means that the impact of a change propagates in only one direction and remains controllable.

### Treating dependencies as controllable design elements

DI turns dependencies from implicit hard-coding into explicit, controllable design elements.

```php
// Implicit (uncontrollable)
class OrderService
{
    public function __construct()
    {
        $this->repository = new MySQLOrderRepository(); // Cannot be changed
    }
}

// Explicit (controllable)
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $repository // Controllable as a design element
    ) {}
}
```

This explicitness lets a team share a framework for thinking about dependency control. During review, it becomes possible to discuss "why does this class depend on this?" and "is this dependency appropriate?"

### A structure that brings order to coding

DI brings a certain order to how software is written. In traditional programming, any tool (object) could be called freely from anywhere. This freedom looks like flexibility, but in practice it produced disorder.

DI establishes a clear pattern. Dependencies that are needed are declared in the constructor, and each method uses them.

```php
class OrderService
{
    // Structural discipline: declare everything you need in the constructor
    public function __construct(
        private OrderRepositoryInterface $repository,
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}

    // Each method uses only the dependencies that have been prepared
    public function processOrder(Order $order): void
    {
        $this->repository->save($order);      // Prepared in the constructor
        $this->emailService->send(...);       // Prepared in the constructor
        $this->logger->info(...);             // Prepared in the constructor
    }
}
```

The concrete benefits of this structural discipline are clear. Looking at the constructor tells you at a glance which dependencies the class needs. If a dependency is missing, an error occurs early in the constructor, preventing unexpected runtime failures. New objects are not suddenly created inside methods, so the behavior of the code becomes predictable.

This order is especially valuable in team development. During code review, looking only at the constructor lets you judge the scope of the class's responsibility and the appropriateness of its dependencies. New team members can begin understanding the code from the clear "entrance" that is the constructor.

### Flexibility through object composition

DI promotes design through object composition rather than inheritance. It splits objects into small parts and combines them to achieve complex behavior:

```php
// Extension through inheritance (rigid)
class OrderService extends BaseService { }
class PremiumOrderService extends OrderService { }
class ExpressOrderService extends PremiumOrderService { } // The hierarchy gets deeper

// Extension through composition (flexible)
class OrderService
{
    public function __construct(
        private OrderValidatorInterface $validator,     // Part 1
        private PricingStrategyInterface $pricing,      // Part 2
        private NotificationInterface $notification     // Part 3
    ) {}
}

// Different behavior by swapping parts
new OrderService(
    new PremiumValidator(),
    new DynamicPricing(),
    new CompositeNotification([new Email(), new SMS()])
);
```

With composition, behavior can be changed at runtime, and testing becomes easier. Above all, the impact of a change is localized.

### The Acyclic Dependencies Principle (ADP)

Another important aspect of dependency control is eliminating circular dependencies:

```php
// ❌ Circular dependency (bad design)
class OrderService
{
    public function __construct(private InvoiceService $invoice) {}
}

class InvoiceService
{
    public function __construct(private OrderService $order) {} // Circular!
}

// ✅ Make the direction of dependency one-way
interface InvoiceEventInterface { }

class OrderService
{
    public function __construct(
        private InvoiceEventInterface $invoiceEvent // Depends on the interface
    ) {}
}

class InvoiceService implements InvoiceEventInterface
{
    // Does not depend on OrderService
}
```

With ADP, the dependency graph becomes a directed acyclic graph (DAG), and the impact of a change propagates in only one direction. This is extremely important for controlling complexity.

### Software development = designing for change

The essence of DI is to accept the unavoidable reality that "change happens" and to control that change at the structural level.

In code where dependencies are implicitly hard-coded, it is difficult to grasp "if I change this line, where will it affect?" Implementation details are scattered across multiple places, and a change may ripple to unexpected locations. When dependencies are explicitly controlled, however, the impact of a change becomes visible. Changing one implementation does not affect its dependents as long as you do not change the interface they depend on. Conversely, if you change an interface, the compiler or IDE immediately shows every affected location.

More importantly, the way you respond to new requirements changes. With traditional design, you had to modify existing code when adding a new feature. With DI, you only add a new implementation class and specify it in the binding configuration. You can introduce a new feature without touching existing business logic at all. This is the Open/Closed Principle in practice.

And because dependencies become explicit, every team member can understand the same structure. In code review, constructive discussion becomes possible: "why does this class depend on this interface?" and "is this dependency appropriate, or is it a design smell?" Through the common language of dependencies, you can communicate design intent and share the direction of improvement.

Testability is merely a secondary benefit of this design philosophy. Code whose impact of change is controlled and whose parts are replaceable is inevitably easier to test. Testing is the act of "replacing the production implementation with a test implementation." Code designed with DI has replaceability at its core, so testing is not work that requires special effort—it is a natural consequence of the design.

---

**Next:** [SOLID Principles in Practice](solid-principles.html) - How DI enables better design

**Related:** [Ray.Di Fundamentals](raydi-fundamentals.html) - The framework's concrete approach
