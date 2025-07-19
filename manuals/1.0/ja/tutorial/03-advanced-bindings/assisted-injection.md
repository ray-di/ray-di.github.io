---
layout: docs-ja
title: アシスト束縛
category: Manual
permalink: /manuals/1.0/ja/tutorial/03-advanced-bindings/assisted-injection.html
---

# アシスト束縛

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- アシスト束縛とは何か、なぜ必要なのか
- ファクトリーパターンとDIの組み合わせ
- ランタイムパラメータと注入依存関係の混在
- 実践的なE-commerceアプリケーションでの使用例
- Google Guiceとの関係性と実装方法

## アシスト束縛とは

**アシスト束縛**（Google Guiceでは**Assisted Injection**として知られる）は、オブジェクトの作成時にランタイムパラメータ（実行時に決まる値）と注入依存関係を組み合わせる機能です。これにより、ファクトリーパターンを使いながらDIの恩恵を受けることができます。

### 問題：ランタイムパラメータとDIの混在

```php
// 従来の問題：ランタイムパラメータと依存関係の混在
class Order
{
    public function __construct(
        private int $orderId,           // ランタイムパラメータ
        private string $customerEmail,  // ランタイムパラメータ
        private PaymentGateway $paymentGateway,  // 依存関係
        private LoggerInterface $logger          // 依存関係
    ) {}
}

// 問題：手動でファクトリーを作成する必要がある
class OrderFactory
{
    public function __construct(
        private PaymentGateway $paymentGateway,
        private LoggerInterface $logger
    ) {}
    
    public function create(int $orderId, string $customerEmail): Order
    {
        return new Order(
            $orderId,
            $customerEmail,
            $this->paymentGateway,
            $this->logger
        );
    }
}
```

### 解決策：アシスト束縛

```php
use Ray\Di\Di\Assisted;

// アシスト束縛を使用した解決策
class Order
{
    public function __construct(
        #[Assisted] private int $orderId,           // ランタイムパラメータ
        #[Assisted] private string $customerEmail,  // ランタイムパラメータ
        private PaymentGateway $paymentGateway,     // 注入される依存関係
        private LoggerInterface $logger             // 注入される依存関係
    ) {}
    
    public function process(): void
    {
        $this->logger->info("Processing order {$this->orderId} for {$this->customerEmail}");
        $this->paymentGateway->processPayment($this->orderId);
    }
}

// ファクトリーインターフェースの定義
interface OrderFactoryInterface
{
    public function create(int $orderId, string $customerEmail): Order;
}

// モジュールでの設定
use Ray\Di\AssistedModule;

class OrderModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new AssistedModule());
        $this->bind(OrderFactoryInterface::class);
    }
}

// 使用例
class OrderService
{
    public function __construct(
        private OrderFactoryInterface $orderFactory
    ) {}
    
    public function createOrder(int $orderId, string $customerEmail): Order
    {
        return $this->orderFactory->create($orderId, $customerEmail);
    }
}
```

## Google Guiceとの関係

### Google Guice の例

```java
// Google Guice
public class RealPayment implements Payment {
    @AssistedInject
    public RealPayment(
        CreditService creditService,
        AuthService authService,
        @Assisted Date startDate,
        @Assisted Money amount) {
        // ...
    }
}

// ファクトリーインターフェース
public interface PaymentFactory {
    Payment create(Date startDate, Money amount);
}

// モジュール設定
install(new FactoryModuleBuilder()
    .implement(Payment.class, RealPayment.class)
    .build(PaymentFactory.class));
```

### Ray.Di の対応

```php
// Ray.Di
class RealPayment implements Payment
{
    public function __construct(
        private CreditService $creditService,
        private AuthService $authService,
        #[Assisted] private DateTimeInterface $startDate,
        #[Assisted] private Money $amount
    ) {}
}

// ファクトリーインターフェース
interface PaymentFactoryInterface
{
    public function create(DateTimeInterface $startDate, Money $amount): Payment;
}

// モジュール設定
class PaymentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new AssistedModule());
        $this->bind(PaymentFactoryInterface::class);
    }
}
```

## 実践的な使用例

### 1. E-commerce商品システム

