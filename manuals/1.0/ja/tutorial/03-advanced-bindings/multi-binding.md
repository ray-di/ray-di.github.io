---
layout: docs-ja
title: マルチバインディング
category: Manual
permalink: /manuals/1.0/ja/tutorial/03-advanced-bindings/multi-binding.html
---

# マルチバインディング

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- マルチバインディングとは何か、なぜ有用なのか
- 同じインターフェースの複数実装を配列として注入する方法
- Setバインディングとその実践的な使用場面
- プラグインアーキテクチャとイベントシステムの構築
- 実際のE-commerceアプリケーションでの活用例

## マルチバインディングとは

**マルチバインディング**は、同じインターフェースの複数の実装をセットまたは配列として注入する機能です。これにより、プラグインアーキテクチャやイベントシステムなど、拡張可能で柔軟なアプリケーションを構築できます。

### 基本的な概念

```php
// 従来の単一バインディング
$this->bind(PaymentGatewayInterface::class)->to(StripePaymentGateway::class);

// マルチバインディング：複数の実装を配列として注入
$this->bind(PaymentGatewayInterface::class)->to(StripePaymentGateway::class);
$this->bind(PaymentGatewayInterface::class)->to(PayPalPaymentGateway::class);
$this->bind(PaymentGatewayInterface::class)->to(SquarePaymentGateway::class);

// 注入側では配列として受け取る
class PaymentProcessor
{
    public function __construct(
        private array $paymentGateways // PaymentGatewayInterface[]
    ) {}
}
```

## Setバインディングの基本

### 1. 基本的な使用方法

```php
use Ray\Di\AbstractModule;
use Ray\Di\Di\Set;

// インターフェースの定義
interface EventListenerInterface
{
    public function handle(Event $event): void;
}

// 複数の実装
class EmailNotificationListener implements EventListenerInterface
{
    public function handle(Event $event): void
    {
        if ($event instanceof OrderPlacedEvent) {
            // メール通知を送信
            $this->sendOrderConfirmationEmail($event->getOrder());
        }
    }
    
    private function sendOrderConfirmationEmail(Order $order): void
    {
        // メール送信ロジック
    }
}

class InventoryUpdateListener implements EventListenerInterface
{
    public function handle(Event $event): void
    {
        if ($event instanceof OrderPlacedEvent) {
            // 在庫を更新
            $this->updateInventory($event->getOrder());
        }
    }
    
    private function updateInventory(Order $order): void
    {
        // 在庫更新ロジック
    }
}

class AuditLogListener implements EventListenerInterface
{
    public function handle(Event $event): void
    {
        // 全てのイベントを監査ログに記録
        $this->logEvent($event);
    }
    
    private function logEvent(Event $event): void
    {
        // 監査ログ記録ロジック
    }
}

// モジュールでのバインディング
class EventModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(EventListenerInterface::class)->to(EmailNotificationListener::class);
        $this->bind(EventListenerInterface::class)->to(InventoryUpdateListener::class);
        $this->bind(EventListenerInterface::class)->to(AuditLogListener::class);
    }
}

// 使用側
class EventDispatcher
{
    public function __construct(
        #[Set] private array $listeners // EventListenerInterface[]
    ) {}
    
    public function dispatch(Event $event): void
    {
        foreach ($this->listeners as $listener) {
            $listener->handle($event);
        }
    }
}
```

### 2. 名前付きSetバインディング

