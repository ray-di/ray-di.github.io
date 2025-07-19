---
layout: docs-ja
title: モジュールの分割と結合
category: Manual
permalink: /manuals/1.0/ja/tutorial/02-basic-bindings/module-composition.html
---

# モジュールの分割と結合

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- モジュールの適切な分割方法と結合戦略
- 関心事の分離によるモジュール設計
- 環境別モジュールとテスト用モジュール
- モジュール間の依存関係管理
- 大規模アプリケーションでのモジュール構成

## モジュール分割の原則

### 1. 単一責任の原則

```php
// 悪い例：全てを一つのモジュールに詰め込む
class EverythingModule extends AbstractModule
{
    protected function configure(): void
    {
        // データベース関連
        $this->bind(PDO::class)->toProvider(PDOProvider::class);
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        
        // 決済関連
        $this->bind(PaymentGatewayInterface::class)->to(StripePaymentGateway::class);
        
        // メール関連
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
        
        // ログ関連
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
        
        // キャッシュ関連
        $this->bind(CacheInterface::class)->to(RedisCache::class);
    }
}

// 良い例：責任ごとに分割
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(PDO::class)->toProvider(PDOProvider::class)->in(Singleton::class);
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(ProductRepositoryInterface::class)->to(MySQLProductRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
    }
}

class PaymentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(PaymentGatewayInterface::class)->to(StripePaymentGateway::class);
        $this->bind(PaymentProcessorInterface::class)->to(PaymentProcessor::class);
        $this->bind(RefundServiceInterface::class)->to(RefundService::class);
    }
}

class NotificationModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
        $this->bind(SMSServiceInterface::class)->to(TwilioSMSService::class);
        $this->bind(PushNotificationInterface::class)->to(PushNotificationService::class);
    }
}
```

### 2. 関心事の分離

```php
// インフラストラクチャモジュール
class InfrastructureModule extends AbstractModule
{
    protected function configure(): void
    {
        // 永続化
        $this->bind(PDO::class)->toProvider(PDOProvider::class)->in(Singleton::class);
        
        // キャッシュ
        $this->bind(CacheInterface::class)->to(RedisCache::class)->in(Singleton::class);
        
        // ログ
        $this->bind(LoggerInterface::class)->to(FileLogger::class)->in(Singleton::class);
        
        // 設定
        $this->bind(ConfigInterface::class)->to(EnvConfig::class)->in(Singleton::class);
    }
}

// ドメインサービスモジュール
class DomainModule extends AbstractModule
{
    protected function configure(): void
    {
        // ドメインサービス
        $this->bind(UserServiceInterface::class)->to(UserService::class);
        $this->bind(ProductServiceInterface::class)->to(ProductService::class);
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        
        // ビジネスルール
        $this->bind(PricingServiceInterface::class)->to(PricingService::class);
        $this->bind(InventoryServiceInterface::class)->to(InventoryService::class);
    }
}

// アプリケーションサービスモジュール
class ApplicationModule extends AbstractModule
{
    protected function configure(): void
    {
        // アプリケーションサービス
        $this->bind(UserManagementInterface::class)->to(UserManagementService::class);
        $this->bind(OrderProcessingInterface::class)->to(OrderProcessingService::class);
        $this->bind(CatalogManagementInterface::class)->to(CatalogManagementService::class);
        
        // ワークフロー
        $this->bind(CheckoutWorkflowInterface::class)->to(CheckoutWorkflow::class);
        $this->bind(RefundWorkflowInterface::class)->to(RefundWorkflow::class);
    }
}

// ウェブ層モジュール
class WebModule extends AbstractModule
{
    protected function configure(): void
    {
        // コントローラー
        $this->bind(UserControllerInterface::class)->to(UserController::class);
        $this->bind(ProductControllerInterface::class)->to(ProductController::class);
        $this->bind(OrderControllerInterface::class)->to(OrderController::class);
        
        // ミドルウェア
        $this->bind(AuthenticationMiddleware::class);
        $this->bind(LoggingMiddleware::class);
        $this->bind(ValidationMiddleware::class);
    }
}
```

