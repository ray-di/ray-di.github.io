---
layout: docs-ja
title: Ray.Diの基礎
category: Manual
permalink: /manuals/1.0/ja/tutorial/01-foundations/raydi-fundamentals.html
---

# Ray.Diの基礎

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diの哲学と設計原則
- 基本的なDIコンテナの使用方法
- モジュールとバインディングの作成
- インジェクションの種類と使用場面
- スコープとオブジェクトライフサイクル
- 実践的な例での使用方法

## Ray.Diの哲学

Ray.Diは**Google Guice**にインスパイアされたPHP依存注入フレームワークです。

### 核心原則
- **明示的な設定**: 魔法のような自動配線よりも明示的な設定を優先
- **コンパイル時の安全性**: 実行時ではなく、可能な限り構築時にエラーを検出
- **パフォーマンス**: 最適化されたコンテナの生成とキャッシュ
- **テスト可能性**: 簡単にモックやスタブを注入可能

### 他のDIフレームワークとの違い
```php
// 従来のDIコンテナ（配列ベース）
$container['UserRepository'] = function($c) {
    return new MySQLUserRepository($c['Database']);
};

// Ray.Di（型安全なバインディング）
$this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
```

## 基本的な使用方法

### 1. インストール
```bash
composer require ray/di
```

### 2. 最初の例
```php
<?php
use Ray\Di\Injector;

interface GreetingServiceInterface
{
    public function greet(string $name): string;
}

class EnglishGreetingService implements GreetingServiceInterface
{
    public function greet(string $name): string
    {
        return "Hello, {$name}!";
    }
}

class HelloWorld
{
    public function __construct(
        private GreetingServiceInterface $greetingService
    ) {}
    
    public function sayHello(string $name): string
    {
        return $this->greetingService->greet($name);
    }
}

// DIコンテナの設定
$injector = new Injector();
$injector->bind(GreetingServiceInterface::class)->to(EnglishGreetingService::class);

// オブジェクトの取得
$helloWorld = $injector->getInstance(HelloWorld::class);
echo $helloWorld->sayHello('World'); // "Hello, World"
```

## モジュールシステム

### AbstractModuleの使用
```php
use Ray\Di\AbstractModule;

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // 基本的なバインディング
        $this->bind(GreetingServiceInterface::class)->to(EnglishGreetingService::class);
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
    }
}

// モジュールの使用
$injector = new Injector(new AppModule());
```

### 複数モジュールの組み合わせ
```php
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(DatabaseConnectionInterface::class)->to(MySQLConnection::class);
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(ProductRepositoryInterface::class)->to(MySQLProductRepository::class);
    }
}

class EmailModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
        $this->bind(EmailTemplateInterface::class)->to(TwigEmailTemplate::class);
    }
}

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new DatabaseModule());
        $this->install(new EmailModule());
        
        // アプリケーション固有のバインディング
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
    }
}
```

## バインディングの種類

### 1. 基本的なバインディング
```php
// インターフェースから実装への基本的なバインディング
$this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
```

### 2. インスタンスバインディング
```php
// 特定のインスタンスをバインド
$config = new AppConfig(['database' => 'mysql://localhost/myapp']);
$this->bind(AppConfig::class)->toInstance($config);
```

### 3. プロバイダーバインディング
```php
// 複雑な作成ロジックにプロバイダーを使用
$this->bind(DatabaseConnectionInterface::class)->toProvider(DatabaseConnectionProvider::class);

class DatabaseConnectionProvider implements ProviderInterface
{
    public function get(): DatabaseConnectionInterface
    {
        $config = $_ENV['DATABASE_URL'] ?? 'sqlite::memory:';
        return new DatabaseConnection($config);
    }
}
```

### 4. 注釈付きバインディング
```php
// 同じインターフェースの複数実装を区別
$this->bind(LoggerInterface::class)->annotatedWith('file')->to(FileLogger::class);
$this->bind(LoggerInterface::class)->annotatedWith('email')->to(EmailLogger::class);

// 使用側
class OrderService
{
    public function __construct(
        #[Named('file')] private LoggerInterface $fileLogger,
        #[Named('email')] private LoggerInterface $emailLogger
    ) {}
}
```

## インジェクションの種類