```php
use Ray\Di\Di\Named;

class NotificationModule extends AbstractModule
{
    protected function configure(): void
    {
        // 異なる種類の通知リスナーを分離
        $this->bind(NotificationInterface::class)->annotatedWith('email')->to(EmailNotification::class);
        $this->bind(NotificationInterface::class)->annotatedWith('email')->to(EmailDigestNotification::class);
        
        $this->bind(NotificationInterface::class)->annotatedWith('sms')->to(SMSNotification::class);
        $this->bind(NotificationInterface::class)->annotatedWith('sms')->to(SMSAlertNotification::class);
        
        $this->bind(NotificationInterface::class)->annotatedWith('push')->to(PushNotification::class);
        $this->bind(NotificationInterface::class)->annotatedWith('push')->to(PushAlertNotification::class);
    }
}

class NotificationService
{
    public function __construct(
        #[Set, Named('email')] private array $emailNotifications,
        #[Set, Named('sms')] private array $smsNotifications,
        #[Set, Named('push')] private array $pushNotifications
    ) {}
    
    public function sendEmailNotifications(string $message): void
    {
        foreach ($this->emailNotifications as $notification) {
            $notification->send($message);
        }
    }
    
    public function sendSMSNotifications(string $message): void
    {
        foreach ($this->smsNotifications as $notification) {
            $notification->send($message);
        }
    }
    
    public function sendPushNotifications(string $message): void
    {
        foreach ($this->pushNotifications as $notification) {
            $notification->send($message);
        }
    }
}
```

## プラグインアーキテクチャの構築

### 1. 決済ゲートウェイプラグイン

```php
interface PaymentGatewayInterface
{
    public function getName(): string;
    public function isEnabled(): bool;
    public function processPayment(PaymentRequest $request): PaymentResult;
    public function supports(string $paymentMethod): bool;
}

class StripePaymentGateway implements PaymentGatewayInterface
{
    public function getName(): string
    {
        return 'Stripe';
    }
    
    public function isEnabled(): bool
    {
        return !empty($_ENV['STRIPE_SECRET_KEY']);
    }
    
    public function processPayment(PaymentRequest $request): PaymentResult
    {
        // Stripe決済処理
        return new PaymentResult(true, 'stripe_transaction_id');
    }
    
    public function supports(string $paymentMethod): bool
    {
        return in_array($paymentMethod, ['credit_card', 'apple_pay', 'google_pay']);
    }
}

class PayPalPaymentGateway implements PaymentGatewayInterface
{
    public function getName(): string
    {
        return 'PayPal';
    }
    
    public function isEnabled(): bool
    {
        return !empty($_ENV['PAYPAL_CLIENT_ID']);
    }
    
    public function processPayment(PaymentRequest $request): PaymentResult
    {
        // PayPal決済処理
        return new PaymentResult(true, 'paypal_transaction_id');
    }
    
    public function supports(string $paymentMethod): bool
    {
        return in_array($paymentMethod, ['paypal', 'paypal_credit']);
    }
}

// 決済プロセッサー
class PaymentProcessor
{
    public function __construct(
        #[Set] private array $paymentGateways // PaymentGatewayInterface[]
    ) {}
    
    public function processPayment(PaymentRequest $request): PaymentResult
    {
        $availableGateways = $this->getAvailableGateways($request->getPaymentMethod());
        
        if (empty($availableGateways)) {
            throw new UnsupportedPaymentMethodException($request->getPaymentMethod());
        }
        
        // 最初に利用可能なゲートウェイを使用
        $gateway = $availableGateways[0];
        
        try {
            return $gateway->processPayment($request);
        } catch (PaymentException $e) {
            // フォールバック処理
            return $this->tryFallbackGateways($request, array_slice($availableGateways, 1));
        }
    }
    
    private function getAvailableGateways(string $paymentMethod): array
    {
        return array_filter($this->paymentGateways, function (PaymentGatewayInterface $gateway) use ($paymentMethod) {
            return $gateway->isEnabled() && $gateway->supports($paymentMethod);
        });
    }
    
    private function tryFallbackGateways(PaymentRequest $request, array $gateways): PaymentResult
    {
        foreach ($gateways as $gateway) {
            try {
                return $gateway->processPayment($request);
            } catch (PaymentException $e) {
                // 次のゲートウェイを試す
                continue;
            }
        }
        
        throw new AllPaymentGatewaysFailedException();
    }
    
    public function getAvailablePaymentMethods(): array
    {
        $methods = [];
        foreach ($this->paymentGateways as $gateway) {
            if ($gateway->isEnabled()) {
                $methods[] = $gateway->getName();
            }
        }
        return $methods;
    }
}
```

