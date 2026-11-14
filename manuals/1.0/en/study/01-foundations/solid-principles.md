---
layout: docs-en
title: SOLID Principles in Practice
category: Manual
permalink: /manuals/1.0/en/study/01-foundations/solid-principles.html
---

# SOLID Principles in Practice: The Path to Maintainable Code

## The problem: fragile code where changes cascade

Do bugs appear in unexpected places every time you add a new feature? Have you ever experienced "I added PayPal as a payment method and somehow email sending broke"? This is a typical symptom that occurs when code is tightly coupled, responsibilities are mixed, and abstractions are inappropriate.

The SOLID principles are five guidelines for solving these fundamental design problems. They are not abstract theory but practical answers to concrete problems you face in daily development. Combined with dependency injection, they enable code that is resilient to change, easy to extend, and testable.

## Single Responsibility Principle (SRP) - one reason to change

Consider a class that handles user registration. What happens if this class directly handles database storage, email sending, and logging all by itself?

```php
// ❌ Problem: a class that tries to do everything itself
class UserManager
{
    public function createUser(string $email, string $password): User
    {
        $user = new User($email, $this->hashPassword($password));

        // Database access, email sending, and logging are mixed together
        $pdo = new PDO('mysql:host=localhost;dbname=app', 'user', 'pass');
        $stmt = $pdo->prepare('INSERT INTO users...');
        $stmt->execute([...]);

        $mailer = new PHPMailer();
        $mailer->send();

        error_log("User created: " . $email);

        return $user;
    }
}
```

This creates a fundamental maintainability problem. Why should you need to touch user-creation logic when changing the email service to SendGrid? Should tests of business logic break when you change the database to PostgreSQL?

The Single Responsibility Principle solves this by giving each class one clear responsibility:

```php
// ✅ Solution: separate responsibilities and inject dependencies
class UserService
{
    public function __construct(
        private UserRepositoryInterface $repository,
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}

    public function createUser(string $email, string $password): User
    {
        $user = new User($email, $this->hashPassword($password));

        $this->repository->save($user);
        $this->emailService->sendWelcome($user);
        $this->logger->info("User created: {$email}");

        return $user;
    }
}
```

Why does this matter? Changing the email implementation does not touch UserService at all. Changing the database does not affect the business logic. By focusing each class on a single responsibility, the impact of a change becomes clear and unexpected bugs are prevented.

### Constructor over-injection - a design smell

**Important warning**: When a constructor receives many dependencies (generally four or more), that is a **design smell** called **constructor over-injection**. It is a sign that the Single Responsibility Principle (SRP) is being violated:

```php
// ⚠️ Warning: the constructor receives too many dependencies
class OrderService
{
    public function __construct(
        private OrderValidatorInterface $validator,
        private PriceCalculatorInterface $calculator,
        private OrderRepositoryInterface $repository,
        private EmailServiceInterface $emailService,
        private SMSServiceInterface $smsService,
        private LoggerInterface $logger,
        private MetricsCollectorInterface $metrics,
        private AuditLogInterface $auditLog,
        private InventoryServiceInterface $inventory
    ) {} // 9 dependencies - this is too many!
}
```

**What this problem suggests:**
1. The class has multiple responsibilities (SRP violation)
2. The class is too large (refactoring is needed)
3. The level of abstraction is not appropriate

**Solution:**
1. **Separate responsibilities**: Split the class into smaller classes with single responsibilities
2. **Facade pattern**: Group related dependencies into a facade
3. **Revisit the level of abstraction**: Introduce a higher-level abstraction

```php
// ✅ Improved example: separate responsibilities
class OrderValidator
{
    public function __construct(
        private ValidationRulesInterface $rules,
        private LoggerInterface $logger
    ) {}
}

class OrderNotifier
{
    public function __construct(
        private EmailServiceInterface $emailService,
        private SMSServiceInterface $smsService
    ) {}
}

class OrderProcessor
{
    public function __construct(
        private OrderRepositoryInterface $repository,
        private InventoryServiceInterface $inventory,
        private MetricsCollectorInterface $metrics
    ) {}
}

// OrderService performs only high-level coordination
class OrderService
{
    public function __construct(
        private OrderValidator $validator,      // Three facades
        private OrderNotifier $notifier,        // Clearer and easier to maintain
        private OrderProcessor $processor
    ) {}
}
```

When the number of dependencies grows, that is a signal to revisit the design. DI makes design problems in code visible and acts as a guide toward better design.

## Open/Closed Principle (OCP) - open for extension, closed for modification

Consider discount calculation for an e-commerce site. Do you modify existing code every time you add a new discount type?

```php
// ❌ Problem: existing code is modified for every new feature
class OrderCalculator
{
    public function calculateDiscount(Order $order): float
    {
        switch ($order->getCustomerType()) {
            case 'student': return $order->getTotal() * 0.1;
            case 'senior': return $order->getTotal() * 0.15;
            case 'employee': return $order->getTotal() * 0.2;
            // Modify here for every new discount type...
        }
    }
}
```

This creates a fundamental tension between adding features and keeping existing features stable. Have you ever added a Black Friday discount and somehow broken the student discount?

The Open/Closed Principle lets you add new features without modifying existing code:

```php
// ✅ Solution: make it extensible with the Strategy pattern
interface DiscountStrategy {
    public function calculate(Order $order): float;
    public function supports(string $customerType): bool;
}

class OrderCalculator {
    public function __construct(private array $strategies) {}

    public function calculateDiscount(Order $order): float {
        foreach ($this->strategies as $strategy) {
            if ($strategy->supports($order->getCustomerType())) {
                return $strategy->calculate($order);
            }
        }
        return 0;
    }
}
```

