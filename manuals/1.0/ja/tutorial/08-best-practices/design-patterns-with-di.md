---
layout: docs-ja
title: DIを使ったデザインパターン
category: Manual
permalink: /manuals/1.0/ja/tutorial/08-best-practices/design-patterns-with-di.html
---

# DIを使ったデザインパターン

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diと組み合わせた効果的なデザインパターン
- 依存性注入を活用した各種パターンの実装
- 実際のアプリケーション開発での活用方法
- アーキテクチャパターンとの統合
- 保守性と拡張性を向上させる設計手法

## 生成パターン

### 1. Factory Pattern with DI

```php
// 製品インターフェース
interface NotificationInterface
{
    public function send(string $message, array $recipients): void;
}

// 具体的な製品クラス
class EmailNotification implements NotificationInterface
{
    public function __construct(
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}

    public function send(string $message, array $recipients): void
    {
        foreach ($recipients as $recipient) {
            $this->emailService->send($recipient, 'Notification', $message);
            $this->logger->info("Email sent to {$recipient}");
        }
    }
}

class SmsNotification implements NotificationInterface
{
    public function __construct(
        private SmsServiceInterface $smsService,
        private LoggerInterface $logger
    ) {}

    public function send(string $message, array $recipients): void
    {
        foreach ($recipients as $recipient) {
            $this->smsService->send($recipient, $message);
            $this->logger->info("SMS sent to {$recipient}");
        }
    }
}

class PushNotification implements NotificationInterface
{
    public function __construct(
        private PushServiceInterface $pushService,
        private LoggerInterface $logger
    ) {}

    public function send(string $message, array $recipients): void
    {
        foreach ($recipients as $recipient) {
            $this->pushService->send($recipient, $message);
            $this->logger->info("Push notification sent to {$recipient}");
        }
    }
}

// DIを使ったファクトリー
class NotificationFactory
{
    public function __construct(
        private Injector $injector
    ) {}

    public function create(string $type): NotificationInterface
    {
        return match ($type) {
            'email' => $this->injector->getInstance(EmailNotification::class),
            'sms' => $this->injector->getInstance(SmsNotification::class),
            'push' => $this->injector->getInstance(PushNotification::class),
            default => throw new InvalidArgumentException("Unknown notification type: {$type}")
        };
    }

    public function createMultiple(array $types): array
    {
        $notifications = [];
        foreach ($types as $type) {
            $notifications[] = $this->create($type);
        }
        return $notifications;
    }
}

// 使用例
class NotificationService
{
    public function __construct(
        private NotificationFactory $factory,
        private UserRepositoryInterface $userRepository
    ) {}

    public function sendUserNotification(int $userId, string $message): void
    {
        $user = $this->userRepository->findById($userId);
        $preferences = $user->getNotificationPreferences();
        
        $notifications = $this->factory->createMultiple($preferences);
        
        foreach ($notifications as $notification) {
            $notification->send($message, [$user->getContactInfo()]);
        }
    }
}
```

### 2. Abstract Factory Pattern

```php
// 抽象ファクトリー
interface PaymentGatewayFactoryInterface
{
    public function createProcessor(): PaymentProcessorInterface;
    public function createValidator(): PaymentValidatorInterface;
    public function createLogger(): PaymentLoggerInterface;
}

// 具体的なファクトリー
class StripePaymentGatewayFactory implements PaymentGatewayFactoryInterface
{
    public function __construct(
        private Injector $injector
    ) {}

    public function createProcessor(): PaymentProcessorInterface
    {
        return $this->injector->getInstance(StripePaymentProcessor::class);
    }

    public function createValidator(): PaymentValidatorInterface
    {
        return $this->injector->getInstance(StripePaymentValidator::class);
    }

    public function createLogger(): PaymentLoggerInterface
    {
        return $this->injector->getInstance(StripePaymentLogger::class);
    }
}

class PayPalPaymentGatewayFactory implements PaymentGatewayFactoryInterface
{
    public function __construct(
        private Injector $injector
    ) {}

    public function createProcessor(): PaymentProcessorInterface
    {
        return $this->injector->getInstance(PayPalPaymentProcessor::class);
    }

    public function createValidator(): PaymentValidatorInterface
    {
        return $this->injector->getInstance(PayPalPaymentValidator::class);
    }

    public function createLogger(): PaymentLoggerInterface
    {
        return $this->injector->getInstance(PayPalPaymentLogger::class);
    }
}

// ファクトリーの束縛
class PaymentModule extends AbstractModule
{
    protected function configure(): void
    {
        // 環境に応じてファクトリーを選択
        $gatewayType = $_ENV['PAYMENT_GATEWAY'] ?? 'stripe';
        
        if ($gatewayType === 'stripe') {
            $this->bind(PaymentGatewayFactoryInterface::class)
                ->to(StripePaymentGatewayFactory::class);
        } else {
            $this->bind(PaymentGatewayFactoryInterface::class)
                ->to(PayPalPaymentGatewayFactory::class);
        }
    }
}
```