### 2. バリデーションプラグイン

```php
interface ValidatorInterface
{
    public function validate(mixed $value): ValidationResult;
    public function supports(string $type): bool;
}

class EmailValidator implements ValidatorInterface
{
    public function validate(mixed $value): ValidationResult
    {
        if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
            return new ValidationResult(false, ['Invalid email format']);
        }
        return new ValidationResult(true);
    }
    
    public function supports(string $type): bool
    {
        return $type === 'email';
    }
}

class PasswordValidator implements ValidatorInterface
{
    public function validate(mixed $value): ValidationResult
    {
        $errors = [];
        
        if (strlen($value) < 8) {
            $errors[] = 'Password must be at least 8 characters long';
        }
        
        if (!preg_match('/[A-Z]/', $value)) {
            $errors[] = 'Password must contain at least one uppercase letter';
        }
        
        if (!preg_match('/[a-z]/', $value)) {
            $errors[] = 'Password must contain at least one lowercase letter';
        }
        
        if (!preg_match('/[0-9]/', $value)) {
            $errors[] = 'Password must contain at least one number';
        }
        
        return new ValidationResult(empty($errors), $errors);
    }
    
    public function supports(string $type): bool
    {
        return $type === 'password';
    }
}

class ValidationService
{
    public function __construct(
        #[Set] private array $validators // ValidatorInterface[]
    ) {}
    
    public function validate(string $type, mixed $value): ValidationResult
    {
        $supportedValidators = array_filter($this->validators, fn($validator) => $validator->supports($type));
        
        if (empty($supportedValidators)) {
            throw new UnsupportedValidationTypeException($type);
        }
        
        $allErrors = [];
        $allValid = true;
        
        foreach ($supportedValidators as $validator) {
            $result = $validator->validate($value);
            if (!$result->isValid()) {
                $allValid = false;
                $allErrors = array_merge($allErrors, $result->getErrors());
            }
        }
        
        return new ValidationResult($allValid, $allErrors);
    }
}
```

## イベントシステムの構築

### 1. ドメインイベントシステム

```php
interface DomainEventInterface
{
    public function getEventName(): string;
    public function getOccurredAt(): DateTimeImmutable;
    public function getPayload(): array;
}

class OrderPlacedEvent implements DomainEventInterface
{
    public function __construct(
        private Order $order,
        private ?DateTimeImmutable $occurredAt = null
    ) {
        $this->occurredAt = $occurredAt ?? new DateTimeImmutable();
    }
    
    public function getEventName(): string
    {
        return 'order.placed';
    }
    
    public function getOccurredAt(): DateTimeImmutable
    {
        return $this->occurredAt;
    }
    
    public function getPayload(): array
    {
        return [
            'order_id' => $this->order->getId(),
            'customer_id' => $this->order->getCustomerId(),
            'total' => $this->order->getTotal(),
            'items' => $this->order->getItems()
        ];
    }
    
    public function getOrder(): Order
    {
        return $this->order;
    }
}

class UserRegisteredEvent implements DomainEventInterface
{
    public function __construct(
        private User $user,
        private ?DateTimeImmutable $occurredAt = null
    ) {
        $this->occurredAt = $occurredAt ?? new DateTimeImmutable();
    }
    
    public function getEventName(): string
    {
        return 'user.registered';
    }
    
    public function getOccurredAt(): DateTimeImmutable
    {
        return $this->occurredAt;
    }
    
    public function getPayload(): array
    {
        return [
            'user_id' => $this->user->getId(),
            'email' => $this->user->getEmail(),
            'registration_date' => $this->occurredAt->format('Y-m-d H:i:s')
        ];
    }
    
    public function getUser(): User
    {
        return $this->user;
    }
}

interface EventHandlerInterface
{
    public function handle(DomainEventInterface $event): void;
    public function supports(string $eventName): bool;
}

class OrderEmailNotificationHandler implements EventHandlerInterface
{
    public function __construct(
        private EmailServiceInterface $emailService,
        private UserRepositoryInterface $userRepository
    ) {}
    
    public function handle(DomainEventInterface $event): void
    {
        if ($event instanceof OrderPlacedEvent) {
            $order = $event->getOrder();
            $user = $this->userRepository->findById($order->getCustomerId());
            
            if ($user) {
                $this->emailService->sendOrderConfirmation($user, $order);
            }
        }
    }
    
    public function supports(string $eventName): bool
    {
        return $eventName === 'order.placed';
    }
}

class WelcomeEmailHandler implements EventHandlerInterface
{
    public function __construct(
        private EmailServiceInterface $emailService
    ) {}
    
    public function handle(DomainEventInterface $event): void
    {
        if ($event instanceof UserRegisteredEvent) {
            $user = $event->getUser();
            $this->emailService->sendWelcomeEmail($user);
        }
    }
    
    public function supports(string $eventName): bool
    {
        return $eventName === 'user.registered';
    }
}

class EventDispatcher
{
    public function __construct(
        #[Set] private array $eventHandlers // EventHandlerInterface[]
    ) {}
    
    public function dispatch(DomainEventInterface $event): void
    {
        $eventName = $event->getEventName();
        
        foreach ($this->eventHandlers as $handler) {
            if ($handler->supports($eventName)) {
                try {
                    $handler->handle($event);
                } catch (Exception $e) {
                    // エラーログを記録して処理を続行
                    error_log("Event handler failed: {$e->getMessage()}");
                }
            }
        }
    }
}
```

