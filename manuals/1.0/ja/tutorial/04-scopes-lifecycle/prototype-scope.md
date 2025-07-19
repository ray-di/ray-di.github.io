---
layout: docs-ja
title: プロトタイプスコープとインスタンス管理
category: Manual
permalink: /manuals/1.0/ja/tutorial/04-scopes-lifecycle/prototype-scope.html
---

# プロトタイプスコープとインスタンス管理

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- プロトタイプスコープ（デフォルト）の動作と特性
- シングルトンとプロトタイプスコープの適切な使い分け
- ビジネスロジック層での状態管理とインスタンス分離
- パフォーマンスとメモリ使用量の最適化戦略
- 実際のE-commerceアプリケーションでのスコープ選択

## プロトタイプスコープの基礎

### 1. Ray.Diのデフォルトスコープ

```php
use Ray\Di\AbstractModule;
use Ray\Di\Injector;
use Ray\Di\Scope\Singleton;

// プロトタイプスコープ（デフォルト動作）
class ECommerceModule extends AbstractModule
{
    protected function configure(): void
    {
        // プロトタイプスコープ（明示的な指定不要）
        $this->bind(OrderServiceInterface::class)
            ->to(OrderService::class);
        // 毎回新しいインスタンスが作成される
        
        $this->bind(ShoppingCartInterface::class)
            ->to(ShoppingCart::class);
        // リクエストごとに独立したカート
        
        $this->bind(UserServiceInterface::class)
            ->to(UserService::class);
        // ユーザー操作ごとに新しいサービスインスタンス
        
        // 比較：シングルトンスコープ（明示的指定）
        $this->bind(DatabaseInterface::class)
            ->to(MySQLDatabase::class)
            ->in(Singleton::class);
        // アプリケーション全体で同じインスタンス
        
        $this->bind(CacheInterface::class)
            ->to(RedisCache::class)
            ->in(Singleton::class);
        // キャッシュは状態を共有
    }
}

// プロトタイプの動作を確認
class PrototypeDemo
{
    public function demonstratePrototypeBehavior(): void
    {
        $injector = new Injector(new ECommerceModule());
        
        echo "=== プロトタイプスコープの動作 ===\n";
        
        // 毎回異なるインスタンスが作成される
        $orderService1 = $injector->getInstance(OrderServiceInterface::class);
        $orderService2 = $injector->getInstance(OrderServiceInterface::class);
        
        echo "OrderService instances are different: " . 
             ($orderService1 !== $orderService2 ? 'Yes' : 'No') . "\n";
        echo "Instance 1 ID: " . spl_object_id($orderService1) . "\n";
        echo "Instance 2 ID: " . spl_object_id($orderService2) . "\n\n";
        
        echo "=== シングルトンスコープとの比較 ===\n";
        
        // シングルトンは同じインスタンスが返される
        $cache1 = $injector->getInstance(CacheInterface::class);
        $cache2 = $injector->getInstance(CacheInterface::class);
        
        echo "Cache instances are same: " . 
             ($cache1 === $cache2 ? 'Yes' : 'No') . "\n";
        echo "Cache 1 ID: " . spl_object_id($cache1) . "\n";
        echo "Cache 2 ID: " . spl_object_id($cache2) . "\n";
    }
}
```

### 2. 状態分離の重要性

