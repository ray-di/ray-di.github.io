---
layout: docs-ja
title: メソッドインターセプター
category: Manual
permalink: /manuals/1.0/ja/tutorial/05-aop-interceptors/method-interceptors.html
---

# メソッドインターセプター

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- メソッドインターセプターの詳細な実装方法
- MethodInvocationインターフェースの活用
- 高度なインターセプターパターンとテクニック
- 実際のE-commerceアプリケーションでの複雑な実装
- パフォーマンス最適化とデバッグ手法

## MethodInvocationの詳細

### 1. MethodInvocationインターフェースの理解

```php
use Ray\Aop\MethodInvocation;
use Ray\Aop\MethodInterceptor;

class DetailedMethodAnalysisInterceptor implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation): mixed
    {
        // メソッド情報の取得
        $method = $invocation->getMethod();
        $targetObject = $invocation->getThis();
        $arguments = $invocation->getArguments();
        
        echo "=== Method Analysis ===\n";
        echo "Class: " . get_class($targetObject) . "\n";
        echo "Method: " . $method->getName() . "\n";
        echo "Modifiers: " . implode(', ', $this->getMethodModifiers($method)) . "\n";
        echo "Parameters: " . $this->formatParameters($method->getParameters()) . "\n";
        echo "Arguments: " . $this->formatArguments($arguments) . "\n";
        echo "Return Type: " . ($method->getReturnType()?->getName() ?? 'mixed') . "\n";
        
        // アトリビュート情報の表示
        $attributes = $method->getAttributes();
        if (!empty($attributes)) {
            echo "Attributes: " . $this->formatAttributes($attributes) . "\n";
        }
        
        // メソッド実行
        $startTime = microtime(true);
        
        try {
            $result = $invocation->proceed();
            
            $duration = microtime(true) - $startTime;
            echo "Execution Time: " . round($duration * 1000, 2) . "ms\n";
            echo "Result Type: " . (is_object($result) ? get_class($result) : gettype($result)) . "\n";
            echo "========================\n";
            
            return $result;
            
        } catch (Exception $e) {
            $duration = microtime(true) - $startTime;
            echo "Exception: " . get_class($e) . "\n";
            echo "Message: " . $e->getMessage() . "\n";
            echo "Duration before exception: " . round($duration * 1000, 2) . "ms\n";
            echo "========================\n";
            
            throw $e;
        }
    }
    
    private function getMethodModifiers(\ReflectionMethod $method): array
    {
        $modifiers = [];
        if ($method->isPublic()) $modifiers[] = 'public';
        if ($method->isProtected()) $modifiers[] = 'protected';
        if ($method->isPrivate()) $modifiers[] = 'private';
        if ($method->isStatic()) $modifiers[] = 'static';
        if ($method->isFinal()) $modifiers[] = 'final';
        if ($method->isAbstract()) $modifiers[] = 'abstract';
        return $modifiers;
    }
    
    private function formatParameters(array $parameters): string
    {
        $formatted = [];
        foreach ($parameters as $param) {
            $type = $param->getType()?->getName() ?? 'mixed';
            $name = '$' . $param->getName();
            $default = $param->isDefaultValueAvailable() ? ' = ' . var_export($param->getDefaultValue(), true) : '';
            $formatted[] = "{$type} {$name}{$default}";
        }
        return implode(', ', $formatted);
    }
    
    private function formatArguments(array $arguments): string
    {
        $formatted = [];
        foreach ($arguments as $i => $arg) {
            if (is_object($arg)) {
                $formatted[] = "#{$i}: " . get_class($arg) . " object";
            } elseif (is_array($arg)) {
                $formatted[] = "#{$i}: array[" . count($arg) . "]";
            } elseif (is_string($arg) && strlen($arg) > 50) {
                $formatted[] = "#{$i}: string(" . strlen($arg) . ") '" . substr($arg, 0, 50) . "...'";
            } else {
                $formatted[] = "#{$i}: " . var_export($arg, true);
            }
        }
        return implode(', ', $formatted);
    }
    
    private function formatAttributes(array $attributes): string
    {
        $formatted = [];
        foreach ($attributes as $attr) {
            $formatted[] = $attr->getName();
        }
        return implode(', ', $formatted);
    }
}
```

