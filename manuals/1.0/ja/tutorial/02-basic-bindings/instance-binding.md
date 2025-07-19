---
layout: docs-ja
title: インスタンスバインディング
category: Manual
permalink: /manuals/1.0/ja/tutorial/02-basic-bindings/instance-binding.html
---

# インスタンスバインディング

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- インスタンスバインディングとは何か、いつ使用するか
- 設定オブジェクトとシングルトンインスタンスの注入方法
- イミュータブルオブジェクトとファクトリーオブジェクトの活用
- 実践的なE-commerceアプリケーションでの使用例
- インスタンスバインディングのベストプラクティス

## インスタンスバインディングとは

**インスタンスバインディング**は、すでに作成されたオブジェクトのインスタンスを直接DIコンテナにバインドする方法です。これにより、設定オブジェクト、シングルトンインスタンス、またはファクトリーオブジェクトなどの事前作成されたオブジェクトを注入できます。

### 基本的な使用方法

```php
use Ray\Di\AbstractModule;

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // 設定オブジェクトのインスタンスバインディング
        $config = new AppConfig([
            'database_host' => 'localhost',
            'database_port' => 3306,
            'debug_mode' => false
        ]);
        
        $this->bind(AppConfig::class)->toInstance($config);
        
        // 事前作成されたサービスのインスタンスバインディング
        $logger = new FileLogger('/var/log/app.log');
        $this->bind(LoggerInterface::class)->toInstance($logger);
    }
}
```

## 設定オブジェクトでの使用

### 1. アプリケーション設定

```php
class AppConfig
{
    public function __construct(private array $config) {}
    
    public function getDatabaseHost(): string
    {
        return $this->config['database_host'];
    }
    
    public function getDatabasePort(): int
    {
        return $this->config['database_port'];
    }
    
    public function isDebugMode(): bool
    {
        return $this->config['debug_mode'] ?? false;
    }
    
    public function getApiKey(): string
    {
        return $this->config['api_key'];
    }
}

class DatabaseService
{
    public function __construct(private AppConfig $config) {}
    
    public function connect(): PDO
    {
        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=app',
            $this->config->getDatabaseHost(),
            $this->config->getDatabasePort()
        );
        
        return new PDO($dsn, 'username', 'password');
    }
}

// モジュールでの設定
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // 環境に応じた設定を作成
        $config = new AppConfig([
            'database_host' => $_ENV['DB_HOST'] ?? 'localhost',
            'database_port' => (int)($_ENV['DB_PORT'] ?? 3306),
            'debug_mode' => $_ENV['APP_DEBUG'] === 'true',
            'api_key' => $_ENV['API_KEY'] ?? ''
        ]);
        
        $this->bind(AppConfig::class)->toInstance($config);
    }
}
```

### 2. 複数の設定オブジェクト

```php
class DatabaseConfig
{
    public function __construct(
        private string $host,
        private int $port,
        private string $database,
        private string $username,
        private string $password
    ) {}
    
    public function getDsn(): string
    {
        return "mysql:host={$this->host};port={$this->port};dbname={$this->database}";
    }
    
    public function getUsername(): string { return $this->username; }
    public function getPassword(): string { return $this->password; }
}

class EmailConfig
{
    public function __construct(
        private string $smtpHost,
        private int $smtpPort,
        private string $username,
        private string $password
    ) {}
    
    public function getSmtpHost(): string { return $this->smtpHost; }
    public function getSmtpPort(): int { return $this->smtpPort; }
    public function getUsername(): string { return $this->username; }
    public function getPassword(): string { return $this->password; }
}

class ConfigModule extends AbstractModule
{
    protected function configure(): void
    {
        // データベース設定
        $dbConfig = new DatabaseConfig(
            $_ENV['DB_HOST'] ?? 'localhost',
            (int)($_ENV['DB_PORT'] ?? 3306),
            $_ENV['DB_NAME'] ?? 'app',
            $_ENV['DB_USER'] ?? 'root',
            $_ENV['DB_PASS'] ?? ''
        );
        
        // メール設定
        $emailConfig = new EmailConfig(
            $_ENV['SMTP_HOST'] ?? 'localhost',
            (int)($_ENV['SMTP_PORT'] ?? 587),
            $_ENV['SMTP_USER'] ?? '',
            $_ENV['SMTP_PASS'] ?? ''
        );
        
        $this->bind(DatabaseConfig::class)->toInstance($dbConfig);
        $this->bind(EmailConfig::class)->toInstance($emailConfig);
    }
}
```

## ファクトリーオブジェクトでの使用

### 1. 複雑な作成ロジックを持つファクトリー