### 1. コンストラクタインジェクション（推奨）
```php
class OrderService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private PaymentServiceInterface $paymentService,
        private LoggerInterface $logger
    ) {}
}
```

### 2. メソッドインジェクション
```php
class OrderService
{
    private LoggerInterface $logger;
    
    #[Inject]
    public function setLogger(LoggerInterface $logger): void
    {
        $this->logger = $logger;
    }
}
```

### 3. プロパティインジェクション（避ける）
```php
class OrderService
{
    #[Inject]
    public LoggerInterface $logger;
}
```

## スコープとライフサイクル

### シングルトンスコープ
```php
// 常に同じインスタンスを返す
$this->bind(DatabaseConnectionInterface::class)
    ->to(MySQLConnection::class)
    ->in(Singleton::class);
```

### プロトタイプスコープ（デフォルト）
```php
// 毎回新しいインスタンスを作成
$this->bind(OrderServiceInterface::class)->to(OrderService::class);
```

### カスタムスコープ
```php
class RequestScope implements ScopeInterface
{
    private static array $instances = [];
    
    public function scope(callable $creator): callable
    {
        return function() use ($creator) {
            $key = spl_object_hash($creator);
            if (!isset(self::$instances[$key])) {
                self::$instances[$key] = $creator();
            }
            return self::$instances[$key];
        };
    }
}

// カスタムスコープの使用
$this->bind(RequestIdInterface::class)->to(RequestId::class)->in(RequestScope::class);
```

## 高度な機能

### 1. 環境固有のモジュール
```php
// 開発環境用モジュール
class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(CacheInterface::class)->to(ArrayCache::class);
    }
}

// 本番環境用モジュール
class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(CacheInterface::class)->to(RedisCache::class);
    }
}

// アプリケーションの起動時に適切なモジュールを選択
$module = getenv('APP_ENV') === 'production' 
    ? new ProductionModule() 
    : new DevelopmentModule();
$injector = new Injector($module);
```

### 2. マルチバインディング
```php
// 複数の実装をセットとして注入
$this->bind(EventListenerInterface::class)->to(EmailEventListener::class);
$this->bind(EventListenerInterface::class)->to(LogEventListener::class);
$this->bind(EventListenerInterface::class)->to(SlackEventListener::class);

class EventDispatcher
{
    public function __construct(
        private array $listeners // EventListenerInterface[] として注入
    ) {}
    
    public function dispatch(Event $event): void
    {
        foreach ($this->listeners as $listener) {
            $listener->handle($event);
        }
    }
}
```

### 3. プロバイダーインジェクション
```php
class OrderService
{
    public function __construct(
        private ProviderInterface $userRepositoryProvider
    ) {}
    
    public function processOrder(Order $order): void
    {
        // 必要なときだけインスタンスを作成
        $userRepository = $this->userRepositoryProvider->get();
        $user = $userRepository->findById($order->getUserId());
        // ...
    }
}
```

## テストでの使用

### 1. テスト用モジュール
```php
class TestModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(InMemoryUserRepository::class);
        $this->bind(EmailServiceInterface::class)->to(MockEmailService::class);
        $this->bind(LoggerInterface::class)->to(NullLogger::class);
    }
}

class OrderServiceTest extends PHPUnit\Framework\TestCase
{
    public function testProcessOrder(): void
    {
        $injector = new Injector(new TestModule());
        $orderService = $injector->getInstance(OrderService::class);
        
        // テストの実行...
    }
}
```

### 2. 部分的なモック注入
```php
class PartialMockModule extends AbstractModule
{
    public function __construct(
        private UserRepositoryInterface $mockUserRepository
    ) {}
    
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->toInstance($this->mockUserRepository);
        // 他の依存関係は通常通り
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
    }
}
```

## 実践的な例：E-commerce注文システム

### ドメインモデル
```php
class Order
{
    public function __construct(
        private int $id,
        private int $userId,
        private array $items,
        private float $total
    ) {}
    
    // getters...
}

class OrderItem
{
    public function __construct(
        private int $productId,
        private int $quantity,
        private float $price
    ) {}
    
    // getters...
}
```

