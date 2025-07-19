---
layout: docs-ja
title: アスペクト指向プログラミング
category: Manual
permalink: /manuals/1.0/ja/tutorial/05-aop-interceptors/aspect-oriented-programming.html
---

# アスペクト指向プログラミング

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- アスペクト指向プログラミング（AOP）の基本概念
- Ray.DiでのAOP実装とインターセプター
- 横断的関心事の分離と実装
- E-commerceアプリケーションでの実践的AOP活用
- パフォーマンス監視、ログ、セキュリティの実装

## AOPの基本概念

### 1. アスペクト指向プログラミングとは

```php
// 従来のアプローチ：横断的関心事がビジネスロジックに混入
class UserService
{
    public function createUser(array $userData): User
    {
        // ログ出力（横断的関心事）
        $this->logger->info('Creating user', $userData);
        
        // パフォーマンス測定開始（横断的関心事）
        $startTime = microtime(true);
        
        // セキュリティチェック（横断的関心事）
        if (!$this->security->isAuthorized('user:create')) {
            throw new UnauthorizedException();
        }
        
        try {
            // ビジネスロジック（核心関心事）
            $user = new User($userData);
            $this->userRepository->save($user);
            
            // 成功ログ（横断的関心事）
            $this->logger->info('User created successfully', ['id' => $user->getId()]);
            
            return $user;
        } catch (Exception $e) {
            // エラーログ（横断的関心事）
            $this->logger->error('User creation failed', ['error' => $e->getMessage()]);
            throw $e;
        } finally {
            // パフォーマンス測定終了（横断的関心事）
            $duration = microtime(true) - $startTime;
            $this->metrics->record('user_creation_time', $duration);
        }
    }
}

// AOPアプローチ：横断的関心事を分離
class UserService
{
    #[Log]
    #[Authorize('user:create')]
    #[Monitor]
    public function createUser(array $userData): User
    {
        // ビジネスロジックのみに集中
        $user = new User($userData);
        $this->userRepository->save($user);
        return $user;
    }
}
```

### 2. AOP用語とRay.Diでの実装

```php
use Ray\Aop\MethodInterceptor;
use Ray\Aop\MethodInvocation;

// Aspect（アスペクト）：横断的関心事の実装
class LoggingInterceptor implements MethodInterceptor
{
    public function __construct(
        private LoggerInterface $logger
    ) {}
    
    // Advice（アドバイス）：実際の処理
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod()->getName();
        $class = $invocation->getThis()::class;
        
        // Before advice
        $this->logger->info("Calling {$class}::{$method}");
        
        try {
            // Join point（ジョインポイント）：元のメソッド実行
            $result = $invocation->proceed();
            
            // After returning advice
            $this->logger->info("Successfully completed {$class}::{$method}");
            
            return $result;
        } catch (Exception $e) {
            // After throwing advice
            $this->logger->error("Exception in {$class}::{$method}: {$e->getMessage()}");
            throw $e;
        }
    }
}

// Pointcut（ポイントカット）：適用対象の指定
#[Attribute]
class Log
{
    public function __construct(
        public readonly string $level = 'info'
    ) {}
}

// モジュールでの設定
class AopModule extends AbstractModule
{
    protected function configure(): void
    {
        // インターセプターの束縛
        $this->bindInterceptor(
            $this->matcher->any(),                    // クラスマッチャー
            $this->matcher->annotatedWith(Log::class), // メソッドマッチャー
            [LoggingInterceptor::class]              // インターセプター
        );
    }
}
```

## 基本的なインターセプター実装

### 1. ログインターセプター

