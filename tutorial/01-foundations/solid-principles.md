# SOLID Principles in Practice

## 🎯 Learning Objectives

By the end of this section, you'll understand:
- All five SOLID principles and their practical applications
- How dependency injection enables SOLID design
- Real-world examples in an e-commerce context
- Common violations and how to fix them
- The relationship between SOLID and maintainable code

## 🏗️ What are SOLID Principles?

SOLID is an acronym for five design principles that make software designs more understandable, flexible, and maintainable:

- **S** - Single Responsibility Principle (SRP)
- **O** - Open/Closed Principle (OCP)  
- **L** - Liskov Substitution Principle (LSP)
- **I** - Interface Segregation Principle (ISP)
- **D** - Dependency Inversion Principle (DIP)

Let's explore each principle with practical e-commerce examples!

## 1️⃣ Single Responsibility Principle (SRP)

> *"A class should have only one reason to change."*

### ❌ Violation Example

```php
class OrderService
{
    public function processOrder(Order $order): void
    {
        // Responsibility 1: Order validation
        if (empty($order->getItems())) {
            throw new InvalidOrderException('Order must have items');
        }
        
        // Responsibility 2: Price calculation
        $total = 0;
        foreach ($order->getItems() as $item) {
            $total += $item->getPrice() * $item->getQuantity();
        }
        $order->setTotal($total);
        
        // Responsibility 3: Database persistence
        $pdo = new PDO('mysql:host=localhost;dbname=shop', 'user', 'pass');
        $stmt = $pdo->prepare('INSERT INTO orders...');
        $stmt->execute([...]);
        
        // Responsibility 4: Email notification
        $smtp = new Swift_SmtpTransport('smtp.gmail.com', 587);
        $mailer = new Swift_Mailer($smtp);
        $message = new Swift_Message('Order Confirmation');
        $mailer->send($message);
        
        // Responsibility 5: Inventory updates
        foreach ($order->getItems() as $item) {
            $inventoryStmt = $pdo->prepare('UPDATE inventory SET quantity = quantity - ? WHERE product_id = ?');
            $inventoryStmt->execute([$item->getQuantity(), $item->getProductId()]);
        }
    }
}
```

**Problems:**
- Changes to email logic require changing `OrderService`
- Changes to database schema require changing `OrderService`
- Testing is difficult - one test class tests everything
- Code is hard to understand - too many concerns mixed together

### ✅ SRP Solution

```php
// Single responsibility: Order business rules
class OrderValidator
{
    public function validate(Order $order): void
    {
        if (empty($order->getItems())) {
            throw new InvalidOrderException('Order must have items');
        }
        
        if ($order->getCustomer()->getAge() < 18) {
            throw new InvalidOrderException('Customer must be 18+');
        }
    }
}

// Single responsibility: Price calculations
class PriceCalculator
{
    public function calculateTotal(Order $order): Money
    {
        $total = Money::zero();
        foreach ($order->getItems() as $item) {
            $itemTotal = $item->getPrice()->multiply($item->getQuantity());
            $total = $total->add($itemTotal);
        }
        return $total;
    }
}

// Single responsibility: Order persistence
class OrderRepository
{
    public function __construct(private PDO $database) {}
    
    public function save(Order $order): void
    {
        $stmt = $this->database->prepare('INSERT INTO orders...');
        $stmt->execute([...]);
    }
}

// Single responsibility: Order notifications
class OrderNotificationService
{
    public function __construct(private EmailServiceInterface $emailService) {}
    
    public function sendConfirmation(Order $order): void
    {
        $this->emailService->send(
            $order->getCustomer()->getEmail(),
            'Order Confirmation',
            $this->buildConfirmationEmail($order)
        );
    }
}

// Single responsibility: Inventory management
class InventoryService
{
    public function reserveItems(array $items): void
    {
        foreach ($items as $item) {
            $this->reserveItem($item->getProductId(), $item->getQuantity());
        }
    }
}

// Orchestrator: Coordinates all services
class OrderService
{
    public function __construct(
        private OrderValidator $validator,
        private PriceCalculator $calculator,
        private OrderRepository $repository,
        private OrderNotificationService $notificationService,
        private InventoryService $inventoryService
    ) {}
    
    public function processOrder(Order $order): void
    {
        $this->validator->validate($order);
        
        $total = $this->calculator->calculateTotal($order);
        $order->setTotal($total);
        
        $this->inventoryService->reserveItems($order->getItems());
        $this->repository->save($order);
        $this->notificationService->sendConfirmation($order);
    }
}
```