```php
class PaymentGatewayFactory
{
    public function __construct(
        private string $defaultProvider = 'stripe',
        private array $providers = []
    ) {}
    
    public function create(string $provider = null): PaymentGatewayInterface
    {
        $provider = $provider ?? $this->defaultProvider;
        
        if (!isset($this->providers[$provider])) {
            throw new InvalidArgumentException("Unknown payment provider: {$provider}");
        }
        
        return $this->providers[$provider];
    }
}

class PaymentModule extends AbstractModule
{
    protected function configure(): void
    {
        // 事前に設定されたファクトリーを作成
        $paymentFactory = new PaymentGatewayFactory('stripe', [
            'stripe' => new StripePaymentGateway($_ENV['STRIPE_SECRET_KEY']),
            'paypal' => new PayPalPaymentGateway($_ENV['PAYPAL_CLIENT_ID']),
            'square' => new SquarePaymentGateway($_ENV['SQUARE_ACCESS_TOKEN'])
        ]);
        
        $this->bind(PaymentGatewayFactory::class)->toInstance($paymentFactory);
    }
}

class OrderService
{
    public function __construct(
        private PaymentGatewayFactory $paymentFactory
    ) {}
    
    public function processOrder(Order $order): void
    {
        // 注文に応じて適切な決済ゲートウェイを選択
        $gateway = $this->paymentFactory->create($order->getPaymentMethod());
        $gateway->processPayment($order->getTotal());
    }
}
```

### 2. 設定可能なサービスファクトリー

```php
class CacheFactory
{
    public function __construct(
        private string $defaultDriver = 'redis',
        private array $configs = []
    ) {}
    
    public function create(string $driver = null): CacheInterface
    {
        $driver = $driver ?? $this->defaultDriver;
        $config = $this->configs[$driver] ?? [];
        
        return match($driver) {
            'redis' => new RedisCache($config),
            'memcached' => new MemcachedCache($config),
            'file' => new FileCache($config),
            default => throw new InvalidArgumentException("Unknown cache driver: {$driver}")
        };
    }
}

class CacheModule extends AbstractModule
{
    protected function configure(): void
    {
        $cacheFactory = new CacheFactory('redis', [
            'redis' => [
                'host' => $_ENV['REDIS_HOST'] ?? 'localhost',
                'port' => (int)($_ENV['REDIS_PORT'] ?? 6379),
                'password' => $_ENV['REDIS_PASSWORD'] ?? null
            ],
            'memcached' => [
                'host' => $_ENV['MEMCACHED_HOST'] ?? 'localhost',
                'port' => (int)($_ENV['MEMCACHED_PORT'] ?? 11211)
            ],
            'file' => [
                'path' => $_ENV['CACHE_PATH'] ?? '/tmp/cache'
            ]
        ]);
        
        $this->bind(CacheFactory::class)->toInstance($cacheFactory);
    }
}
```

## 環境固有の設定

### 1. 開発環境用の設定

```php
class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        // 開発環境用の設定
        $config = new AppConfig([
            'database_host' => 'localhost',
            'database_port' => 3306,
            'debug_mode' => true,
            'log_level' => 'DEBUG',
            'cache_driver' => 'array'
        ]);
        
        // 開発用のモックサービス
        $mockPaymentGateway = new MockPaymentGateway();
        $mockEmailService = new MockEmailService();
        
        $this->bind(AppConfig::class)->toInstance($config);
        $this->bind(PaymentGatewayInterface::class)->toInstance($mockPaymentGateway);
        $this->bind(EmailServiceInterface::class)->toInstance($mockEmailService);
    }
}
```

### 2. 本番環境用の設定

```php
class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        // 本番環境用の設定
        $config = new AppConfig([
            'database_host' => $_ENV['DB_HOST'],
            'database_port' => (int)$_ENV['DB_PORT'],
            'debug_mode' => false,
            'log_level' => 'ERROR',
            'cache_driver' => 'redis'
        ]);
        
        // 本番用のサービス
        $stripeGateway = new StripePaymentGateway($_ENV['STRIPE_SECRET_KEY']);
        $sendgridService = new SendGridEmailService($_ENV['SENDGRID_API_KEY']);
        
        $this->bind(AppConfig::class)->toInstance($config);
        $this->bind(PaymentGatewayInterface::class)->toInstance($stripeGateway);
        $this->bind(EmailServiceInterface::class)->toInstance($sendgridService);
    }
}
```

## E-commerceプラットフォームでの実践例

### 1. ショッピングカート設定