### 3. Builder Pattern with DI

```php
// 複雑なオブジェクトの構築
class ReportBuilder
{
    private array $data = [];
    private array $filters = [];
    private array $aggregations = [];
    private string $format = 'html';

    public function __construct(
        private DataSourceInterface $dataSource,
        private FilterProcessorInterface $filterProcessor,
        private AggregationProcessorInterface $aggregationProcessor,
        private FormatterInterface $formatter
    ) {}

    public function setDateRange(DateTime $start, DateTime $end): self
    {
        $this->filters[] = new DateRangeFilter($start, $end);
        return $this;
    }

    public function setCategory(string $category): self
    {
        $this->filters[] = new CategoryFilter($category);
        return $this;
    }

    public function addAggregation(string $field, string $function): self
    {
        $this->aggregations[] = new Aggregation($field, $function);
        return $this;
    }

    public function setFormat(string $format): self
    {
        $this->format = $format;
        return $this;
    }

    public function build(): Report
    {
        // データの取得
        $rawData = $this->dataSource->getData();
        
        // フィルタリング
        $filteredData = $this->filterProcessor->process($rawData, $this->filters);
        
        // 集計
        $aggregatedData = $this->aggregationProcessor->process($filteredData, $this->aggregations);
        
        // フォーマット
        $formattedData = $this->formatter->format($aggregatedData, $this->format);
        
        return new Report($formattedData, $this->format);
    }
}

// DIを使ったビルダーファクトリー
class ReportBuilderFactory
{
    public function __construct(
        private Injector $injector
    ) {}

    public function createBuilder(): ReportBuilder
    {
        return $this->injector->getInstance(ReportBuilder::class);
    }
}

// 使用例
class ReportService
{
    public function __construct(
        private ReportBuilderFactory $builderFactory
    ) {}

    public function generateSalesReport(DateTime $start, DateTime $end): Report
    {
        return $this->builderFactory
            ->createBuilder()
            ->setDateRange($start, $end)
            ->setCategory('sales')
            ->addAggregation('amount', 'sum')
            ->addAggregation('count', 'count')
            ->setFormat('pdf')
            ->build();
    }
}
```

## 構造パターン

### 1. Adapter Pattern with DI

```php
// 既存のサードパーティライブラリ
class LegacyPdfLibrary
{
    public function generatePdf(string $html): string
    {
        // 旧式のPDF生成処理
        return "PDF content from legacy library";
    }
}

// 新しいPDFライブラリ
class ModernPdfLibrary
{
    public function createPdf(string $content, array $options = []): string
    {
        // 新しいPDF生成処理
        return "PDF content from modern library";
    }
}

// 統一インターフェース
interface PdfGeneratorInterface
{
    public function generate(string $content, array $options = []): string;
}

// アダプター
class LegacyPdfAdapter implements PdfGeneratorInterface
{
    public function __construct(
        private LegacyPdfLibrary $legacyLibrary
    ) {}

    public function generate(string $content, array $options = []): string
    {
        return $this->legacyLibrary->generatePdf($content);
    }
}

class ModernPdfAdapter implements PdfGeneratorInterface
{
    public function __construct(
        private ModernPdfLibrary $modernLibrary
    ) {}

    public function generate(string $content, array $options = []): string
    {
        return $this->modernLibrary->createPdf($content, $options);
    }
}

// 設定に応じたアダプター選択
class PdfModule extends AbstractModule
{
    protected function configure(): void
    {
        $useModernLibrary = $_ENV['USE_MODERN_PDF'] ?? false;
        
        if ($useModernLibrary) {
            $this->bind(PdfGeneratorInterface::class)
                ->to(ModernPdfAdapter::class);
        } else {
            $this->bind(PdfGeneratorInterface::class)
                ->to(LegacyPdfAdapter::class);
        }
    }
}
```

