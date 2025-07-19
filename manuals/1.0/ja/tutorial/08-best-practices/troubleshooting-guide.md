---
layout: docs-ja
title: トラブルシューティングガイド
category: Manual
permalink: /manuals/1.0/ja/tutorial/08-best-practices/troubleshooting-guide.html
---

# トラブルシューティングガイド

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diでよく発生する問題の識別と解決方法
- 効果的なデバッグ技法とツール
- パフォーマンスの問題の診断と対処
- 依存性注入に関するベストプラクティス
- 実際の開発現場での問題解決手法

## 一般的な問題とその解決方法

### 1. 束縛エラーの解決

#### 問題: 束縛が見つからない

```php
// エラー例
Ray\Di\Exception\Unbound: - (default)
interface ShopSmart\UserRepositoryInterface
```

**原因と解決方法:**

```php
// 問題のあるコード
class UserService
{
    public function __construct(
        private UserRepositoryInterface $userRepository  // 束縛されていない
    ) {}
}

// 解決方法 1: モジュールで束縛を定義
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // 束縛を追加
        $this->bind(UserRepositoryInterface::class)
            ->to(MySQLUserRepository::class);
    }
}

// 解決方法 2: 実装クラスを直接使用
class UserService
{
    public function __construct(
        private MySQLUserRepository $userRepository  // 具体的な実装
    ) {}
}

// 解決方法 3: プロバイダーを使用
class UserRepositoryProvider implements ProviderInterface
{
    public function __construct(
        private DatabaseInterface $database,
        private LoggerInterface $logger
    ) {}

    public function get(): UserRepositoryInterface
    {
        return new MySQLUserRepository($this->database, $this->logger);
    }
}

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)
            ->toProvider(UserRepositoryProvider::class);
    }
}
```

#### 問題: 循環依存

```php
// エラー例
Ray\Di\Exception\CyclicDependency: Cyclic dependency detected
```

**原因と解決方法:**

```php
// 問題のあるコード（循環依存）
class UserService
{
    public function __construct(
        private OrderService $orderService
    ) {}
}

class OrderService
{
    public function __construct(
        private UserService $userService  // 循環依存
    ) {}
}

// 解決方法 1: 依存関係を再設計
class UserService
{
    public function __construct(
        private UserRepositoryInterface $userRepository
    ) {}
}

class OrderService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,  // 共通の依存関係
        private OrderRepositoryInterface $orderRepository
    ) {}
}

// 解決方法 2: 中間サービスを導入
class UserOrderService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private OrderRepositoryInterface $orderRepository
    ) {}
    
    public function getUserOrders(int $userId): array
    {
        return $this->orderRepository->findByUserId($userId);
    }
}

class UserService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private UserOrderService $userOrderService
    ) {}
}

class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private UserOrderService $userOrderService
    ) {}
}

// 解決方法 3: イベントを使用
class UserService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private EventDispatcherInterface $eventDispatcher
    ) {}
    
    public function createUser(array $userData): User
    {
        $user = new User($userData);
        $this->userRepository->save($user);
        
        // イベントを発行（直接的な依存を避ける）
        $this->eventDispatcher->dispatch(new UserCreatedEvent($user));
        
        return $user;
    }
}
```

### 2. スコープ関連の問題

#### 問題: シングルトンスコープの予期しない動作

```php
// 問題のあるコード
class DatabaseConnection
{
    private static ?PDO $connection = null;
    
    public function getConnection(): PDO
    {
        if (self::$connection === null) {
            self::$connection = new PDO(/* 接続情報 */);
        }
        return self::$connection;
    }
}

// 問題: 静的プロパティとシングルトンスコープの競合
```

**解決方法:**

