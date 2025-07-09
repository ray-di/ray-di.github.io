# Dependency Injection Principles

## 🎯 Learning Objectives

By the end of this section, you'll understand:
- What dependency injection is and why it matters
- The problems DI solves in software design
- Core principles of Inversion of Control (IoC)
- How DI enables better software architecture
- The relationship between DI and SOLID principles

## 🤔 The Problem: Tight Coupling

Let's start with a common problem in software development. Imagine we're building an e-commerce platform and need to send order confirmation emails:

```php
class OrderService
{
    public function processOrder(Order $order): void
    {
        // Validate order
        if (!$this->validateOrder($order)) {
            throw new InvalidOrderException();
        }
        
        // Save to database
        $database = new MySQLDatabase();
        $database->save($order);
        
        // Send confirmation email
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

### 🚨 What's Wrong Here?

This code demonstrates **tight coupling** - several problems that make the code hard to maintain:

1. **Hard Dependencies**: `OrderService` directly creates `MySQLDatabase`, `SMTPEmailService`, and `FileLogger`
2. **Difficult Testing**: How do you test this without actually sending emails or writing to files?
3. **Inflexible**: What if you want to switch from MySQL to PostgreSQL? Or from SMTP to SendGrid?
4. **Violates SOLID Principles**: The class has multiple reasons to change
5. **Hard to Mock**: Unit testing becomes impossible

## 💡 The Solution: Dependency Injection

Dependency Injection solves these problems by **inverting the control** of object creation:

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
        // Validate order
        if (!$this->validateOrder($order)) {
            throw new InvalidOrderException();
        }
        
        // Save to database
        $this->database->save($order);
        
        // Send confirmation email
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

### ✅ Benefits Achieved

1. **Loose Coupling**: `OrderService` depends on abstractions, not concrete implementations
2. **Testability**: Easy to inject mock objects for testing
3. **Flexibility**: Switch implementations without changing `OrderService`
4. **Single Responsibility**: Each class has one reason to change
5. **Open/Closed Principle**: Open for extension, closed for modification

## 🔄 Inversion of Control (IoC)

**Traditional Control Flow:**
```
Object A creates Object B
Object A controls Object B's lifecycle
Object A knows Object B's concrete type
```

**Inverted Control Flow:**
```
Container creates Object B
Container injects Object B into Object A
Object A only knows Object B's interface
```

### Example: Before and After IoC

**Before (Object creates its dependencies):**
```php
class UserService
{
    private $repository;
    
    public function __construct()
    {
        // UserService controls the creation
        $this->repository = new MySQLUserRepository();
    }
}
```

**After (Dependencies are injected):**
```php
class UserService
{
    public function __construct(
        private UserRepositoryInterface $repository
    ) {
        // Container controls the creation and injection
    }
}
```

## 🏗️ Types of Dependency Injection

### 1. Constructor Injection (Recommended)

```php
class ProductService
{
    public function __construct(
        private ProductRepositoryInterface $repository,
        private CacheInterface $cache
    ) {}
}
```

**Pros:**
- Dependencies are clear and required
- Immutable after construction
- Fails fast if dependencies are missing

### 2. Method Injection

```php
class ProductService
{
    public function findProduct(int $id, LoggerInterface $logger): Product
    {
        $logger->info("Finding product: $id");
        return $this->repository->find($id);
    }
}
```

**Use Cases:**
- Optional dependencies
- Dependencies that vary per method call

### 3. Property Injection (Avoid)

```php
class ProductService
{
    public LoggerInterface $logger;
    
    public function setLogger(LoggerInterface $logger): void
    {
        $this->logger = $logger;
    }
}
```

**Problems:**
- Dependencies are not clear
- Mutable state
- Can be used before dependencies are set

## 🎭 Design Patterns Enabled by DI

### Factory Pattern
```php
interface OrderProcessorFactory
{
    public function createProcessor(string $type): OrderProcessorInterface;
}

class OrderService
{
    public function __construct(
        private OrderProcessorFactory $processorFactory
    ) {}
    
    public function processOrder(Order $order): void
    {
        $processor = $this->processorFactory->createProcessor($order->getType());
        $processor->process($order);
    }
}
```

### Strategy Pattern
```php
interface ShippingStrategy
{
    public function calculateCost(Package $package): Money;
}

class ShippingService
{
    public function __construct(
        private array $strategies // Injected set of strategies
    ) {}
    
    public function calculateShipping(Package $package, string $method): Money
    {
        return $this->strategies[$method]->calculateCost($package);
    }
}
```

### Observer Pattern
```php
interface EventDispatcherInterface
{
    public function dispatch(EventInterface $event): void;
}

