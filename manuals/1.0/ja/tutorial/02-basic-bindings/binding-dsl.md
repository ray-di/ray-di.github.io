---
layout: docs-ja
title: 束縛DSL
category: Manual
permalink: /manuals/1.0/ja/tutorial/02-basic-bindings/binding-dsl.html
---

# 束縛DSL

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diの表現力豊かな束縛DSL（Domain Specific Language）
- 流暢な（fluent）APIによる直感的な設定方法
- 複雑な束縛パターンの組み合わせ
- 条件付き束縛とアノテーション
- メソッドチェーンによる可読性の向上

## DSLの基本概念

### 1. 流暢なAPI（Fluent API）

```php
// 基本的な束縛DSL
class ShopModule extends AbstractModule
{
    protected function configure(): void
    {
        // 基本的な束縛
        $this->bind(UserRepositoryInterface::class)
            ->to(MySQLUserRepository::class);
        
        // スコープ付き束縛
        $this->bind(DatabaseConnectionInterface::class)
            ->to(MySQLConnection::class)
            ->in(Singleton::class);
        
        // プロバイダー束縛
        $this->bind(PDO::class)
            ->toProvider(DatabaseProvider::class)
            ->in(Singleton::class);
        
        // インスタンス束縛
        $this->bind(ConfigInterface::class)
            ->toInstance(new Config(['debug' => true]));
        
        // アノテーション付き束縛
        $this->bind(LoggerInterface::class)
            ->annotatedWith('error')
            ->to(ErrorLogger::class);
        
        // 名前付き束縛
        $this->bind(CacheInterface::class)
            ->annotatedWith('user')
            ->to(UserCache::class)
            ->in(Singleton::class);
    }
}
```

### 2. DSLの構文構造

```php
// DSLの基本パターン
$this->bind(Interface::class)        // 束縛の開始
    ->to(Implementation::class)      // 実装クラスの指定
    ->in(Scope::class)              // スコープの指定
    ->annotatedWith('qualifier');   // 修飾子の指定

// 複数の修飾子を組み合わせ
$this->bind(PaymentGatewayInterface::class)
    ->annotatedWith('stripe')
    ->to(StripePaymentGateway::class)
    ->in(Singleton::class);

$this->bind(PaymentGatewayInterface::class)
    ->annotatedWith('paypal')
    ->to(PayPalPaymentGateway::class)
    ->in(Singleton::class);
```

## 高度な束縛パターン

### 1. 条件付き束縛

```php
class ConditionalModule extends AbstractModule
{
    protected function configure(): void
    {
        // 環境に応じた束縛
        if ($_ENV['APP_ENV'] === 'production') {
            $this->bind(LoggerInterface::class)
                ->to(SyslogLogger::class)
                ->in(Singleton::class);
        } else {
            $this->bind(LoggerInterface::class)
                ->to(FileLogger::class)
                ->in(Singleton::class);
        }
        
        // 設定に応じた束縛
        if ($_ENV['CACHE_ENABLED'] === 'true') {
            $this->bind(CacheInterface::class)
                ->to(RedisCache::class)
                ->in(Singleton::class);
        } else {
            $this->bind(CacheInterface::class)
                ->to(NullCache::class)
                ->in(Singleton::class);
        }
        
        // 機能フラグに応じた束縛
        if ($this->isFeatureEnabled('advanced_search')) {
            $this->bind(SearchEngineInterface::class)
                ->to(ElasticsearchEngine::class);
        } else {
            $this->bind(SearchEngineInterface::class)
                ->to(DatabaseSearchEngine::class);
        }
    }
    
    private function isFeatureEnabled(string $feature): bool
    {
        return $_ENV["FEATURE_{$feature}"] ?? false;
    }
}
```

### 2. 複雑なプロバイダー束縛