**Benefits:**
- Each class has one reason to change
- Easy to test each component independently
- Easy to modify or replace individual parts
- Code is more readable and maintainable

## 2️⃣ Open/Closed Principle (OCP)

> *"Software entities should be open for extension, but closed for modification."*

### ❌ Violation Example

```php
class ShippingCalculator
{
    public function calculateShipping(Order $order): Money
    {
        if ($order->getShippingMethod() === 'standard') {
            return Money::of(10.00);
        } elseif ($order->getShippingMethod() === 'express') {
            return Money::of(25.00);
        } elseif ($order->getShippingMethod() === 'overnight') {
            return Money::of(50.00);
        } elseif ($order->getShippingMethod() === 'international') {
            // New requirement: international shipping
            return Money::of(75.00);
        }
        
        throw new InvalidArgumentException('Unknown shipping method');
    }
}
```

**Problems:**
- Adding new shipping methods requires modifying existing code
- Risk of breaking existing functionality
- Violates the "closed for modification" principle

### ✅ OCP Solution

```php
// Open for extension: New strategies can be added
interface ShippingStrategyInterface
{
    public function calculateCost(Order $order): Money;
    public function getMethodName(): string;
}

class StandardShipping implements ShippingStrategyInterface
{
    public function calculateCost(Order $order): Money
    {
        return Money::of(10.00);
    }
    
    public function getMethodName(): string
    {
        return 'standard';
    }
}

class ExpressShipping implements ShippingStrategyInterface
{
    public function calculateCost(Order $order): Money
    {
        return Money::of(25.00);
    }
    
    public function getMethodName(): string
    {
        return 'express';
    }
}

class OvernightShipping implements ShippingStrategyInterface
{
    public function calculateCost(Order $order): Money
    {
        $baseCost = Money::of(50.00);
        
        // Express shipping has weight-based pricing
        $weight = $order->getTotalWeight();
        if ($weight > 10) {
            $baseCost = $baseCost->add(Money::of(20.00));
        }
        
        return $baseCost;
    }
    
    public function getMethodName(): string
    {
        return 'overnight';
    }
}

// New shipping method: No modification of existing code!
class InternationalShipping implements ShippingStrategyInterface
{
    public function calculateCost(Order $order): Money
    {
        $baseCost = Money::of(75.00);
        
        // International shipping has country-specific pricing
        $country = $order->getShippingAddress()->getCountry();
        $multiplier = $this->getCountryMultiplier($country);
        
        return $baseCost->multiply($multiplier);
    }
    
    public function getMethodName(): string
    {
        return 'international';
    }
    
    private function getCountryMultiplier(string $country): float
    {
        return match($country) {
            'CA', 'MX' => 1.2,
            'EU' => 1.5,
            'AS' => 2.0,
            default => 1.0
        };
    }
}

// Closed for modification: This class never changes
class ShippingCalculator
{
    public function __construct(
        private array $strategies // Array of ShippingStrategyInterface
    ) {}
    
    public function calculateShipping(Order $order): Money
    {
        foreach ($this->strategies as $strategy) {
            if ($strategy->getMethodName() === $order->getShippingMethod()) {
                return $strategy->calculateCost($order);
            }
        }
        
        throw new InvalidArgumentException('Unknown shipping method');
    }
}
```

**Benefits:**
- Adding new shipping methods doesn't require changing existing code
- Each strategy can have its own complex logic
- Easy to test each strategy independently
- Follows the strategy pattern

## 3️⃣ Liskov Substitution Principle (LSP)

> *"Objects of a superclass should be replaceable with objects of its subclasses without breaking the application."*