### 2. E-commerceでの実践例

```php
// 製品検索プラグイン
interface ProductSearchInterface
{
    public function search(string $query): array;
    public function getProviderName(): string;
    public function getPriority(): int;
}

class ElasticsearchProductSearch implements ProductSearchInterface
{
    public function search(string $query): array
    {
        // Elasticsearch検索実装
        return [];
    }
    
    public function getProviderName(): string
    {
        return 'Elasticsearch';
    }
    
    public function getPriority(): int
    {
        return 100; // 高優先度
    }
}

class DatabaseProductSearch implements ProductSearchInterface
{
    public function search(string $query): array
    {
        // データベース検索実装（フォールバック）
        return [];
    }
    
    public function getProviderName(): string
    {
        return 'Database';
    }
    
    public function getPriority(): int
    {
        return 1; // 低優先度（フォールバック）
    }
}

class ProductSearchService
{
    public function __construct(
        #[Set] private array $searchProviders // ProductSearchInterface[]
    ) {
        // 優先度でソート
        usort($this->searchProviders, fn($a, $b) => $b->getPriority() - $a->getPriority());
    }
    
    public function search(string $query): array
    {
        foreach ($this->searchProviders as $provider) {
            try {
                $results = $provider->search($query);
                if (!empty($results)) {
                    return $results;
                }
            } catch (Exception $e) {
                // 次のプロバイダーを試す
                error_log("Search provider {$provider->getProviderName()} failed: {$e->getMessage()}");
                continue;
            }
        }
        
        return []; // 全てのプロバイダーが失敗
    }
}

// 注文処理フック
interface OrderHookInterface
{
    public function beforeOrderPlace(Order $order): void;
    public function afterOrderPlace(Order $order): void;
}

class InventoryReservationHook implements OrderHookInterface
{
    public function beforeOrderPlace(Order $order): void
    {
        // 在庫を予約
        foreach ($order->getItems() as $item) {
            $this->reserveInventory($item->getProductId(), $item->getQuantity());
        }
    }
    
    public function afterOrderPlace(Order $order): void
    {
        // 在庫を確定
        foreach ($order->getItems() as $item) {
            $this->confirmInventory($item->getProductId(), $item->getQuantity());
        }
    }
}

class LoyaltyPointsHook implements OrderHookInterface
{
    public function beforeOrderPlace(Order $order): void
    {
        // 注文前は何もしない
    }
    
    public function afterOrderPlace(Order $order): void
    {
        // ロイヤルティポイントを付与
        $points = $this->calculateLoyaltyPoints($order);
        $this->awardPoints($order->getCustomerId(), $points);
    }
}

class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        #[Set] private array $orderHooks // OrderHookInterface[]
    ) {}
    
    public function placeOrder(Order $order): void
    {
        // 前処理フック
        foreach ($this->orderHooks as $hook) {
            $hook->beforeOrderPlace($order);
        }
        
        // 注文を保存
        $this->orderRepository->save($order);
        
        // 後処理フック
        foreach ($this->orderHooks as $hook) {
            $hook->afterOrderPlace($order);
        }
    }
}
```