```php
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        // 設定ベースのデータベース接続
        $this->bind(PDO::class)
            ->annotatedWith('primary')
            ->toProvider(function() {
                $config = $_ENV;
                $dsn = "mysql:host={$config['DB_HOST']};dbname={$config['DB_NAME']}";
                return new PDO($dsn, $config['DB_USER'], $config['DB_PASS'], [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                ]);
            })
            ->in(Singleton::class);
        
        // レプリケーション用の読み取り専用接続
        $this->bind(PDO::class)
            ->annotatedWith('readonly')
            ->toProvider(function() {
                $config = $_ENV;
                $dsn = "mysql:host={$config['DB_READ_HOST']};dbname={$config['DB_NAME']}";
                return new PDO($dsn, $config['DB_USER'], $config['DB_PASS'], [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                ]);
            })
            ->in(Singleton::class);
        
        // ライトリポジトリ
        $this->bind(UserRepositoryInterface::class)
            ->annotatedWith('write')
            ->to(WriteUserRepository::class);
        
        // リードリポジトリ
        $this->bind(UserRepositoryInterface::class)
            ->annotatedWith('read')
            ->to(ReadUserRepository::class);
    }
}

class WriteUserRepository implements UserRepositoryInterface
{
    public function __construct(
        #[Named('primary')] private PDO $pdo
    ) {}
    
    // 書き込み操作
}

class ReadUserRepository implements UserRepositoryInterface
{
    public function __construct(
        #[Named('readonly')] private PDO $pdo
    ) {}
    
    // 読み取り操作
}
```

### 3. マルチ束縛のDSL

```php
class EventModule extends AbstractModule
{
    protected function configure(): void
    {
        // イベントリスナーのマルチ束縛
        $this->bind(EventListenerInterface::class)
            ->annotatedWith('order')
            ->to(OrderEmailNotificationListener::class);
        
        $this->bind(EventListenerInterface::class)
            ->annotatedWith('order')
            ->to(OrderInventoryUpdateListener::class);
        
        $this->bind(EventListenerInterface::class)
            ->annotatedWith('order')
            ->to(OrderAuditLogListener::class);
        
        // ユーザーイベントリスナー
        $this->bind(EventListenerInterface::class)
            ->annotatedWith('user')
            ->to(UserWelcomeEmailListener::class);
        
        $this->bind(EventListenerInterface::class)
            ->annotatedWith('user')
            ->to(UserAnalyticsListener::class);
        
        // グローバルリスナー
        $this->bind(EventListenerInterface::class)
            ->to(GlobalAuditListener::class);
        
        $this->bind(EventListenerInterface::class)
            ->to(GlobalMetricsListener::class);
    }
}

class EventDispatcher
{
    public function __construct(
        #[Set, Named('order')] private array $orderListeners,
        #[Set, Named('user')] private array $userListeners,
        #[Set] private array $globalListeners
    ) {}
    
    public function dispatchOrderEvent(OrderEvent $event): void
    {
        // 注文固有のリスナー
        foreach ($this->orderListeners as $listener) {
            $listener->handle($event);
        }
        
        // グローバルリスナー
        foreach ($this->globalListeners as $listener) {
            $listener->handle($event);
        }
    }
    
    public function dispatchUserEvent(UserEvent $event): void
    {
        // ユーザー固有のリスナー
        foreach ($this->userListeners as $listener) {
            $listener->handle($event);
        }
        
        // グローバルリスナー
        foreach ($this->globalListeners as $listener) {
            $listener->handle($event);
        }
    }
}
```

## アノテーションとカスタム修飾子

### 1. カスタムアノテーション

```php
// カスタムアノテーションの定義
#[Attribute]
class Database
{
    public function __construct(
        public readonly string $type
    ) {}
}

#[Attribute]
class Environment
{
    public function __construct(
        public readonly string $env
    ) {}
}

#[Attribute]
class Priority
{
    public function __construct(
        public readonly int $level
    ) {}
}

// カスタムアノテーションを使った束縛
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        // 主データベース
        $this->bind(PDO::class)
            ->annotatedWith(Database::class, 'primary')
            ->toProvider(PrimaryDatabaseProvider::class)
            ->in(Singleton::class);
        
        // セカンダリデータベース
        $this->bind(PDO::class)
            ->annotatedWith(Database::class, 'secondary')
            ->toProvider(SecondaryDatabaseProvider::class)
            ->in(Singleton::class);
        
        // 環境別ログ設定
        $this->bind(LoggerInterface::class)
            ->annotatedWith(Environment::class, 'development')
            ->to(VerboseLogger::class);
        
        $this->bind(LoggerInterface::class)
            ->annotatedWith(Environment::class, 'production')
            ->to(OptimizedLogger::class);
        
        // 優先度付きプロセッサー
        $this->bind(ProcessorInterface::class)
            ->annotatedWith(Priority::class, 'high')
            ->to(HighPriorityProcessor::class);
        
        $this->bind(ProcessorInterface::class)
            ->annotatedWith(Priority::class, 'low')
            ->to(LowPriorityProcessor::class);
    }
}

// 使用例
class OrderService
{
    public function __construct(
        #[Database('primary')] private PDO $writePdo,
        #[Database('secondary')] private PDO $readPdo,
        #[Environment('production')] private LoggerInterface $logger
    ) {}
}
```