### 2. Decorator Pattern with DI

```php
// 基本インターフェース
interface NotificationSenderInterface
{
    public function send(string $message, array $recipients): void;
}

// 基本実装
class BasicNotificationSender implements NotificationSenderInterface
{
    public function __construct(
        private EmailServiceInterface $emailService
    ) {}

    public function send(string $message, array $recipients): void
    {
        foreach ($recipients as $recipient) {
            $this->emailService->send($recipient, 'Notification', $message);
        }
    }
}

// デコレーター基底クラス
abstract class NotificationDecorator implements NotificationSenderInterface
{
    public function __construct(
        protected NotificationSenderInterface $sender
    ) {}

    public function send(string $message, array $recipients): void
    {
        $this->sender->send($message, $recipients);
    }
}

// 具体的なデコレーター
class EncryptionDecorator extends NotificationDecorator
{
    public function __construct(
        NotificationSenderInterface $sender,
        private EncryptionServiceInterface $encryptionService
    ) {
        parent::__construct($sender);
    }

    public function send(string $message, array $recipients): void
    {
        $encryptedMessage = $this->encryptionService->encrypt($message);
        parent::send($encryptedMessage, $recipients);
    }
}

class LoggingDecorator extends NotificationDecorator
{
    public function __construct(
        NotificationSenderInterface $sender,
        private LoggerInterface $logger
    ) {
        parent::__construct($sender);
    }

    public function send(string $message, array $recipients): void
    {
        $this->logger->info('Sending notification', [
            'recipients' => count($recipients),
            'message_length' => strlen($message)
        ]);
        
        parent::send($message, $recipients);
        
        $this->logger->info('Notification sent successfully');
    }
}

class RateLimitDecorator extends NotificationDecorator
{
    public function __construct(
        NotificationSenderInterface $sender,
        private RateLimiterInterface $rateLimiter
    ) {
        parent::__construct($sender);
    }

    public function send(string $message, array $recipients): void
    {
        foreach ($recipients as $recipient) {
            if (!$this->rateLimiter->isAllowed($recipient)) {
                throw new RateLimitExceededException("Rate limit exceeded for {$recipient}");
            }
        }
        
        parent::send($message, $recipients);
    }
}

// DIを使ったデコレーター構成
class NotificationModule extends AbstractModule
{
    protected function configure(): void
    {
        // 基本実装
        $this->bind(NotificationSenderInterface::class)
            ->annotatedWith(Named::class, 'basic')
            ->to(BasicNotificationSender::class);
        
        // デコレーター付きの実装
        $this->bind(NotificationSenderInterface::class)
            ->toProvider(NotificationDecoratorProvider::class);
    }
}

class NotificationDecoratorProvider implements ProviderInterface
{
    public function __construct(
        private Injector $injector
    ) {}

    public function get(): NotificationSenderInterface
    {
        $basicSender = $this->injector->getInstance(
            NotificationSenderInterface::class,
            new Named('basic')
        );
        
        // デコレーターを適用
        $sender = new LoggingDecorator(
            $basicSender,
            $this->injector->getInstance(LoggerInterface::class)
        );
        
        $sender = new EncryptionDecorator(
            $sender,
            $this->injector->getInstance(EncryptionServiceInterface::class)
        );
        
        $sender = new RateLimitDecorator(
            $sender,
            $this->injector->getInstance(RateLimiterInterface::class)
        );
        
        return $sender;
    }
}
```

### 3. Facade Pattern with DI