```php
// ショッピングカートでの状態分離の例
class ShoppingCart implements ShoppingCartInterface
{
    private array $items = [];
    private ?string $customerId = null;
    private float $totalAmount = 0.0;
    private DateTime $createdAt;
    
    public function __construct(
        private PricingServiceInterface $pricingService,
        private LoggerInterface $logger
    ) {
        $this->createdAt = new DateTime();
        $this->logger->debug('New shopping cart created', [
            'cart_id' => spl_object_id($this),
            'created_at' => $this->createdAt->format('c')
        ]);
    }
    
    public function setCustomer(string $customerId): void
    {
        $this->customerId = $customerId;
        $this->logger->info('Customer assigned to cart', [
            'cart_id' => spl_object_id($this),
            'customer_id' => $customerId
        ]);
    }
    
    public function addItem(Product $product, int $quantity): void
    {
        $itemId = $product->getId();
        
        if (isset($this->items[$itemId])) {
            $this->items[$itemId]['quantity'] += $quantity;
        } else {
            $this->items[$itemId] = [
                'product' => $product,
                'quantity' => $quantity,
                'price' => $this->pricingService->getPrice($product),
                'added_at' => new DateTime()
            ];
        }
        
        $this->recalculateTotal();
        
        $this->logger->info('Item added to cart', [
            'cart_id' => spl_object_id($this),
            'product_id' => $itemId,
            'quantity' => $quantity,
            'total_items' => count($this->items)
        ]);
    }
    
    private function recalculateTotal(): void
    {
        $this->totalAmount = array_sum(array_map(
            fn($item) => $item['price'] * $item['quantity'],
            $this->items
        ));
    }
    
    public function getItems(): array
    {
        return $this->items;
    }
    
    public function getTotal(): float
    {
        return $this->totalAmount;
    }
    
    public function getCustomerId(): ?string
    {
        return $this->customerId;
    }
}

// 複数ユーザーでの状態分離デモ
class MultiUserDemo
{
    public function demonstrateStateIsolation(): void
    {
        $injector = new Injector(new ECommerceModule());
        
        // ユーザーAのカート
        $cartA = $injector->getInstance(ShoppingCartInterface::class);
        $cartA->setCustomer('user-a');
        $cartA->addItem(new Product('laptop', 'Gaming Laptop', 1500.0), 1);
        
        // ユーザーBのカート
        $cartB = $injector->getInstance(ShoppingCartInterface::class);
        $cartB->setCustomer('user-b');
        $cartB->addItem(new Product('mouse', 'Gaming Mouse', 80.0), 2);
        
        // 状態が完全に分離されていることを確認
        echo "Cart A - Customer: " . $cartA->getCustomerId() . "\n";
        echo "Cart A - Items: " . count($cartA->getItems()) . "\n";
        echo "Cart A - Total: $" . $cartA->getTotal() . "\n\n";
        
        echo "Cart B - Customer: " . $cartB->getCustomerId() . "\n";
        echo "Cart B - Items: " . count($cartB->getItems()) . "\n";
        echo "Cart B - Total: $" . $cartB->getTotal() . "\n";
    }
}
```

## ビジネスサービスでの活用

### 1. 注文処理サービス

```php
class OrderService implements OrderServiceInterface
{
    private array $validationErrors = [];
    private ?Order $currentOrder = null;
    private array $processingSteps = [];
    
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private PaymentServiceInterface $paymentService,
        private InventoryServiceInterface $inventoryService,
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}
    
    public function processOrder(OrderData $orderData): OrderResult
    {
        $this->currentOrder = null;
        $this->validationErrors = [];
        $this->processingSteps = [];
        
        try {
            $this->addProcessingStep('validation_started');
            $this->validateOrderData($orderData);
            
            $this->addProcessingStep('order_creation');
            $this->currentOrder = $this->createOrder($orderData);
            
            $this->addProcessingStep('inventory_check');
            $this->checkInventory($this->currentOrder);
            
            $this->addProcessingStep('payment_processing');
            $paymentResult = $this->processPayment($this->currentOrder);
            
            $this->addProcessingStep('order_confirmation');
            $this->confirmOrder($this->currentOrder, $paymentResult);
            
            $this->addProcessingStep('notification_sent');
            $this->sendConfirmationEmail($this->currentOrder);
            
            $this->logger->info('Order processed successfully', [
                'order_id' => $this->currentOrder->getId(),
                'processing_steps' => $this->processingSteps,
                'processing_time' => $this->getProcessingTime()
            ]);
            
            return new OrderResult(true, $this->currentOrder);
        } catch (OrderProcessingException $e) {
            $this->logger->error('Order processing failed', [
                'order_data' => $orderData->toArray(),
                'validation_errors' => $this->validationErrors,
                'processing_steps' => $this->processingSteps,
                'error' => $e->getMessage()
            ]);
            
            return new OrderResult(false, null, $e->getMessage());
        }
    }
    
    private function validateOrderData(OrderData $orderData): void
    {
        if (empty($orderData->getItems())) {
            $this->validationErrors[] = 'Order must contain at least one item';
        }
        
        if (!$orderData->getCustomerId()) {
            $this->validationErrors[] = 'Customer ID is required';
        }
        
        if (!$orderData->getShippingAddress()) {
            $this->validationErrors[] = 'Shipping address is required';
        }
        
        if (!empty($this->validationErrors)) {
            throw new OrderProcessingException('Validation failed: ' . implode(', ', $this->validationErrors));
        }
    }
    
    private function addProcessingStep(string $step): void
    {
        $this->processingSteps[] = [
            'step' => $step,
            'timestamp' => microtime(true),
            'memory_usage' => memory_get_usage()
        ];
    }
    
    private function getProcessingTime(): float
    {
        if (count($this->processingSteps) < 2) {
            return 0;
        }
        
        $start = $this->processingSteps[0]['timestamp'];
        $end = end($this->processingSteps)['timestamp'];
        
        return $end - $start;
    }
    
    public function getValidationErrors(): array
    {
        return $this->validationErrors;
    }
    
    public function getProcessingSteps(): array
    {
        return $this->processingSteps;
    }
}
```