```php
class DetailedLoggingInterceptor implements MethodInterceptor
{
    public function __construct(
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $class = $invocation->getThis()::class;
        $methodName = $method->getName();
        $arguments = $invocation->getArguments();
        
        // メソッド呼び出し前のログ
        $this->logger->info("Method call: {$class}::{$methodName}", [
            'arguments' => $this->sanitizeArguments($arguments),
            'timestamp' => date('Y-m-d H:i:s')
        ]);
        
        $startTime = microtime(true);
        
        try {
            $result = $invocation->proceed();
            
            $duration = microtime(true) - $startTime;
            
            // 成功時のログ
            $this->logger->info("Method completed: {$class}::{$methodName}", [
                'duration' => round($duration * 1000, 2) . 'ms',
                'result_type' => is_object($result) ? get_class($result) : gettype($result)
            ]);
            
            return $result;
            
        } catch (Exception $e) {
            $duration = microtime(true) - $startTime;
            
            // エラー時のログ
            $this->logger->error("Method failed: {$class}::{$methodName}", [
                'duration' => round($duration * 1000, 2) . 'ms',
                'exception' => get_class($e),
                'message' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            
            throw $e;
        }
    }
    
    private function sanitizeArguments(array $arguments): array
    {
        return array_map(function ($arg) {
            if (is_string($arg) && strlen($arg) > 100) {
                return substr($arg, 0, 100) . '...';
            }
            if (is_array($arg) && isset($arg['password'])) {
                $arg['password'] = '***';
            }
            return $arg;
        }, $arguments);
    }
}
```

### 2. パフォーマンス監視インターセプター

```php
class PerformanceInterceptor implements MethodInterceptor
{
    public function __construct(
        private MetricsCollectorInterface $metrics,
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $class = $invocation->getThis()::class;
        $methodName = "{$class}::{$method->getName()}";
        
        $startTime = microtime(true);
        $startMemory = memory_get_usage(true);
        
        try {
            $result = $invocation->proceed();
            
            $this->recordMetrics($methodName, $startTime, $startMemory, true);
            
            return $result;
            
        } catch (Exception $e) {
            $this->recordMetrics($methodName, $startTime, $startMemory, false);
            throw $e;
        }
    }
    
    private function recordMetrics(string $methodName, float $startTime, int $startMemory, bool $success): void
    {
        $duration = microtime(true) - $startTime;
        $memoryUsage = memory_get_usage(true) - $startMemory;
        
        // メトリクス記録
        $this->metrics->timing($methodName . '.duration', $duration * 1000);
        $this->metrics->gauge($methodName . '.memory', $memoryUsage);
        $this->metrics->increment($methodName . '.calls');
        
        if ($success) {
            $this->metrics->increment($methodName . '.success');
        } else {
            $this->metrics->increment($methodName . '.failure');
        }
        
        // 遅いメソッドの警告
        if ($duration > 1.0) {
            $this->logger->warning("Slow method execution: {$methodName}", [
                'duration' => round($duration * 1000, 2) . 'ms',
                'memory' => round($memoryUsage / 1024 / 1024, 2) . 'MB'
            ]);
        }
        
        // メモリ使用量の警告
        if ($memoryUsage > 10 * 1024 * 1024) { // 10MB
            $this->logger->warning("High memory usage: {$methodName}", [
                'memory' => round($memoryUsage / 1024 / 1024, 2) . 'MB'
            ]);
        }
    }
}

#[Attribute]
class Monitor
{
    public function __construct(
        public readonly float $slowThreshold = 1.0,
        public readonly int $memoryThreshold = 10485760 // 10MB
    ) {}
}
```

### 3. キャッシュインターセプター

```php
class CacheInterceptor implements MethodInterceptor
{
    public function __construct(
        private CacheInterface $cache,
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $cacheKey = $this->generateCacheKey($invocation);
        
        // キャッシュからの取得を試行
        $cached = $this->cache->get($cacheKey);
        if ($cached !== null) {
            $this->logger->debug("Cache hit: {$cacheKey}");
            return $cached;
        }
        
        // キャッシュミス：実際のメソッドを実行
        $this->logger->debug("Cache miss: {$cacheKey}");
        $result = $invocation->proceed();
        
        // 結果をキャッシュに保存
        $ttl = $this->getTtl($invocation);
        $this->cache->set($cacheKey, $result, $ttl);
        
        return $result;
    }
    
    private function generateCacheKey(MethodInvocation $invocation): string
    {
        $method = $invocation->getMethod();
        $class = $invocation->getThis()::class;
        $arguments = $invocation->getArguments();
        
        // 引数をシリアライズしてキーに含める
        $argsHash = md5(serialize($arguments));
        
        return "cache:{$class}:{$method->getName()}:{$argsHash}";
    }
    
    private function getTtl(MethodInvocation $invocation): int
    {
        $method = $invocation->getMethod();
        $attributes = $method->getAttributes(Cacheable::class);
        
        if (!empty($attributes)) {
            $cacheable = $attributes[0]->newInstance();
            return $cacheable->ttl;
        }
        
        return 3600; // デフォルト1時間
    }
}

#[Attribute]
class Cacheable
{
    public function __construct(
        public readonly int $ttl = 3600,
        public readonly string $key = ''
    ) {}
}
```

