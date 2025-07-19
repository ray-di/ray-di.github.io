---
layout: docs-ja
title: インジェクションポイントの利用
category: Manual
permalink: /manuals/1.0/ja/tutorial/03-advanced-bindings/injection-point.html
---

# インジェクションポイントの利用

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- インジェクションポイントとは何か、なぜ有用なのか
- 注入される場所に応じて異なる実装を提供する方法
- LoggerFactoryパターンの実装
- CDI（Contexts and Dependency Injection）との類似点
- 実践的な使用例とベストプラクティス

## インジェクションポイントとは

**インジェクションポイント**は、依存関係が注入される場所（クラス、フィールド、メソッド）のメタデータを取得できる機能です。これにより、同じインターフェースでも**注入される場所に応じて異なる実装**を提供できます。

### 問題：すべてのクラスに同じLoggerが注入される

```php
interface LoggerInterface
{
    public function info(string $message): void;
    public function error(string $message): void;
}

class FileLogger implements LoggerInterface
{
    public function __construct(private string $logFile) {}
    
    public function info(string $message): void
    {
        file_put_contents($this->logFile, "[INFO] {$message}\n", FILE_APPEND);
    }
    
    public function error(string $message): void
    {
        file_put_contents($this->logFile, "[ERROR] {$message}\n", FILE_APPEND);
    }
}

// 従来の方法：すべてのクラスに同じLoggerが注入される
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(LoggerInterface::class)->toInstance(new FileLogger('/var/log/app.log'));
    }
}

class OrderService
{
    public function __construct(
        private LoggerInterface $logger // 汎用的なapp.logに書き込む
    ) {}
}

class UserService
{
    public function __construct(
        private LoggerInterface $logger // 同じapp.logに書き込む
    ) {}
}
```

### 解決策：インジェクションポイントを使用したコンテキスチャルインジェクション

```php
use Ray\Di\InjectionPointInterface;

class LoggerFactory
{
    public function create(InjectionPointInterface $ip): LoggerInterface
    {
        // 注入されるクラスの情報を取得
        $class = $ip->getClass();
        $className = $class->getName();
        
        // クラス名に基づいて専用のLoggerを作成
        $logFile = '/var/log/' . strtolower($className) . '.log';
        return new FileLogger($logFile);
    }
}

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(LoggerInterface::class)->toProvider(LoggerFactory::class);
    }
}

class OrderService
{
    public function __construct(
        private LoggerInterface $logger // /var/log/orderservice.log に書き込む
    ) {}
    
    public function processOrder(Order $order): void
    {
        $this->logger->info("Processing order: {$order->getId()}");
        // 処理...
    }
}

class UserService
{
    public function __construct(
        private LoggerInterface $logger // /var/log/userservice.log に書き込む
    ) {}
    
    public function createUser(User $user): void
    {
        $this->logger->info("Creating user: {$user->getEmail()}");
        // 処理...
    }
}
```

## InjectionPointInterfaceの詳細

### 利用可能なメタデータ

```php
interface InjectionPointInterface
{
    public function getClass(): ReflectionClass;
    public function getMethod(): ?ReflectionMethod;
    public function getParameter(): ?ReflectionParameter;
    public function getQualifier(): ?object;
}

class AdvancedLoggerFactory
{
    public function create(InjectionPointInterface $ip): LoggerInterface
    {
        $class = $ip->getClass();
        $method = $ip->getMethod();
        $parameter = $ip->getParameter();
        
        // クラス名
        $className = $class->getName();
        
        // 注入されるメソッド（通常は__construct）
        $methodName = $method ? $method->getName() : 'unknown';
        
        // パラメータ名
        $paramName = $parameter ? $parameter->getName() : 'unknown';
        
        // 詳細な情報を使用してLoggerを設定
        $logFile = sprintf(
            '/var/log/%s_%s_%s.log',
            strtolower($className),
            $methodName,
            $paramName
        );
        
        return new FileLogger($logFile);
    }
}
```

## 実践的な使用例

### 1. 環境固有のデータベース接続

```php
class DatabaseFactory
{
    public function create(InjectionPointInterface $ip): DatabaseInterface
    {
        $class = $ip->getClass();
        $className = $class->getName();
        
        // クラス名に基づいて適切なデータベースを選択
        return match(true) {
            str_contains($className, 'User') => new UserDatabase(),
            str_contains($className, 'Order') => new OrderDatabase(),
            str_contains($className, 'Product') => new ProductDatabase(),
            default => new DefaultDatabase()
        };
    }
}

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(DatabaseInterface::class)->toProvider(DatabaseFactory::class);
    }
}
```

### 2. キャッシュ戦略の切り替え