### ❌ Violation Example

```php
interface PaymentProcessorInterface
{
    public function processPayment(Money $amount): PaymentResult;
}

class CreditCardProcessor implements PaymentProcessorInterface
{
    public function processPayment(Money $amount): PaymentResult
    {
        // Normal payment processing
        return new PaymentResult(true, 'Payment successful');
    }
}

class GiftCardProcessor implements PaymentProcessorInterface
{
    public function processPayment(Money $amount): PaymentResult
    {
        // Problem: Gift cards can't process amounts greater than balance
        if ($amount->greaterThan($this->getBalance())) {
            throw new InsufficientFundsException(); // LSP violation!
        }
        
        return new PaymentResult(true, 'Payment successful');
    }
}

// This code expects PaymentProcessorInterface to always work
class PaymentService
{
    public function processOrderPayment(Order $order, PaymentProcessorInterface $processor): void
    {
        try {
            $result = $processor->processPayment($order->getTotal());
            // This assumes processPayment never throws exceptions
            // But GiftCardProcessor violates this assumption!
        } catch (Exception $e) {
            // Unexpected exception handling needed
        }
    }
}
```

### ✅ LSP Solution

```php
// Contract is clear: method can fail, returns result object
interface PaymentProcessorInterface
{
    public function processPayment(Money $amount): PaymentResult;
    public function canProcessAmount(Money $amount): bool;
}

class PaymentResult
{
    public function __construct(
        private bool $success,
        private string $message,
        private ?string $transactionId = null
    ) {}
    
    public function isSuccessful(): bool { return $this->success; }
    public function getMessage(): string { return $this->message; }
    public function getTransactionId(): ?string { return $this->transactionId; }
}

class CreditCardProcessor implements PaymentProcessorInterface
{
    public function processPayment(Money $amount): PaymentResult
    {
        // Simulate credit card processing
        if ($this->validateCard() && $this->authorizeCharge($amount)) {
            return new PaymentResult(true, 'Payment successful', 'cc_' . uniqid());
        }
        
        return new PaymentResult(false, 'Credit card authorization failed');
    }
    
    public function canProcessAmount(Money $amount): bool
    {
        // Credit cards typically have high limits
        return $amount->lessThanOrEqual(Money::of(10000));
    }
}

class GiftCardProcessor implements PaymentProcessorInterface
{
    public function processPayment(Money $amount): PaymentResult
    {
        if (!$this->canProcessAmount($amount)) {
            return new PaymentResult(false, 'Insufficient gift card balance');
        }
        
        $this->deductBalance($amount);
        return new PaymentResult(true, 'Payment successful', 'gc_' . uniqid());
    }
    
    public function canProcessAmount(Money $amount): bool
    {
        return $amount->lessThanOrEqual($this->getBalance());
    }
    
    private function getBalance(): Money { /* ... */ }
    private function deductBalance(Money $amount): void { /* ... */ }
}

// Now this works correctly with any PaymentProcessorInterface
class PaymentService
{
    public function processOrderPayment(Order $order, PaymentProcessorInterface $processor): void
    {
        if (!$processor->canProcessAmount($order->getTotal())) {
            throw new PaymentException('Payment processor cannot handle this amount');
        }
        
        $result = $processor->processPayment($order->getTotal());
        
        if ($result->isSuccessful()) {
            $order->markAsPaid($result->getTransactionId());
        } else {
            throw new PaymentException($result->getMessage());
        }
    }
}
```

**Key LSP Rules:**
- Subtypes must honor the contract of their parent type
- Exceptions should not be stronger (more restrictive) in subtypes
- Preconditions cannot be stronger in subtypes
- Postconditions cannot be weaker in subtypes

## 4️⃣ Interface Segregation Principle (ISP)

> *"Clients should not be forced to depend upon interfaces they do not use."*

### ❌ Violation Example