### 2. 引数の操作と変更

```php
class ArgumentModificationInterceptor implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $arguments = $invocation->getArguments();
        
        // 引数の検査と修正
        $modifiedArguments = $this->processArguments($method, $arguments);
        
        // 修正された引数で新しいMethodInvocationを作成
        if ($modifiedArguments !== $arguments) {
            return $this->invokeWithModifiedArguments($invocation, $modifiedArguments);
        }
        
        return $invocation->proceed();
    }
    
    private function processArguments(\ReflectionMethod $method, array $arguments): array
    {
        $parameters = $method->getParameters();
        $modified = $arguments;
        
        foreach ($parameters as $index => $param) {
            if (!isset($arguments[$index])) {
                continue;
            }
            
            $value = $arguments[$index];
            $paramType = $param->getType();
            
            // 文字列の正規化
            if ($paramType && $paramType->getName() === 'string' && is_string($value)) {
                $modified[$index] = $this->normalizeString($value);
            }
            
            // 配列の検証と修正
            if ($paramType && $paramType->getName() === 'array' && is_array($value)) {
                $modified[$index] = $this->sanitizeArray($value);
            }
            
            // オブジェクトのバリデーション
            if (is_object($value)) {
                $this->validateObject($value, $param);
            }
        }
        
        return $modified;
    }
    
    private function normalizeString(string $value): string
    {
        // 文字列の正規化処理
        $normalized = trim($value);
        $normalized = preg_replace('/\s+/', ' ', $normalized); // 連続する空白を単一に
        $normalized = filter_var($normalized, FILTER_SANITIZE_STRING, FILTER_FLAG_NO_ENCODE_QUOTES);
        
        return $normalized;
    }
    
    private function sanitizeArray(array $value): array
    {
        // 配列の再帰的サニタイズ
        array_walk_recursive($value, function (&$item) {
            if (is_string($item)) {
                $item = $this->normalizeString($item);
            }
        });
        
        return $value;
    }
    
    private function validateObject(object $value, \ReflectionParameter $param): void
    {
        $expectedType = $param->getType();
        if ($expectedType && !$value instanceof $expectedType->getName()) {
            throw new InvalidArgumentException(
                "Expected {$expectedType->getName()}, got " . get_class($value)
            );
        }
    }
    
    private function invokeWithModifiedArguments(MethodInvocation $invocation, array $modifiedArguments): mixed
    {
        // Ray.Diの内部実装に依存する部分
        // 実際の実装では、新しいMethodInvocationを作成するか、
        // 引数を変更する別の手法を使用する必要があります
        $targetObject = $invocation->getThis();
        $method = $invocation->getMethod();
        
        return $method->invokeArgs($targetObject, $modifiedArguments);
    }
}
```

## 高度なインターセプターパターン

### 1. 条件付き実行インターセプター