## セキュリティとバリデーション

### 1. 認証・認可インターセプター

```php
class AuthorizationInterceptor implements MethodInterceptor
{
    public function __construct(
        private SecurityContextInterface $security,
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $attributes = $method->getAttributes(Authorize::class);
        
        if (empty($attributes)) {
            return $invocation->proceed();
        }
        
        $authorize = $attributes[0]->newInstance();
        $requiredPermissions = $authorize->permissions;
        $requireAll = $authorize->requireAll;
        
        // 認証チェック
        if (!$this->security->isAuthenticated()) {
            $this->logger->warning("Unauthorized access attempt", [
                'method' => $method->getName(),
                'class' => $invocation->getThis()::class
            ]);
            throw new UnauthorizedException('Authentication required');
        }
        
        // 認可チェック
        if (!$this->checkPermissions($requiredPermissions, $requireAll)) {
            $this->logger->warning("Access denied", [
                'method' => $method->getName(),
                'class' => $invocation->getThis()::class,
                'user' => $this->security->getCurrentUser()->getId(),
                'required_permissions' => $requiredPermissions
            ]);
            throw new ForbiddenException('Insufficient permissions');
        }
        
        return $invocation->proceed();
    }
    
    private function checkPermissions(array $permissions, bool $requireAll): bool
    {
        $userPermissions = $this->security->getCurrentUser()->getPermissions();
        
        if ($requireAll) {
            return empty(array_diff($permissions, $userPermissions));
        } else {
            return !empty(array_intersect($permissions, $userPermissions));
        }
    }
}

#[Attribute]
class Authorize
{
    public function __construct(
        public readonly array $permissions,
        public readonly bool $requireAll = true
    ) {}
}
```

### 2. バリデーションインターセプター

```php
class ValidationInterceptor implements MethodInterceptor
{
    public function __construct(
        private ValidatorInterface $validator,
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $attributes = $method->getAttributes(Validate::class);
        
        if (empty($attributes)) {
            return $invocation->proceed();
        }
        
        $validate = $attributes[0]->newInstance();
        $arguments = $invocation->getArguments();
        $parameters = $method->getParameters();
        
        // 各引数をバリデーション
        foreach ($validate->rules as $paramIndex => $rules) {
            if (isset($arguments[$paramIndex])) {
                $paramName = $parameters[$paramIndex]->getName();
                $value = $arguments[$paramIndex];
                
                $result = $this->validator->validate($value, $rules);
                
                if (!$result->isValid()) {
                    $this->logger->warning("Validation failed", [
                        'method' => $method->getName(),
                        'parameter' => $paramName,
                        'errors' => $result->getErrors()
                    ]);
                    
                    throw new ValidationException(
                        "Validation failed for parameter '{$paramName}': " . 
                        implode(', ', $result->getErrors())
                    );
                }
            }
        }
        
        return $invocation->proceed();
    }
}

#[Attribute]
class Validate
{
    public function __construct(
        public readonly array $rules
    ) {}
}

// 使用例
class UserService
{
    #[Validate([
        0 => ['required', 'email'],           // 第1引数（email）
        1 => ['required', 'string', 'min:8'] // 第2引数（password）
    ])]
    public function createUser(string $email, string $password): User
    {
        // バリデーション済みの引数でビジネスロジックを実行
        return new User(['email' => $email, 'password' => $password]);
    }
}
```

## E-commerceでの実践的AOP活用

### 1. 注文処理システムでのAOP

