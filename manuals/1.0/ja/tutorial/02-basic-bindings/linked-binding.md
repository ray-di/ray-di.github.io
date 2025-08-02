---
layout: docs-ja
title: リンク束縛
category: Manual
permalink: /manuals/1.0/ja/tutorial/02-basic-bindings/linked-binding.html
---

# リンク束縛

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- リンク束縛とは何か、最も基本的な束縛方法
- インターフェースから具象クラスへのリンク
- 抽象クラスから具象クラスへのリンク
- スコープとリンク束縛の組み合わせ
- 実践的なE-commerceアプリケーションでの使用例

## リンク束縛とは

**リンク束縛**（Google Guiceでは**Linked Bindings**として知られる）は、インターフェースや抽象クラスを具象クラスにリンクする最も基本的で重要な束縛方法です。これにより、依存性逆転原則（DIP）を実現し、疎結合なアーキテクチャを構築できます。


## DIの基本原理とオブジェクトグラフ

### オブジェクトの生成と注入の仕組み

DIの核心は、**オブジェクトが自分の依存関係を作らない**ことです。代わりに、外部（Ray.Di）が依存関係を作成し、プロパティとしてセットします。

```php
class OrderService
{
    // OrderService は UserRepository の存在を「知らない」
    // Ray.Di が作成したインスタンスがプロパティにセットされる
    public function __construct(
        private UserRepositoryInterface $userRepository // ← ここにセットされる
    ) {}
    
    public function createOrder(int $userId): Order
    {
        // 何の実装かは知らないが、インターフェース経由で使用
        $user = $this->userRepository->findById($userId);
        // ...
    }
}

// Ray.Di が内部で実行する処理：
// 1. MySQLUserRepository のインスタンスを作成
// 2. OrderService のコンストラクタに渡す  
// 3. OrderService は注入された具体的な実装を知らない
```

### オブジェクトグラフビルダーとしてのRay.Di

Ray.Diは**大きくて複雑なオブジェクトグラフを組み立てるビルダー**として機能します。手動作成との違いは、特に深い依存関係で顕著になります。

#### 手動作成の限界
```php
// 深い依存関係を手動で作成（全てを上から渡す必要）
$pdo = new PDO($dsn, $user, $pass);
$userRepository = new MySQLUserRepository($pdo);
$logger = new FileLogger('/var/log/app.log');
$emailService = new SMTPEmailService($logger);
$httpClient = new GuzzleHttpClient();
$paymentGateway = new StripePaymentGateway($httpClient, $logger);

// 最上位のサービスを作るために、全ての依存関係を準備
$orderService = new OrderService($userRepository, $emailService, $paymentGateway);
$orderController = new OrderController($orderService, $logger);

// さらに深くなると管理が困難...
```

#### Ray.Diによる自動組み立て
```php
// Ray.Di が深い依存関係も自動で解決
$injector = new Injector(new AppModule());

// これだけで完全なオブジェクトグラフを構築
$orderController = $injector->getInstance(OrderController::class);

// 内部で自動実行される組み立て：
//
// OrderController
//     └── OrderService  
//         ├── UserRepository → MySQLUserRepository → PDO
//         ├── EmailService → SMTPEmailService → FileLogger
//         └── PaymentGateway → StripePaymentGateway → HttpClient + FileLogger
```

### 非環式依存原則（ADP）

Ray.Diは**非環式依存原則**に基づき、依存関係が一方向で循環しないことを保証します。

#### 正しい一方向の依存関係
```php
// 健全な依存方向
OrderService → UserRepositoryInterface → MySQLUserRepository → PDO
     ↓
EmailServiceInterface → SMTPEmailService → LoggerInterface
```

#### 循環依存の禁止
```php
// 循環依存（Ray.Diが検出してエラー）
OrderService → UserService → OrderService  // 循環！
```