```php
class ConditionalExecutionInterceptor implements MethodInterceptor
{
    public function __construct(
        private SecurityContextInterface $security,
        private FeatureFlagInterface $featureFlags,
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $conditions = $this->extractConditions($method);
        
        // 条件をチェック
        foreach ($conditions as $condition) {
            if (!$this->evaluateCondition($condition, $invocation)) {
                return $this->handleConditionFailure($condition, $invocation);
            }
        }
        
        return $invocation->proceed();
    }
    
    private function extractConditions(\ReflectionMethod $method): array
    {
        $conditions = [];
        
        // FeatureFlag条件
        $featureFlagAttrs = $method->getAttributes(RequireFeature::class);
        foreach ($featureFlagAttrs as $attr) {
            $conditions[] = [
                'type' => 'feature_flag',
                'config' => $attr->newInstance()
            ];
        }
        
        // 時間制限条件
        $timeWindowAttrs = $method->getAttributes(TimeWindow::class);
        foreach ($timeWindowAttrs as $attr) {
            $conditions[] = [
                'type' => 'time_window',
                'config' => $attr->newInstance()
            ];
        }
        
        // ユーザー条件
        $userConditionAttrs = $method->getAttributes(UserCondition::class);
        foreach ($userConditionAttrs as $attr) {
            $conditions[] = [
                'type' => 'user_condition',
                'config' => $attr->newInstance()
            ];
        }
        
        return $conditions;
    }
    
    private function evaluateCondition(array $condition, MethodInvocation $invocation): bool
    {
        return match($condition['type']) {
            'feature_flag' => $this->checkFeatureFlag($condition['config']),
            'time_window' => $this->checkTimeWindow($condition['config']),
            'user_condition' => $this->checkUserCondition($condition['config']),
            default => true
        };
    }
    
    private function checkFeatureFlag(RequireFeature $config): bool
    {
        return $this->featureFlags->isEnabled($config->feature);
    }
    
    private function checkTimeWindow(TimeWindow $config): bool
    {
        $now = new DateTime();
        $start = new DateTime($config->start);
        $end = new DateTime($config->end);
        
        return $now >= $start && $now <= $end;
    }
    
    private function checkUserCondition(UserCondition $config): bool
    {
        if (!$this->security->isAuthenticated()) {
            return false;
        }
        
        $user = $this->security->getCurrentUser();
        
        return match($config->condition) {
            'premium' => $user->isPremium(),
            'admin' => $user->isAdmin(),
            'verified' => $user->isVerified(),
            default => true
        };
    }
    
    private function handleConditionFailure(array $condition, MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $class = $invocation->getThis()::class;
        
        $this->logger->warning("Condition failed for method {$class}::{$method->getName()}", [
            'condition_type' => $condition['type'],
            'condition_config' => $condition['config']
        ]);
        
        return match($condition['type']) {
            'feature_flag' => throw new FeatureNotAvailableException(),
            'time_window' => throw new ServiceUnavailableException('Service not available at this time'),
            'user_condition' => throw new AccessDeniedException('User condition not met'),
            default => null
        };
    }
}

// 条件アトリビュート
#[Attribute]
class RequireFeature
{
    public function __construct(public readonly string $feature) {}
}

#[Attribute]
class TimeWindow
{
    public function __construct(
        public readonly string $start,
        public readonly string $end
    ) {}
}

#[Attribute]
class UserCondition
{
    public function __construct(public readonly string $condition) {}
}
```

### 2. リトライインターセプター