```php
class OrderService
{
    #[Log]
    #[Monitor]
    #[Authorize(['order:create'])]
    #[Validate([
        0 => ['required', 'array'],
        1 => ['required', 'integer', 'min:1']
    ])]
    public function createOrder(array $items, int $customerId): Order
    {
        // ビジネスロジックのみ
        $order = new Order($customerId, $items);
        $this->orderRepository->save($order);
        return $order;
    }
    
    #[Cacheable(ttl: 300)]
    #[Log]
    public function getOrderHistory(int $customerId): array
    {
        return $this->orderRepository->findByCustomerId($customerId);
    }
    
    #[Monitor]
    #[Authorize(['order:process'])]
    #[Transaction]
    public function processPayment(Order $order, PaymentData $payment): PaymentResult
    {
        $result = $this->paymentGateway->process($order->getTotal(), $payment);
        
        if ($result->isSuccess()) {
            $order->markAsPaid($result->getTransactionId());
            $this->orderRepository->save($order);
        }
        
        return $result;
    }
}
```

### 2. トランザクション管理インターセプター

```php
class TransactionInterceptor implements MethodInterceptor
{
    public function __construct(
        private DatabaseInterface $database,
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $methodName = $method->getName();
        
        $this->logger->debug("Starting transaction for {$methodName}");
        
        $this->database->beginTransaction();
        
        try {
            $result = $invocation->proceed();
            
            $this->database->commit();
            $this->logger->debug("Transaction committed for {$methodName}");
            
            return $result;
            
        } catch (Exception $e) {
            $this->database->rollback();
            $this->logger->error("Transaction rolled back for {$methodName}", [
                'error' => $e->getMessage()
            ]);
            
            throw $e;
        }
    }
}

#[Attribute]
class Transaction {}
```

### 3. レート制限インターセプター

```php
class RateLimitInterceptor implements MethodInterceptor
{
    public function __construct(
        private CacheInterface $cache,
        private SecurityContextInterface $security,
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $attributes = $method->getAttributes(RateLimit::class);
        
        if (empty($attributes)) {
            return $invocation->proceed();
        }
        
        $rateLimit = $attributes[0]->newInstance();
        $key = $this->generateRateLimitKey($invocation, $rateLimit);
        
        if (!$this->checkRateLimit($key, $rateLimit)) {
            $this->logger->warning("Rate limit exceeded", [
                'method' => $method->getName(),
                'user' => $this->security->getCurrentUser()?->getId(),
                'limit' => $rateLimit->requests,
                'window' => $rateLimit->window
            ]);
            
            throw new RateLimitExceededException(
                "Rate limit exceeded: {$rateLimit->requests} requests per {$rateLimit->window} seconds"
            );
        }
        
        return $invocation->proceed();
    }
    
    private function generateRateLimitKey(MethodInvocation $invocation, RateLimit $rateLimit): string
    {
        $method = $invocation->getMethod();
        $class = $invocation->getThis()::class;
        
        if ($rateLimit->perUser && $this->security->isAuthenticated()) {
            $userId = $this->security->getCurrentUser()->getId();
            return "rate_limit:{$class}:{$method->getName()}:user:{$userId}";
        }
        
        // IPベースの制限
        $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        return "rate_limit:{$class}:{$method->getName()}:ip:{$ip}";
    }
    
    private function checkRateLimit(string $key, RateLimit $rateLimit): bool
    {
        $current = $this->cache->get($key, 0);
        
        if ($current >= $rateLimit->requests) {
            return false;
        }
        
        $this->cache->set($key, $current + 1, $rateLimit->window);
        return true;
    }
}

#[Attribute]
class RateLimit
{
    public function __construct(
        public readonly int $requests,
        public readonly int $window,
        public readonly bool $perUser = true
    ) {}
}

// 使用例
class APIController
{
    #[RateLimit(requests: 100, window: 3600)] // 1時間に100リクエスト
    public function getProducts(): array
    {
        return $this->productService->getAllProducts();
    }
    
    #[RateLimit(requests: 10, window: 60)] // 1分間に10リクエスト
    public function createOrder(array $orderData): Order
    {
        return $this->orderService->createOrder($orderData);
    }
}
```

## 統合AOPモジュール

### 1. 包括的AOPモジュール