### サービス層
```php
interface OrderServiceInterface
{
    public function processOrder(Order $order): void;
}

class OrderService implements OrderServiceInterface
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private PaymentServiceInterface $paymentService,
        private InventoryServiceInterface $inventoryService,
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}
    
    public function processOrder(Order $order): void
    {
        $this->logger->info("Processing order: {$order->getId()}");
        
        // ユーザー検証
        $user = $this->userRepository->findById($order->getUserId());
        if (!$user) {
            throw new UserNotFoundException();
        }
        
        // 在庫確認
        foreach ($order->getItems() as $item) {
            if (!$this->inventoryService->isAvailable($item->getProductId(), $item->getQuantity())) {
                throw new InsufficientInventoryException();
            }
        }
        
        // 支払い処理
        $this->paymentService->processPayment($order->getTotal());
        
        // 在庫更新
        $this->inventoryService->updateInventory($order->getItems());
        
        // 確認メール送信
        $this->emailService->sendOrderConfirmation($user, $order);
        
        $this->logger->info("Order processed successfully: {$order->getId()}");
    }
}
```

### DIモジュール設定
```php
class EcommerceModule extends AbstractModule
{
    protected function configure(): void
    {
        // リポジトリ層
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(ProductRepositoryInterface::class)->to(MySQLProductRepository::class);
        
        // サービス層
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        $this->bind(PaymentServiceInterface::class)->to(StripePaymentService::class);
        $this->bind(InventoryServiceInterface::class)->to(InventoryService::class);
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
        
        // インフラストラクチャ
        $this->bind(LoggerInterface::class)->to(FileLogger::class)->in(Singleton::class);
        $this->bind(DatabaseConnectionInterface::class)->to(MySQLConnection::class)->in(Singleton::class);
    }
}
```

### 使用例
```php
// アプリケーション起動
$injector = new Injector(new EcommerceModule());

// Webコントローラー
class OrderController
{
    public function __construct(
        private OrderServiceInterface $orderService
    ) {}
    
    public function processOrder(Request $request): Response
    {
        $order = new Order(
            $request->get('id'),
            $request->get('user_id'),
            $request->get('items'),
            $request->get('total')
        );
        
        try {
            $this->orderService->processOrder($order);
            return new Response('Order processed successfully', 200);
        } catch (Exception $e) {
            return new Response('Order processing failed: ' . $e->getMessage(), 400);
        }
    }
}

// DIコンテナから取得
$orderController = $injector->getInstance(OrderController::class);
```

## ベストプラクティス

### 1. モジュールの設計
```php
// 良い：関心事ごとにモジュールを分離
class DatabaseModule extends AbstractModule { /* ... */ }
class EmailModule extends AbstractModule { /* ... */ }
class LoggingModule extends AbstractModule { /* ... */ }

// 悪い：すべてを一つのモジュールに
class GiantModule extends AbstractModule { /* ... */ }
```

### 2. インターフェースの使用
```php
// 良い：インターフェースを使用
$this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);

// 悪い：具象クラスを直接バインド
$this->bind(MySQLUserRepository::class)->to(MySQLUserRepository::class);
```

### 3. 依存関係の最小化
```php
// 良い：必要最小限の依存関係
class OrderService
{
    public function __construct(
        private PaymentServiceInterface $paymentService
    ) {}
}

// 悪い：不要な依存関係
class OrderService
{
    public function __construct(
        private PaymentServiceInterface $paymentService,
        private DatabaseConnectionInterface $db, // 直接使用しない
        private ConfigInterface $config // 直接使用しない
    ) {}
}
```

## 次のステップ

Ray.Diの基礎を理解したので、次に進む準備が整いました。

1. **基本的なバインディングの詳細学習**: 各バインディングタイプの実践的な使用方法
2. **高度な機能の探索**: マルチバインディング、AOP
3. **実世界の例での練習**: 複雑なアプリケーションでの適用方法

**続きは:** [基本的なバインディング](../index.html#part-2-基本的なバインディング)

## 重要なポイント

- **Ray.Di**は明示的な設定を重視する
- **モジュールシステム**により設定を整理し、再利用可能にする
- **バインディングDSL**は型安全で表現力豊か
- **スコープ**によりオブジェクトライフサイクルを制御
- **テスト**では専用のモジュールを使用
- **SOLID原則**がRay.Diの使用を導く

---

Ray.Diは設定が複雑に見えるかもしれませんが、この明示性こそが大規模アプリケーションでの保守性とテスト可能性を保証します。