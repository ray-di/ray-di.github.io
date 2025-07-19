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

### Google Guiceとの関係

Ray.DiはGoogle Guiceにインスパイアされており、リンク束縛は以下のように対応しています：

**Google Guice:**
```java
// Linked Binding
bind(UserRepository.class).to(MySQLUserRepository.class);
```

**Ray.Di:**
```php
// リンク束縛（Linked Binding）
$this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
```

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
        if ($user->getId()) {
            $this->update($user);
        } else {
            $this->insert($user);
        }
    }
    
    public function findByEmail(string $email): ?User
    {
        $stmt = $this->pdo->prepare('SELECT * FROM users WHERE email = ?');
        $stmt->execute([$email]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $data ? new User($data) : null;
    }
    
    private function insert(User $user): void
    {
        $stmt = $this->pdo->prepare('INSERT INTO users (email, name) VALUES (?, ?)');
        $stmt->execute([$user->getEmail(), $user->getName()]);
    }
    
    private function update(User $user): void
    {
        $stmt = $this->pdo->prepare('UPDATE users SET email = ?, name = ? WHERE id = ?');
        $stmt->execute([$user->getEmail(), $user->getName(), $user->getId()]);
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

### 2. 複数のインターフェース実装

```php
// 異なるストレージ実装
class PostgreSQLUserRepository implements UserRepositoryInterface
{
    public function __construct(private PDO $pdo) {}
    
    public function findById(int $id): ?User
    {
        // PostgreSQL固有の実装
        $stmt = $this->pdo->prepare('SELECT * FROM users WHERE id = $1');
        $stmt->execute([$id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $data ? new User($data) : null;
    }
    
    public function save(User $user): void
    {
        // PostgreSQL固有の実装
    }
    
    public function findByEmail(string $email): ?User
    {
        // PostgreSQL固有の実装
        $stmt = $this->pdo->prepare('SELECT * FROM users WHERE email = $1');
        $stmt->execute([$email]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $data ? new User($data) : null;
    }
}

class InMemoryUserRepository implements UserRepositoryInterface
{
    private array $users = [];
    private int $nextId = 1;
    
    public function findById(int $id): ?User
    {
        return $this->users[$id] ?? null;
    }
    
    public function save(User $user): void
    {
        if (!$user->getId()) {
            $user->setId($this->nextId++);
        }
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

// 環境に応じたバインディング
class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(InMemoryUserRepository::class);
    }
}

class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
    }
}
```

## 抽象クラスから具象クラスへのバインディング

### 1. 抽象クラスの活用

```php
// 抽象クラスの定義
abstract class PaymentGateway
{
    protected array $config;
    
    public function __construct(array $config)
    {
        $this->config = $config;
        $this->initialize();
    }
    
    abstract protected function initialize(): void;
    abstract public function processPayment(float $amount, array $paymentData): PaymentResult;
    abstract public function refundPayment(string $transactionId): bool;
    
    protected function validateAmount(float $amount): bool
    {
        return $amount > 0;
    }
    
    protected function logTransaction(string $message): void
    {
        // 共通のログ処理
        error_log("Payment: {$message}");
    }
}

// 具象クラスの実装
class StripePaymentGateway extends PaymentGateway
{
    private $stripe;
    
    protected function initialize(): void
    {
        $this->stripe = new \Stripe\StripeClient($this->config['secret_key']);
    }
    
    public function processPayment(float $amount, array $paymentData): PaymentResult
    {
        if (!$this->validateAmount($amount)) {
            throw new InvalidArgumentException('Invalid amount');
        }
        
        try {
            $charge = $this->stripe->charges->create([
                'amount' => $amount * 100, // Stripeは cents 単位
                'currency' => 'usd',
                'source' => $paymentData['token']
            ]);
            
            $this->logTransaction("Stripe payment processed: {$charge->id}");
            return new PaymentResult(true, $charge->id);
        } catch (\Exception $e) {
            $this->logTransaction("Stripe payment failed: {$e->getMessage()}");
            return new PaymentResult(false, null, $e->getMessage());
        }
    }
    
    public function refundPayment(string $transactionId): bool
    {
        try {
            $this->stripe->refunds->create(['charge' => $transactionId]);
            $this->logTransaction("Stripe refund processed: {$transactionId}");
            return true;
        } catch (\Exception $e) {
            $this->logTransaction("Stripe refund failed: {$e->getMessage()}");
            return false;
        }
    }
}

class PayPalPaymentGateway extends PaymentGateway
{
    private $paypal;
    
    protected function initialize(): void
    {
        $this->paypal = new \PayPal\Api\ApiContext(
            new \PayPal\Auth\OAuthTokenCredential(
                $this->config['client_id'],
                $this->config['client_secret']
            )
        );
    }
    
    public function processPayment(float $amount, array $paymentData): PaymentResult
    {
        if (!$this->validateAmount($amount)) {
            throw new InvalidArgumentException('Invalid amount');
        }
        
        try {
            // PayPal固有の実装
            $this->logTransaction("PayPal payment processed");
            return new PaymentResult(true, 'paypal_transaction_id');
        } catch (\Exception $e) {
            $this->logTransaction("PayPal payment failed: {$e->getMessage()}");
            return new PaymentResult(false, null, $e->getMessage());
        }
    }
    
    public function refundPayment(string $transactionId): bool
    {
        try {
            // PayPal固有の実装
            $this->logTransaction("PayPal refund processed: {$transactionId}");
            return true;
        } catch (\Exception $e) {
            $this->logTransaction("PayPal refund failed: {$e->getMessage()}");
            return false;
        }
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

## E-commerceプラットフォームでの実践例

### 1. 商品管理システム

```php
// 商品リポジトリ
interface ProductRepositoryInterface
{
    public function findById(int $id): ?Product;
    public function findByCategory(string $category): array;
    public function save(Product $product): void;
    public function findFeatured(): array;
    public function search(string $query): array;
}

class MySQLProductRepository implements ProductRepositoryInterface
{
    public function __construct(private PDO $pdo) {}
    
    public function findById(int $id): ?Product
    {
        $stmt = $this->pdo->prepare('SELECT * FROM products WHERE id = ?');
        $stmt->execute([$id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $data ? new Product($data) : null;
    }
    
    public function findByCategory(string $category): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM products WHERE category = ?');
        $stmt->execute([$category]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        return array_map(fn($data) => new Product($data), $results);
    }
    
    public function save(Product $product): void
    {
        if ($product->getId()) {
            $this->update($product);
        } else {
            $this->insert($product);
        }
    }
    
    public function findFeatured(): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM products WHERE featured = 1');
        $stmt->execute();
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        return array_map(fn($data) => new Product($data), $results);
    }
    
    public function search(string $query): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM products WHERE name LIKE ? OR description LIKE ?');
        $searchTerm = "%{$query}%";
        $stmt->execute([$searchTerm, $searchTerm]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        return array_map(fn($data) => new Product($data), $results);
    }
    
    private function insert(Product $product): void
    {
        $stmt = $this->pdo->prepare('INSERT INTO products (name, description, price, category) VALUES (?, ?, ?, ?)');
        $stmt->execute([
            $product->getName(),
            $product->getDescription(),
            $product->getPrice(),
            $product->getCategory()
        ]);
    }
    
    private function update(Product $product): void
    {
        $stmt = $this->pdo->prepare('UPDATE products SET name = ?, description = ?, price = ?, category = ? WHERE id = ?');
        $stmt->execute([
            $product->getName(),
            $product->getDescription(),
            $product->getPrice(),
            $product->getCategory(),
            $product->getId()
        ]);
    }
}

// 商品サービス
class ProductService
{
    public function __construct(
        private ProductRepositoryInterface $productRepository,
        private CacheInterface $cache
    ) {}
    
    public function getProduct(int $id): ?Product
    {
        $cacheKey = "product_{$id}";
        $product = $this->cache->get($cacheKey);
        
        if ($product === null) {
            $product = $this->productRepository->findById($id);
            if ($product) {
                $this->cache->set($cacheKey, $product, 3600);
            }
        }
        
        return $product;
    }
    
    public function getFeaturedProducts(): array
    {
        $cacheKey = "featured_products";
        $products = $this->cache->get($cacheKey);
        
        if ($products === null) {
            $products = $this->productRepository->findFeatured();
            $this->cache->set($cacheKey, $products, 1800);
        }
        
        return $products;
    }
    
    public function searchProducts(string $query): array
    {
        return $this->productRepository->search($query);
    }
}

// モジュール
class ProductModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(ProductRepositoryInterface::class)->to(MySQLProductRepository::class);
        $this->bind(CacheInterface::class)->to(RedisCache::class)->in(Singleton::class);
    }
}
```

### 2. 注文管理システム

```php
// 注文リポジトリ
interface OrderRepositoryInterface
{
    public function findById(int $id): ?Order;
    public function findByUserId(int $userId): array;
    public function save(Order $order): void;
    public function findByStatus(string $status): array;
}

class MySQLOrderRepository implements OrderRepositoryInterface
{
    public function __construct(private PDO $pdo) {}
    
    public function findById(int $id): ?Order
    {
        $stmt = $this->pdo->prepare('SELECT * FROM orders WHERE id = ?');
        $stmt->execute([$id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $data ? new Order($data) : null;
    }
    
    public function findByUserId(int $userId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC');
        $stmt->execute([$userId]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        return array_map(fn($data) => new Order($data), $results);
    }
    
    public function save(Order $order): void
    {
        if ($order->getId()) {
            $this->update($order);
        } else {
            $this->insert($order);
        }
    }
    
    public function findByStatus(string $status): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM orders WHERE status = ?');
        $stmt->execute([$status]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        return array_map(fn($data) => new Order($data), $results);
    }
    
    private function insert(Order $order): void
    {
        $stmt = $this->pdo->prepare('INSERT INTO orders (user_id, total, status) VALUES (?, ?, ?)');
        $stmt->execute([
            $order->getUserId(),
            $order->getTotal(),
            $order->getStatus()
        ]);
    }
    
    private function update(Order $order): void
    {
        $stmt = $this->pdo->prepare('UPDATE orders SET total = ?, status = ? WHERE id = ?');
        $stmt->execute([
            $order->getTotal(),
            $order->getStatus(),
            $order->getId()
        ]);
    }
}

// 注文サービス
class OrderService implements OrderServiceInterface
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private UserRepositoryInterface $userRepository,
        private PaymentGateway $paymentGateway,
        private EmailServiceInterface $emailService
    ) {}
    
    public function createOrder(int $userId, array $items): Order
    {
        $user = $this->userRepository->findById($userId);
        if (!$user) {
            throw new UserNotFoundException("User not found: {$userId}");
        }
        
        $order = new Order([
            'user_id' => $userId,
            'items' => $items,
            'total' => $this->calculateTotal($items),
            'status' => 'pending'
        ]);
        
        $this->orderRepository->save($order);
        return $order;
    }
    
    public function processPayment(Order $order, array $paymentData): bool
    {
        $result = $this->paymentGateway->processPayment($order->getTotal(), $paymentData);
        
        if ($result->isSuccess()) {
            $order->setStatus('paid');
            $order->setTransactionId($result->getTransactionId());
            $this->orderRepository->save($order);
            
            // 確認メールを送信
            $user = $this->userRepository->findById($order->getUserId());
            $this->emailService->sendOrderConfirmation($user, $order);
            
            return true;
        }
        
        return false;
    }
    
    private function calculateTotal(array $items): float
    {
        $total = 0;
        foreach ($items as $item) {
            $total += $item['price'] * $item['quantity'];
        }
        return $total;
    }
}

// 統合モジュール
class ECommerceModule extends AbstractModule
{
    protected function configure(): void
    {
        // リポジトリ
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(ProductRepositoryInterface::class)->to(MySQLProductRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        
        // サービス
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
        
        // 決済とキャッシュ（シングルトン）
        $this->bind(PaymentGateway::class)->to(StripePaymentGateway::class);
        $this->bind(CacheInterface::class)->to(RedisCache::class)->in(Singleton::class);
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

// 悪い：実装の詳細が漏れている
interface UserRepositoryInterface
{
    public function findByIdWithSQLQuery(int $id): ?User;
    public function saveToMySQLTable(User $user): void;
    public function findByEmailUsingIndex(string $email): ?User;
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