### 2. ユーザーサービス

```php
class UserService implements UserServiceInterface
{
    private ?User $currentUser = null;
    private array $operationLog = [];
    
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private AuthenticationServiceInterface $authService,
        private CacheInterface $cache,
        private LoggerInterface $logger
    ) {}
    
    public function authenticate(string $email, string $password): AuthResult
    {
        $this->logOperation('authentication_attempt', ['email' => $email]);
        
        try {
            $user = $this->userRepository->findByEmail($email);
            
            if (!$user) {
                $this->logOperation('authentication_failed', ['reason' => 'user_not_found']);
                return new AuthResult(false, 'Invalid credentials');
            }
            
            if (!$this->authService->verifyPassword($password, $user->getPasswordHash())) {
                $this->logOperation('authentication_failed', ['reason' => 'invalid_password']);
                return new AuthResult(false, 'Invalid credentials');
            }
            
            $this->currentUser = $user;
            $this->logOperation('authentication_success', ['user_id' => $user->getId()]);
            
            // セッション情報をキャッシュ（シングルトンのキャッシュサービス）
            $sessionData = [
                'user_id' => $user->getId(),
                'email' => $user->getEmail(),
                'roles' => $user->getRoles(),
                'authenticated_at' => time()
            ];
            
            $sessionId = $this->generateSessionId();
            $this->cache->set("session:{$sessionId}", $sessionData, 3600);
            
            return new AuthResult(true, 'Authentication successful', $sessionId);
        } catch (Exception $e) {
            $this->logOperation('authentication_error', ['error' => $e->getMessage()]);
            $this->logger->error('Authentication error', [
                'email' => $email,
                'error' => $e->getMessage()
            ]);
            
            return new AuthResult(false, 'Authentication error');
        }
    }
    
    public function updateProfile(string $userId, UserProfileData $profileData): UpdateResult
    {
        $this->logOperation('profile_update_attempt', ['user_id' => $userId]);
        
        try {
            $user = $this->userRepository->findById($userId);
            
            if (!$user) {
                return new UpdateResult(false, 'User not found');
            }
            
            // プロファイル更新
            $user->setName($profileData->getName());
            $user->setEmail($profileData->getEmail());
            $user->setUpdatedAt(new DateTime());
            
            $this->userRepository->save($user);
            
            // キャッシュを更新
            $this->cache->delete("user:{$userId}");
            
            $this->logOperation('profile_update_success', ['user_id' => $userId]);
            
            return new UpdateResult(true, 'Profile updated successfully');
        } catch (Exception $e) {
            $this->logOperation('profile_update_error', ['error' => $e->getMessage()]);
            return new UpdateResult(false, 'Update failed');
        }
    }
    
    private function logOperation(string $operation, array $context = []): void
    {
        $this->operationLog[] = [
            'operation' => $operation,
            'context' => $context,
            'timestamp' => microtime(true),
            'service_instance' => spl_object_id($this)
        ];
    }
    
    private function generateSessionId(): string
    {
        return bin2hex(random_bytes(32));
    }
    
    public function getCurrentUser(): ?User
    {
        return $this->currentUser;
    }
    
    public function getOperationLog(): array
    {
        return $this->operationLog;
    }
}
```

