---
layout: docs-ja
title: 依存注入の原則
category: Manual
permalink: /manuals/1.0/ja/tutorial/01-foundations/dependency-injection-principles.html
---

# 依存注入の原則

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- 依存注入とは何か、なぜ重要なのか
- DIがソフトウェア設計で解決する問題
- 制御の反転（IoC）の中核原則
- DIがより良いソフトウェアアーキテクチャを可能にする方法
- DIとSOLID原則の関係

## 問題：密結合

ソフトウェア開発でよくある問題から始めます。E-commerceプラットフォームを構築していて、注文確認メールを送信する必要があるとします：

```php
class OrderService
{
    public function processOrder(Order $order): void
    {
        // 注文の検証
        if (!$this->validateOrder($order)) {
            throw new InvalidOrderException();
        }
        
        // データベースに保存
        $database = new MySQLDatabase();
        $database->save($order);
        
        // 確認メールを送信
        $emailService = new SMTPEmailService();
        $emailService->send(
            $order->getCustomerEmail(),
            'Order Confirmation',
            $this->generateOrderEmail($order)
        );
        
        // トランザクションをログに記録
        $logger = new FileLogger('/var/log/orders.log');
        $logger->info("Order {$order->getId()} processed successfully");
    }
}
```

### 問題点

このコードは**密結合**を示しています。コードの保守を困難にするいくつかの問題があります：

1. **ハード依存性**: `OrderService`が`MySQLDatabase`、`SMTPEmailService`、`FileLogger`を直接作成
2. **テストの困難さ**: 実際にメールを送信したりファイルに書き込んだりしないでテストする方法がありません
3. **柔軟性の欠如**: MySQLからPostgreSQLに変更したい場合や、SMTPからSendGridに変更したい場合に対応が困難です
4. **SOLID原則の違反**: クラスが変更される理由が複数ある
5. **モックの困難さ**: 単体テストが不可能

## 解決策：依存注入

依存注入は、オブジェクト作成の**制御を反転**させることで、これらの問題を解決します：

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
        // 注文の検証
        if (!$this->validateOrder($order)) {
            throw new InvalidOrderException();
        }
        
        // データベースに保存
        $this->database->save($order);
        
        // 確認メールを送信
        $this->emailService->send(
            $order->getCustomerEmail(),
            'Order Confirmation',
            $this->generateOrderEmail($order)
        );
        
        // トランザクションをログに記録
        $this->logger->info("Order {$order->getId()} processed successfully");
    }
}
```

### 達成された利点

1. **疎結合**: `OrderService`は抽象化に依存し、具象実装に依存しない
2. **テスト可能性**: テスト用にモックオブジェクトを簡単に注入できる
3. **柔軟性**: `OrderService`を変更せずに実装を切り替えられる
4. **単一責任**: 各クラスが変更される理由は一つ
5. **オープン・クローズド原則**: 拡張に対してオープン、変更に対してクローズド

## 制御の反転（IoC）

**従来の制御フロー:**
```
オブジェクトAがオブジェクトBを作成
オブジェクトAがオブジェクトBのライフサイクルを制御
オブジェクトAがオブジェクトBの具象型を知っている
```

**反転した制御フロー:**
```
コンテナがオブジェクトBを作成
コンテナがオブジェクトBをオブジェクトAに注入
オブジェクトAはオブジェクトBのインターフェースのみを知っている
```

### 例：IoC前後の比較

**前（オブジェクトが依存関係を作成）:**
```php
class UserService
{
    private $repository;
    
    public function __construct()
    {
        // UserServiceが作成を制御
        $this->repository = new MySQLUserRepository();
    }
}
```

**後（依存関係が注入される）:**
```php
class UserService
{
    public function __construct(
        private UserRepositoryInterface $repository
    ) {
        // コンテナが作成と注入を制御
    }
}
```

## 依存注入のタイプ

### 1. コンストラクタ注入（推奨）

```php
class ProductService
{
    public function __construct(
        private ProductRepositoryInterface $repository,
        private CacheInterface $cache
    ) {}
}
```

**メリット:**
- 依存関係が明確で必須
- 構築後は不変
- 依存関係が欠落している場合、高速に失敗

### 2. メソッド注入

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

**用途:**
- オプショナルな依存関係
- メソッド呼び出しごとに異なる依存関係

### 3. プロパティ注入（避ける）

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

**問題:**
- 依存関係が明確でない
- 可変状態
- 依存関係が設定される前に使用される可能性

## DIが可能にするデザインパターン

### ファクトリーパターン
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

### ストラテジーパターン
```php
interface ShippingStrategy
{
    public function calculateCost(Package $package): Money;
}

class ShippingService
{
    public function __construct(
        private array $strategies // 注入されたストラテジーのセット
    ) {}
    
    public function calculateShipping(Package $package, string $method): Money
    {
        return $this->strategies[$method]->calculateCost($package);
    }
}
```

### オブザーバーパターン
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
        // 注文を処理...
        
        // オブザーバーに通知
        $this->eventDispatcher->dispatch(new OrderProcessedEvent($order));
    }
}
```