## 環境別モジュール

### 1. 環境固有の設定

```php
// 基本モジュール
abstract class BaseModule extends AbstractModule
{
    protected function configure(): void
    {
        // 共通の束縛
        $this->bind(UserServiceInterface::class)->to(UserService::class);
        $this->bind(ProductServiceInterface::class)->to(ProductService::class);
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
    }
    
    abstract protected function configureEnvironment(): void;
}

// 開発環境モジュール
class DevelopmentModule extends BaseModule
{
    protected function configure(): void
    {
        parent::configure();
        $this->configureEnvironment();
    }
    
    protected function configureEnvironment(): void
    {
        // 開発環境用の設定
        $this->bind(UserRepositoryInterface::class)->to(InMemoryUserRepository::class);
        $this->bind(ProductRepositoryInterface::class)->to(InMemoryProductRepository::class);
        $this->bind(EmailServiceInterface::class)->to(MockEmailService::class);
        $this->bind(PaymentGatewayInterface::class)->to(MockPaymentGateway::class);
        $this->bind(LoggerInterface::class)->to(ConsoleLogger::class);
        
        // デバッグ用サービス
        $this->bind(DebugServiceInterface::class)->to(DebugService::class);
        $this->bind(ProfilerInterface::class)->to(Profiler::class);
    }
}

// ステージング環境モジュール
class StagingModule extends BaseModule
{
    protected function configure(): void
    {
        parent::configure();
        $this->configureEnvironment();
    }
    
    protected function configureEnvironment(): void
    {
        // ステージング環境用の設定
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(ProductRepositoryInterface::class)->to(MySQLProductRepository::class);
        $this->bind(EmailServiceInterface::class)->to(TestEmailService::class);
        $this->bind(PaymentGatewayInterface::class)->to(SandboxPaymentGateway::class);
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
        
        // ステージング固有のサービス
        $this->bind(TestDataGeneratorInterface::class)->to(TestDataGenerator::class);
    }
}

// 本番環境モジュール
class ProductionModule extends BaseModule
{
    protected function configure(): void
    {
        parent::configure();
        $this->configureEnvironment();
    }
    
    protected function configureEnvironment(): void
    {
        // 本番環境用の設定
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(ProductRepositoryInterface::class)->to(MySQLProductRepository::class);
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
        $this->bind(PaymentGatewayInterface::class)->to(StripePaymentGateway::class);
        $this->bind(LoggerInterface::class)->to(SyslogLogger::class);
        
        // 本番環境固有のサービス
        $this->bind(MonitoringServiceInterface::class)->to(MonitoringService::class);
        $this->bind(AlertServiceInterface::class)->to(AlertService::class);
    }
}
```

### 2. 環境別設定の自動選択

```php
class EnvironmentModuleFactory
{
    public static function create(): AbstractModule
    {
        $environment = $_ENV['APP_ENV'] ?? 'development';
        
        return match($environment) {
            'development' => new DevelopmentModule(),
            'staging' => new StagingModule(),
            'production' => new ProductionModule(),
            'testing' => new TestingModule(),
            default => throw new InvalidArgumentException("Unknown environment: {$environment}")
        };
    }
}

// 使用例
class Application
{
    private Injector $injector;
    
    public function __construct()
    {
        $environmentModule = EnvironmentModuleFactory::create();
        $this->injector = new Injector($environmentModule);
    }
    
    public function run(): void
    {
        $userService = $this->injector->getInstance(UserServiceInterface::class);
        // アプリケーションロジック
    }
}
```

## モジュールの階層化と組み合わせ

### 1. 階層的なモジュール構造