```php
class CacheFactory
{
    public function create(InjectionPointInterface $ip): CacheInterface
    {
        $class = $ip->getClass();
        $className = $class->getName();
        
        // クラスの特性に基づいてキャッシュ戦略を選択
        return match(true) {
            str_contains($className, 'User') => new RedisCache('user_cache'),
            str_contains($className, 'Session') => new MemoryCache(),
            str_contains($className, 'Product') => new FileCache('/tmp/product_cache'),
            default => new NullCache()
        };
    }
}
```

### 3. アトリビュートとの組み合わせ

```php
#[Attribute]
class LogLevel
{
    public function __construct(public string $level) {}
}

class AttributeLoggerFactory
{
    public function create(InjectionPointInterface $ip): LoggerInterface
    {
        $class = $ip->getClass();
        $parameter = $ip->getParameter();
        
        // アトリビュートから情報を取得
        $attributes = $parameter?->getAttributes(LogLevel::class) ?? [];
        $logLevel = $attributes[0]?->newInstance()->level ?? 'INFO';
        
        $className = $class->getName();
        $logFile = '/var/log/' . strtolower($className) . '.log';
        
        return new ConfigurableLogger($logFile, $logLevel);
    }
}

class OrderService
{
    public function __construct(
        #[LogLevel('DEBUG')] private LoggerInterface $logger
    ) {}
}

class UserService
{
    public function __construct(
        #[LogLevel('ERROR')] private LoggerInterface $logger
    ) {}
}
```

## CDI（Contexts and Dependency Injection）との比較

### Java CDI の例

```java
@ApplicationScoped
public class LoggerFactory {
    @Produces
    public Logger createLogger(InjectionPoint ip) {
        return LoggerFactory.getLogger(ip.getMember().getDeclaringClass().getName());
    }
}

@RequestScoped
public class OrderService {
    @Inject
    private Logger logger; // OrderService用のLoggerが注入される
}
```

### Ray.Di の equivalent

```php
class LoggerFactory
{
    public function create(InjectionPointInterface $ip): LoggerInterface
    {
        $class = $ip->getClass();
        return new FileLogger('/var/log/' . $class->getName() . '.log');
    }
}

class OrderService
{
    public function __construct(
        private LoggerInterface $logger // OrderService用のLoggerが注入される
    ) {}
}
```

## 高度なパターン

### 1. 条件付きインジェクション

```php
class ConditionalServiceFactory
{
    public function create(InjectionPointInterface $ip): ServiceInterface
    {
        $class = $ip->getClass();
        $className = $class->getName();
        
        // 環境変数やクラス名に基づいて実装を選択
        $environment = $_ENV['APP_ENV'] ?? 'production';
        $isTestClass = str_contains($className, 'Test');
        
        return match(true) {
            $isTestClass => new MockService(),
            $environment === 'development' => new DevelopmentService(),
            $environment === 'staging' => new StagingService(),
            default => new ProductionService()
        };
    }
}
```

### 2. 階層的なサービス選択

```php
class HierarchicalServiceFactory
{
    public function create(InjectionPointInterface $ip): ServiceInterface
    {
        $class = $ip->getClass();
        $namespace = $class->getNamespaceName();
        
        // 名前空間に基づいてサービスを選択
        return match(true) {
            str_starts_with($namespace, 'App\\Admin') => new AdminService(),
            str_starts_with($namespace, 'App\\Api') => new ApiService(),
            str_starts_with($namespace, 'App\\Web') => new WebService(),
            default => new DefaultService()
        };
    }
}
```

### 3. 動的な設定の注入

```php
class ConfigFactory
{
    public function create(InjectionPointInterface $ip): ConfigInterface
    {
        $class = $ip->getClass();
        $className = $class->getName();
        
        // クラス名に基づいて適切な設定を読み込む
        $configKey = strtolower(str_replace('Service', '', $className));
        $configFile = "/config/{$configKey}.php";
        
        if (file_exists($configFile)) {
            return new FileConfig($configFile);
        }
        
        return new DefaultConfig();
    }
}
```

## E-commerceプラットフォームでの実践例

### 注文処理システム