### 2. 動的修飾子

```php
class DynamicModule extends AbstractModule
{
    private array $config;
    
    public function __construct(array $config)
    {
        $this->config = $config;
    }
    
    protected function configure(): void
    {
        // 設定ベースの動的束縛
        foreach ($this->config['services'] as $serviceName => $serviceConfig) {
            $this->bindService($serviceName, $serviceConfig);
        }
        
        // 決済ゲートウェイの動的束縛
        foreach ($this->config['payment']['gateways'] as $gateway) {
            if ($gateway['enabled']) {
                $this->bindPaymentGateway($gateway);
            }
        }
    }
    
    private function bindService(string $name, array $config): void
    {
        $interfaceClass = $config['interface'];
        $implementationClass = $config['implementation'];
        $scope = $config['scope'] ?? null;
        
        $binding = $this->bind($interfaceClass)
            ->annotatedWith('service', $name)
            ->to($implementationClass);
        
        if ($scope) {
            $binding->in($scope);
        }
    }
    
    private function bindPaymentGateway(array $gateway): void
    {
        $this->bind(PaymentGatewayInterface::class)
            ->annotatedWith('gateway', $gateway['name'])
            ->to($gateway['class'])
            ->in(Singleton::class);
    }
}

// 設定例
$config = [
    'services' => [
        'user_service' => [
            'interface' => UserServiceInterface::class,
            'implementation' => UserService::class,
            'scope' => null
        ],
        'cache_service' => [
            'interface' => CacheInterface::class,
            'implementation' => RedisCache::class,
            'scope' => Singleton::class
        ]
    ],
    'payment' => [
        'gateways' => [
            ['name' => 'stripe', 'class' => StripeGateway::class, 'enabled' => true],
            ['name' => 'paypal', 'class' => PayPalGateway::class, 'enabled' => false],
        ]
    ]
];
```

## DSLパターンのベストプラクティス

### 1. 読みやすい束縛チェーン

```php
class ReadableModule extends AbstractModule
{
    protected function configure(): void
    {
        // 良い：段階的で読みやすい
        $this->bind(UserRepositoryInterface::class)
            ->to(MySQLUserRepository::class)
            ->in(Singleton::class);
        
        $this->bind(EmailServiceInterface::class)
            ->annotatedWith('transactional')
            ->to(TransactionalEmailService::class)
            ->in(Singleton::class);
        
        // チェーンが長い場合は改行で整理
        $this->bind(ComplexServiceInterface::class)
            ->annotatedWith('advanced')
            ->toProvider(ComplexServiceProvider::class)
            ->in(Singleton::class);
    }
}
```

### 2. 設定の外部化

```php
class ConfigurableModule extends AbstractModule
{
    public function __construct(
        private ServiceConfig $config
    ) {}
    
    protected function configure(): void
    {
        // 設定駆動の束縛
        $this->configureDatabase();
        $this->configureCache();
        $this->configurePayment();
        $this->configureNotifications();
    }
    
    private function configureDatabase(): void
    {
        $dbConfig = $this->config->getDatabase();
        
        $this->bind(PDO::class)
            ->toProvider(function() use ($dbConfig) {
                return new PDO(
                    $dbConfig->getDsn(),
                    $dbConfig->getUsername(),
                    $dbConfig->getPassword(),
                    $dbConfig->getOptions()
                );
            })
            ->in(Singleton::class);
        
        $this->bind(UserRepositoryInterface::class)
            ->to($dbConfig->getUserRepositoryClass())
            ->in($dbConfig->getRepositoryScope());
    }
    
    private function configureCache(): void
    {
        $cacheConfig = $this->config->getCache();
        
        if ($cacheConfig->isEnabled()) {
            $this->bind(CacheInterface::class)
                ->to($cacheConfig->getDriverClass())
                ->in(Singleton::class);
        } else {
            $this->bind(CacheInterface::class)
                ->to(NullCache::class)
                ->in(Singleton::class);
        }
    }
}
```

### 3. ファクトリーベースのDSL