```php
// 複雑なサブシステム
class OrderProcessor
{
    public function __construct(
        private InventoryService $inventoryService,
        private PaymentService $paymentService,
        private ShippingService $shippingService,
        private EmailService $emailService,
        private AuditService $auditService
    ) {}

    public function process(Order $order): void
    {
        // 在庫確認
        $this->inventoryService->reserveItems($order->getItems());
        
        // 支払い処理
        $paymentResult = $this->paymentService->processPayment($order);
        
        // 配送手配
        $this->shippingService->scheduleShipping($order);
        
        // 確認メール送信
        $this->emailService->sendOrderConfirmation($order);
        
        // 監査ログ
        $this->auditService->logOrderProcessed($order);
    }
}

// ファサード
class OrderFacade
{
    public function __construct(
        private OrderProcessor $processor,
        private OrderValidator $validator,
        private OrderRepository $repository,
        private LoggerInterface $logger
    ) {}

    public function createOrder(array $orderData): Order
    {
        try {
            // バリデーション
            $this->validator->validate($orderData);
            
            // 注文作成
            $order = new Order($orderData);
            
            // 処理実行
            $this->processor->process($order);
            
            // 保存
            $this->repository->save($order);
            
            $this->logger->info('Order created successfully', ['order_id' => $order->getId()]);
            
            return $order;
            
        } catch (Exception $e) {
            $this->logger->error('Order creation failed', ['error' => $e->getMessage()]);
            throw new OrderCreationException('Failed to create order', 0, $e);
        }
    }

    public function cancelOrder(int $orderId): void
    {
        $order = $this->repository->findById($orderId);
        
        if (!$order) {
            throw new OrderNotFoundException("Order not found: {$orderId}");
        }
        
        // 在庫復元
        $this->inventoryService->restoreItems($order->getItems());
        
        // 返金処理
        $this->paymentService->refundPayment($order);
        
        // 配送キャンセル
        $this->shippingService->cancelShipping($order);
        
        // キャンセル通知
        $this->emailService->sendCancellationNotification($order);
        
        // 注文更新
        $order->cancel();
        $this->repository->save($order);
        
        $this->logger->info('Order cancelled successfully', ['order_id' => $orderId]);
    }
}
```

## 行動パターン

### 1. Strategy Pattern with DI

```php
// 戦略インターフェース
interface PricingStrategyInterface
{
    public function calculatePrice(Product $product, Customer $customer): float;
}

// 具体的な戦略
class RegularPricingStrategy implements PricingStrategyInterface
{
    public function calculatePrice(Product $product, Customer $customer): float
    {
        return $product->getBasePrice();
    }
}

class MemberPricingStrategy implements PricingStrategyInterface
{
    public function __construct(
        private DiscountServiceInterface $discountService
    ) {}

    public function calculatePrice(Product $product, Customer $customer): float
    {
        $basePrice = $product->getBasePrice();
        $discount = $this->discountService->getMemberDiscount($customer);
        
        return $basePrice * (1 - $discount);
    }
}

class VipPricingStrategy implements PricingStrategyInterface
{
    public function __construct(
        private DiscountServiceInterface $discountService,
        private LoyaltyServiceInterface $loyaltyService
    ) {}

    public function calculatePrice(Product $product, Customer $customer): float
    {
        $basePrice = $product->getBasePrice();
        $memberDiscount = $this->discountService->getMemberDiscount($customer);
        $loyaltyDiscount = $this->loyaltyService->getLoyaltyDiscount($customer);
        
        return $basePrice * (1 - $memberDiscount - $loyaltyDiscount);
    }
}

// 戦略選択ファクトリー
class PricingStrategyFactory
{
    public function __construct(
        private Injector $injector
    ) {}

    public function createStrategy(Customer $customer): PricingStrategyInterface
    {
        return match ($customer->getType()) {
            'regular' => $this->injector->getInstance(RegularPricingStrategy::class),
            'member' => $this->injector->getInstance(MemberPricingStrategy::class),
            'vip' => $this->injector->getInstance(VipPricingStrategy::class),
            default => $this->injector->getInstance(RegularPricingStrategy::class)
        };
    }
}

// コンテキスト
class PricingService
{
    public function __construct(
        private PricingStrategyFactory $strategyFactory
    ) {}

    public function calculatePrice(Product $product, Customer $customer): float
    {
        $strategy = $this->strategyFactory->createStrategy($customer);
        return $strategy->calculatePrice($product, $customer);
    }
}
```