```php
// Fat interface: Forces clients to implement methods they don't need
interface UserManagementInterface
{
    // User CRUD operations
    public function createUser(array $userData): User;
    public function updateUser(int $userId, array $userData): User;
    public function deleteUser(int $userId): void;
    public function findUser(int $userId): ?User;
    
    // Password management
    public function changePassword(int $userId, string $newPassword): void;
    public function resetPassword(int $userId): string;
    
    // Email operations
    public function sendWelcomeEmail(int $userId): void;
    public function sendPasswordResetEmail(int $userId): void;
    
    // Admin operations
    public function banUser(int $userId): void;
    public function unbanUser(int $userId): void;
    public function getUserStatistics(): array;
}

// This class only needs basic CRUD but must implement everything
class UserRepository implements UserManagementInterface
{
    public function createUser(array $userData): User { /* implementation */ }
    public function updateUser(int $userId, array $userData): User { /* implementation */ }
    public function deleteUser(int $userId): void { /* implementation */ }
    public function findUser(int $userId): ?User { /* implementation */ }
    
    // Forced to implement these even though repository shouldn't handle passwords
    public function changePassword(int $userId, string $newPassword): void
    {
        throw new BadMethodCallException('Repository should not handle passwords');
    }
    
    public function resetPassword(int $userId): string
    {
        throw new BadMethodCallException('Repository should not handle passwords');
    }
    
    // Forced to implement email methods
    public function sendWelcomeEmail(int $userId): void
    {
        throw new BadMethodCallException('Repository should not send emails');
    }
    
    public function sendPasswordResetEmail(int $userId): void
    {
        throw new BadMethodCallException('Repository should not send emails');
    }
    
    // Forced to implement admin methods
    public function banUser(int $userId): void
    {
        throw new BadMethodCallException('Repository should not handle admin operations');
    }
    
    public function unbanUser(int $userId): void
    {
        throw new BadMethodCallException('Repository should not handle admin operations');
    }
    
    public function getUserStatistics(): array
    {
        throw new BadMethodCallException('Repository should not generate statistics');
    }
}
```

### ✅ ISP Solution

```php
// Segregated interfaces: Each serves a specific purpose
interface UserRepositoryInterface
{
    public function createUser(array $userData): User;
    public function updateUser(int $userId, array $userData): User;
    public function deleteUser(int $userId): void;
    public function findUser(int $userId): ?User;
}

interface PasswordServiceInterface
{
    public function changePassword(int $userId, string $newPassword): void;
    public function resetPassword(int $userId): string;
    public function validatePassword(string $password): bool;
}

interface UserNotificationInterface
{
    public function sendWelcomeEmail(int $userId): void;
    public function sendPasswordResetEmail(int $userId): void;
    public function sendAccountUpdateEmail(int $userId): void;
}

interface UserAdministrationInterface
{
    public function banUser(int $userId): void;
    public function unbanUser(int $userId): void;
    public function getUserStatistics(): array;
    public function getActiveUserCount(): int;
}

// Clean implementations: Each class implements only what it needs
class UserRepository implements UserRepositoryInterface
{
    public function createUser(array $userData): User { /* implementation */ }
    public function updateUser(int $userId, array $userData): User { /* implementation */ }
    public function deleteUser(int $userId): void { /* implementation */ }
    public function findUser(int $userId): ?User { /* implementation */ }
}

class PasswordService implements PasswordServiceInterface
{
    public function changePassword(int $userId, string $newPassword): void { /* implementation */ }
    public function resetPassword(int $userId): string { /* implementation */ }
    public function validatePassword(string $password): bool { /* implementation */ }
}

class UserNotificationService implements UserNotificationInterface
{
    public function sendWelcomeEmail(int $userId): void { /* implementation */ }
    public function sendPasswordResetEmail(int $userId): void { /* implementation */ }
    public function sendAccountUpdateEmail(int $userId): void { /* implementation */ }
}

class UserAdministrationService implements UserAdministrationInterface
{
    public function banUser(int $userId): void { /* implementation */ }
    public function unbanUser(int $userId): void { /* implementation */ }
    public function getUserStatistics(): array { /* implementation */ }
    public function getActiveUserCount(): int { /* implementation */ }
}

// Clients depend only on what they need
class UserController
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private PasswordServiceInterface $passwordService,
        private UserNotificationInterface $notificationService
    ) {}
    
    public function register(array $userData): Response
    {
        $user = $this->userRepository->createUser($userData);
        $this->notificationService->sendWelcomeEmail($user->getId());
        return new Response('User created successfully');
    }
}

class AdminController
{
    public function __construct(
        private UserAdministrationInterface $adminService
    ) {}
    
    public function dashboard(): Response
    {
        $stats = $this->adminService->getUserStatistics();
        return new Response($stats);
    }
}
```