## テストの利点

### DI なし（テストが困難）
```php
class OrderServiceTest extends PHPUnit\Framework\TestCase
{
    public function testProcessOrder(): void
    {
        $service = new OrderService();
        
        // 実際にメールを送信せずにテストするには？
        // データベース呼び出しを検証するには？
        // 外部依存関係を制御するには？
        
        $order = new Order(/*...*/);
        $service->processOrder($order); // これはテストで失敗します
    }
}
```

### DI あり（テストが簡単）
```php
class OrderServiceTest extends PHPUnit\Framework\TestCase
{
    public function testProcessOrder(): void
    {
        // モックを作成
        $database = $this->createMock(DatabaseInterface::class);
        $emailService = $this->createMock(EmailServiceInterface::class);
        $logger = $this->createMock(LoggerInterface::class);
        
        // 期待値を設定
        $database->expects($this->once())->method('save');
        $emailService->expects($this->once())->method('send');
        $logger->expects($this->once())->method('info');
        
        // 制御された依存関係でテスト
        $service = new OrderService($database, $emailService, $logger);
        $order = new Order(/*...*/);
        $service->processOrder($order);
    }
}
```

## アーキテクチャの利点

### 階層化アーキテクチャ
```
┌─────────────────────┐
│   プレゼンテーション      │ ← コントローラー、ビュー
├─────────────────────┤
│   アプリケーション      │ ← サービス、ユースケース
├─────────────────────┤
│   ドメイン           │ ← ビジネスロジック
├─────────────────────┤
│   インフラストラクチャ  │ ← データベース、外部API
└─────────────────────┘
```

DIが層間のクリーンな分離を可能にします：

```php
// ドメイン層（純粋なビジネスロジック）
interface UserRepositoryInterface
{
    public function findByEmail(string $email): ?User;
}

// アプリケーション層（ドメインを協調）
class AuthenticationService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private PasswordHasherInterface $passwordHasher
    ) {}
}

// インフラストラクチャ層（技術的詳細）
class MySQLUserRepository implements UserRepositoryInterface
{
    // データベース固有の実装
}
```

### ヘキサゴナルアーキテクチャ（ポート・アンド・アダプター）
```
     ┌─────────────────┐
     │   Application   │
     │      Core       │
     └─────────────────┘
            │   │
    ┌───────┘   └───────┐
    │                   │
┌───▼───┐           ┌───▼───┐
│ ポート │           │ ポート │
│  Web  │           │  DB   │
└───────┘           └───────┘
```

```php
// コアアプリケーション
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository, // ポート
        private PaymentGatewayInterface $paymentGateway   // ポート
    ) {}
}

// アダプター（実装）
class SQLOrderRepository implements OrderRepositoryInterface {} // アダプター
class StripePaymentGateway implements PaymentGatewayInterface {} // アダプター
```

## 主要原則のまとめ

### 1. 抽象化に依存する
```php
// 良い：インターフェースに依存
public function __construct(private LoggerInterface $logger) {}

// 悪い：具象クラスに依存
public function __construct(private FileLogger $logger) {}
```

### 2. 依存関係を注入し、作成しない
```php
// 良い：依存関係が注入される
public function __construct(private DatabaseInterface $db) {}

// 悪い：依存関係を作成する
public function __construct() {
    $this->db = new MySQLDatabase();
}
```

### 3. 必要な依存関係にはコンストラクタ注入を使用
```php
// 良い：何が必要かが明確
public function __construct(
    private UserRepositoryInterface $userRepository,
    private EmailServiceInterface $emailService
) {}
```

### 4. コンストラクタをシンプルに保つ
```php
// 良い：ただの代入
public function __construct(private ServiceInterface $service) {}

// 悪い：コンストラクタ内のロジック
public function __construct(ServiceInterface $service) {
    $this->service = $service;
    $this->initialize(); // ロジックは避ける
}
```

## 次のステップ

依存注入の原則を理解したので、次に進む準備が整いました。

1. **SOLID原則の学習**: DIがより良い設計を可能にする方法を見る
2. **Ray.Diの基礎の探索**: フレームワークのアプローチを理解する
3. **例での練習**: 適切なDIで構築を開始する

**続きは:** [SOLID原則の実践](solid-principles.html)

## 重要なポイント

- **依存注入**はオブジェクト作成の制御を反転させる
- **疎結合**によりコードがより保守しやすく、テストしやすくなる
- **抽象化**により柔軟性が提供され、デザインパターンが可能になる
- **コンストラクタ注入**が必要な依存関係の推奨方法
- **DI**によりクリーンなアーキテクチャと関心事の分離が可能
- **テスト**は注入されたモック依存関係で簡単になる

---

依存注入は単なる技術的パターンではありません。アプリケーション内でオブジェクトがどのように協調するかについての根本的な思考の変化です。