```php
class RetryInterceptor implements MethodInterceptor
{
    public function __construct(
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $retryAttrs = $method->getAttributes(Retry::class);
        
        if (empty($retryAttrs)) {
            return $invocation->proceed();
        }
        
        $retry = $retryAttrs[0]->newInstance();
        
        return $this->executeWithRetry($invocation, $retry);
    }
    
    private function executeWithRetry(MethodInvocation $invocation, Retry $config): mixed
    {
        $attempts = 0;
        $lastException = null;
        
        while ($attempts < $config->maxAttempts) {
            $attempts++;
            
            try {
                $result = $invocation->proceed();
                
                // 成功した場合、リトライ情報をログ出力
                if ($attempts > 1) {
                    $this->logger->info("Method succeeded after {$attempts} attempts", [
                        'method' => $invocation->getMethod()->getName(),
                        'class' => get_class($invocation->getThis())
                    ]);
                }
                
                return $result;
                
            } catch (Exception $e) {
                $lastException = $e;
                
                // リトライ可能な例外かチェック
                if (!$this->isRetryableException($e, $config)) {
                    throw $e;
                }
                
                // 最後の試行でない場合は待機
                if ($attempts < $config->maxAttempts) {
                    $delay = $this->calculateDelay($attempts, $config);
                    
                    $this->logger->warning("Method failed, retrying in {$delay}ms", [
                        'method' => $invocation->getMethod()->getName(),
                        'class' => get_class($invocation->getThis()),
                        'attempt' => $attempts,
                        'max_attempts' => $config->maxAttempts,
                        'exception' => get_class($e),
                        'message' => $e->getMessage()
                    ]);
                    
                    usleep($delay * 1000); // マイクロ秒に変換
                }
            }
        }
        
        // 全ての試行が失敗した場合
        $this->logger->error("Method failed after {$attempts} attempts", [
            'method' => $invocation->getMethod()->getName(),
            'class' => get_class($invocation->getThis()),
            'final_exception' => get_class($lastException),
            'message' => $lastException->getMessage()
        ]);
        
        throw new RetryExhaustedException(
            "Method failed after {$attempts} attempts",
            0,
            $lastException
        );
    }
    
    private function isRetryableException(Exception $e, Retry $config): bool
    {
        // 設定された例外クラスに一致するかチェック
        foreach ($config->retryOn as $exceptionClass) {
            if ($e instanceof $exceptionClass) {
                return true;
            }
        }
        
        return false;
    }
    
    private function calculateDelay(int $attempt, Retry $config): int
    {
        return match($config->backoffStrategy) {
            'fixed' => $config->delay,
            'linear' => $config->delay * $attempt,
            'exponential' => $config->delay * (2 ** ($attempt - 1)),
            'random' => rand($config->delay, $config->delay * 2),
            default => $config->delay
        };
    }
}

#[Attribute]
class Retry
{
    public function __construct(
        public readonly int $maxAttempts = 3,
        public readonly int $delay = 1000, // ミリ秒
        public readonly string $backoffStrategy = 'exponential',
        public readonly array $retryOn = [Exception::class]
    ) {}
}

// 使用例
class ExternalAPIService
{
    #[Retry(
        maxAttempts: 5,
        delay: 500,
        backoffStrategy: 'exponential',
        retryOn: [NetworkException::class, TimeoutException::class]
    )]
    public function fetchUserData(int $userId): array
    {
        // 外部API呼び出し（失敗する可能性がある）
        return $this->httpClient->get("/users/{$userId}");
    }
}
```

### 3. 回路ブレーカーインターセプター