```php
// 商品レビューシステム
class ProductReview
{
    public function __construct(
        #[Assisted] private int $productId,
        #[Assisted] private int $userId,
        #[Assisted] private string $reviewText,
        #[Assisted] private int $rating,
        private UserRepositoryInterface $userRepository,
        private ProductRepositoryInterface $productRepository,
        private LoggerInterface $logger
    ) {}
    
    public function validate(): bool
    {
        $user = $this->userRepository->findById($this->userId);
        $product = $this->productRepository->findById($this->productId);
        
        if (!$user || !$product) {
            $this->logger->error("Invalid user or product for review");
            return false;
        }
        
        if ($this->rating < 1 || $this->rating > 5) {
            $this->logger->error("Invalid rating: {$this->rating}");
            return false;
        }
        
        return true;
    }
    
    public function save(): void
    {
        if ($this->validate()) {
            // レビューを保存
            $this->logger->info("Review saved for product {$this->productId}");
        }
    }
    
    public function getProductId(): int { return $this->productId; }
    public function getUserId(): int { return $this->userId; }
    public function getReviewText(): string { return $this->reviewText; }
    public function getRating(): int { return $this->rating; }
}

interface ProductReviewFactoryInterface
{
    public function create(int $productId, int $userId, string $reviewText, int $rating): ProductReview;
}

class ReviewService
{
    public function __construct(
        private ProductReviewFactoryInterface $reviewFactory
    ) {}
    
    public function submitReview(int $productId, int $userId, string $reviewText, int $rating): bool
    {
        $review = $this->reviewFactory->create($productId, $userId, $reviewText, $rating);
        
        if ($review->validate()) {
            $review->save();
            return true;
        }
        
        return false;
    }
}
```

### 2. 通知システム

```php
class EmailNotification
{
    public function __construct(
        #[Assisted] private string $recipient,
        #[Assisted] private string $subject,
        #[Assisted] private string $body,
        private EmailServiceInterface $emailService,
        private TemplateEngineInterface $templateEngine,
        private LoggerInterface $logger
    ) {}
    
    public function send(): bool
    {
        try {
            $formattedBody = $this->templateEngine->render('email/notification.html', [
                'body' => $this->body,
                'recipient' => $this->recipient
            ]);
            
            $this->emailService->send($this->recipient, $this->subject, $formattedBody);
            $this->logger->info("Email sent to {$this->recipient}");
            
            return true;
        } catch (Exception $e) {
            $this->logger->error("Failed to send email: {$e->getMessage()}");
            return false;
        }
    }
}

interface EmailNotificationFactoryInterface
{
    public function create(string $recipient, string $subject, string $body): EmailNotification;
}

class NotificationService
{
    public function __construct(
        private EmailNotificationFactoryInterface $emailFactory
    ) {}
    
    public function sendOrderConfirmation(Order $order): void
    {
        $notification = $this->emailFactory->create(
            $order->getCustomerEmail(),
            'Order Confirmation',
            "Your order #{$order->getId()} has been confirmed."
        );
        
        $notification->send();
    }
    
    public function sendShippingNotification(Order $order, string $trackingNumber): void
    {
        $notification = $this->emailFactory->create(
            $order->getCustomerEmail(),
            'Order Shipped',
            "Your order #{$order->getId()} has been shipped. Tracking: {$trackingNumber}"
        );
        
        $notification->send();
    }
}
```

### 3. 複雑なレポートシステム

```php
class SalesReport
{
    public function __construct(
        #[Assisted] private DateTimeInterface $startDate,
        #[Assisted] private DateTimeInterface $endDate,
        #[Assisted] private string $reportType,
        private OrderRepositoryInterface $orderRepository,
        private CacheInterface $cache,
        private LoggerInterface $logger
    ) {}
    
    public function generate(): array
    {
        $cacheKey = "sales_report_{$this->reportType}_{$this->startDate->format('Y-m-d')}_{$this->endDate->format('Y-m-d')}";
        
        $cachedReport = $this->cache->get($cacheKey);
        if ($cachedReport !== null) {
            $this->logger->info("Using cached report: {$cacheKey}");
            return $cachedReport;
        }
        
        $this->logger->info("Generating new report: {$this->reportType}");
        
        $orders = $this->orderRepository->findByDateRange($this->startDate, $this->endDate);
        
        $report = match($this->reportType) {
            'daily' => $this->generateDailyReport($orders),
            'weekly' => $this->generateWeeklyReport($orders),
            'monthly' => $this->generateMonthlyReport($orders),
            default => throw new InvalidArgumentException("Unknown report type: {$this->reportType}")
        };
        
        $this->cache->set($cacheKey, $report, 3600); // 1時間キャッシュ
        
        return $report;
    }
    
    private function generateDailyReport(array $orders): array
    {
        // 日次レポートの生成ロジック
        return ['type' => 'daily', 'data' => $orders];
    }
    
    private function generateWeeklyReport(array $orders): array
    {
        // 週次レポートの生成ロジック
        return ['type' => 'weekly', 'data' => $orders];
    }
    
    private function generateMonthlyReport(array $orders): array
    {
        // 月次レポートの生成ロジック
        return ['type' => 'monthly', 'data' => $orders];
    }
}

interface SalesReportFactoryInterface
{
    public function create(DateTimeInterface $startDate, DateTimeInterface $endDate, string $reportType): SalesReport;
}

class ReportService
{
    public function __construct(
        private SalesReportFactoryInterface $reportFactory
    ) {}
    
    public function generateDailyReport(DateTimeInterface $date): array
    {
        $startDate = $date->modify('midnight');
        $endDate = $date->modify('23:59:59');
        
        $report = $this->reportFactory->create($startDate, $endDate, 'daily');
        return $report->generate();
    }
    
    public function generateMonthlyReport(int $year, int $month): array
    {
        $startDate = new DateTime("{$year}-{$month}-01");
        $endDate = (clone $startDate)->modify('last day of this month')->modify('23:59:59');
        
        $report = $this->reportFactory->create($startDate, $endDate, 'monthly');
        return $report->generate();
    }
}
```

