---
layout: docs-ja
title: パフォーマンス考慮事項
category: Manual
permalink: /manuals/1.0/ja/tutorial/08-best-practices/performance-considerations.html
---

# パフォーマンス考慮事項

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diのパフォーマンス特性と最適化方法
- Ray.Compilerを使用したコンパイル時最適化
- スコープとライフサイクル管理によるパフォーマンス向上
- プロバイダーとファクトリーの効率的な使用
- 実際のベンチマークとパフォーマンス測定

## Ray.Diのパフォーマンス特性

### 1. DI コンテナのオーバーヘッド

Ray.Diは実行時にリフレクションを使用してオブジェクトを作成します。これは柔軟性をもたらしますが、パフォーマンスのオーバーヘッドも発生します。

```php
// 通常のオブジェクト作成
$service = new UserService(
    new MySQLUserRepository(new PDO($dsn)),
    new SMTPEmailService($config),
    new FileLogger('/var/log/app.log')
);

// Ray.Diを使用したオブジェクト作成
$injector = new Injector(new AppModule());
$service = $injector->getInstance(UserService::class);
```

**パフォーマンス比較:**
- 手動作成: 基準
- Ray.Di (標準): 手動作成より低速 (リフレクションのオーバーヘッド)
- Ray.Di (コンパイル済み): 手動作成より高速 (最適化されたコード生成)

## Ray.Compiler による最適化

### 1. コンパイル時最適化の概念

Ray.Compilerは、実行時のリフレクションとバインディング解決を回避し、事前にコンパイルされたPHPコードを生成します。**コンパイル済みのRay.Diは、手動でのオブジェクト作成よりも高速に動作します。**

### なぜコンパイル済みDIが手動作成より高速なのか？

1. **最適化されたオブジェクト作成順序**: コンパイラが依存関係グラフを解析し、最も効率的な作成順序を決定
2. **インライン化**: 小さなオブジェクト作成は直接インライン化され、関数呼び出しのオーバーヘッドを削減
3. **事前計算された依存関係**: 実行時に依存関係を解決する必要がなく、すべて事前に計算済み
4. **最適化されたメモリ配置**: オブジェクトの作成パターンが最適化され、メモリの局所性が向上
5. **無駄なチェックの除去**: バリデーションや条件分岐が事前に処理され、実行時には必要最小限のコードのみ実行

```php
use Ray\Compiler\Compiler;
use Ray\Compiler\CompiledInjector;

// 開発時: バインディングをコンパイル
$compiler = new Compiler();
$scripts = $compiler->compile(
    new AppModule(),
    __DIR__ . '/tmp/di'
);

// 本番時: コンパイル済みインジェクターを使用
$injector = new CompiledInjector(__DIR__ . '/tmp/di');
$service = $injector->getInstance(UserService::class);
```

### 2. コンパイルプロセスの詳細

```php
// bin/compile.php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

use Ray\Compiler\Compiler;
use Your\App\Module\AppModule;

try {
    $scriptDir = __DIR__ . '/../tmp/di';
    
    // 既存のコンパイル済みファイルを削除
    if (is_dir($scriptDir)) {
        $files = glob($scriptDir . '/*');
        foreach ($files as $file) {
            unlink($file);
        }
    } else {
        mkdir($scriptDir, 0755, true);
    }
    
    $compiler = new Compiler();
    $scripts = $compiler->compile(new AppModule(), $scriptDir);
    
    printf("Successfully compiled %d files.\n", count($scripts));
    
    // 生成されたファイルの詳細を表示
    foreach ($scripts as $class => $file) {
        printf("  %s -> %s\n", $class, basename($file));
    }
    
} catch (Exception $e) {
    fprintf(STDERR, "Compilation failed: %s\n", $e->getMessage());
    exit(1);
}
```

### 3. Composer統合