## スコープ選択の指針

### 1. プロトタイプスコープが適切なケース

```php
class PrototypeRecommendedModule extends AbstractModule
{
    protected function configure(): void
    {
        // ✅ プロトタイプ推奨：ビジネスロジックサービス
        $this->bind(OrderServiceInterface::class)
            ->to(OrderService::class);
        // 理由：注文処理の状態を保持、リクエストごとに独立
        
        $this->bind(UserServiceInterface::class)
            ->to(UserService::class);
        // 理由：ユーザー操作の状態を保持、セッションごとに独立
        
        $this->bind(ShoppingCartInterface::class)
            ->to(ShoppingCart::class);
        // 理由：カートの状態を保持、ユーザーごとに独立
        
        $this->bind(ReportGeneratorInterface::class)
            ->to(ReportGenerator::class);
        // 理由：レポート生成の進行状態を保持
        
        $this->bind(ValidationContextInterface::class)
            ->to(ValidationContext::class);
        // 理由：バリデーション結果を蓄積、リクエストごとに独立
        
        $this->bind(WorkflowProcessorInterface::class)
            ->to(WorkflowProcessor::class);
        // 理由：ワークフローの実行状態を保持
    }
}

// プロトタイプが適切な理由の例
class OrderService implements OrderServiceInterface
{
    // ❌ これらの状態があるためシングルトンは危険
    private array $validationErrors = [];      // リクエスト固有
    private ?Order $currentOrder = null;       // リクエスト固有
    private array $processingSteps = [];       // リクエスト固有
    private DateTime $processStartTime;        // リクエスト固有
    
    // ✅ これらの依存関係はシングルトンでも安全
    public function __construct(
        private OrderRepositoryInterface $repository,    // ステートレス
        private PaymentServiceInterface $paymentService, // ステートレス  
        private LoggerInterface $logger                  // シングルトン
    ) {}
}
```

### 2. シングルトンスコープが適切なケース

```php
class SingletonRecommendedModule extends AbstractModule
{
    protected function configure(): void
    {
        // ✅ シングルトン推奨：インフラストラクチャサービス
        $this->bind(DatabaseInterface::class)
            ->to(MySQLDatabase::class)
            ->in(Singleton::class);
        // 理由：接続プール、重いリソース
        
        $this->bind(CacheInterface::class)
            ->to(RedisCache::class)
            ->in(Singleton::class);
        // 理由：キャッシュ状態の共有、接続の再利用
        
        $this->bind(LoggerInterface::class)
            ->to(FileLogger::class)
            ->in(Singleton::class);
        // 理由：ログファイルハンドル、設定の共有
        
        $this->bind(ConfigInterface::class)
            ->to(ApplicationConfig::class)
            ->in(Singleton::class);
        // 理由：設定データの共有、初期化コストの削減
        
        // ✅ ステートレスサービスもシングルトン可
        $this->bind(ValidatorInterface::class)
            ->to(Validator::class)
            ->in(Singleton::class);
        // 理由：バリデーションルール、状態を持たない
        
        $this->bind(FactoryInterface::class)
            ->to(ServiceFactory::class)
            ->in(Singleton::class);
        // 理由：オブジェクト作成ロジック、状態を持たない
    }
}
```

## パフォーマンス最適化

### 1. メモリ使用量の監視