```php
class ServiceFactory
{
    private AbstractModule $module;
    
    public function __construct(AbstractModule $module)
    {
        $this->module = $module;
    }
    
    public function singleton(string $interface, string $implementation): self
    {
        $this->module->bind($interface)
            ->to($implementation)
            ->in(Singleton::class);
        return $this;
    }
    
    public function prototype(string $interface, string $implementation): self
    {
        $this->module->bind($interface)
            ->to($implementation);
        return $this;
    }
    
    public function instance(string $interface, object $instance): self
    {
        $this->module->bind($interface)
            ->toInstance($instance);
        return $this;
    }
    
    public function provider(string $interface, string $provider, ?string $scope = null): self
    {
        $binding = $this->module->bind($interface)
            ->toProvider($provider);
        
        if ($scope) {
            $binding->in($scope);
        }
        
        return $this;
    }
    
    public function named(string $interface, string $name, string $implementation): self
    {
        $this->module->bind($interface)
            ->annotatedWith('named', $name)
            ->to($implementation);
        return $this;
    }
}

// 使用例
class FluentModule extends AbstractModule
{
    protected function configure(): void
    {
        $factory = new ServiceFactory($this);
        
        $factory
            ->singleton(DatabaseInterface::class, MySQLDatabase::class)
            ->singleton(CacheInterface::class, RedisCache::class)
            ->prototype(OrderServiceInterface::class, OrderService::class)
            ->named(LoggerInterface::class, 'error', ErrorLogger::class)
            ->named(LoggerInterface::class, 'access', AccessLogger::class)
            ->provider(PDO::class, DatabaseProvider::class, Singleton::class);
    }
}
```

## 実践的なDSLパターン

### 1. E-commerceプラットフォームのDSL

```php
class ECommerceModule extends AbstractModule
{
    protected function configure(): void
    {
        // ユーザー管理
        $this->configureUserManagement();
        
        // 商品管理
        $this->configureProductManagement();
        
        // 注文処理
        $this->configureOrderProcessing();
        
        // 決済処理
        $this->configurePaymentProcessing();
        
        // 通知システム
        $this->configureNotificationSystem();
    }
    
    private function configureUserManagement(): void
    {
        $this->bind(UserRepositoryInterface::class)
            ->to(MySQLUserRepository::class);
        
        $this->bind(UserServiceInterface::class)
            ->to(UserService::class);
        
        $this->bind(AuthenticationServiceInterface::class)
            ->to(JWTAuthenticationService::class)
            ->in(Singleton::class);
        
        $this->bind(PasswordHasherInterface::class)
            ->to(BcryptPasswordHasher::class)
            ->in(Singleton::class);
    }
    
    private function configureProductManagement(): void
    {
        $this->bind(ProductRepositoryInterface::class)
            ->to(MySQLProductRepository::class);
        
        $this->bind(CategoryRepositoryInterface::class)
            ->to(MySQLCategoryRepository::class);
        
        $this->bind(InventoryServiceInterface::class)
            ->to(InventoryService::class);
        
        $this->bind(PricingServiceInterface::class)
            ->to(DynamicPricingService::class);
        
        // 商品検索
        $this->bind(SearchEngineInterface::class)
            ->annotatedWith('product')
            ->to(ElasticsearchEngine::class)
            ->in(Singleton::class);
    }
    
    private function configureOrderProcessing(): void
    {
        $this->bind(OrderRepositoryInterface::class)
            ->to(MySQLOrderRepository::class);
        
        $this->bind(OrderServiceInterface::class)
            ->to(OrderService::class);
        
        $this->bind(ShoppingCartInterface::class)
            ->to(RedisShoppingCart::class);
        
        // 注文状態管理
        $this->bind(OrderStateMachineInterface::class)
            ->to(OrderStateMachine::class)
            ->in(Singleton::class);
    }
    
    private function configurePaymentProcessing(): void
    {
        // 複数の決済ゲートウェイ
        $this->bind(PaymentGatewayInterface::class)
            ->annotatedWith('stripe')
            ->to(StripePaymentGateway::class)
            ->in(Singleton::class);
        
        $this->bind(PaymentGatewayInterface::class)
            ->annotatedWith('paypal')
            ->to(PayPalPaymentGateway::class)
            ->in(Singleton::class);
        
        // 決済プロセッサー
        $this->bind(PaymentProcessorInterface::class)
            ->to(MultiGatewayPaymentProcessor::class);
        
        // 決済検証
        $this->bind(PaymentValidatorInterface::class)
            ->to(PaymentValidator::class);
    }
    
    private function configureNotificationSystem(): void
    {
        // メール通知
        $this->bind(EmailServiceInterface::class)
            ->annotatedWith('transactional')
            ->to(TransactionalEmailService::class)
            ->in(Singleton::class);
        
        $this->bind(EmailServiceInterface::class)
            ->annotatedWith('marketing')
            ->to(MarketingEmailService::class)
            ->in(Singleton::class);
        
        // SMS通知
        $this->bind(SMSServiceInterface::class)
            ->to(TwilioSMSService::class)
            ->in(Singleton::class);
        
        // プッシュ通知
        $this->bind(PushNotificationInterface::class)
            ->to(FirebasePushNotification::class)
            ->in(Singleton::class);
    }
}
```