```php
class CircuitBreakerInterceptor implements MethodInterceptor
{
    private array $circuits = [];
    
    public function __construct(
        private CacheInterface $cache,
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $cbAttrs = $method->getAttributes(CircuitBreaker::class);
        
        if (empty($cbAttrs)) {
            return $invocation->proceed();
        }
        
        $config = $cbAttrs[0]->newInstance();
        $circuitKey = $this->getCircuitKey($invocation, $config);
        
        return $this->executeWithCircuitBreaker($invocation, $config, $circuitKey);
    }
    
    private function executeWithCircuitBreaker(MethodInvocation $invocation, CircuitBreaker $config, string $circuitKey): mixed
    {
        $state = $this->getCircuitState($circuitKey, $config);
        
        switch ($state['status']) {
            case 'OPEN':
                if (time() - $state['opened_at'] < $config->timeout) {
                    throw new CircuitOpenException("Circuit breaker is OPEN for {$circuitKey}");
                }
                // タイムアウト後はHALF_OPENに移行
                $this->setCircuitState($circuitKey, 'HALF_OPEN');
                return $this->executeInHalfOpenState($invocation, $config, $circuitKey);
                
            case 'HALF_OPEN':
                return $this->executeInHalfOpenState($invocation, $config, $circuitKey);
                
            case 'CLOSED':
            default:
                return $this->executeInClosedState($invocation, $config, $circuitKey);
        }
    }
    
    private function executeInClosedState(MethodInvocation $invocation, CircuitBreaker $config, string $circuitKey): mixed
    {
        try {
            $result = $invocation->proceed();
            
            // 成功時は成功カウンターをリセット
            $this->recordSuccess($circuitKey);
            
            return $result;
            
        } catch (Exception $e) {
            $this->recordFailure($circuitKey, $config);
            
            $state = $this->getCircuitState($circuitKey, $config);
            if ($state['failure_count'] >= $config->failureThreshold) {
                $this->openCircuit($circuitKey);
                $this->logger->warning("Circuit breaker opened for {$circuitKey}", [
                    'failure_count' => $state['failure_count'],
                    'threshold' => $config->failureThreshold
                ]);
            }
            
            throw $e;
        }
    }
    
    private function executeInHalfOpenState(MethodInvocation $invocation, CircuitBreaker $config, string $circuitKey): mixed
    {
        try {
            $result = $invocation->proceed();
            
            // 成功時はCLOSEDに移行
            $this->closeCircuit($circuitKey);
            $this->logger->info("Circuit breaker closed for {$circuitKey}");
            
            return $result;
            
        } catch (Exception $e) {
            // 失敗時はOPENに戻る
            $this->openCircuit($circuitKey);
            $this->logger->warning("Circuit breaker reopened for {$circuitKey}");
            
            throw $e;
        }
    }
    
    private function getCircuitKey(MethodInvocation $invocation, CircuitBreaker $config): string
    {
        $class = get_class($invocation->getThis());
        $method = $invocation->getMethod()->getName();
        
        if ($config->key) {
            return $config->key;
        }
        
        return "circuit_breaker:{$class}:{$method}";
    }
    
    private function getCircuitState(string $key, CircuitBreaker $config): array
    {
        return $this->cache->get($key, [
            'status' => 'CLOSED',
            'failure_count' => 0,
            'opened_at' => null
        ]);
    }
    
    private function setCircuitState(string $key, string $status, array $additionalData = []): void
    {
        $state = $this->getCircuitState($key, new CircuitBreaker());
        $state['status'] = $status;
        $state = array_merge($state, $additionalData);
        
        $this->cache->set($key, $state, 3600);
    }
    
    private function recordFailure(string $key, CircuitBreaker $config): void
    {
        $state = $this->getCircuitState($key, $config);
        $state['failure_count']++;
        $this->cache->set($key, $state, 3600);
    }
    
    private function recordSuccess(string $key): void
    {
        $state = $this->getCircuitState($key, new CircuitBreaker());
        $state['failure_count'] = 0;
        $this->cache->set($key, $state, 3600);
    }
    
    private function openCircuit(string $key): void
    {
        $this->setCircuitState($key, 'OPEN', ['opened_at' => time()]);
    }
    
    private function closeCircuit(string $key): void
    {
        $this->setCircuitState($key, 'CLOSED', ['failure_count' => 0, 'opened_at' => null]);
    }
}

#[Attribute]
class CircuitBreaker
{
    public function __construct(
        public readonly int $failureThreshold = 5,
        public readonly int $timeout = 60, // 秒
        public readonly string $key = ''
    ) {}
}
```

## E-commerceでの実践的活用

### 1. 注文処理の包括的インターセプター