### 2. Observer Pattern with DI

```php
// 観察者インターフェース
interface EventObserverInterface
{
    public function handle(DomainEvent $event): void;
}

// 具体的な観察者
class EmailNotificationObserver implements EventObserverInterface
{
    public function __construct(
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}

    public function handle(DomainEvent $event): void
    {
        if ($event instanceof UserRegisteredEvent) {
            $this->sendWelcomeEmail($event);
        } elseif ($event instanceof OrderCompletedEvent) {
            $this->sendOrderConfirmation($event);
        }
    }

    private function sendWelcomeEmail(UserRegisteredEvent $event): void
    {
        $user = $event->getUser();
        $this->emailService->sendWelcomeEmail($user->getEmail(), $user->getName());
        $this->logger->info('Welcome email sent', ['user_id' => $user->getId()]);
    }

    private function sendOrderConfirmation(OrderCompletedEvent $event): void
    {
        $order = $event->getOrder();
        $this->emailService->sendOrderConfirmation($order);
        $this->logger->info('Order confirmation sent', ['order_id' => $order->getId()]);
    }
}

class AuditObserver implements EventObserverInterface
{
    public function __construct(
        private AuditServiceInterface $auditService
    ) {}

    public function handle(DomainEvent $event): void
    {
        $this->auditService->recordEvent($event);
    }
}

class MetricsObserver implements EventObserverInterface
{
    public function __construct(
        private MetricsCollectorInterface $metricsCollector
    ) {}

    public function handle(DomainEvent $event): void
    {
        $this->metricsCollector->increment('domain_events', [
            'type' => $event->getType(),
            'timestamp' => $event->getTimestamp()
        ]);
    }
}

// イベントディスパッチャー
class EventDispatcher
{
    private array $observers = [];

    public function addObserver(EventObserverInterface $observer): void
    {
        $this->observers[] = $observer;
    }

    public function dispatch(DomainEvent $event): void
    {
        foreach ($this->observers as $observer) {
            $observer->handle($event);
        }
    }
}

// DIを使ったイベントシステム設定
class EventModule extends AbstractModule
{
    protected function configure(): void
    {
        // 観察者の束縛
        $this->bind(EventObserverInterface::class)
            ->annotatedWith(Named::class, 'email')
            ->to(EmailNotificationObserver::class);
        
        $this->bind(EventObserverInterface::class)
            ->annotatedWith(Named::class, 'audit')
            ->to(AuditObserver::class);
        
        $this->bind(EventObserverInterface::class)
            ->annotatedWith(Named::class, 'metrics')
            ->to(MetricsObserver::class);
        
        // ディスパッチャーの設定
        $this->bind(EventDispatcher::class)
            ->toProvider(EventDispatcherProvider::class)
            ->in(Singleton::class);
    }
}

class EventDispatcherProvider implements ProviderInterface
{
    public function __construct(
        private Injector $injector
    ) {}

    public function get(): EventDispatcher
    {
        $dispatcher = new EventDispatcher();
        
        // 観察者の登録
        $dispatcher->addObserver($this->injector->getInstance(
            EventObserverInterface::class,
            new Named('email')
        ));
        
        $dispatcher->addObserver($this->injector->getInstance(
            EventObserverInterface::class,
            new Named('audit')
        ));
        
        $dispatcher->addObserver($this->injector->getInstance(
            EventObserverInterface::class,
            new Named('metrics')
        ));
        
        return $dispatcher;
    }
}
```

### 3. Command Pattern with DI