**Benefits:**
- Classes only implement methods they actually use
- Changes to one interface don't affect unrelated clients
- Easier to test and mock
- More cohesive interfaces

## 5️⃣ Dependency Inversion Principle (DIP)

> *"Depend upon abstractions, not concretions."*

### ❌ Violation Example

```php
// High-level module depends on low-level modules
class OrderService
{
    private MySQLOrderRepository $orderRepository;
    private SMTPEmailService $emailService;
    private FileLogger $logger;
    
    public function __construct()
    {
        // Depends on concrete implementations
        $this->orderRepository = new MySQLOrderRepository();
        $this->emailService = new SMTPEmailService();
        $this->logger = new FileLogger('/var/log/orders.log');
    }
    
    public function processOrder(Order $order): void
    {
        // High-level business logic mixed with low-level details
        $this->orderRepository->save($order);
        $this->emailService->sendConfirmation($order);
        $this->logger->log("Order processed: " . $order->getId());
    }
}

// Low-level modules
class MySQLOrderRepository
{
    public function save(Order $order): void
    {
        // MySQL-specific implementation
    }
}

class SMTPEmailService
{
    public function sendConfirmation(Order $order): void
    {
        // SMTP-specific implementation
    }
}

class FileLogger
{
    public function log(string $message): void
    {
        // File-specific implementation
    }
}
```

**Problems:**
- `OrderService` is tightly coupled to specific implementations
- Hard to change database from MySQL to PostgreSQL
- Hard to switch from SMTP to SendGrid
- Impossible to test without real database/email/files

### ✅ DIP Solution

```php
// Abstractions (interfaces)
interface OrderRepositoryInterface
{
    public function save(Order $order): void;
    public function findById(int $id): ?Order;
}

interface EmailServiceInterface
{
    public function sendOrderConfirmation(Order $order): void;
}

interface LoggerInterface
{
    public function info(string $message): void;
    public function error(string $message): void;
}

// High-level module depends on abstractions
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}
    
    public function processOrder(Order $order): void
    {
        try {
            $this->orderRepository->save($order);
            $this->emailService->sendOrderConfirmation($order);
            $this->logger->info("Order processed successfully: " . $order->getId());
        } catch (Exception $e) {
            $this->logger->error("Failed to process order: " . $e->getMessage());
            throw $e;
        }
    }
}

// Low-level modules implement abstractions
class MySQLOrderRepository implements OrderRepositoryInterface
{
    public function save(Order $order): void
    {
        // MySQL-specific implementation
    }
    
    public function findById(int $id): ?Order
    {
        // MySQL-specific implementation
    }
}

class PostgreSQLOrderRepository implements OrderRepositoryInterface
{
    public function save(Order $order): void
    {
        // PostgreSQL-specific implementation
    }
    
    public function findById(int $id): ?Order
    {
        // PostgreSQL-specific implementation
    }
}

class SendGridEmailService implements EmailServiceInterface
{
    public function sendOrderConfirmation(Order $order): void
    {
        // SendGrid API implementation
    }
}

class SMTPEmailService implements EmailServiceInterface
{
    public function sendOrderConfirmation(Order $order): void
    {
        // SMTP implementation
    }
}

class ElasticSearchLogger implements LoggerInterface
{
    public function info(string $message): void
    {
        // ElasticSearch logging
    }
    
    public function error(string $message): void
    {
        // ElasticSearch error logging
    }
}
```