## 高度なパターン

### 1. 複数のファクトリーの組み合わせ

```php
// 注文アイテムファクトリー
class OrderItem
{
    public function __construct(
        #[Assisted] private int $productId,
        #[Assisted] private int $quantity,
        #[Assisted] private float $price,
        private ProductRepositoryInterface $productRepository,
        private LoggerInterface $logger
    ) {}
    
    public function validate(): bool
    {
        $product = $this->productRepository->findById($this->productId);
        return $product && $product->isAvailable() && $this->quantity > 0;
    }
    
    public function getTotalPrice(): float
    {
        return $this->price * $this->quantity;
    }
}

interface OrderItemFactoryInterface
{
    public function create(int $productId, int $quantity, float $price): OrderItem;
}

// 注文ファクトリー
class ComplexOrder
{
    public function __construct(
        #[Assisted] private int $customerId,
        #[Assisted] private array $itemsData,
        private OrderItemFactoryInterface $itemFactory,
        private CustomerRepositoryInterface $customerRepository,
        private LoggerInterface $logger
    ) {}
    
    public function build(): Order
    {
        $customer = $this->customerRepository->findById($this->customerId);
        if (!$customer) {
            throw new CustomerNotFoundException("Customer not found: {$this->customerId}");
        }
        
        $items = [];
        foreach ($this->itemsData as $itemData) {
            $item = $this->itemFactory->create(
                $itemData['product_id'],
                $itemData['quantity'],
                $itemData['price']
            );
            
            if ($item->validate()) {
                $items[] = $item;
            } else {
                $this->logger->warning("Invalid item skipped: " . json_encode($itemData));
            }
        }
        
        if (empty($items)) {
            throw new EmptyOrderException("No valid items in order");
        }
        
        return new Order($customer, $items);
    }
}

interface ComplexOrderFactoryInterface
{
    public function create(int $customerId, array $itemsData): ComplexOrder;
}
```

### 2. 条件付きファクトリー

```php
class PaymentProcessor
{
    public function __construct(
        #[Assisted] private string $paymentMethod,
        #[Assisted] private float $amount,
        #[Assisted] private array $paymentData,
        private PaymentGatewayRegistryInterface $gatewayRegistry,
        private LoggerInterface $logger
    ) {}
    
    public function process(): PaymentResult
    {
        $gateway = $this->gatewayRegistry->getGateway($this->paymentMethod);
        
        if (!$gateway) {
            $this->logger->error("Payment gateway not found: {$this->paymentMethod}");
            throw new PaymentGatewayNotFoundException($this->paymentMethod);
        }
        
        $this->logger->info("Processing payment: {$this->paymentMethod}, Amount: {$this->amount}");
        
        return $gateway->process($this->amount, $this->paymentData);
    }
}

interface PaymentProcessorFactoryInterface
{
    public function create(string $paymentMethod, float $amount, array $paymentData): PaymentProcessor;
}

class PaymentService
{
    public function __construct(
        private PaymentProcessorFactoryInterface $processorFactory
    ) {}
    
    public function processPayment(string $method, float $amount, array $data): PaymentResult
    {
        $processor = $this->processorFactory->create($method, $amount, $data);
        return $processor->process();
    }
}
```

## モジュール設定とベストプラクティス

### 1. 統合モジュール