```php
// コマンドインターフェース
interface CommandInterface
{
    public function execute(): void;
    public function undo(): void;
}

// 具体的なコマンド
class CreateUserCommand implements CommandInterface
{
    private ?User $createdUser = null;

    public function __construct(
        private UserServiceInterface $userService,
        private array $userData
    ) {}

    public function execute(): void
    {
        $this->createdUser = $this->userService->createUser($this->userData);
    }

    public function undo(): void
    {
        if ($this->createdUser) {
            $this->userService->deleteUser($this->createdUser->getId());
        }
    }
}

class UpdateProductCommand implements CommandInterface
{
    private ?Product $originalProduct = null;

    public function __construct(
        private ProductServiceInterface $productService,
        private int $productId,
        private array $updateData
    ) {}

    public function execute(): void
    {
        $this->originalProduct = $this->productService->getProduct($this->productId);
        $this->productService->updateProduct($this->productId, $this->updateData);
    }

    public function undo(): void
    {
        if ($this->originalProduct) {
            $this->productService->updateProduct(
                $this->productId,
                $this->originalProduct->toArray()
            );
        }
    }
}

// コマンドファクトリー
class CommandFactory
{
    public function __construct(
        private Injector $injector
    ) {}

    public function createCreateUserCommand(array $userData): CommandInterface
    {
        return new CreateUserCommand(
            $this->injector->getInstance(UserServiceInterface::class),
            $userData
        );
    }

    public function createUpdateProductCommand(int $productId, array $updateData): CommandInterface
    {
        return new UpdateProductCommand(
            $this->injector->getInstance(ProductServiceInterface::class),
            $productId,
            $updateData
        );
    }
}

// コマンドインボーカー
class CommandProcessor
{
    private array $history = [];

    public function __construct(
        private LoggerInterface $logger
    ) {}

    public function execute(CommandInterface $command): void
    {
        try {
            $command->execute();
            $this->history[] = $command;
            
            $this->logger->info('Command executed successfully', [
                'command' => get_class($command)
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Command execution failed', [
                'command' => get_class($command),
                'error' => $e->getMessage()
            ]);
            throw $e;
        }
    }

    public function undo(): void
    {
        if (empty($this->history)) {
            throw new NoCommandToUndoException('No command to undo');
        }

        $command = array_pop($this->history);
        
        try {
            $command->undo();
            
            $this->logger->info('Command undone successfully', [
                'command' => get_class($command)
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Command undo failed', [
                'command' => get_class($command),
                'error' => $e->getMessage()
            ]);
            throw $e;
        }
    }

    public function getHistory(): array
    {
        return $this->history;
    }
}
```

## アーキテクチャパターンとの統合

### 1. Repository Pattern with DI

```php
// リポジトリインターフェース
interface RepositoryInterface
{
    public function findById(int $id): ?object;
    public function save(object $entity): void;
    public function delete(int $id): void;
}

// 抽象リポジトリ
abstract class AbstractRepository implements RepositoryInterface
{
    public function __construct(
        protected DatabaseInterface $database,
        protected LoggerInterface $logger
    ) {}

    abstract protected function getTableName(): string;
    abstract protected function hydrate(array $data): object;
    abstract protected function extract(object $entity): array;

    public function findById(int $id): ?object
    {
        $sql = "SELECT * FROM {$this->getTableName()} WHERE id = ?";
        $result = $this->database->query($sql, [$id]);
        
        if (empty($result)) {
            return null;
        }
        
        return $this->hydrate($result[0]);
    }

    public function save(object $entity): void
    {
        $data = $this->extract($entity);
        
        if (isset($data['id']) && $data['id']) {
            $this->update($data);
        } else {
            $this->insert($data);
        }
    }

    public function delete(int $id): void
    {
        $sql = "DELETE FROM {$this->getTableName()} WHERE id = ?";
        $this->database->execute($sql, [$id]);
        
        $this->logger->info("Entity deleted from {$this->getTableName()}", ['id' => $id]);
    }

    private function insert(array $data): void
    {
        $columns = implode(', ', array_keys($data));
        $placeholders = implode(', ', array_fill(0, count($data), '?'));
        
        $sql = "INSERT INTO {$this->getTableName()} ({$columns}) VALUES ({$placeholders})";
        $this->database->execute($sql, array_values($data));
    }

    private function update(array $data): void
    {
        $id = $data['id'];
        unset($data['id']);
        
        $setClause = implode(', ', array_map(fn($col) => "{$col} = ?", array_keys($data)));
        $sql = "UPDATE {$this->getTableName()} SET {$setClause} WHERE id = ?";
        
        $this->database->execute($sql, [...array_values($data), $id]);
    }
}

// 具体的なリポジトリ
class UserRepository extends AbstractRepository implements UserRepositoryInterface
{
    protected function getTableName(): string
    {
        return 'users';
    }

    protected function hydrate(array $data): User
    {
        return new User(
            $data['id'],
            $data['name'],
            $data['email'],
            $data['password'],
            new DateTime($data['created_at']),
            new DateTime($data['updated_at'])
        );
    }

    protected function extract(object $entity): array
    {
        assert($entity instanceof User);
        
        return [
            'id' => $entity->getId(),
            'name' => $entity->getName(),
            'email' => $entity->getEmail(),
            'password' => $entity->getPassword(),
            'created_at' => $entity->getCreatedAt()->format('Y-m-d H:i:s'),
            'updated_at' => $entity->getUpdatedAt()->format('Y-m-d H:i:s')
        ];
    }

    public function findByEmail(string $email): ?User
    {
        $sql = "SELECT * FROM {$this->getTableName()} WHERE email = ?";
        $result = $this->database->query($sql, [$email]);
        
        if (empty($result)) {
            return null;
        }
        
        return $this->hydrate($result[0]);
    }
}
```