```json
{
    "scripts": {
        "compile": "php bin/compile.php",
        "post-install-cmd": ["@compile"],
        "post-update-cmd": ["@compile"]
    },
    "scripts-descriptions": {
        "compile": "Compile Ray.Di bindings for production"
    }
}
```

### 4. パフォーマンス比較

```php
class PerformanceBenchmark
{
    public function benchmarkInjectors(): void
    {
        $module = new AppModule();
        
        // 標準インジェクター
        $standardInjector = new Injector($module);
        
        // コンパイル済みインジェクター
        $compiledInjector = new CompiledInjector(__DIR__ . '/tmp/di');
        
        $iterations = 10000;
        
        // 標準インジェクターのベンチマーク
        $start = microtime(true);
        for ($i = 0; $i < $iterations; $i++) {
            $service = $standardInjector->getInstance(UserService::class);
        }
        $standardTime = microtime(true) - $start;
        
        // コンパイル済みインジェクターのベンチマーク
        $start = microtime(true);
        for ($i = 0; $i < $iterations; $i++) {
            $service = $compiledInjector->getInstance(UserService::class);
        }
        $compiledTime = microtime(true) - $start;
        
        printf("Standard Injector: %.4f seconds\n", $standardTime);
        printf("Compiled Injector: %.4f seconds\n", $compiledTime);
        printf("Performance improvement: %.1fx faster\n", $standardTime / $compiledTime);
    }
}
```

## スコープとライフサイクル最適化

### 1. 適切なスコープの選択

```php
class OptimizedModule extends AbstractModule
{
    protected function configure(): void
    {
        // 重いオブジェクトはシングルトン
        $this->bind(DatabaseConnectionInterface::class)
            ->to(MySQLConnection::class)
            ->in(Singleton::class);
            
        $this->bind(CacheInterface::class)
            ->to(RedisCache::class)
            ->in(Singleton::class);
            
        // 設定オブジェクトもシングルトン
        $this->bind(ConfigInterface::class)
            ->to(AppConfig::class)
            ->in(Singleton::class);
            
        // ステートレスなサービスもシングルトン
        $this->bind(ValidationServiceInterface::class)
            ->to(ValidationService::class)
            ->in(Singleton::class);
            
        // 状態を持つオブジェクトはプロトタイプ（デフォルト）
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        $this->bind(UserSessionInterface::class)->to(UserSession::class);
    }
}
```

### 2. 遅延初期化の活用

```php
class LazyConnectionProvider implements ProviderInterface
{
    private ?PDO $connection = null;
    
    public function __construct(private ConfigInterface $config) {}
    
    public function get(): PDO
    {
        // 最初にアクセスされるまで接続を作成しない
        if ($this->connection === null) {
            $this->connection = $this->createConnection();
        }
        
        return $this->connection;
    }
    
    private function createConnection(): PDO
    {
        $dsn = $this->config->getDatabaseDsn();
        $username = $this->config->getDatabaseUsername();
        $password = $this->config->getDatabasePassword();
        
        return new PDO($dsn, $username, $password, [
            PDO::ATTR_PERSISTENT => true,
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
        ]);
    }
}
```

## プロバイダーとファクトリーの最適化

### 1. 効率的なプロバイダー設計

```php
// 良い：軽量で高速なプロバイダー
class FastLoggerProvider implements ProviderInterface
{
    public function __construct(private string $logPath) {}
    
    public function get(): LoggerInterface
    {
        return new FileLogger($this->logPath);
    }
}

// 悪い：重い処理を含むプロバイダー
class SlowLoggerProvider implements ProviderInterface
{
    public function get(): LoggerInterface
    {
        // 毎回重い処理を実行（アンチパターン）
        $logPath = $this->scanLogDirectory();
        $this->validateLogPermissions($logPath);
        $this->rotateOldLogs($logPath);
        
        return new FileLogger($logPath);
    }
}
```

### 2. キャッシュ戦略