```php
// レベル1: 基盤モジュール
class CoreModule extends AbstractModule
{
    protected function configure(): void
    {
        // 最も基本的な束縛
        $this->bind(LoggerInterface::class)->to(FileLogger::class)->in(Singleton::class);
        $this->bind(ConfigInterface::class)->to(EnvConfig::class)->in(Singleton::class);
        $this->bind(EventDispatcherInterface::class)->to(EventDispatcher::class)->in(Singleton::class);
    }
}

// レベル2: インフラストラクチャモジュール
class InfrastructureModule extends AbstractModule
{
    protected function configure(): void
    {
        // Coreモジュールをインストール
        $this->install(new CoreModule());
        
        // インフラ固有の束縛
        $this->bind(PDO::class)->toProvider(PDOProvider::class)->in(Singleton::class);
        $this->bind(CacheInterface::class)->to(RedisCache::class)->in(Singleton::class);
        $this->bind(QueueInterface::class)->to(RedisQueue::class)->in(Singleton::class);
    }
}

// レベル3: ドメインモジュール
class DomainModule extends AbstractModule
{
    protected function configure(): void
    {
        // Infrastructureモジュールをインストール
        $this->install(new InfrastructureModule());
        
        // リポジトリ
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(ProductRepositoryInterface::class)->to(MySQLProductRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        
        // ドメインサービス
        $this->bind(UserServiceInterface::class)->to(UserService::class);
        $this->bind(ProductServiceInterface::class)->to(ProductService::class);
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
    }
}

// レベル4: アプリケーションモジュール
class ApplicationModule extends AbstractModule
{
    protected function configure(): void
    {
        // Domainモジュールをインストール
        $this->install(new DomainModule());
        
        // アプリケーションサービス
        $this->bind(UserManagementInterface::class)->to(UserManagementService::class);
        $this->bind(OrderProcessingInterface::class)->to(OrderProcessingService::class);
        $this->bind(CatalogManagementInterface::class)->to(CatalogManagementService::class);
        
        // ワークフロー
        $this->bind(CheckoutWorkflowInterface::class)->to(CheckoutWorkflow::class);
    }
}

// レベル5: プレゼンテーションモジュール
class WebModule extends AbstractModule
{
    protected function configure(): void
    {
        // Applicationモジュールをインストール
        $this->install(new ApplicationModule());
        
        // Webコントローラー
        $this->bind(UserControllerInterface::class)->to(UserController::class);
        $this->bind(ProductControllerInterface::class)->to(ProductController::class);
        $this->bind(OrderControllerInterface::class)->to(OrderController::class);
        
        // ミドルウェア
        $this->bind(AuthenticationMiddleware::class);
        $this->bind(AuthorizationMiddleware::class);
        $this->bind(ValidationMiddleware::class);
    }
}
```

### 2. 機能別モジュール組み合わせ