### 2. Unit of Work Pattern with DI

```php
// 作業単位インターフェース
interface UnitOfWorkInterface
{
    public function registerNew(object $entity): void;
    public function registerClean(object $entity): void;
    public function registerDirty(object $entity): void;
    public function registerDeleted(object $entity): void;
    public function commit(): void;
    public function rollback(): void;
}

// 実装
class UnitOfWork implements UnitOfWorkInterface
{
    private array $newEntities = [];
    private array $cleanEntities = [];
    private array $dirtyEntities = [];
    private array $deletedEntities = [];

    public function __construct(
        private DatabaseInterface $database,
        private EntityManagerInterface $entityManager,
        private LoggerInterface $logger
    ) {}

    public function registerNew(object $entity): void
    {
        $this->newEntities[] = $entity;
    }

    public function registerClean(object $entity): void
    {
        $this->cleanEntities[] = $entity;
    }

    public function registerDirty(object $entity): void
    {
        $this->dirtyEntities[] = $entity;
    }

    public function registerDeleted(object $entity): void
    {
        $this->deletedEntities[] = $entity;
    }

    public function commit(): void
    {
        $this->database->beginTransaction();
        
        try {
            // 新規エンティティを挿入
            foreach ($this->newEntities as $entity) {
                $this->entityManager->insert($entity);
            }
            
            // 変更されたエンティティを更新
            foreach ($this->dirtyEntities as $entity) {
                $this->entityManager->update($entity);
            }
            
            // 削除されたエンティティを削除
            foreach ($this->deletedEntities as $entity) {
                $this->entityManager->delete($entity);
            }
            
            $this->database->commit();
            $this->clear();
            
            $this->logger->info('Unit of work committed successfully');
            
        } catch (Exception $e) {
            $this->database->rollback();
            $this->logger->error('Unit of work commit failed', ['error' => $e->getMessage()]);
            throw $e;
        }
    }

    public function rollback(): void
    {
        $this->database->rollback();
        $this->clear();
        $this->logger->info('Unit of work rolled back');
    }

    private function clear(): void
    {
        $this->newEntities = [];
        $this->cleanEntities = [];
        $this->dirtyEntities = [];
        $this->deletedEntities = [];
    }
}
```

## 次のステップ

デザインパターンの実装を理解したので、最後のトピックに進む準備が整いました。

1. **トラブルシューティングガイド**: 実際の問題解決手法
2. **まとめ**: 学習した内容の総括
3. **実践的な活用方法**: 実際のプロジェクトでの応用

**続きは:** [トラブルシューティングガイド](troubleshooting-guide.html)

## 重要なポイント

- **Factory Pattern**: DIを使った柔軟なオブジェクト生成
- **Adapter Pattern**: 既存コードとの統合を効率化
- **Decorator Pattern**: 機能拡張を動的に適用
- **Strategy Pattern**: アルゴリズムの交換可能な実装
- **Observer Pattern**: 疎結合なイベント処理
- **Command Pattern**: 操作の実行と取り消し
- **Repository Pattern**: データアクセスの抽象化

---

Ray.Diと組み合わせたデザインパターンにより、保守性と拡張性の高いアプリケーションを構築できます。各パターンの特徴を理解し、適切な場面で活用することが重要です。