```php
class PerformanceAnalyzer
{
    public function __construct(
        private LoggerInterface $logger
    ) {}
    
    public function analyzeInstanceCreation(): void
    {
        $injector = new Injector(new ECommerceModule());
        
        $initialMemory = memory_get_usage(true);
        $this->logger->info('Performance analysis started', [
            'initial_memory' => $this->formatBytes($initialMemory)
        ]);
        
        // プロトタイプインスタンスの作成測定
        $instances = [];
        $creationTimes = [];
        
        for ($i = 0; $i < 100; $i++) {
            $startTime = microtime(true);
            $instance = $injector->getInstance(OrderServiceInterface::class);
            $endTime = microtime(true);
            
            $instances[] = $instance;
            $creationTimes[] = $endTime - $startTime;
            
            if ($i % 20 === 0) {
                $currentMemory = memory_get_usage(true);
                $this->logger->debug('Instance creation checkpoint', [
                    'instances_created' => $i + 1,
                    'current_memory' => $this->formatBytes($currentMemory),
                    'memory_increase' => $this->formatBytes($currentMemory - $initialMemory)
                ]);
            }
        }
        
        $finalMemory = memory_get_usage(true);
        $totalCreationTime = array_sum($creationTimes);
        $avgCreationTime = $totalCreationTime / count($creationTimes);
        
        $this->logger->info('Performance analysis completed', [
            'instances_created' => count($instances),
            'total_memory_used' => $this->formatBytes($finalMemory - $initialMemory),
            'avg_creation_time' => round($avgCreationTime * 1000, 3) . 'ms',
            'total_creation_time' => round($totalCreationTime * 1000, 2) . 'ms'
        ]);
        
        // メモリクリーンアップテスト
        unset($instances);
        gc_collect_cycles();
        
        $afterCleanupMemory = memory_get_usage(true);
        $this->logger->info('Memory cleanup analysis', [
            'memory_before_cleanup' => $this->formatBytes($finalMemory),
            'memory_after_cleanup' => $this->formatBytes($afterCleanupMemory),
            'memory_freed' => $this->formatBytes($finalMemory - $afterCleanupMemory)
        ]);
    }
    
    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB'];
        $bytes = max($bytes, 0);
        $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
        $pow = min($pow, count($units) - 1);
        $bytes /= (1 << (10 * $pow));
        return round($bytes, 2) . ' ' . $units[$pow];
    }
}
```

### 2. オブジェクトライフサイクル管理

```php
class ObjectLifecycleManager
{
    private array $instanceTracking = [];
    
    public function __construct(
        private LoggerInterface $logger
    ) {}
    
    public function trackInstanceLifecycle(): void
    {
        $injector = new Injector(new ECommerceModule());
        
        // プロトタイプインスタンスのライフサイクル追跡
        $this->trackPrototypeLifecycle($injector);
        
        // シングルトンインスタンスのライフサイクル追跡
        $this->trackSingletonLifecycle($injector);
    }
    
    private function trackPrototypeLifecycle(Injector $injector): void
    {
        $this->logger->info('=== Prototype Lifecycle Tracking ===');
        
        for ($i = 0; $i < 3; $i++) {
            $orderService = $injector->getInstance(OrderServiceInterface::class);
            $instanceId = spl_object_id($orderService);
            
            $this->instanceTracking['prototype'][$instanceId] = [
                'created_at' => microtime(true),
                'instance_number' => $i + 1
            ];
            
            $this->logger->info('Prototype instance created', [
                'instance_id' => $instanceId,
                'instance_number' => $i + 1,
                'class' => get_class($orderService)
            ]);
            
            // 短時間使用後に解放
            unset($orderService);
            
            $this->logger->info('Prototype instance released', [
                'instance_id' => $instanceId
            ]);
        }
    }
    
    private function trackSingletonLifecycle(Injector $injector): void
    {
        $this->logger->info('=== Singleton Lifecycle Tracking ===');
        
        for ($i = 0; $i < 3; $i++) {
            $cache = $injector->getInstance(CacheInterface::class);
            $instanceId = spl_object_id($cache);
            
            if (!isset($this->instanceTracking['singleton'][$instanceId])) {
                $this->instanceTracking['singleton'][$instanceId] = [
                    'created_at' => microtime(true),
                    'access_count' => 0
                ];
                
                $this->logger->info('Singleton instance created', [
                    'instance_id' => $instanceId,
                    'class' => get_class($cache)
                ]);
            }
            
            $this->instanceTracking['singleton'][$instanceId]['access_count']++;
            
            $this->logger->info('Singleton instance accessed', [
                'instance_id' => $instanceId,
                'access_number' => $i + 1,
                'total_accesses' => $this->instanceTracking['singleton'][$instanceId]['access_count']
            ]);
        }
    }
    
    public function getTrackingReport(): array
    {
        return $this->instanceTracking;
    }
}
```