```php
// 解決方法 1: DIコンテナにシングルトン管理を委譲
class DatabaseConnection
{
    private ?PDO $connection = null;
    
    public function __construct(
        private string $dsn,
        private string $username,
        private string $password
    ) {}
    
    public function getConnection(): PDO
    {
        if ($this->connection === null) {
            $this->connection = new PDO($this->dsn, $this->username, $this->password);
        }
        return $this->connection;
    }
}

class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(DatabaseConnection::class)
            ->to(DatabaseConnection::class)
            ->in(Singleton::class);  // DIコンテナが管理
    }
}

// 解決方法 2: プロバイダーを使用
class DatabaseConnectionProvider implements ProviderInterface
{
    private ?PDO $connection = null;
    
    public function get(): PDO
    {
        if ($this->connection === null) {
            $this->connection = new PDO(
                $_ENV['DATABASE_DSN'],
                $_ENV['DATABASE_USERNAME'],
                $_ENV['DATABASE_PASSWORD']
            );
        }
        return $this->connection;
    }
}
```

### 3. アノテーションとアトリビュート

#### 問題: アトリビュートが認識されない

```php
// 問題のあるコード
class PaymentService
{
    public function __construct(
        #[Named('stripe')] private PaymentGatewayInterface $gateway  // 認識されない
    ) {}
}
```

**解決方法:**

```php
// 解決方法 1: use文を確認
use Ray\Di\Di\Named;

class PaymentService
{
    public function __construct(
        #[Named('stripe')] private PaymentGatewayInterface $gateway
    ) {}
}

// 解決方法 2: モジュールでの束縛を確認
class PaymentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(PaymentGatewayInterface::class)
            ->annotatedWith(Named::class, 'stripe')
            ->to(StripePaymentGateway::class);
        
        $this->bind(PaymentGatewayInterface::class)
            ->annotatedWith(Named::class, 'paypal')
            ->to(PayPalPaymentGateway::class);
    }
}
```

## デバッグとトラブルシューティング手法

### 1. エラーメッセージの読み方

```php
// よくあるエラーメッセージとその対処法

// 1. Unbound exception
/*
Ray\Di\Exception\Unbound: - (default)
interface App\UserRepositoryInterface
*/

// デバッグ手順:
// 1. インターフェースが正しく束縛されているか確認
// 2. モジュールが正しく読み込まれているか確認
// 3. 名前空間が正しいか確認

// 2. NotFound exception
/*
Ray\Di\Exception\NotFound: - App\UserService
*/

// デバッグ手順:
// 1. クラスが存在するか確認
// 2. オートロードが正しく設定されているか確認
// 3. 名前空間が正しいか確認

// 3. Configuration exception
/*
Ray\Di\Exception\Configuration: duplicate binding
*/

// デバッグ手順:
// 1. 同じインターフェースが複数回束縛されていないか確認
// 2. 複数のモジュールで同じ束縛が定義されていないか確認
```

### 2. デバッグユーティリティ

```php
// DIコンテナの状態を確認するユーティリティ
class DIDebugger
{
    public function __construct(
        private Injector $injector
    ) {}
    
    public function dumpBindings(): void
    {
        // 束縛情報を出力
        echo "=== DI Container Bindings ===\n";
        
        // 実際の実装は Ray\Di の内部構造に依存
        // 開発時のデバッグ用途
    }
    
    public function checkBinding(string $interface): void
    {
        try {
            $instance = $this->injector->getInstance($interface);
            echo "✓ {$interface} -> " . get_class($instance) . "\n";
        } catch (Exception $e) {
            echo "✗ {$interface} -> Error: " . $e->getMessage() . "\n";
        }
    }
    
    public function validateDependencies(string $class): void
    {
        $reflection = new ReflectionClass($class);
        $constructor = $reflection->getConstructor();
        
        if ($constructor === null) {
            echo "✓ {$class} has no constructor dependencies\n";
            return;
        }
        
        echo "Dependencies for {$class}:\n";
        
        foreach ($constructor->getParameters() as $param) {
            $type = $param->getType();
            if ($type === null) {
                echo "  ✗ {$param->getName()} -> No type hint\n";
                continue;
            }
            
            $typeName = $type->getName();
            
            try {
                $this->injector->getInstance($typeName);
                echo "  ✓ {$param->getName()} -> {$typeName}\n";
            } catch (Exception $e) {
                echo "  ✗ {$param->getName()} -> {$typeName} (Error: {$e->getMessage()})\n";
            }
        }
    }
}

// 使用例
$debugger = new DIDebugger($injector);
$debugger->validateDependencies(UserService::class);
$debugger->checkBinding(UserRepositoryInterface::class);
```