```php
class CachedServiceProvider implements ProviderInterface
{
    private static array $cache = [];
    
    public function __construct(private string $serviceKey) {}
    
    public function get(): ServiceInterface
    {
        if (!isset(self::$cache[$this->serviceKey])) {
            self::$cache[$this->serviceKey] = $this->createService();
        }
        
        return self::$cache[$this->serviceKey];
    }
    
    private function createService(): ServiceInterface
    {
        // 重い初期化処理
        return new ExpensiveService();
    }
}
```

## メモリ最適化

### 1. 循環参照の回避

```php
// 良い：循環参照を避ける設計
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
        
        // イベントを発行（循環参照なし）
        $this->eventDispatcher->dispatch(new UserCreatedEvent($user));
        
        return $user;
    }
}

// 悪い：循環参照のリスク
class BadUserService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private OrderServiceInterface $orderService // 危険：OrderServiceがUserServiceを参照する可能性
    ) {}
}
```

### 2. メモリリークの防止

```php
class MemoryEfficientProvider implements ProviderInterface
{
    private WeakMap $instances;
    
    public function __construct()
    {
        $this->instances = new WeakMap();
    }
    
    public function get(): ServiceInterface
    {
        $key = new stdClass();
        
        if (!isset($this->instances[$key])) {
            $this->instances[$key] = new ExpensiveService();
        }
        
        return $this->instances[$key];
    }
}
```

## 実際のベンチマーク

### 1. E-commerceアプリケーションでの測定

```php
class EcommercePerformanceTest
{
    public function testOrderProcessingPerformance(): void
    {
        $scenarios = [
            'manual' => $this->createManualServices(),
            'standard_di' => new Injector(new AppModule()),
            'compiled_di' => new CompiledInjector(__DIR__ . '/tmp/di')
        ];
        
        foreach ($scenarios as $name => $injector) {
            $time = $this->measureOrderProcessing($injector);
            printf("%s: %.4f seconds\n", $name, $time);
        }
    }
    
    private function measureOrderProcessing($injector): float
    {
        $orders = $this->generateTestOrders(1000);
        
        $start = microtime(true);
        
        foreach ($orders as $orderData) {
            if ($injector instanceof InjectorInterface) {
                $orderService = $injector->getInstance(OrderServiceInterface::class);
            } else {
                $orderService = $injector; // 手動作成のサービス
            }
            
            $orderService->processOrder($orderData);
        }
        
        return microtime(true) - $start;
    }
    
    private function generateTestOrders(int $count): array
    {
        $orders = [];
        for ($i = 0; $i < $count; $i++) {
            $orders[] = [
                'user_id' => rand(1, 1000),
                'items' => $this->generateRandomItems(),
                'total' => rand(1000, 50000) / 100
            ];
        }
        return $orders;
    }
}
```

### 2. メモリ使用量の測定

```php
class MemoryBenchmark
{
    public function testMemoryUsage(): void
    {
        $scenarios = [
            'Standard DI' => function() {
                return new Injector(new AppModule());
            },
            'Compiled DI' => function() {
                return new CompiledInjector(__DIR__ . '/tmp/di');
            }
        ];
        
        foreach ($scenarios as $name => $factory) {
            $this->measureMemoryUsage($name, $factory);
        }
    }
    
    private function measureMemoryUsage(string $name, callable $factory): void
    {
        $startMemory = memory_get_usage(true);
        
        $injector = $factory();
        
        // 1000個のオブジェクトを作成
        for ($i = 0; $i < 1000; $i++) {
            $service = $injector->getInstance(UserService::class);
            unset($service); // 明示的に解放
        }
        
        $endMemory = memory_get_usage(true);
        $peakMemory = memory_get_peak_usage(true);
        
        printf("%s:\n", $name);
        printf("  Memory used: %s\n", $this->formatBytes($endMemory - $startMemory));
        printf("  Peak memory: %s\n", $this->formatBytes($peakMemory));
        printf("\n");
    }
    
    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB'];
        $factor = floor(log($bytes, 1024));
        
        return sprintf('%.2f %s', $bytes / (1024 ** $factor), $units[$factor]);
    }
}
```