```php
class OrderProcessingInterceptor implements MethodInterceptor
{
    public function __construct(
        private LoggerInterface $logger,
        private MetricsCollectorInterface $metrics,
        private NotificationServiceInterface $notifications,
        private AuditServiceInterface $audit
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $methodName = $method->getName();
        
        // 注文関連メソッドのみ処理
        if (!$this->isOrderMethod($methodName)) {
            return $invocation->proceed();
        }
        
        $context = $this->createProcessingContext($invocation);
        
        try {
            // 前処理
            $this->beforeProcessing($context);
            
            // メイン処理
            $result = $invocation->proceed();
            
            // 後処理（成功）
            $this->afterSuccessfulProcessing($context, $result);
            
            return $result;
            
        } catch (Exception $e) {
            // 後処理（失敗）
            $this->afterFailedProcessing($context, $e);
            throw $e;
        }
    }
    
    private function isOrderMethod(string $methodName): bool
    {
        return in_array($methodName, [
            'createOrder',
            'updateOrder',
            'cancelOrder',
            'processPayment',
            'fulfillOrder',
            'refundOrder'
        ]);
    }
    
    private function createProcessingContext(MethodInvocation $invocation): array
    {
        $method = $invocation->getMethod();
        $arguments = $invocation->getArguments();
        
        return [
            'method' => $method->getName(),
            'class' => get_class($invocation->getThis()),
            'arguments' => $arguments,
            'start_time' => microtime(true),
            'transaction_id' => uniqid('txn_', true),
            'user_id' => $this->getCurrentUserId(),
            'session_id' => session_id()
        ];
    }
    
    private function beforeProcessing(array $context): void
    {
        // 監査ログ
        $this->audit->recordMethodCall([
            'transaction_id' => $context['transaction_id'],
            'method' => $context['method'],
            'user_id' => $context['user_id'],
            'arguments' => $this->sanitizeArguments($context['arguments']),
            'timestamp' => date('Y-m-d H:i:s')
        ]);
        
        // メトリクス
        $this->metrics->increment("order.method.{$context['method']}.attempts");
        
        // ログ
        $this->logger->info("Order processing started", [
            'transaction_id' => $context['transaction_id'],
            'method' => $context['method'],
            'user_id' => $context['user_id']
        ]);
    }
    
    private function afterSuccessfulProcessing(array $context, mixed $result): void
    {
        $duration = microtime(true) - $context['start_time'];
        
        // メトリクス
        $this->metrics->increment("order.method.{$context['method']}.success");
        $this->metrics->timing("order.method.{$context['method']}.duration", $duration * 1000);
        
        // 監査ログ
        $this->audit->recordMethodSuccess([
            'transaction_id' => $context['transaction_id'],
            'duration' => $duration,
            'result_type' => is_object($result) ? get_class($result) : gettype($result)
        ]);
        
        // 通知（特定のメソッドのみ）
        if (in_array($context['method'], ['createOrder', 'cancelOrder', 'refundOrder'])) {
            $this->sendNotification($context['method'], $result, $context['user_id']);
        }
        
        // ログ
        $this->logger->info("Order processing completed", [
            'transaction_id' => $context['transaction_id'],
            'method' => $context['method'],
            'duration' => round($duration * 1000, 2) . 'ms'
        ]);
    }
    
    private function afterFailedProcessing(array $context, Exception $e): void
    {
        $duration = microtime(true) - $context['start_time'];
        
        // メトリクス
        $this->metrics->increment("order.method.{$context['method']}.failure");
        $this->metrics->increment("order.exception." . get_class($e));
        
        // 監査ログ
        $this->audit->recordMethodFailure([
            'transaction_id' => $context['transaction_id'],
            'duration' => $duration,
            'exception' => get_class($e),
            'message' => $e->getMessage(),
            'trace' => $e->getTraceAsString()
        ]);
        
        // 重要なエラーの場合は即座に通知
        if ($this->isCriticalError($e)) {
            $this->notifications->sendCriticalAlert([
                'transaction_id' => $context['transaction_id'],
                'method' => $context['method'],
                'error' => get_class($e),
                'message' => $e->getMessage(),
                'user_id' => $context['user_id']
            ]);
        }
        
        // ログ
        $this->logger->error("Order processing failed", [
            'transaction_id' => $context['transaction_id'],
            'method' => $context['method'],
            'exception' => get_class($e),
            'message' => $e->getMessage(),
            'duration' => round($duration * 1000, 2) . 'ms'
        ]);
    }
    
    private function sanitizeArguments(array $arguments): array
    {
        // 機密情報を除去
        return array_map(function ($arg) {
            if (is_array($arg)) {
                unset($arg['password'], $arg['credit_card'], $arg['cvv']);
                return $arg;
            }
            return $arg;
        }, $arguments);
    }
    
    private function getCurrentUserId(): ?int
    {
        // セキュリティコンテキストからユーザーIDを取得
        return $_SESSION['user_id'] ?? null;
    }
    
    private function sendNotification(string $method, mixed $result, ?int $userId): void
    {
        if (!$userId) return;
        
        $message = match($method) {
            'createOrder' => "Order #{$result->getId()} has been created successfully",
            'cancelOrder' => "Order #{$result->getId()} has been cancelled",
            'refundOrder' => "Refund for order #{$result->getId()} has been processed",
            default => null
        };
        
        if ($message) {
            $this->notifications->sendToUser($userId, $message);
        }
    }
    
    private function isCriticalError(Exception $e): bool
    {
        return $e instanceof PaymentFailedException ||
               $e instanceof DatabaseConnectionException ||
               $e instanceof SecurityException;
    }
}
```