## ベストプラクティス

### 1. 順序制御

```php
interface PriorityInterface
{
    public function getPriority(): int;
}

class OrderedMultiBinding
{
    public function __construct(
        #[Set] private array $processors // ProcessorInterface[]
    ) {
        // 優先度でソート
        usort($this->processors, function($a, $b) {
            $priorityA = $a instanceof PriorityInterface ? $a->getPriority() : 0;
            $priorityB = $b instanceof PriorityInterface ? $b->getPriority() : 0;
            return $priorityB - $priorityA; // 降順
        });
    }
}
```

### 2. 条件付きバインディング

```php
class ConditionalModule extends AbstractModule
{
    protected function configure(): void
    {
        // 環境に応じてバインディング
        if (getenv('STRIPE_ENABLED') === 'true') {
            $this->bind(PaymentGatewayInterface::class)->to(StripePaymentGateway::class);
        }
        
        if (getenv('PAYPAL_ENABLED') === 'true') {
            $this->bind(PaymentGatewayInterface::class)->to(PayPalPaymentGateway::class);
        }
        
        // 常に有効なフォールバック
        $this->bind(PaymentGatewayInterface::class)->to(CashPaymentGateway::class);
    }
}
```

### 3. エラーハンドリング

```php
class RobustEventDispatcher
{
    public function __construct(
        #[Set] private array $handlers,
        private LoggerInterface $logger
    ) {}
    
    public function dispatch(DomainEventInterface $event): void
    {
        $errors = [];
        
        foreach ($this->handlers as $handler) {
            if ($handler->supports($event->getEventName())) {
                try {
                    $handler->handle($event);
                } catch (Exception $e) {
                    $errors[] = $e;
                    $this->logger->error("Event handler failed", [
                        'handler' => get_class($handler),
                        'event' => $event->getEventName(),
                        'error' => $e->getMessage()
                    ]);
                }
            }
        }
        
        if (!empty($errors)) {
            // 必要に応じて集約エラーを投げる
            throw new EventHandlingException($errors);
        }
    }
}
```

## 次のステップ

マルチバインディングの使用方法を理解したので、次に進む準備が整いました。

1. **アシストインジェクションの学習**: ファクトリーパターンの高度な実装
2. **スコープとライフサイクルの探索**: オブジェクトの生存期間管理
3. **実世界の例での練習**: 複雑なアプリケーションでの適用方法

**続きは:** [アシストインジェクション](assisted-injection.html)

## 重要なポイント

- **マルチバインディング**は同じインターフェースの複数実装を配列として注入
- **#[Set]**アトリビュートを使用して配列注入を明示
- **プラグインアーキテクチャ**により拡張可能なアプリケーションを構築
- **イベントシステム**で疎結合なコンポーネント間通信を実現
- **優先度制御**とエラーハンドリングで堅牢な実装を提供
- **条件付きバインディング**で環境に応じた柔軟な設定が可能

---

マルチバインディングは、拡張可能で保守しやすいアーキテクチャを構築するための強力な機能です。プラグインシステムやイベント駆動アーキテクチャの実装に不可欠な技術です。