### 3. ログを使った診断

```php
// DIコンテナの動作をログで追跡
class LoggingInjector
{
    public function __construct(
        private Injector $injector,
        private LoggerInterface $logger
    ) {}
    
    public function getInstance(string $interface): object
    {
        $this->logger->debug("Requesting instance of {$interface}");
        
        $startTime = microtime(true);
        
        try {
            $instance = $this->injector->getInstance($interface);
            $duration = microtime(true) - $startTime;
            
            $this->logger->debug("Successfully created instance of {$interface}", [
                'class' => get_class($instance),
                'duration' => $duration * 1000 . 'ms'
            ]);
            
            return $instance;
            
        } catch (Exception $e) {
            $duration = microtime(true) - $startTime;
            
            $this->logger->error("Failed to create instance of {$interface}", [
                'error' => $e->getMessage(),
                'duration' => $duration * 1000 . 'ms'
            ]);
            
            throw $e;
        }
    }
}
```

## パフォーマンスの問題

### 1. 遅いインスタンス化

```php
// 問題のあるコード
class ExpensiveService
{
    public function __construct()
    {
        // 重い初期化処理
        sleep(2);
        $this->heavyInitialization();
    }
    
    private function heavyInitialization(): void
    {
        // 大量のデータ処理
        for ($i = 0; $i < 1000000; $i++) {
            // 重い処理
        }
    }
}
```

**解決方法:**

```php
// 解決方法 1: 遅延初期化
class ExpensiveService
{
    private ?array $data = null;
    
    public function __construct()
    {
        // 軽い初期化のみ
    }
    
    public function getData(): array
    {
        if ($this->data === null) {
            $this->data = $this->loadData();
        }
        return $this->data;
    }
    
    private function loadData(): array
    {
        // 重い処理は必要時に実行
        return [];
    }
}

// 解決方法 2: プロバイダーを使用
class ExpensiveServiceProvider implements ProviderInterface
{
    public function get(): ExpensiveService
    {
        // 必要時にのみ作成
        return new ExpensiveService();
    }
}

// 解決方法 3: ファクトリーを使用
class ExpensiveServiceFactory
{
    public function create(): ExpensiveService
    {
        return new ExpensiveService();
    }
}
```

### 2. メモリ使用量の問題

```php
// 問題のあるコード
class MemoryIntensiveService
{
    private array $cache = [];
    
    public function processData(array $data): array
    {
        // キャッシュが無制限に成長
        $key = serialize($data);
        
        if (!isset($this->cache[$key])) {
            $this->cache[$key] = $this->heavyProcessing($data);
        }
        
        return $this->cache[$key];
    }
}
```

**解決方法:**

```php
// 解決方法 1: LRUキャッシュを使用
class MemoryIntensiveService
{
    private array $cache = [];
    private array $usage = [];
    private int $maxSize = 1000;
    
    public function processData(array $data): array
    {
        $key = serialize($data);
        
        if (isset($this->cache[$key])) {
            $this->usage[$key] = microtime(true);
            return $this->cache[$key];
        }
        
        $result = $this->heavyProcessing($data);
        $this->addToCache($key, $result);
        
        return $result;
    }
    
    private function addToCache(string $key, array $value): void
    {
        if (count($this->cache) >= $this->maxSize) {
            $this->evictOldest();
        }
        
        $this->cache[$key] = $value;
        $this->usage[$key] = microtime(true);
    }
    
    private function evictOldest(): void
    {
        asort($this->usage);
        $oldestKey = array_key_first($this->usage);
        
        unset($this->cache[$oldestKey]);
        unset($this->usage[$oldestKey]);
    }
}

// 解決方法 2: 外部キャッシュを使用
class MemoryIntensiveService
{
    public function __construct(
        private CacheInterface $cache
    ) {}
    
    public function processData(array $data): array
    {
        $key = 'processed:' . md5(serialize($data));
        
        $cached = $this->cache->get($key);
        if ($cached !== null) {
            return $cached;
        }
        
        $result = $this->heavyProcessing($data);
        $this->cache->set($key, $result, 3600);
        
        return $result;
    }
}
```