**Dependency Injection Configuration:**
```php
// Configuration determines which implementations to use
$container = new DIContainer();

// Can easily switch implementations
$container->bind(OrderRepositoryInterface::class, MySQLOrderRepository::class);
$container->bind(EmailServiceInterface::class, SendGridEmailService::class);
$container->bind(LoggerInterface::class, ElasticSearchLogger::class);

// OrderService gets injected with the configured implementations
$orderService = $container->get(OrderService::class);
```

## 🎯 SOLID Principles Working Together

Let's see how all SOLID principles work together in a complete example:

```php
// SRP: Each class has a single responsibility
// ISP: Focused interfaces
interface ProductRepositoryInterface
{
    public function findById(int $id): ?Product;
    public function save(Product $product): void;
}

interface InventoryServiceInterface
{
    public function reserveStock(int $productId, int $quantity): bool;
    public function releaseStock(int $productId, int $quantity): void;
}

interface PricingServiceInterface
{
    public function calculatePrice(Product $product, Customer $customer): Money;
}

// OCP: Open for extension, closed for modification
interface DiscountStrategyInterface
{
    public function calculateDiscount(Money $amount, Customer $customer): Money;
}

class VIPDiscountStrategy implements DiscountStrategyInterface
{
    public function calculateDiscount(Money $amount, Customer $customer): Money
    {
        return $customer->isVIP() ? $amount->multiply(0.9) : Money::zero();
    }
}

class SeasonalDiscountStrategy implements DiscountStrategyInterface
{
    public function calculateDiscount(Money $amount, Customer $customer): Money
    {
        return $this->isHolidaySeason() ? $amount->multiply(0.95) : Money::zero();
    }
}

// LSP: All implementations can be substituted
class PricingService implements PricingServiceInterface
{
    public function __construct(
        private array $discountStrategies // Array of DiscountStrategyInterface
    ) {}
    
    public function calculatePrice(Product $product, Customer $customer): Money
    {
        $basePrice = $product->getPrice();
        
        $totalDiscount = Money::zero();
        foreach ($this->discountStrategies as $strategy) {
            $discount = $strategy->calculateDiscount($basePrice, $customer);
            $totalDiscount = $totalDiscount->add($discount);
        }
        
        return $basePrice->subtract($totalDiscount);
    }
}

// DIP: Depends on abstractions, not concretions
class CartService
{
    public function __construct(
        private ProductRepositoryInterface $productRepository,
        private InventoryServiceInterface $inventoryService,
        private PricingServiceInterface $pricingService
    ) {}
    
    public function addToCart(Cart $cart, int $productId, int $quantity): void
    {
        $product = $this->productRepository->findById($productId);
        if (!$product) {
            throw new ProductNotFoundException();
        }
        
        if (!$this->inventoryService->reserveStock($productId, $quantity)) {
            throw new InsufficientStockException();
        }
        
        $price = $this->pricingService->calculatePrice($product, $cart->getCustomer());
        $cart->addItem(new CartItem($product, $quantity, $price));
    }
}
```

## 🎓 Key Benefits of SOLID + DI

1. **Maintainability**: Easy to modify and extend
2. **Testability**: Easy to mock dependencies  
3. **Flexibility**: Easy to swap implementations
4. **Readability**: Clear responsibilities and dependencies
5. **Reusability**: Components can be reused in different contexts
6. **Reliability**: Fewer bugs due to loose coupling

## 🚀 Next Steps

Now that you understand SOLID principles, you're ready to:

1. **Learn Ray.Di Fundamentals**: See how the framework implements these principles
2. **Practice with Examples**: Apply SOLID principles in real code
3. **Explore Design Patterns**: See how SOLID enables common patterns

**Continue to:** [Ray.Di Fundamentals](raydi-fundamentals.md)

## 💡 Key Takeaways

- **SOLID principles** create maintainable, flexible software
- **Dependency injection** naturally enables SOLID design
- **Each principle** addresses specific design problems
- **Together** they create robust, testable architectures
- **Ray.Di** provides the tools to implement SOLID principles easily

---

**Remember:** SOLID principles are not rules to follow blindly, but guidelines that help you create better software architecture. Use them wisely and adapt them to your specific context!