### 2. データベース操作の最適化インターセプター

```php
class DatabaseOptimizationInterceptor implements MethodInterceptor
{
    private array $queryCache = [];
    private array $connectionPool = [];
    
    public function __construct(
        private DatabaseManagerInterface $dbManager,
        private CacheInterface $cache,
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $optimizationAttrs = $method->getAttributes(OptimizeDB::class);
        
        if (empty($optimizationAttrs)) {
            return $invocation->proceed();
        }
        
        $config = $optimizationAttrs[0]->newInstance();
        
        return $this->executeWithOptimization($invocation, $config);
    }
    
    private function executeWithOptimization(MethodInvocation $invocation, OptimizeDB $config): mixed
    {
        // 読み取り専用操作の場合はレプリカを使用
        if ($config->readOnly) {
            $this->switchToReadReplica();
        }
        
        // クエリキャッシュを確認
        if ($config->cacheable) {
            $cacheKey = $this->generateCacheKey($invocation, $config);
            $cached = $this->cache->get($cacheKey);
            
            if ($cached !== null) {
                $this->logger->debug("Database query cache hit", ['key' => $cacheKey]);
                return $cached;
            }
        }
        
        // バッチ処理の開始
        if ($config->batch) {
            $this->dbManager->beginBatch();
        }
        
        // 接続プールの管理
        $connection = $this->getOptimalConnection($config);
        
        try {
            $startTime = microtime(true);
            
            $result = $invocation->proceed();
            
            $duration = microtime(true) - $startTime;
            
            // 遅いクエリの警告
            if ($duration > $config->slowQueryThreshold) {
                $this->logger->warning("Slow database query detected", [
                    'method' => $invocation->getMethod()->getName(),
                    'duration' => round($duration * 1000, 2) . 'ms',
                    'threshold' => $config->slowQueryThreshold * 1000 . 'ms'
                ]);
            }
            
            // 結果をキャッシュ
            if ($config->cacheable && $result !== null) {
                $this->cache->set($cacheKey, $result, $config->cacheLifetime);
            }
            
            // バッチ処理の終了
            if ($config->batch) {
                $this->dbManager->commitBatch();
            }
            
            return $result;
            
        } catch (Exception $e) {
            if ($config->batch) {
                $this->dbManager->rollbackBatch();
            }
            
            throw $e;
        } finally {
            $this->returnConnection($connection);
        }
    }
    
    private function switchToReadReplica(): void
    {
        $this->dbManager->switchToReadReplica();
    }
    
    private function generateCacheKey(MethodInvocation $invocation, OptimizeDB $config): string
    {
        if ($config->cacheKey) {
            return $config->cacheKey;
        }
        
        $method = $invocation->getMethod();
        $class = get_class($invocation->getThis());
        $arguments = $invocation->getArguments();
        
        $argsHash = md5(serialize($arguments));
        
        return "db_cache:{$class}:{$method->getName()}:{$argsHash}";
    }
    
    private function getOptimalConnection(OptimizeDB $config): DatabaseConnection
    {
        // 接続プールから最適な接続を取得
        foreach ($this->connectionPool as $connection) {
            if ($connection->isAvailable() && $connection->matchesRequirements($config)) {
                $connection->setInUse(true);
                return $connection;
            }
        }
        
        // 新しい接続を作成
        $connection = $this->dbManager->createConnection($config);
        $this->connectionPool[] = $connection;
        
        return $connection;
    }
    
    private function returnConnection(DatabaseConnection $connection): void
    {
        $connection->setInUse(false);
    }
}

#[Attribute]
class OptimizeDB
{
    public function __construct(
        public readonly bool $readOnly = false,
        public readonly bool $cacheable = false,
        public readonly int $cacheLifetime = 3600,
        public readonly string $cacheKey = '',
        public readonly bool $batch = false,
        public readonly float $slowQueryThreshold = 1.0
    ) {}
}
```