### 2. 環境別設定DSL

```php
class EnvironmentAwareModule extends AbstractModule
{
    private string $environment;
    
    public function __construct()
    {
        $this->environment = $_ENV['APP_ENV'] ?? 'development';
    }
    
    protected function configure(): void
    {
        $this->configureCommonServices();
        
        match($this->environment) {
            'development' => $this->configureDevelopment(),
            'testing' => $this->configureTesting(),
            'staging' => $this->configureStaging(),
            'production' => $this->configureProduction(),
            default => throw new InvalidArgumentException("Unknown environment: {$this->environment}")
        };
    }
    
    private function configureCommonServices(): void
    {
        // 全環境共通の束縛
        $this->bind(UserServiceInterface::class)
            ->to(UserService::class);
        
        $this->bind(OrderServiceInterface::class)
            ->to(OrderService::class);
    }
    
    private function configureDevelopment(): void
    {
        $this->bind(LoggerInterface::class)
            ->to(VerboseConsoleLogger::class)
            ->in(Singleton::class);
        
        $this->bind(CacheInterface::class)
            ->to(ArrayCache::class)
            ->in(Singleton::class);
        
        $this->bind(EmailServiceInterface::class)
            ->to(FileEmailService::class)
            ->in(Singleton::class);
    }
    
    private function configureProduction(): void
    {
        $this->bind(LoggerInterface::class)
            ->to(SyslogLogger::class)
            ->in(Singleton::class);
        
        $this->bind(CacheInterface::class)
            ->to(RedisCache::class)
            ->in(Singleton::class);
        
        $this->bind(EmailServiceInterface::class)
            ->to(SMTPEmailService::class)
            ->in(Singleton::class);
        
        // 本番環境専用サービス
        $this->bind(MonitoringInterface::class)
            ->to(NewRelicMonitoring::class)
            ->in(Singleton::class);
    }
}
```

## デバッグとトラブルシューティング

### 1. 束縛の検査

```php
class DiagnosticModule extends AbstractModule
{
    protected function configure(): void
    {
        // デバッグモードでの詳細ログ
        if ($_ENV['DEBUG_DI'] === 'true') {
            $this->enableDetailedLogging();
        }
        
        // 束縛の検証
        $this->validateBindings();
    }
    
    private function enableDetailedLogging(): void
    {
        $this->bind(InjectorInterface::class)
            ->toProvider(function() {
                return new LoggingInjector(new Injector($this));
            })
            ->in(Singleton::class);
    }
    
    private function validateBindings(): void
    {
        // 必須の束縛が存在することを確認
        $requiredBindings = [
            UserRepositoryInterface::class,
            ProductRepositoryInterface::class,
            OrderRepositoryInterface::class,
        ];
        
        foreach ($requiredBindings as $binding) {
            if (!$this->isBound($binding)) {
                throw new MissingBindingException("Required binding not found: {$binding}");
            }
        }
    }
}
```

## 次のステップ

束縛DSLの使用方法を理解したので、次に進む準備が整いました。

1. **スコープとライフサイクルの学習**: オブジェクトの生存期間管理
2. **AOPとインターセプターの探索**: 横断的関心事の実装
3. **実世界の例での練習**: 複雑なアプリケーションでの活用方法

**続きは:** [シングルトンスコープ](../04-scopes-lifecycle/singleton-scope.html)

## 重要なポイント

- **DSL**により直感的で読みやすい設定が可能
- **メソッドチェーン**で流暢なAPI設計を実現
- **条件付き束縛**で環境に応じた柔軟な設定
- **カスタムアノテーション**で表現力を拡張
- **設定の外部化**により保守性を向上
- **デバッグ機能**でトラブルシューティングを支援

---

Ray.Diの束縛DSLは、複雑な依存関係を直感的で保守しやすい方法で設定できる強力な機能です。適切に活用することで、読みやすく理解しやすい設定コードを作成できます。