A new discount type? Just add a new Strategy class. Existing code is not touched at all. This lets you add new features safely while keeping existing features stable.

## Liskov Substitution Principle (LSP) - substitutability that behaves as expected

Have you ever passed a derived class to code that expects a base class and found that the program no longer works correctly? Have you ever experienced "the Shape interface is supposed to have getArea(), so why does this fail?" This is a typical symptom that occurs when a derived class does not honor the contract of its base class.

```php
// ✅ Correct LSP: every derived class honors the base class contract
abstract class Shape
{
    abstract public function getArea(): float;
}

class Circle extends Shape
{
    public function __construct(private float $radius) {}

    public function getArea(): float
    {
        return pi() * $this->radius ** 2;
    }
}

class Rectangle extends Shape
{
    public function __construct(
        private float $width,
        private float $height
    ) {}

    public function getArea(): float
    {
        return $this->width * $this->height;
    }
}

// Code that expects Shape works with any derived class
function calculateTotalArea(array $shapes): float
{
    $total = 0;
    foreach ($shapes as $shape) {
        $total += $shape->getArea(); // Works for both Circle and Rectangle
    }
    return $total;
}
```

In this example, both `Circle` and `Rectangle` fully honor the `Shape` contract (having a getArea() method). Either class can be treated as a `Shape`.

The Liskov Substitution Principle requires that a derived class fully honor the contract of its base class. A contract includes not only the method signature but also preconditions (assumptions under which the method is called), postconditions (results the method guarantees), and invariants (conditions the class always satisfies). A derived class must not strengthen preconditions. It must not weaken postconditions. It must preserve the behavior established by the base class.

Why does this matter? Behavior promised by the type is reliably honored. Code does not break when you substitute implementations. You can build a trustworthy system without unexpected side effects.

## Interface Segregation Principle (ISP) - depend only on what you need

When implementing a CRUD interface, have you ever been forced to implement a delete method in a read-only reporting service? Writing `throw new Exception("read-only")` for methods you do not use creates the fundamental design problem of unnecessary complexity.

```php
// ❌ Problem: a bloated interface
interface UserRepositoryInterface {
    public function find(int $id): User;
    public function findAll(): array;
    public function save(User $user): void;
    public function delete(int $id): void;  // Not needed for reports
    public function update(User $user): void; // Not needed for the audit log
}

// ✅ Solution: separate by purpose
interface UserReaderInterface {
    public function find(int $id): User;
    public function findAll(): array;
}

interface UserWriterInterface {
    public function save(User $user): void;
    public function update(User $user): void;
    public function delete(int $id): void;
}

// Reports only read
class ReportService {
    public function __construct(private UserReaderInterface $reader) {}
}
```

This principle splits a bloated interface into small interfaces by purpose. The reporting service depends only on `UserReaderInterface`, while a service that needs full access can implement both interfaces.

Why does this matter? Each service depends only on the features it truly needs. The reporting service cannot accidentally call delete. The audit log cannot mistakenly update. The smaller the interface, the easier it is to implement and use, and the easier it is to write tests.

## Dependency Inversion Principle (DIP) - depend on abstractions

When high-level business logic depends on low-level implementation details, changes ripple:

```php
// ❌ Problem: direct dependency on a concrete class
class UserService {
    public function __construct() {
        $this->mailer = new PHPMailer(); // Depends on a concrete class
    }
}

// ✅ Solution: depend on an interface
class UserService {
    public function __construct(
        private EmailServiceInterface $emailService // Depends on an abstraction
    ) {}
}
```

Why does this matter? When changing from PHPMailer to SendGrid, the UserService code does not need to change. Mock implementations can be injected during tests. Different implementations can be used per environment.

## Realizing SOLID principles with Ray.Di

Ray.Di is a powerful tool for realizing these principles naturally:

```php
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // DIP: bind an interface to an implementation
        $this->bind(EmailServiceInterface::class)
             ->to(SendGridEmailService::class);

        // OCP: bind the pricing strategy
        // When switching to a new strategy (for example, PromotionalPricing),
        // only this module configuration changes; existing code stays untouched
        $this->bind(PricingStrategyInterface::class)
             ->to(StandardPricingStrategy::class);
    }
}
```

## Why SOLID principles matter

Code that follows the SOLID principles behaves predictably under change. Adding new features does not break existing ones. Fixing a bug does not create a new one. Tests are easier to write and maintenance is easier.

This is not idealism. Have you ever been uneasy on the eve of a release, wondering "will this change affect anything else?" The SOLID principles resolve that unease at the design level. When each part has a clear responsibility, is properly separated, and can be safely substituted, changes become local and predictable.

## Practical points

The SOLID principles are not dogmatic rules but guidelines for better design. You do not have to apply all of them perfectly. It is important to find the right balance considering project size, team skill, and deadlines.

Start small. Begin with the Dependency Inversion Principle and reduce direct dependencies on concrete classes. Next, apply the Single Responsibility Principle and split bloated classes. By improving incrementally, you can practice SOLID principles without overextending yourself.

---

**Next:** [Ray.Di Fundamentals](raydi-fundamentals.html) - Practical use of the framework

**Previous:** [Dependency Injection Principles](dependency-injection-principles.html)