#### 階層構造による分離
```php
// 依存関係の方向性
アプリケーション層 (OrderController)
    ↓ 知っている
サービス層 (OrderService)  
    ↓ 知っている
リポジトリ層 (MySQLUserRepository)
    ↓ 知っている  
インフラ層 (PDO)

// 逆方向は知らない：
// PDO は MySQLUserRepository を知らない
// MySQLUserRepository は OrderService を知らない
// OrderService は OrderController を知らない
```

この原則により、各オブジェクトは自分より下位の抽象化のみを知り、上位層の存在を知る必要がありません。結果として、**変更に強く、テストしやすい**システムが構築できます。

### 基本的な使用方法

```php
use Ray\Di\AbstractModule;

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // インターフェースから具象クラスへのバインディング
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
    }
}
```

## インターフェースから具象クラスへのバインディング

### 1. 基本的なパターン

```php
// インターフェースの定義
interface UserRepositoryInterface
{
    public function findById(int $id): ?User;
    public function save(User $user): void;
    public function findByEmail(string $email): ?User;
}

// 具象クラスの実装
class MySQLUserRepository implements UserRepositoryInterface
{
    public function __construct(private PDO $pdo) {}
    
    public function findById(int $id): ?User
    {
        $stmt = $this->pdo->prepare('SELECT * FROM users WHERE id = ?');
        $stmt->execute([$id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $data ? new User($data) : null;
    }
    
    public function save(User $user): void
    {
        // INSERT or UPDATE logic
    }
    
    public function findByEmail(string $email): ?User
    {
        $stmt = $this->pdo->prepare('SELECT * FROM users WHERE email = ?');
        $stmt->execute([$email]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $data ? new User($data) : null;
    }
}

// サービスクラス
class UserService
{
    public function __construct(
        private UserRepositoryInterface $userRepository
    ) {}
    
    public function createUser(string $email, string $name): User
    {
        $user = new User(null, $email, $name);
        $this->userRepository->save($user);
        return $user;
    }
    
    public function getUserById(int $id): ?User
    {
        return $this->userRepository->findById($id);
    }
}

// モジュールでのバインディング
class UserModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
    }
}
```


## 抽象クラスから具象クラスへのバインディング

インターフェースと同様に、抽象クラスも具象クラスにバインドできます：

```php
// 抽象クラスの定義
abstract class PaymentGateway
{
    abstract public function processPayment(float $amount): bool;
    
    protected function validateAmount(float $amount): bool
    {
        return $amount > 0; // 共通のバリデーション
    }
}

// 具象クラスの実装
class StripePaymentGateway extends PaymentGateway
{
    public function processPayment(float $amount): bool
    {
        if (!$this->validateAmount($amount)) {
            return false;
        }
        // Stripe固有の処理
        return true;
    }
}

// バインディング
class PaymentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(PaymentGateway::class)->to(StripePaymentGateway::class);
    }
}
```

## スコープとクラスバインディングの組み合わせ

### 1. シングルトンスコープ

```php
use Ray\Di\Scope\Singleton;

class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        // データベース接続はシングルトン
        $this->bind(DatabaseConnectionInterface::class)
            ->to(MySQLConnection::class)
            ->in(Singleton::class);
            
        // キャッシュサービスもシングルトン
        $this->bind(CacheInterface::class)
            ->to(RedisCache::class)
            ->in(Singleton::class);
    }
}

class MySQLConnection implements DatabaseConnectionInterface
{
    private PDO $pdo;
    
    public function __construct()
    {
        $dsn = 'mysql:host=localhost;dbname=app';
        $this->pdo = new PDO($dsn, 'user', 'password');
        echo "Database connection created\n"; // デバッグ用
    }
    
    public function getPdo(): PDO
    {
        return $this->pdo;
    }
}

class RedisCache implements CacheInterface
{
    private Redis $redis;
    
    public function __construct()
    {
        $this->redis = new Redis();
        $this->redis->connect('localhost', 6379);
        echo "Redis connection created\n"; // デバッグ用
    }
    
    public function get(string $key): mixed
    {
        return $this->redis->get($key);
    }
    
    public function set(string $key, mixed $value, int $ttl = 3600): bool
    {
        return $this->redis->setex($key, $ttl, serialize($value));
    }
}
```