```php
class ShopConfig
{
    public function __construct(
        private string $currency = 'USD',
        private float $taxRate = 0.08,
        private int $maxItemsPerCart = 100,
        private array $allowedCountries = ['US', 'CA', 'JP'],
        private array $shippingRates = []
    ) {}
    
    public function getCurrency(): string { return $this->currency; }
    public function getTaxRate(): float { return $this->taxRate; }
    public function getMaxItemsPerCart(): int { return $this->maxItemsPerCart; }
    public function getAllowedCountries(): array { return $this->allowedCountries; }
    public function getShippingRates(): array { return $this->shippingRates; }
}

class ShopModule extends AbstractModule
{
    protected function configure(): void
    {
        $shopConfig = new ShopConfig(
            currency: $_ENV['SHOP_CURRENCY'] ?? 'USD',
            taxRate: (float)($_ENV['TAX_RATE'] ?? 0.08),
            maxItemsPerCart: (int)($_ENV['MAX_CART_ITEMS'] ?? 100),
            allowedCountries: explode(',', $_ENV['ALLOWED_COUNTRIES'] ?? 'US,CA,JP'),
            shippingRates: [
                'standard' => 5.99,
                'express' => 12.99,
                'overnight' => 24.99
            ]
        );
        
        $this->bind(ShopConfig::class)->toInstance($shopConfig);
    }
}

class CartService
{
    public function __construct(
        private ShopConfig $config
    ) {}
    
    public function addItem(Cart $cart, Product $product, int $quantity): void
    {
        $currentItemCount = $cart->getTotalItemCount();
        
        if ($currentItemCount + $quantity > $this->config->getMaxItemsPerCart()) {
            throw new CartLimitExceededException();
        }
        
        $cart->addItem($product, $quantity);
    }
    
    public function calculateTotal(Cart $cart): float
    {
        $subtotal = $cart->getSubtotal();
        $tax = $subtotal * $this->config->getTaxRate();
        return $subtotal + $tax;
    }
}
```

### 2. 決済システム設定

```php
class PaymentProviderRegistry
{
    public function __construct(
        private array $providers = [],
        private string $defaultProvider = 'stripe'
    ) {}
    
    public function getProvider(string $name = null): PaymentGatewayInterface
    {
        $name = $name ?? $this->defaultProvider;
        
        if (!isset($this->providers[$name])) {
            throw new InvalidArgumentException("Payment provider '{$name}' not found");
        }
        
        return $this->providers[$name];
    }
    
    public function getAvailableProviders(): array
    {
        return array_keys($this->providers);
    }
}

class PaymentModule extends AbstractModule
{
    protected function configure(): void
    {
        $paymentRegistry = new PaymentProviderRegistry([
            'stripe' => new StripePaymentGateway([
                'secret_key' => $_ENV['STRIPE_SECRET_KEY'],
                'publishable_key' => $_ENV['STRIPE_PUBLISHABLE_KEY']
            ]),
            'paypal' => new PayPalPaymentGateway([
                'client_id' => $_ENV['PAYPAL_CLIENT_ID'],
                'client_secret' => $_ENV['PAYPAL_CLIENT_SECRET'],
                'sandbox' => $_ENV['PAYPAL_SANDBOX'] === 'true'
            ]),
            'square' => new SquarePaymentGateway([
                'access_token' => $_ENV['SQUARE_ACCESS_TOKEN'],
                'location_id' => $_ENV['SQUARE_LOCATION_ID']
            ])
        ], 'stripe');
        
        $this->bind(PaymentProviderRegistry::class)->toInstance($paymentRegistry);
    }
}
```

## イミュータブルオブジェクトの活用

### 1. 値オブジェクトのバインディング

```php
class Money
{
    public function __construct(
        private float $amount,
        private string $currency
    ) {}
    
    public function getAmount(): float { return $this->amount; }
    public function getCurrency(): string { return $this->currency; }
    
    public function add(Money $other): Money
    {
        if ($this->currency !== $other->currency) {
            throw new InvalidArgumentException('Currency mismatch');
        }
        
        return new Money($this->amount + $other->amount, $this->currency);
    }
}

class ShippingRates
{
    public function __construct(private array $rates) {}
    
    public function getRate(string $method): Money
    {
        if (!isset($this->rates[$method])) {
            throw new InvalidArgumentException("Unknown shipping method: {$method}");
        }
        
        return $this->rates[$method];
    }
}

class ShippingModule extends AbstractModule
{
    protected function configure(): void
    {
        $shippingRates = new ShippingRates([
            'standard' => new Money(5.99, 'USD'),
            'express' => new Money(12.99, 'USD'),
            'overnight' => new Money(24.99, 'USD')
        ]);
        
        $this->bind(ShippingRates::class)->toInstance($shippingRates);
    }
}
```

### 2. 設定の階層化