## 実世界での使用例

### 1. E-commerceチェックアウトプロセス

```php
class CheckoutProcessModule extends AbstractModule
{
    protected function configure(): void
    {
        // プロトタイプ：チェックアウト固有の状態
        $this->bind(CheckoutProcessInterface::class)
            ->to(CheckoutProcess::class);
        
        $this->bind(PaymentProcessorInterface::class)
            ->to(PaymentProcessor::class);
        
        // シングルトン：共有リソース
        $this->bind(PaymentGatewayInterface::class)
            ->to(StripeGateway::class)
            ->in(Singleton::class);
        
        $this->bind(TaxCalculatorInterface::class)
            ->to(TaxCalculator::class)
            ->in(Singleton::class);
    }
}

class CheckoutProcess implements CheckoutProcessInterface
{
    private array $checkoutSteps = [];
    private array $calculatedTaxes = [];
    private ?PaymentResult $paymentResult = null;
    private CheckoutState $state;
    
    public function __construct(
        private ShoppingCartInterface $cart,
        private PaymentProcessorInterface $paymentProcessor,
        private TaxCalculatorInterface $taxCalculator,
        private OrderServiceInterface $orderService
    ) {
        $this->state = CheckoutState::INITIALIZED;
        $this->addStep('initialized');
    }
    
    public function processCheckout(CheckoutData $checkoutData): CheckoutResult
    {
        try {
            $this->state = CheckoutState::PROCESSING;
            $this->addStep('processing_started');
            
            // Step 1: 税金計算
            $this->calculateTaxes($checkoutData);
            $this->addStep('taxes_calculated');
            
            // Step 2: 支払い処理
            $this->processPayment($checkoutData);
            $this->addStep('payment_processed');
            
            // Step 3: 注文作成
            $order = $this->createOrder($checkoutData);
            $this->addStep('order_created');
            
            $this->state = CheckoutState::COMPLETED;
            $this->addStep('checkout_completed');
            
            return new CheckoutResult(true, $order, $this->checkoutSteps);
        } catch (CheckoutException $e) {
            $this->state = CheckoutState::FAILED;
            $this->addStep('checkout_failed', ['error' => $e->getMessage()]);
            
            return new CheckoutResult(false, null, $this->checkoutSteps, $e->getMessage());
        }
    }
    
    private function calculateTaxes(CheckoutData $checkoutData): void
    {
        foreach ($this->cart->getItems() as $item) {
            $tax = $this->taxCalculator->calculateTax(
                $item['product'],
                $item['quantity'],
                $checkoutData->getShippingAddress()
            );
            
            $this->calculatedTaxes[$item['product']->getId()] = $tax;
        }
    }
    
    private function addStep(string $stepName, array $data = []): void
    {
        $this->checkoutSteps[] = [
            'step' => $stepName,
            'timestamp' => microtime(true),
            'state' => $this->state->value,
            'data' => $data,
            'process_instance' => spl_object_id($this)
        ];
    }
    
    public function getCheckoutSteps(): array
    {
        return $this->checkoutSteps;
    }
}

enum CheckoutState: string
{
    case INITIALIZED = 'initialized';
    case PROCESSING = 'processing';
    case COMPLETED = 'completed';
    case FAILED = 'failed';
}
```

## テスト戦略

### 1. プロトタイプサービスのテスト