```php
// ユーザー管理機能モジュール
class UserFeatureModule extends AbstractModule
{
    protected function configure(): void
    {
        // リポジトリ
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(UserPreferenceRepositoryInterface::class)->to(MySQLUserPreferenceRepository::class);
        
        // サービス
        $this->bind(UserServiceInterface::class)->to(UserService::class);
        $this->bind(AuthenticationServiceInterface::class)->to(AuthenticationService::class);
        $this->bind(UserPreferenceServiceInterface::class)->to(UserPreferenceService::class);
        
        // バリデーター
        $this->bind(UserValidatorInterface::class)->to(UserValidator::class);
        $this->bind(PasswordValidatorInterface::class)->to(PasswordValidator::class);
    }
}

// 商品管理機能モジュール
class ProductFeatureModule extends AbstractModule
{
    protected function configure(): void
    {
        // リポジトリ
        $this->bind(ProductRepositoryInterface::class)->to(MySQLProductRepository::class);
        $this->bind(CategoryRepositoryInterface::class)->to(MySQLCategoryRepository::class);
        $this->bind(InventoryRepositoryInterface::class)->to(MySQLInventoryRepository::class);
        
        // サービス
        $this->bind(ProductServiceInterface::class)->to(ProductService::class);
        $this->bind(CategoryServiceInterface::class)->to(CategoryService::class);
        $this->bind(InventoryServiceInterface::class)->to(InventoryService::class);
        $this->bind(PricingServiceInterface::class)->to(PricingService::class);
        
        // バリデーター
        $this->bind(ProductValidatorInterface::class)->to(ProductValidator::class);
    }
}

// 注文処理機能モジュール
class OrderFeatureModule extends AbstractModule
{
    protected function configure(): void
    {
        // リポジトリ
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(ShoppingCartRepositoryInterface::class)->to(RedisShoppingCartRepository::class);
        
        // サービス
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        $this->bind(ShoppingCartServiceInterface::class)->to(ShoppingCartService::class);
        $this->bind(CheckoutServiceInterface::class)->to(CheckoutService::class);
        
        // 決済
        $this->bind(PaymentGatewayInterface::class)->to(StripePaymentGateway::class);
        $this->bind(PaymentProcessorInterface::class)->to(PaymentProcessor::class);
    }
}

// E-commerceアプリケーション全体モジュール
class ECommerceAppModule extends AbstractModule
{
    protected function configure(): void
    {
        // 基盤モジュール
        $this->install(new CoreModule());
        $this->install(new InfrastructureModule());
        
        // 機能モジュール
        $this->install(new UserFeatureModule());
        $this->install(new ProductFeatureModule());
        $this->install(new OrderFeatureModule());
        
        // 横断的関心事
        $this->install(new SecurityModule());
        $this->install(new NotificationModule());
        $this->install(new MonitoringModule());
    }
}
```

## テスト用モジュール

### 1. 単体テスト用モジュール

```php
class UnitTestModule extends AbstractModule
{
    protected function configure(): void
    {
        // モックリポジトリ
        $this->bind(UserRepositoryInterface::class)->to(MockUserRepository::class);
        $this->bind(ProductRepositoryInterface::class)->to(MockProductRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MockOrderRepository::class);
        
        // モックサービス
        $this->bind(EmailServiceInterface::class)->to(MockEmailService::class);
        $this->bind(PaymentGatewayInterface::class)->to(MockPaymentGateway::class);
        $this->bind(LoggerInterface::class)->to(NullLogger::class);
        
        // テスト用ヘルパー
        $this->bind(TestDataBuilderInterface::class)->to(TestDataBuilder::class);
        $this->bind(AssertionHelperInterface::class)->to(AssertionHelper::class);
    }
}

class MockUserRepository implements UserRepositoryInterface
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
    
    // テスト用メソッド
    public function clear(): void
    {
        $this->users = [];
        $this->nextId = 1;
    }
    
    public function getUsers(): array
    {
        return $this->users;
    }
}
```

### 2. 統合テスト用モジュール

```php
class IntegrationTestModule extends AbstractModule
{
    protected function configure(): void
    {
        // 実際のリポジトリ（テストDB使用）
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(ProductRepositoryInterface::class)->to(MySQLProductRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        
        // テスト用データベース設定
        $this->bind(PDO::class)->toProvider(TestDatabaseProvider::class)->in(Singleton::class);
        
        // モック外部サービス
        $this->bind(EmailServiceInterface::class)->to(MockEmailService::class);
        $this->bind(PaymentGatewayInterface::class)->to(MockPaymentGateway::class);
        
        // テスト用ログ
        $this->bind(LoggerInterface::class)->to(TestLogger::class);
        
        // テスト用ヘルパー
        $this->bind(DatabaseCleanerInterface::class)->to(DatabaseCleaner::class);
        $this->bind(TestFixtureLoaderInterface::class)->to(TestFixtureLoader::class);
    }
}

class TestDatabaseProvider implements ProviderInterface
{
    public function get(): PDO
    {
        $dsn = 'mysql:host=localhost;dbname=test_ecommerce';
        $pdo = new PDO($dsn, 'test_user', 'test_password', [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
        
        return $pdo;
    }
}
```

## 動的モジュール構成

### 1. 設定ベースの動的モジュール