```php
class DatabaseConfig
{
    public function __construct(
        private string $host,
        private int $port,
        private string $database,
        private string $username,
        private string $password,
        private array $options = []
    ) {}
    
    public function getDsn(): string
    {
        return "mysql:host={$this->host};port={$this->port};dbname={$this->database}";
    }
    
    public function getCredentials(): array
    {
        return [$this->username, $this->password];
    }
    
    public function getOptions(): array
    {
        return $this->options;
    }
}

class CacheConfig
{
    public function __construct(
        private string $driver,
        private array $config
    ) {}
    
    public function getDriver(): string { return $this->driver; }
    public function getConfig(): array { return $this->config; }
}

class InfrastructureConfig
{
    public function __construct(
        private DatabaseConfig $database,
        private CacheConfig $cache
    ) {}
    
    public function getDatabase(): DatabaseConfig { return $this->database; }
    public function getCache(): CacheConfig { return $this->cache; }
}

class InfrastructureModule extends AbstractModule
{
    protected function configure(): void
    {
        $dbConfig = new DatabaseConfig(
            $_ENV['DB_HOST'] ?? 'localhost',
            (int)($_ENV['DB_PORT'] ?? 3306),
            $_ENV['DB_NAME'] ?? 'app',
            $_ENV['DB_USER'] ?? 'root',
            $_ENV['DB_PASS'] ?? '',
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
            ]
        );
        
        $cacheConfig = new CacheConfig(
            $_ENV['CACHE_DRIVER'] ?? 'redis',
            [
                'host' => $_ENV['REDIS_HOST'] ?? 'localhost',
                'port' => (int)($_ENV['REDIS_PORT'] ?? 6379),
                'password' => $_ENV['REDIS_PASSWORD'] ?? null
            ]
        );
        
        $infrastructureConfig = new InfrastructureConfig($dbConfig, $cacheConfig);
        
        $this->bind(InfrastructureConfig::class)->toInstance($infrastructureConfig);
    }
}
```

## ベストプラクティス

### 1. 適切な使用場面

```php
// 良い：設定オブジェクトや定数値
class GoodModule extends AbstractModule
{
    protected function configure(): void
    {
        // 設定オブジェクト
        $config = new AppConfig($this->loadConfig());
        $this->bind(AppConfig::class)->toInstance($config);
        
        // 定数値
        $apiKey = $_ENV['API_KEY'];
        $this->bind()->annotatedWith('api_key')->toInstance($apiKey);
        
        // 事前作成されたファクトリー
        $factory = new ServiceFactory($config);
        $this->bind(ServiceFactory::class)->toInstance($factory);
    }
}

// 悪い：複雑な状態を持つオブジェクト
class BadModule extends AbstractModule
{
    protected function configure(): void
    {
        // 悪い：状態を持つサービスのインスタンスバインディング
        $userService = new UserService();
        $userService->setCurrentUser($someUser); // 状態を持つ
        $this->bind(UserService::class)->toInstance($userService);
    }
}
```

### 2. パフォーマンス考慮

```php
class OptimizedModule extends AbstractModule
{
    protected function configure(): void
    {
        // 良い：重い処理を事前に実行
        $expensiveData = $this->loadExpensiveData();
        $this->bind(ExpensiveData::class)->toInstance($expensiveData);
        
        // 良い：設定の事前バリデーション
        $config = new AppConfig($_ENV);
        $config->validate(); // 早期に問題を発見
        $this->bind(AppConfig::class)->toInstance($config);
    }
    
    private function loadExpensiveData(): ExpensiveData
    {
        // 重い処理を一度だけ実行
        return new ExpensiveData(/* データ */);
    }
}
```

### 3. テスト対応

```php
class TestModule extends AbstractModule
{
    protected function configure(): void
    {
        // テスト用の設定
        $testConfig = new AppConfig([
            'database_host' => 'localhost',
            'database_port' => 3306,
            'debug_mode' => true,
            'test_mode' => true
        ]);
        
        // テスト用のモックサービス
        $mockEmailService = new MockEmailService();
        $mockPaymentGateway = new MockPaymentGateway();
        
        $this->bind(AppConfig::class)->toInstance($testConfig);
        $this->bind(EmailServiceInterface::class)->toInstance($mockEmailService);
        $this->bind(PaymentGatewayInterface::class)->toInstance($mockPaymentGateway);
    }
}
```

## 次のステップ

インスタンスバインディングの使用方法を理解したので、次に進む準備が整いました。

1. **クラスバインディングの学習**: インターフェースから実装へのバインディング
2. **プロバイダーバインディングの探索**: 複雑な作成ロジックの実装
3. **実世界の例での練習**: 複合的なバインディングの使用方法

**続きは:** [クラスバインディング](class-binding.html)

## 重要なポイント

- **インスタンスバインディング**は事前作成されたオブジェクトを直接注入
- **設定オブジェクト**やファクトリーオブジェクトに最適
- **イミュータブルオブジェクト**の使用を推奨
- **環境固有の設定**を簡単に切り替え可能
- **重い処理**を事前に実行してパフォーマンスを向上
- **テスト**ではモックオブジェクトを簡単に注入

---

インスタンスバインディングは、設定やファクトリーオブジェクトの管理において非常に有用です。適切に使用することで、柔軟で保守しやすいアプリケーションを構築できます。