```php
class PrototypeServiceTest extends PHPUnit\Framework\TestCase
{
    private Injector $injector;
    
    protected function setUp(): void
    {
        $this->injector = new Injector(new TestModule());
    }
    
    public function testPrototypeInstancesAreIndependent(): void
    {
        // 複数のインスタンスを作成
        $service1 = $this->injector->getInstance(OrderServiceInterface::class);
        $service2 = $this->injector->getInstance(OrderServiceInterface::class);
        
        // インスタンスが異なることを確認
        $this->assertNotSame($service1, $service2);
        
        // それぞれ独立した状態を持つことを確認
        $order1 = new Order('order-1');
        $order2 = new Order('order-2');
        
        $service1->processOrder(new OrderData($order1));
        $service2->processOrder(new OrderData($order2));
        
        // 処理結果が分離されていることを確認
        $this->assertNotEmpty($service1->getProcessingSteps());
        $this->assertNotEmpty($service2->getProcessingSteps());
        $this->assertNotEquals($service1->getProcessingSteps(), $service2->getProcessingSteps());
    }
    
    public function testSingletonInstancesAreShared(): void
    {
        // シングルトンインスタンスは同じ
        $cache1 = $this->injector->getInstance(CacheInterface::class);
        $cache2 = $this->injector->getInstance(CacheInterface::class);
        
        $this->assertSame($cache1, $cache2);
        
        // 状態が共有されることを確認
        $cache1->set('test-key', 'test-value');
        $this->assertEquals('test-value', $cache2->get('test-key'));
    }
    
    public function testConcurrentProcessing(): void
    {
        $processors = [];
        $orders = [];
        
        // 複数の処理プロセスをシミュレート
        for ($i = 0; $i < 5; $i++) {
            $processors[$i] = $this->injector->getInstance(OrderServiceInterface::class);
            $orders[$i] = new OrderData(new Order("concurrent-order-{$i}"));
        }
        
        // 並行処理
        $results = [];
        foreach ($processors as $i => $processor) {
            $results[$i] = $processor->processOrder($orders[$i]);
        }
        
        // すべての処理が成功し、独立していることを確認
        foreach ($results as $i => $result) {
            $this->assertTrue($result->isSuccess(), "Order {$i} should be processed successfully");
            
            // 各プロセッサーが独自の処理ステップを持つ
            $steps = $processors[$i]->getProcessingSteps();
            $this->assertNotEmpty($steps);
            
            // 他のプロセッサーと重複しない
            foreach ($processors as $j => $otherProcessor) {
                if ($i !== $j) {
                    $this->assertNotEquals($steps, $otherProcessor->getProcessingSteps());
                }
            }
        }
    }
}

class TestModule extends AbstractModule
{
    protected function configure(): void
    {
        // テスト用のモック（シングルトン）
        $this->bind(CacheInterface::class)
            ->toInstance(new InMemoryCache())
            ->in(Singleton::class);
        
        $this->bind(LoggerInterface::class)
            ->toInstance(new TestLogger())
            ->in(Singleton::class);
        
        // テスト対象（プロトタイプ）
        $this->bind(OrderServiceInterface::class)
            ->to(OrderService::class);
        
        $this->bind(UserServiceInterface::class)
            ->to(UserService::class);
    }
}
```

## 次のステップ

プロトタイプスコープの理解が完了したので、次の学習に進みましょう。

1. **スコープ比較**: シングルトンとプロトタイプの詳細比較
2. **AOPとインターセプター**: 横断的関心事の実装
3. **実世界の例**: E-commerceプラットフォームでの実践

**続きは:** [スコープ比較とベストプラクティス](scope-comparison.html)

## 重要なポイント

- **プロトタイプスコープ**はRay.Diのデフォルト動作
- **状態を持つサービス**にはプロトタイプが適切
- **ビジネスロジック層**では基本的にプロトタイプを使用
- **インスタンス分離**により並行処理でも安全
- **メモリ使用量**を監視して適切に管理
- **テスト**では状態分離と並行処理を検証

---

プロトタイプスコープにより、各リクエストや処理で独立した状態を維持しながら、柔軟で拡張可能なアプリケーションアーキテクチャを構築できます。シングルトンとの適切な使い分けが、パフォーマンスと保守性のバランスを取る鍵となります。