```php
class ECommerceModule extends AbstractModule
{
    protected function configure(): void
    {
        // アシスト束縛を有効化
        $this->install(new AssistedModule());
        
        // 各ファクトリーの束縛
        $this->bind(OrderFactoryInterface::class);
        $this->bind(ProductReviewFactoryInterface::class);
        $this->bind(EmailNotificationFactoryInterface::class);
        $this->bind(SalesReportFactoryInterface::class);
        $this->bind(PaymentProcessorFactoryInterface::class);
        
        // 依存関係の束縛
        $this->bind(PaymentGateway::class)->to(StripePaymentGateway::class);
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
    }
}
```

### 2. テストでの使用

```php
class OrderServiceTest extends PHPUnit\Framework\TestCase
{
    private OrderService $orderService;
    private OrderFactoryInterface $orderFactory;
    
    protected function setUp(): void
    {
        $injector = new Injector(new TestModule());
        $this->orderService = $injector->getInstance(OrderService::class);
        $this->orderFactory = $injector->getInstance(OrderFactoryInterface::class);
    }
    
    public function testCreateOrder(): void
    {
        $order = $this->orderService->createOrder(123, 'customer@example.com');
        
        $this->assertInstanceOf(Order::class, $order);
        $this->assertEquals(123, $order->getOrderId());
        $this->assertEquals('customer@example.com', $order->getCustomerEmail());
    }
}

class TestModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new AssistedModule());
        $this->bind(OrderFactoryInterface::class);
        $this->bind(PaymentGateway::class)->to(MockPaymentGateway::class);
        $this->bind(LoggerInterface::class)->to(NullLogger::class);
    }
}
```

## ベストプラクティス

### 1. アシストパラメータの命名

```php
// 良い：明確な命名
class UserNotification
{
    public function __construct(
        #[Assisted] private int $userId,
        #[Assisted] private string $notificationMessage,
        private UserRepositoryInterface $userRepository
    ) {}
}

// 悪い：曖昧な命名
class UserNotification
{
    public function __construct(
        #[Assisted] private int $id,
        #[Assisted] private string $message,
        private UserRepositoryInterface $userRepository
    ) {}
}
```

### 2. 依存関係の最小化

```php
// 良い：必要最小限の依存関係
class OrderEmailNotification
{
    public function __construct(
        #[Assisted] private Order $order,
        private EmailServiceInterface $emailService
    ) {}
}

// 悪い：不要な依存関係
class OrderEmailNotification
{
    public function __construct(
        #[Assisted] private Order $order,
        private EmailServiceInterface $emailService,
        private DatabaseInterface $database, // 不要
        private ConfigInterface $config       // 不要
    ) {}
}
```

### 3. バリデーションの実装

```php
class ValidatedOrderItem
{
    public function __construct(
        #[Assisted] private int $productId,
        #[Assisted] private int $quantity,
        private ProductRepositoryInterface $productRepository
    ) {
        $this->validateInput();
    }
    
    private function validateInput(): void
    {
        if ($this->productId <= 0) {
            throw new InvalidArgumentException("Product ID must be positive");
        }
        
        if ($this->quantity <= 0) {
            throw new InvalidArgumentException("Quantity must be positive");
        }
        
        $product = $this->productRepository->findById($this->productId);
        if (!$product) {
            throw new ProductNotFoundException("Product not found: {$this->productId}");
        }
    }
}
```

## 次のステップ

アシスト束縛の使用方法を理解したので、次に進む準備が整いました。

1. **モジュールの分割と結合の学習**: 大規模アプリケーションでのモジュール設計
2. **束縛DSLの探索**: Ray.Diの表現力豊かなDSL
3. **スコープとライフサイクルの学習**: オブジェクトの生存期間管理

**続きは:** [モジュールの分割と結合](../02-basic-bindings/module-composition.html)

## 重要なポイント

- **アシスト束縛**はランタイムパラメータとDI依存関係を組み合わせる
- **#[Assisted]**アトリビュートでランタイムパラメータを明示
- **ファクトリーパターン**とDIの恩恵を同時に享受
- **Google Guice**のAssisted Injectionと同等の機能
- **バリデーション**と**エラーハンドリング**を適切に実装
- **テスト**では簡単にモック依存関係を注入可能

---

アシスト束縛は、実世界のアプリケーションでよく必要となる「実行時パラメータ」と「依存関係」を優雅に組み合わせる強力な機能です。ファクトリーパターンの複雑さを隠蔽しながら、DIの恩恵を最大限に活用できます。