### 2. プロトタイプスコープ（デフォルト）

```php
class ServiceModule extends AbstractModule
{
    protected function configure(): void
    {
        // リクエストごとに新しいインスタンスを作成
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
    }
}

class OrderService implements OrderServiceInterface
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private EmailServiceInterface $emailService
    ) {
        echo "OrderService created\n"; // デバッグ用
    }
    
    public function processOrder(Order $order): void
    {
        // 注文処理
    }
}
```


## ベストプラクティス

### 1. 適切な抽象化レベル

```php
// 良い：適切な抽象化
interface UserRepositoryInterface
{
    public function findById(int $id): ?User;
    public function save(User $user): void;
    public function findByEmail(string $email): ?User;
}

// 悪い：不必要に複雑
interface UserRepositoryInterface
{
    public function findById(int $id): ?User;
    public function save(User $user): void;
    public function findByEmail(string $email): ?User;
    public function findByIdAndCache(int $id): ?User;
    public function saveWithTransaction(User $user): void;
    public function findByEmailAndValidate(string $email): ?User;
    public function countUsers(): int;
    public function getLastInsertId(): int;
}
```

### 2. 単一責任の原則

```php
// 良い：単一責任
class UserService
{
    public function __construct(
        private UserRepositoryInterface $userRepository
    ) {}
    
    public function createUser(string $email, string $name): User
    {
        $user = new User(null, $email, $name);
        $this->userRepository->save($user);
        return $user;
    }
}

// 悪い：複数の責任を持つ
class UserService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private EmailServiceInterface $emailService,
        private PaymentGateway $paymentGateway
    ) {}
    
    public function createUser(string $email, string $name): User
    {
        // ユーザー作成
        $user = new User(null, $email, $name);
        $this->userRepository->save($user);
        
        // メール送信（別の責任）
        $this->emailService->sendWelcomeEmail($user);
        
        // 決済処理（別の責任）
        $this->paymentGateway->setupBilling($user);
        
        return $user;
    }
}
```

### 3. テストしやすい設計

```php
// テスト用のモックリポジトリ
class MockUserRepository implements UserRepositoryInterface
{
    private array $users = [];
    
    public function findById(int $id): ?User
    {
        return $this->users[$id] ?? null;
    }
    
    public function save(User $user): void
    {
        $this->users[$user->getId()] = $user;
    }
    
    public function findByEmail(string $email): ?User
    {
        foreach ($this->users as $user) {
            if ($user->getEmail() === $email) {
                return $user;
            }
        }
        return null;
    }
}

// テスト用モジュール
class TestModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(MockUserRepository::class);
    }
}
```

## 次のステップ

クラスバインディングの使用方法を理解したので、次に進む準備が整いました。

1. **プロバイダーバインディングの学習**: 複雑な作成ロジックの実装
2. **マルチバインディングの探索**: 複数の実装の同時バインディング
3. **実世界の例での練習**: 複合的なバインディングの使用方法

**続きは:** [プロバイダーバインディング](provider-binding.html)

## 重要なポイント

- **クラスバインディング**は最も基本的で重要なバインディング方法
- **インターフェース**を具象クラスにバインドして依存性逆転を実現
- **抽象クラス**を使用して共通のロジックを提供
- **スコープ**を組み合わせてオブジェクトライフサイクルを制御
- **単一責任原則**を守って適切な抽象化レベルを維持
- **テスト**では簡単にモック実装に切り替え可能

---

クラスバインディングは、Ray.Diの核心となる機能です。適切に使用することで、柔軟で保守しやすく、テストしやすいアプリケーションを構築できます。