## 本番環境でのトラブルシューティング

### 1. ログベースの診断

```php
// 本番環境用のエラーハンドラー
class ProductionErrorHandler
{
    public function __construct(
        private LoggerInterface $logger,
        private AlertManagerInterface $alertManager
    ) {}
    
    public function handleDIException(Exception $e): void
    {
        $context = [
            'exception' => get_class($e),
            'message' => $e->getMessage(),
            'trace' => $e->getTraceAsString(),
            'request_id' => $this->getRequestId(),
            'timestamp' => date('Y-m-d H:i:s')
        ];
        
        // 重要度に応じてログレベルを調整
        if ($e instanceof CyclicDependencyException) {
            $this->logger->critical('Cyclic dependency detected', $context);
            $this->alertManager->sendAlert('critical', 'Cyclic dependency in DI container', $context);
        } elseif ($e instanceof UnboundException) {
            $this->logger->error('Unbound dependency', $context);
            $this->alertManager->sendAlert('error', 'Unbound dependency in DI container', $context);
        } else {
            $this->logger->warning('DI container issue', $context);
        }
    }
    
    private function getRequestId(): string
    {
        return $_SERVER['HTTP_X_REQUEST_ID'] ?? uniqid();
    }
}
```

### 2. ヘルスチェック

```php
// DIコンテナのヘルスチェック
class DIHealthChecker
{
    public function __construct(
        private Injector $injector,
        private array $criticalServices = []
    ) {}
    
    public function checkHealth(): array
    {
        $results = [];
        
        foreach ($this->criticalServices as $service) {
            $results[$service] = $this->checkService($service);
        }
        
        return $results;
    }
    
    private function checkService(string $service): array
    {
        $startTime = microtime(true);
        
        try {
            $instance = $this->injector->getInstance($service);
            $duration = microtime(true) - $startTime;
            
            return [
                'status' => 'healthy',
                'duration' => $duration * 1000,
                'class' => get_class($instance)
            ];
            
        } catch (Exception $e) {
            $duration = microtime(true) - $startTime;
            
            return [
                'status' => 'unhealthy',
                'duration' => $duration * 1000,
                'error' => $e->getMessage()
            ];
        }
    }
}

// 使用例
$healthChecker = new DIHealthChecker($injector, [
    UserRepositoryInterface::class,
    PaymentGatewayInterface::class,
    EmailServiceInterface::class
]);

$health = $healthChecker->checkHealth();
```

### 3. パフォーマンス監視

```php
// DIコンテナのパフォーマンス監視
class DIPerformanceMonitor
{
    private array $metrics = [];
    
    public function __construct(
        private MetricsCollectorInterface $metricsCollector
    ) {}
    
    public function recordInstantiation(string $class, float $duration): void
    {
        $this->metrics[] = [
            'class' => $class,
            'duration' => $duration,
            'timestamp' => microtime(true)
        ];
        
        $this->metricsCollector->timing('di.instantiation', $duration * 1000, [
            'class' => $class
        ]);
        
        // 遅いインスタンス化を検出
        if ($duration > 0.1) { // 100ms以上
            $this->metricsCollector->increment('di.slow_instantiation', [
                'class' => $class
            ]);
        }
    }
    
    public function getSlowInstantiations(float $threshold = 0.1): array
    {
        return array_filter($this->metrics, function($metric) use ($threshold) {
            return $metric['duration'] > $threshold;
        });
    }
    
    public function getAverageInstantiationTime(string $class): float
    {
        $classMetrics = array_filter($this->metrics, function($metric) use ($class) {
            return $metric['class'] === $class;
        });
        
        if (empty($classMetrics)) {
            return 0.0;
        }
        
        $totalDuration = array_sum(array_column($classMetrics, 'duration'));
        return $totalDuration / count($classMetrics);
    }
}
```