```php
class OrderModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(LoggerInterface::class)->toProvider(OrderLoggerFactory::class);
        $this->bind(NotificationInterface::class)->toProvider(NotificationFactory::class);
    }
}

class OrderLoggerFactory
{
    public function create(InjectionPointInterface $ip): LoggerInterface
    {
        $class = $ip->getClass();
        $className = $class->getName();
        
        // 注文関連のクラスには特別なフォーマットを使用
        $formatter = match(true) {
            str_contains($className, 'Order') => new OrderLogFormatter(),
            str_contains($className, 'Payment') => new PaymentLogFormatter(),
            str_contains($className, 'Shipping') => new ShippingLogFormatter(),
            default => new DefaultLogFormatter()
        };
        
        return new FormattedLogger($formatter);
    }
}

class NotificationFactory
{
    public function create(InjectionPointInterface $ip): NotificationInterface
    {
        $class = $ip->getClass();
        $className = $class->getName();
        
        // サービスの種類に応じて通知方法を選択
        return match(true) {
            str_contains($className, 'Order') => new OrderNotification(),
            str_contains($className, 'User') => new UserNotification(),
            str_contains($className, 'Admin') => new AdminNotification(),
            default => new DefaultNotification()
        };
    }
}

class OrderService
{
    public function __construct(
        private LoggerInterface $logger,        // OrderLogFormatterを使用
        private NotificationInterface $notifier  // OrderNotificationを使用
    ) {}
    
    public function processOrder(Order $order): void
    {
        $this->logger->info("Processing order: {$order->getId()}");
        
        // 処理...
        
        $this->notifier->send("Order {$order->getId()} processed successfully");
    }
}

class PaymentService
{
    public function __construct(
        private LoggerInterface $logger,        // PaymentLogFormatterを使用
        private NotificationInterface $notifier  // DefaultNotificationを使用
    ) {}
    
    public function processPayment(Payment $payment): void
    {
        $this->logger->info("Processing payment: {$payment->getAmount()}");
        
        // 処理...
    }
}
```

## ベストプラクティス

### 1. 適切な粒度の選択

```php
// 良い：適切なレベルでの区別
class ServiceBasedLoggerFactory
{
    public function create(InjectionPointInterface $ip): LoggerInterface
    {
        $class = $ip->getClass();
        $className = $class->getName();
        
        // サービス層レベルでの区別
        $serviceType = $this->extractServiceType($className);
        return new FileLogger("/var/log/{$serviceType}.log");
    }
    
    private function extractServiceType(string $className): string
    {
        return match(true) {
            str_contains($className, 'Order') => 'order',
            str_contains($className, 'User') => 'user',
            str_contains($className, 'Payment') => 'payment',
            default => 'general'
        };
    }
}

// 悪い：過度に細かい区別
class OverlySpecificLoggerFactory
{
    public function create(InjectionPointInterface $ip): LoggerInterface
    {
        $class = $ip->getClass();
        $method = $ip->getMethod();
        $parameter = $ip->getParameter();
        
        // 過度に細かい区別（管理が困難）
        $logFile = sprintf(
            '/var/log/%s_%s_%s.log',
            $class->getName(),
            $method?->getName(),
            $parameter?->getName()
        );
        
        return new FileLogger($logFile);
    }
}
```

### 2. パフォーマンスの考慮

```php
class CachedLoggerFactory
{
    private array $cache = [];
    
    public function create(InjectionPointInterface $ip): LoggerInterface
    {
        $class = $ip->getClass();
        $className = $class->getName();
        
        // 同じクラスには同じLoggerインスタンスを使用
        if (!isset($this->cache[$className])) {
            $logFile = '/var/log/' . strtolower($className) . '.log';
            $this->cache[$className] = new FileLogger($logFile);
        }
        
        return $this->cache[$className];
    }
}
```

### 3. テストでの対応

```php
class TestLoggerFactory
{
    public function create(InjectionPointInterface $ip): LoggerInterface
    {
        $class = $ip->getClass();
        $className = $class->getName();
        
        // テスト環境では全てNullLoggerを使用
        if (str_contains($className, 'Test')) {
            return new NullLogger();
        }
        
        // テスト環境ではメモリLoggerを使用
        return new MemoryLogger();
    }
}
```

## 次のステップ

インジェクションポイントの使用方法を理解したので、次に進む準備が整いました。

1. **マルチバインディングの学習**: 複数の実装を同時に注入する方法
2. **アシストインジェクションの探索**: ファクトリーパターンの高度な実装
3. **実世界の例での練習**: 複雑なアプリケーションでの適用方法

**続きは:** [マルチバインディング](../index.html#part-3-高度なバインディング)

## 重要なポイント

- **インジェクションポイント**は注入される場所のメタデータを提供
- **コンテキスチャルインジェクション**により同じインターフェースでも異なる実装を提供
- **LoggerFactoryパターン**はインジェクションポイントの典型的な使用例
- **CDI**との類似性により、Javaの経験者にも理解しやすい
- **適切な粒度**とパフォーマンスを考慮した実装が重要
- **テスト**では専用のファクトリーを使用して制御する

---

インジェクションポイントは、Ray.Diの最も強力な機能の一つです。適切に使用することで、柔軟で保守しやすいアプリケーションを構築できます。