## 本番環境での最適化

### 1. Docker統合

```dockerfile
# Multi-stage build for optimization
FROM php:8.2-cli-alpine as builder

WORKDIR /app

# Install composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy composer files
COPY composer.json composer.lock ./

# Install dependencies
RUN composer install \
    --no-dev \
    --no-scripts \
    --prefer-dist \
    --no-interaction \
    --optimize-autoloader

# Copy application code
COPY . .

# Compile DI bindings
RUN php bin/compile.php

# Production stage
FROM php:8.2-cli-alpine

# Install production extensions
RUN apk add --no-cache \
    libpq-dev \
    && docker-php-ext-install \
        pdo_pgsql \
        opcache

# Configure PHP for production
COPY php.ini /usr/local/etc/php/

WORKDIR /app

# Copy compiled application
COPY --from=builder /app/vendor/ ./vendor/
COPY --from=builder /app/src/ ./src/
COPY --from=builder /app/tmp/di/ ./tmp/di/

# Create non-root user
RUN adduser -D appuser
USER appuser

CMD ["php", "app.php"]
```

### 2. OPcache設定

```ini
; php.ini for production
[opcache]
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.validate_timestamps=0
opcache.revalidate_freq=0
opcache.save_comments=0
opcache.fast_shutdown=1

; Additional optimizations
realpath_cache_size=4096K
realpath_cache_ttl=600
```

### 3. 監視とプロファイリング

```php
class PerformanceMonitor
{
    public function monitorDIPerformance(): void
    {
        $start = microtime(true);
        $startMemory = memory_get_usage();
        
        // DI コンテナの使用
        $injector = new CompiledInjector(__DIR__ . '/tmp/di');
        $service = $injector->getInstance(OrderService::class);
        
        $endTime = microtime(true);
        $endMemory = memory_get_usage();
        
        // メトリクスを記録
        $this->recordMetrics([
            'di_creation_time' => ($endTime - $start) * 1000, // ミリ秒
            'memory_usage' => $endMemory - $startMemory,
            'timestamp' => time()
        ]);
    }
    
    private function recordMetrics(array $metrics): void
    {
        // StatsD、Prometheus、CloudWatchなどに送信
        foreach ($metrics as $name => $value) {
            statsd_gauge("app.di.{$name}", $value);
        }
    }
}
```

## ベストプラクティスのまとめ

### 1. 開発環境

- 標準のInjectorを使用して柔軟な開発を行う
- ホットリロードとリアルタイムデバッグを活用
- パフォーマンステストを定期的に実行

### 2. ステージング環境

- コンパイル済みインジェクターを使用して本番環境を模倣
- パフォーマンスベンチマークを実行
- メモリリークテストを実施

### 3. 本番環境

- 必ずCompiledInjectorを使用
- OPcacheを適切に設定
- 監視とアラートを設定
- 定期的なパフォーマンス監査を実施

## 次のステップ

パフォーマンス最適化の手法を理解したので、次に進む準備が整いました。

1. **監視とデバッグの学習**: アプリケーションの健全性監視
2. **スケーラビリティの探索**: 大規模アプリケーションでのDI設計
3. **実世界での適用**: 既存アプリケーションの最適化

**続きは:** [トラブルシューティングガイド](troubleshooting-guide.html)

## 重要なポイント

- **Ray.Compiler**は本番環境で大幅なパフォーマンス向上をもたらす
- **適切なスコープ選択**がメモリ効率に大きく影響
- **遅延初期化**で不要なオブジェクト作成を回避
- **コンパイル済みコードは版管理に含めない**
- **定期的な監視とベンチマーク**でパフォーマンス低下を早期発見
- **環境ごとに適切な設定**を使い分ける

---

パフォーマンス最適化は継続的なプロセスです。Ray.Compilerと適切な設計パターンを組み合わせることで、スケーラブルで高性能なアプリケーションを構築できます。