## デバッグとトラブルシューティング

### 1. デバッグ用インターセプター

```php
class DebugInterceptor implements MethodInterceptor
{
    private static array $callStack = [];
    private static int $depth = 0;
    
    public function __construct(
        private LoggerInterface $logger,
        private bool $enabled
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        if (!$this->enabled) {
            return $invocation->proceed();
        }
        
        $method = $invocation->getMethod();
        $class = get_class($invocation->getThis());
        $methodName = "{$class}::{$method->getName()}";
        
        self::$depth++;
        $indent = str_repeat('  ', self::$depth - 1);
        $callId = uniqid('call_', true);
        
        // 呼び出し開始
        $this->logger->debug("{$indent}→ Entering {$methodName}", [
            'call_id' => $callId,
            'depth' => self::$depth,
            'arguments' => $this->formatArguments($invocation->getArguments())
        ]);
        
        self::$callStack[] = [
            'method' => $methodName,
            'call_id' => $callId,
            'start_time' => microtime(true),
            'depth' => self::$depth
        ];
        
        try {
            $result = $invocation->proceed();
            
            $duration = microtime(true) - end(self::$callStack)['start_time'];
            
            // 呼び出し終了（成功）
            $this->logger->debug("{$indent}← Exiting {$methodName} (success)", [
                'call_id' => $callId,
                'duration' => round($duration * 1000, 2) . 'ms',
                'result_type' => is_object($result) ? get_class($result) : gettype($result)
            ]);
            
            array_pop(self::$callStack);
            self::$depth--;
            
            return $result;
            
        } catch (Exception $e) {
            $duration = microtime(true) - end(self::$callStack)['start_time'];
            
            // 呼び出し終了（例外）
            $this->logger->debug("{$indent}← Exiting {$methodName} (exception)", [
                'call_id' => $callId,
                'duration' => round($duration * 1000, 2) . 'ms',
                'exception' => get_class($e),
                'message' => $e->getMessage()
            ]);
            
            // 呼び出しスタックを出力
            $this->logger->debug("Call stack at exception:", [
                'stack' => array_map(fn($call) => $call['method'], self::$callStack)
            ]);
            
            array_pop(self::$callStack);
            self::$depth--;
            
            throw $e;
        }
    }
    
    private function formatArguments(array $arguments): array
    {
        return array_map(function ($arg, $index) {
            if (is_object($arg)) {
                return "#{$index}: " . get_class($arg) . " object";
            } elseif (is_array($arg)) {
                return "#{$index}: array[" . count($arg) . "]";
            } elseif (is_string($arg) && strlen($arg) > 100) {
                return "#{$index}: string(" . strlen($arg) . ") '" . substr($arg, 0, 100) . "...'";
            } else {
                return "#{$index}: " . var_export($arg, true);
            }
        }, $arguments, array_keys($arguments));
    }
    
    public static function getCurrentCallStack(): array
    {
        return self::$callStack;
    }
    
    public static function getCallDepth(): int
    {
        return self::$depth;
    }
}
```

## 次のステップ

メソッドインターセプターの詳細実装を理解したので、次に進む準備が整いました。

1. **共通の横断的関心事の学習**: 実践的なAOPパターンライブラリ
2. **実世界の例での練習**: 複雑なアプリケーションでの活用方法
3. **パフォーマンス最適化**: 大規模システムでのAOP活用

**続きは:** [共通の横断的関心事](cross-cutting-concerns.html)

## 重要なポイント

- **MethodInvocation**により詳細なメソッド情報にアクセス
- **引数の操作**と結果の変更が可能
- **条件付き実行**により柔軟な制御を実現
- **リトライ**と**回路ブレーカー**で堅牢性を向上
- **デバッグ機能**でトラブルシューティングを支援
- **パフォーマンス監視**で最適化ポイントを特定

---

高度なメソッドインターセプターにより、複雑なビジネス要件に対応しながら、保守しやすく堅牢なアプリケーションを構築できます。適切なパターンの組み合わせが、品質の高いソフトウェアの鍵となります。