```php
class ComprehensiveAopModule extends AbstractModule
{
    protected function configure(): void
    {
        // ログインターセプター
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Log::class),
            [DetailedLoggingInterceptor::class]
        );
        
        // パフォーマンス監視
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Monitor::class),
            [PerformanceInterceptor::class]
        );
        
        // キャッシュ
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Cacheable::class),
            [CacheInterceptor::class]
        );
        
        // 認証・認可
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Authorize::class),
            [AuthorizationInterceptor::class]
        );
        
        // バリデーション
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Validate::class),
            [ValidationInterceptor::class]
        );
        
        // トランザクション
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Transaction::class),
            [TransactionInterceptor::class]
        );
        
        // レート制限
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(RateLimit::class),
            [RateLimitInterceptor::class]
        );
        
        // サービス層全体にログを適用
        $this->bindInterceptor(
            $this->matcher->subclassesOf(ServiceInterface::class),
            $this->matcher->any(),
            [DetailedLoggingInterceptor::class]
        );
        
        // リポジトリ層にパフォーマンス監視を適用
        $this->bindInterceptor(
            $this->matcher->subclassesOf(RepositoryInterface::class),
            $this->matcher->any(),
            [PerformanceInterceptor::class]
        );
    }
}
```

### 2. 条件付きインターセプター適用

```php
class ConditionalAopModule extends AbstractModule
{
    protected function configure(): void
    {
        // 本番環境でのみパフォーマンス監視
        if ($_ENV['APP_ENV'] === 'production') {
            $this->bindInterceptor(
                $this->matcher->any(),
                $this->matcher->annotatedWith(Monitor::class),
                [PerformanceInterceptor::class]
            );
        }
        
        // 開発環境でのみ詳細ログ
        if ($_ENV['APP_ENV'] === 'development') {
            $this->bindInterceptor(
                $this->matcher->any(),
                $this->matcher->any(),
                [DetailedLoggingInterceptor::class]
            );
        }
        
        // セキュリティが有効な場合のみ認証チェック
        if ($_ENV['SECURITY_ENABLED'] === 'true') {
            $this->bindInterceptor(
                $this->matcher->any(),
                $this->matcher->annotatedWith(Authorize::class),
                [AuthorizationInterceptor::class]
            );
        }
    }
}
```

## パフォーマンスとベストプラクティス

### 1. インターセプターの最適化

```php
class OptimizedLoggingInterceptor implements MethodInterceptor
{
    private bool $isDebugEnabled;
    
    public function __construct(
        private LoggerInterface $logger
    ) {
        // ログレベルチェックを事前に実行
        $this->isDebugEnabled = $logger->isHandling(LogLevel::DEBUG);
    }
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        // デバッグログが無効な場合は最小限の処理
        if (!$this->isDebugEnabled) {
            return $invocation->proceed();
        }
        
        // 重い処理はデバッグモードでのみ実行
        $method = $invocation->getMethod();
        $class = $invocation->getThis()::class;
        $methodName = "{$class}::{$method->getName()}";
        
        $this->logger->debug("Method call: {$methodName}");
        
        $result = $invocation->proceed();
        
        $this->logger->debug("Method completed: {$methodName}");
        
        return $result;
    }
}
```

### 2. インターセプターチェーンの最適化

```php
class ChainedInterceptorModule extends AbstractModule
{
    protected function configure(): void
    {
        // 軽量なインターセプターを先に配置
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Log::class),
            [
                // 1. 高速なセキュリティチェック
                QuickSecurityInterceptor::class,
                // 2. ログ出力
                LoggingInterceptor::class,
                // 3. 重いパフォーマンス測定
                PerformanceInterceptor::class
            ]
        );
    }
}
```

## 次のステップ

アスペクト指向プログラミングの基礎を理解したので、次に進む準備が整いました。

1. **メソッドインターセプターの詳細学習**: より高度なインターセプター実装
2. **共通の横断的関心事の探索**: 実践的なAOPパターン
3. **実世界の例での練習**: 複雑なアプリケーションでの活用方法

**続きは:** [メソッドインターセプター](method-interceptors.html)

## 重要なポイント

- **AOP**により横断的関心事をビジネスロジックから分離
- **インターセプター**でメソッド実行の前後に処理を挿入
- **アトリビュート**により宣言的な設定が可能
- **パフォーマンス**、セキュリティ、ログ、キャッシュを統一的に実装
- **条件付き適用**で環境に応じた最適化
- **チェーン構成**で複数の関心事を組み合わせ

---

Ray.DiのAOPは、クリーンで保守しやすいコードを実現するための強力な機能です。適切に活用することで、ビジネスロジックに集中しながら、横断的関心事を効率的に管理できます。