## 予防策とベストプラクティス

### 1. 依存関係の検証

```php
// 起動時の依存関係検証
class DependencyValidator
{
    public function __construct(
        private Injector $injector,
        private array $requiredServices = []
    ) {}
    
    public function validate(): array
    {
        $errors = [];
        
        foreach ($this->requiredServices as $service) {
            try {
                $this->injector->getInstance($service);
            } catch (Exception $e) {
                $errors[] = [
                    'service' => $service,
                    'error' => $e->getMessage()
                ];
            }
        }
        
        return $errors;
    }
    
    public function validateAndThrow(): void
    {
        $errors = $this->validate();
        
        if (!empty($errors)) {
            $errorMessages = array_map(function($error) {
                return "{$error['service']}: {$error['error']}";
            }, $errors);
            
            throw new DependencyValidationException(
                'Dependency validation failed: ' . implode(', ', $errorMessages)
            );
        }
    }
}
```

### 2. 設定の妥当性チェック

```php
// 設定の検証
class ConfigurationValidator
{
    public function __construct(
        private array $requiredConfig = []
    ) {}
    
    public function validate(): array
    {
        $errors = [];
        
        foreach ($this->requiredConfig as $key => $rules) {
            $value = $_ENV[$key] ?? null;
            
            if ($value === null && $rules['required']) {
                $errors[] = "Required configuration '{$key}' is missing";
                continue;
            }
            
            if ($value !== null && isset($rules['type'])) {
                if (!$this->validateType($value, $rules['type'])) {
                    $errors[] = "Configuration '{$key}' has invalid type";
                }
            }
        }
        
        return $errors;
    }
    
    private function validateType(mixed $value, string $type): bool
    {
        return match ($type) {
            'string' => is_string($value),
            'int' => is_numeric($value),
            'bool' => in_array(strtolower($value), ['true', 'false', '1', '0']),
            'url' => filter_var($value, FILTER_VALIDATE_URL) !== false,
            'email' => filter_var($value, FILTER_VALIDATE_EMAIL) !== false,
            default => true
        };
    }
}
```

## 質問への回答

Ray.Di学習中に発生する可能性のある疑問点：

1. **束縛の優先順位は？**
   - 後から定義された束縛が優先される
   - 同じモジュール内では最後の束縛が有効
   - 異なるモジュール間では install の順序が影響

2. **循環依存の回避方法は？**
   - 共通のインターフェースへの依存に変更
   - 中間サービスの導入
   - イベント駆動アーキテクチャの採用

3. **パフォーマンスへの影響は？**
   - 初期化時のコストはあるが、実行時は高速
   - シングルトンスコープを適切に使用
   - 重い初期化は遅延実行を検討

4. **テストとの両立方法は？**
   - テスト用モジュールの作成
   - モック実装の準備
   - 依存関係の分離設計

## 次のステップ

このチュートリアルでRay.Diの包括的な学習を完了しました。実際のプロジェクトで活用する際は：

1. **小さな機能から始める**: 既存プロジェクトの一部から導入
2. **段階的な移行**: 全体を一度に変更せず、部分的に適用
3. **チームでの共有**: 学習した内容をチームメンバーと共有
4. **継続的な改善**: 実際の使用を通じて最適化を図る

**参考資料:**
- [Ray.Di 公式ドキュメント](https://ray-di.github.io/)
- [Google Guice ドキュメント](https://github.com/google/guice/wiki)
- [依存性注入の設計パターン](https://martinfowler.com/articles/injection.html)

## 重要なポイント

- **早期発見**: 開発段階での問題発見が重要
- **ログ活用**: 本番環境では適切なログ記録
- **監視体制**: パフォーマンスと健全性の継続監視
- **予防策**: 設定検証と依存関係の妥当性確認
- **段階的改善**: 小さな変更から始めて徐々に最適化

---

お疲れ様でした！これでRay.Diの完全なスタディガイドが完成しました。実際のプロジェクトでの活用を通じて、さらなる理解を深めていってください。何か不明な点があれば、コミュニティやドキュメントを活用して解決していきましょう。