```php
class ConfigurableModule extends AbstractModule
{
    public function __construct(
        private array $config
    ) {}
    
    protected function configure(): void
    {
        // データベース設定
        if ($this->config['database']['enabled']) {
            $this->configureDatabaseBindings();
        }
        
        // キャッシュ設定
        if ($this->config['cache']['enabled']) {
            $this->configureCacheBindings();
        }
        
        // 決済ゲートウェイ設定
        $this->configurePaymentGateways();
        
        // 通知設定
        $this->configureNotifications();
    }
    
    private function configureDatabaseBindings(): void
    {
        $driver = $this->config['database']['driver'];
        
        match($driver) {
            'mysql' => $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class),
            'postgresql' => $this->bind(UserRepositoryInterface::class)->to(PostgreSQLUserRepository::class),
            'sqlite' => $this->bind(UserRepositoryInterface::class)->to(SQLiteUserRepository::class),
            default => throw new InvalidArgumentException("Unsupported database driver: {$driver}")
        };
    }
    
    private function configureCacheBindings(): void
    {
        $driver = $this->config['cache']['driver'];
        
        match($driver) {
            'redis' => $this->bind(CacheInterface::class)->to(RedisCache::class)->in(Singleton::class),
            'memcached' => $this->bind(CacheInterface::class)->to(MemcachedCache::class)->in(Singleton::class),
            'file' => $this->bind(CacheInterface::class)->to(FileCache::class)->in(Singleton::class),
            default => $this->bind(CacheInterface::class)->to(NullCache::class)->in(Singleton::class)
        };
    }
    
    private function configurePaymentGateways(): void
    {
        $gateways = $this->config['payment']['gateways'];
        
        foreach ($gateways as $gateway) {
            if ($gateway['enabled']) {
                match($gateway['name']) {
                    'stripe' => $this->bind(PaymentGatewayInterface::class)->to(StripePaymentGateway::class),
                    'paypal' => $this->bind(PaymentGatewayInterface::class)->to(PayPalPaymentGateway::class),
                    'square' => $this->bind(PaymentGatewayInterface::class)->to(SquarePaymentGateway::class),
                };
            }
        }
    }
    
    private function configureNotifications(): void
    {
        $channels = $this->config['notifications']['channels'];
        
        if ($channels['email']['enabled']) {
            $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
        }
        
        if ($channels['sms']['enabled']) {
            $this->bind(SMSServiceInterface::class)->to(TwilioSMSService::class);
        }
        
        if ($channels['push']['enabled']) {
            $this->bind(PushNotificationInterface::class)->to(FirebasePushNotification::class);
        }
    }
}

// 設定ファイル（config.php）
return [
    'database' => [
        'enabled' => true,
        'driver' => 'mysql',
        'host' => 'localhost',
        'database' => 'ecommerce',
    ],
    'cache' => [
        'enabled' => true,
        'driver' => 'redis',
        'host' => 'localhost',
    ],
    'payment' => [
        'gateways' => [
            ['name' => 'stripe', 'enabled' => true],
            ['name' => 'paypal', 'enabled' => false],
            ['name' => 'square', 'enabled' => true],
        ]
    ],
    'notifications' => [
        'channels' => [
            'email' => ['enabled' => true],
            'sms' => ['enabled' => false],
            'push' => ['enabled' => true],
        ]
    ]
];

// 使用例
$config = require 'config.php';
$module = new ConfigurableModule($config);
$injector = new Injector($module);
```

### 2. プラグイン対応モジュール