class OrderService
{
    public function __construct(
        private EventDispatcherInterface $eventDispatcher
    ) {}
    
    public function processOrder(Order $order): void
    {
        // Process order...
        
        // Notify observers
        $this->eventDispatcher->dispatch(new OrderProcessedEvent($order));
    }
}
```

## 🧪 Testing Benefits

### Without DI (Hard to Test)
```php
class OrderServiceTest extends PHPUnit\Framework\TestCase
{
    public function testProcessOrder(): void
    {
        $service = new OrderService();
        
        // How do we test without sending real emails?
        // How do we verify database calls?
        // How do we control external dependencies?
        
        $order = new Order(/*...*/);
        $service->processOrder($order); // This will fail in tests!
    }
}
```

### With DI (Easy to Test)
```php
class OrderServiceTest extends PHPUnit\Framework\TestCase
{
    public function testProcessOrder(): void
    {
        // Create mocks
        $database = $this->createMock(DatabaseInterface::class);
        $emailService = $this->createMock(EmailServiceInterface::class);
        $logger = $this->createMock(LoggerInterface::class);
        
        // Set expectations
        $database->expects($this->once())->method('save');
        $emailService->expects($this->once())->method('send');
        $logger->expects($this->once())->method('info');
        
        // Test with controlled dependencies
        $service = new OrderService($database, $emailService, $logger);
        $order = new Order(/*...*/);
        $service->processOrder($order);
    }
}
```

## 🏛️ Architectural Benefits

### Layered Architecture
```
┌─────────────────────┐
│   Presentation      │ ← Controllers, Views
├─────────────────────┤
│   Application       │ ← Services, Use Cases  
├─────────────────────┤
│   Domain            │ ← Business Logic
├─────────────────────┤
│   Infrastructure    │ ← Database, External APIs
└─────────────────────┘
```

DI enables clean separation between layers:

```php
// Domain Layer (pure business logic)
interface UserRepositoryInterface
{
    public function findByEmail(string $email): ?User;
}

// Application Layer (orchestrates domain)
class AuthenticationService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private PasswordHasherInterface $passwordHasher
    ) {}
}

// Infrastructure Layer (technical details)
class MySQLUserRepository implements UserRepositoryInterface
{
    // Database-specific implementation
}
```

### Hexagonal Architecture (Ports and Adapters)
```
     ┌─────────────────┐
     │   Application   │
     │      Core       │
     └─────────────────┘
            │   │
    ┌───────┘   └───────┐
    │                   │
┌───▼───┐           ┌───▼───┐
│ Port  │           │ Port  │
│  Web  │           │  DB   │
└───────┘           └───────┘
```

```php
// Core application
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository, // Port
        private PaymentGatewayInterface $paymentGateway   // Port  
    ) {}
}

// Adapters (implementations)
class SQLOrderRepository implements OrderRepositoryInterface {} // Adapter
class StripePaymentGateway implements PaymentGatewayInterface {} // Adapter
```

## 🎯 Key Principles Summary

### 1. Depend on Abstractions
```php
// Good: Depends on interface
public function __construct(private LoggerInterface $logger) {}

// Bad: Depends on concrete class
public function __construct(private FileLogger $logger) {}
```

### 2. Inject Dependencies, Don't Create Them
```php
// Good: Dependencies injected
public function __construct(private DatabaseInterface $db) {}

// Bad: Creates dependencies
public function __construct() {
    $this->db = new MySQLDatabase();
}
```

### 3. Use Constructor Injection for Required Dependencies
```php
// Good: Clear what's required
public function __construct(
    private UserRepositoryInterface $userRepository,
    private EmailServiceInterface $emailService
) {}
```

### 4. Keep Constructors Simple
```php
// Good: Just assignment
public function __construct(private ServiceInterface $service) {}

// Bad: Logic in constructor
public function __construct(ServiceInterface $service) {
    $this->service = $service;
    $this->initialize(); // Avoid logic
}
```

## 🚀 Next Steps

Now that you understand the principles of dependency injection, you're ready to:

1. **Learn SOLID Principles**: See how DI enables better design
2. **Explore Ray.Di Fundamentals**: Understand the framework's approach
3. **Practice with Examples**: Start building with proper DI

**Continue to:** [SOLID Principles in Practice](solid-principles.md)

## 💡 Key Takeaways

- **Dependency Injection** inverts control of object creation
- **Loose coupling** makes code more maintainable and testable
- **Abstractions** provide flexibility and enable design patterns
- **Constructor injection** is the preferred method for required dependencies
- **DI enables** clean architecture and separation of concerns
- **Testing becomes** simple with injected mock dependencies

---

**Remember:** Dependency injection is not just a technical pattern - it's a fundamental shift in thinking about how objects collaborate in your application!