```php
class PluginModule extends AbstractModule
{
    private array $plugins = [];
    
    public function addPlugin(PluginInterface $plugin): void
    {
        $this->plugins[] = $plugin;
    }
    
    protected function configure(): void
    {
        // 各プラグインのモジュールをインストール
        foreach ($this->plugins as $plugin) {
            $pluginModule = $plugin->getModule();
            if ($pluginModule) {
                $this->install($pluginModule);
            }
        }
        
        // プラグインレジストリ
        $this->bind(PluginRegistryInterface::class)->to(PluginRegistry::class)->in(Singleton::class);
    }
}

interface PluginInterface
{
    public function getName(): string;
    public function getVersion(): string;
    public function getModule(): ?AbstractModule;
    public function isEnabled(): bool;
}

class PaymentPlugin implements PluginInterface
{
    public function getName(): string
    {
        return 'Advanced Payment Gateway';
    }
    
    public function getVersion(): string
    {
        return '1.0.0';
    }
    
    public function getModule(): ?AbstractModule
    {
        return new PaymentPluginModule();
    }
    
    public function isEnabled(): bool
    {
        return $_ENV['PAYMENT_PLUGIN_ENABLED'] === 'true';
    }
}

class PaymentPluginModule extends AbstractModule
{
    protected function configure(): void
    {
        // プラグイン固有の束縛
        $this->bind(AdvancedPaymentInterface::class)->to(AdvancedPaymentGateway::class);
        $this->bind(FraudDetectionInterface::class)->to(FraudDetectionService::class);
    }
}
```

## ベストプラクティス

### 1. モジュール命名規則

```php
// 良い：目的が明確
class UserManagementModule extends AbstractModule {}
class PaymentProcessingModule extends AbstractModule {}
class NotificationModule extends AbstractModule {}

// 悪い：曖昧な命名
class Module1 extends AbstractModule {}
class UtilModule extends AbstractModule {}
class CommonModule extends AbstractModule {}
```

### 2. 循環依存の回避

```php
// 悪い例：循環依存
class ModuleA extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new ModuleB()); // ModuleBに依存
        // ModuleA固有の束縛
    }
}

class ModuleB extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new ModuleA()); // ModuleAに依存（循環！）
        // ModuleB固有の束縛
    }
}

// 良い例：共通モジュールを抽出
class CommonModule extends AbstractModule
{
    protected function configure(): void
    {
        // 共通の束縛
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
        $this->bind(ConfigInterface::class)->to(EnvConfig::class);
    }
}

class ModuleA extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new CommonModule());
        // ModuleA固有の束縛
    }
}

class ModuleB extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new CommonModule());
        // ModuleB固有の束縛
    }
}
```

### 3. 設定の外部化

```php
class ConfigurableApplicationModule extends AbstractModule
{
    public function __construct(
        private ConfigInterface $config
    ) {}
    
    protected function configure(): void
    {
        // 環境に応じたモジュールインストール
        if ($this->config->isEnabled('database')) {
            $this->install(new DatabaseModule($this->config->getSection('database')));
        }
        
        if ($this->config->isEnabled('cache')) {
            $this->install(new CacheModule($this->config->getSection('cache')));
        }
        
        if ($this->config->isEnabled('payment')) {
            $this->install(new PaymentModule($this->config->getSection('payment')));
        }
    }
}

// 設定インターフェース
interface ConfigInterface
{
    public function isEnabled(string $section): bool;
    public function getSection(string $section): array;
    public function get(string $key, mixed $default = null): mixed;
}
```

## 次のステップ

モジュールの分割と結合の方法を理解したので、次に進む準備が整いました。

1. **束縛DSLの学習**: より表現力豊かな設定方法
2. **スコープとライフサイクルの探索**: オブジェクトの生存期間管理
3. **実世界の例での練習**: 複雑なアプリケーションでの活用方法

**続きは:** [束縛DSL](binding-dsl.html)

## 重要なポイント

- **単一責任の原則**を守ってモジュールを分割
- **関心事の分離**により保守性を向上
- **環境別モジュール**で設定を分離
- **階層化**により複雑性を管理
- **動的構成**で柔軟性を実現
- **循環依存を回避**して健全な依存関係を維持

---

適切なモジュール分割と結合は、大規模なアプリケーションの保守性、テスト可能性、拡張性を大幅に向上させます。Ray.Diのモジュールシステムを活用して、クリーンで管理しやすいアーキテクチャを構築しましょう。