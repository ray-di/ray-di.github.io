---
layout: docs-ja
title: 共通の横断的関心事
category: Manual
permalink: /manuals/1.0/ja/tutorial/05-aop-interceptors/cross-cutting-concerns.html
---

# 共通の横断的関心事

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- 横断的関心事の識別と分離方法
- 一般的な横断的関心事の実装パターン
- E-commerceアプリケーションでの実践的活用
- 複数の関心事の組み合わせと管理
- パフォーマンスとメンテナンス性の最適化

## 横断的関心事とは

### 1. 横断的関心事の定義と例

```php
// 横断的関心事が混在したコード（悪い例）
class ProductService
{
    public function updatePrice(int $productId, float $newPrice): void
    {
        // ログ（横断的関心事）
        error_log("Updating price for product {$productId}");
        
        // セキュリティチェック（横断的関心事）
        if (!$this->hasPermission('product:update')) {
            throw new UnauthorizedException();
        }
        
        // バリデーション（横断的関心事）
        if ($newPrice < 0) {
            throw new InvalidArgumentException('Price cannot be negative');
        }
        
        // トランザクション開始（横断的関心事）
        $this->db->beginTransaction();
        
        try {
            // キャッシュ無効化（横断的関心事）
            $this->cache->delete("product:{$productId}");
            
            // ビジネスロジック（核心的関心事）
            $product = $this->repository->find($productId);
            $oldPrice = $product->getPrice();
            $product->setPrice($newPrice);
            $this->repository->save($product);
            
            // 監査ログ（横断的関心事）
            $this->audit->log('price_change', [
                'product_id' => $productId,
                'old_price' => $oldPrice,
                'new_price' => $newPrice,
                'user' => $this->currentUser
            ]);
            
            // トランザクションコミット（横断的関心事）
            $this->db->commit();
            
            // 通知（横断的関心事）
            $this->notifier->notify('price_updated', $product);
            
        } catch (Exception $e) {
            // エラーハンドリング（横断的関心事）
            $this->db->rollback();
            error_log("Failed to update price: " . $e->getMessage());
            throw $e;
        }
    }
}

// AOPで分離したコード（良い例）
class ProductService
{
    #[Logged]
    #[Authorized('product:update')]
    #[Validated]
    #[Transactional]
    #[CacheEvict('product:{productId}')]
    #[Audited('price_change')]
    #[Notify('price_updated')]
    public function updatePrice(int $productId, float $newPrice): void
    {
        // ビジネスロジックのみ
        $product = $this->repository->find($productId);
        $product->setPrice($newPrice);
        $this->repository->save($product);
    }
}
```

### 2. 一般的な横断的関心事

```php
// 横断的関心事のカテゴリー
interface CrossCuttingConcerns
{
    // インフラストラクチャ関連
    const LOGGING = 'logging';
    const CACHING = 'caching';
    const TRANSACTION = 'transaction';
    
    // セキュリティ関連
    const AUTHENTICATION = 'authentication';
    const AUTHORIZATION = 'authorization';
    const ENCRYPTION = 'encryption';
    
    // 監視・分析関連
    const MONITORING = 'monitoring';
    const AUDITING = 'auditing';
    const ANALYTICS = 'analytics';
    
    // エラー処理関連
    const ERROR_HANDLING = 'error_handling';
    const RETRY = 'retry';
    const CIRCUIT_BREAKER = 'circuit_breaker';
    
    // パフォーマンス関連
    const RATE_LIMITING = 'rate_limiting';
    const THROTTLING = 'throttling';
    const LAZY_LOADING = 'lazy_loading';
    
    // ビジネスルール関連
    const VALIDATION = 'validation';
    const NOTIFICATION = 'notification';
    const WORKFLOW = 'workflow';
}
```

## ログとモニタリング

### 1. 構造化ログインターセプター

```php
class StructuredLoggingInterceptor implements MethodInterceptor
{
    public function __construct(
        private LoggerInterface $logger,
        private RequestContextInterface $context
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $metadata = $this->extractMetadata($invocation);
        $correlationId = $this->context->getCorrelationId();
        
        // 構造化ログエントリの作成
        $logEntry = [
            'timestamp' => microtime(true),
            'correlation_id' => $correlationId,
            'class' => $metadata['class'],
            'method' => $metadata['method'],
            'arguments' => $this->sanitizeArguments($invocation->getArguments()),
            'user_id' => $this->context->getUserId(),
            'session_id' => $this->context->getSessionId(),
            'request_id' => $this->context->getRequestId()
        ];
        
        $this->logger->info('Method invocation started', $logEntry);
        
        $startTime = microtime(true);
        
        try {
            $result = $invocation->proceed();
            
            $logEntry['duration_ms'] = (microtime(true) - $startTime) * 1000;
            $logEntry['status'] = 'success';
            $logEntry['result_type'] = is_object($result) ? get_class($result) : gettype($result);
            
            $this->logger->info('Method invocation completed', $logEntry);
            
            return $result;
            
        } catch (Exception $e) {
            $logEntry['duration_ms'] = (microtime(true) - $startTime) * 1000;
            $logEntry['status'] = 'error';
            $logEntry['error'] = [
                'type' => get_class($e),
                'message' => $e->getMessage(),
                'code' => $e->getCode(),
                'file' => $e->getFile(),
                'line' => $e->getLine()
            ];
            
            $this->logger->error('Method invocation failed', $logEntry);
            
            throw $e;
        }
    }
    
    private function extractMetadata(MethodInvocation $invocation): array
    {
        $method = $invocation->getMethod();
        $class = get_class($invocation->getThis());
        
        return [
            'class' => $class,
            'method' => $method->getName(),
            'namespace' => (new \ReflectionClass($class))->getNamespaceName()
        ];
    }
    
    private function sanitizeArguments(array $arguments): array
    {
        return array_map(function ($arg) {
            if (is_object($arg)) {
                return ['type' => 'object', 'class' => get_class($arg)];
            }
            if (is_array($arg)) {
                // 機密情報を除去
                $sanitized = $arg;
                unset($sanitized['password'], $sanitized['token'], $sanitized['secret']);
                return $sanitized;
            }
            if (is_string($arg) && strlen($arg) > 1000) {
                return substr($arg, 0, 1000) . '... (truncated)';
            }
            return $arg;
        }, $arguments);
    }
}
```

### 2. メトリクス収集インターセプター

```php
class MetricsCollectorInterceptor implements MethodInterceptor
{
    private array $customTags = [];
    
    public function __construct(
        private MetricsInterface $metrics,
        private ThresholdConfigInterface $thresholds
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $metricName = $this->generateMetricName($invocation);
        $tags = $this->extractTags($invocation);
        
        // カウンター: メソッド呼び出し回数
        $this->metrics->increment($metricName . '.calls', 1, $tags);
        
        // ゲージ: 同時実行数
        $this->metrics->increment($metricName . '.concurrent', 1, $tags);
        
        $startTime = microtime(true);
        $startMemory = memory_get_usage(true);
        
        try {
            $result = $invocation->proceed();
            
            $this->recordSuccess($metricName, $startTime, $startMemory, $tags);
            
            return $result;
            
        } catch (Exception $e) {
            $this->recordFailure($metricName, $startTime, $startMemory, $e, $tags);
            throw $e;
        } finally {
            $this->metrics->decrement($metricName . '.concurrent', 1, $tags);
        }
    }
    
    private function generateMetricName(MethodInvocation $invocation): string
    {
        $class = get_class($invocation->getThis());
        $method = $invocation->getMethod()->getName();
        
        // クラス名をメトリクス名に変換
        $className = str_replace('\\', '.', $class);
        
        return strtolower("app.method.{$className}.{$method}");
    }
    
    private function extractTags(MethodInvocation $invocation): array
    {
        $method = $invocation->getMethod();
        $tags = [
            'class' => get_class($invocation->getThis()),
            'method' => $method->getName()
        ];
        
        // カスタムタグの抽出
        $tagAttrs = $method->getAttributes(MetricTag::class);
        foreach ($tagAttrs as $attr) {
            $tag = $attr->newInstance();
            $tags[$tag->name] = $tag->value;
        }
        
        return array_merge($tags, $this->customTags);
    }
    
    private function recordSuccess(string $metricName, float $startTime, int $startMemory, array $tags): void
    {
        $duration = (microtime(true) - $startTime) * 1000;
        $memoryUsed = memory_get_usage(true) - $startMemory;
        
        // タイミング
        $this->metrics->timing($metricName . '.duration', $duration, $tags);
        
        // メモリ使用量
        $this->metrics->gauge($metricName . '.memory', $memoryUsed, $tags);
        
        // 成功カウント
        $this->metrics->increment($metricName . '.success', 1, $tags);
        
        // SLO違反チェック
        $threshold = $this->thresholds->getDurationThreshold($metricName);
        if ($threshold && $duration > $threshold) {
            $this->metrics->increment($metricName . '.slo_violation', 1, $tags);
        }
    }
    
    private function recordFailure(string $metricName, float $startTime, int $startMemory, Exception $e, array $tags): void
    {
        $duration = (microtime(true) - $startTime) * 1000;
        $errorTags = array_merge($tags, [
            'error_type' => get_class($e),
            'error_code' => $e->getCode()
        ]);
        
        // エラーカウント
        $this->metrics->increment($metricName . '.error', 1, $errorTags);
        
        // エラー時のタイミング
        $this->metrics->timing($metricName . '.error_duration', $duration, $errorTags);
    }
    
    public function setCustomTags(array $tags): void
    {
        $this->customTags = $tags;
    }
}

#[Attribute]
class MetricTag
{
    public function __construct(
        public readonly string $name,
        public readonly string $value
    ) {}
}
```

## セキュリティとアクセス制御

### 1. 多層セキュリティインターセプター

```php
class SecurityInterceptor implements MethodInterceptor
{
    public function __construct(
        private SecurityManagerInterface $securityManager,
        private AuditLoggerInterface $auditLogger,
        private RateLimiterInterface $rateLimiter
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $securityContext = $this->createSecurityContext($invocation);
        
        // 1. 認証チェック
        $this->checkAuthentication($securityContext);
        
        // 2. レート制限チェック
        $this->checkRateLimit($securityContext);
        
        // 3. 認可チェック
        $this->checkAuthorization($securityContext);
        
        // 4. データアクセス制御
        $this->applyDataAccessControl($securityContext);
        
        // 5. 監査ログ（アクセス試行）
        $this->auditLogger->logAccess($securityContext);
        
        try {
            // 6. セキュリティコンテキストの設定
            $this->securityManager->setContext($securityContext);
            
            $result = $invocation->proceed();
            
            // 7. 結果のフィルタリング（機密情報の除去）
            $filteredResult = $this->filterSensitiveData($result, $securityContext);
            
            // 8. 監査ログ（成功）
            $this->auditLogger->logSuccess($securityContext, $filteredResult);
            
            return $filteredResult;
            
        } catch (Exception $e) {
            // 9. セキュリティ例外の処理
            $this->handleSecurityException($e, $securityContext);
            throw $e;
        } finally {
            // 10. セキュリティコンテキストのクリア
            $this->securityManager->clearContext();
        }
    }
    
    private function createSecurityContext(MethodInvocation $invocation): SecurityContext
    {
        $method = $invocation->getMethod();
        $securityAttrs = $method->getAttributes(Secured::class);
        
        return new SecurityContext([
            'method' => $method->getName(),
            'class' => get_class($invocation->getThis()),
            'user' => $this->securityManager->getCurrentUser(),
            'ip_address' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
            'timestamp' => new DateTime(),
            'requirements' => $securityAttrs ? $securityAttrs[0]->newInstance() : null,
            'arguments' => $invocation->getArguments()
        ]);
    }
    
    private function checkAuthentication(SecurityContext $context): void
    {
        if (!$context->requirements) {
            return;
        }
        
        if ($context->requirements->requiresAuthentication && !$context->user) {
            throw new AuthenticationException('Authentication required');
        }
    }
    
    private function checkRateLimit(SecurityContext $context): void
    {
        if (!$context->requirements || !$context->requirements->rateLimit) {
            return;
        }
        
        $key = $this->getRateLimitKey($context);
        if (!$this->rateLimiter->allowRequest($key, $context->requirements->rateLimit)) {
            throw new RateLimitExceededException('Rate limit exceeded');
        }
    }
    
    private function checkAuthorization(SecurityContext $context): void
    {
        if (!$context->requirements || empty($context->requirements->roles)) {
            return;
        }
        
        $userRoles = $context->user ? $context->user->getRoles() : [];
        $requiredRoles = $context->requirements->roles;
        
        if (!array_intersect($userRoles, $requiredRoles)) {
            throw new AuthorizationException('Insufficient permissions');
        }
    }
    
    private function applyDataAccessControl(SecurityContext $context): void
    {
        if (!$context->requirements || !$context->requirements->dataAccessControl) {
            return;
        }
        
        // データアクセス制御ルールの適用
        $this->securityManager->applyDataFilters($context);
    }
    
    private function filterSensitiveData(mixed $result, SecurityContext $context): mixed
    {
        if (!$context->requirements || !$context->requirements->filterSensitiveData) {
            return $result;
        }
        
        return $this->securityManager->filterSensitiveFields($result);
    }
    
    private function handleSecurityException(Exception $e, SecurityContext $context): void
    {
        $this->auditLogger->logSecurityException($context, $e);
        
        // セキュリティアラートの送信
        if ($this->isSecurityThreat($e)) {
            $this->securityManager->raiseSecurityAlert($context, $e);
        }
    }
    
    private function getRateLimitKey(SecurityContext $context): string
    {
        $user = $context->user;
        if ($user) {
            return "rate_limit:user:{$user->getId()}:{$context->class}:{$context->method}";
        }
        
        return "rate_limit:ip:{$context->ip_address}:{$context->class}:{$context->method}";
    }
    
    private function isSecurityThreat(Exception $e): bool
    {
        return $e instanceof AuthenticationException ||
               $e instanceof AuthorizationException ||
               $e instanceof SecurityException;
    }
}

#[Attribute]
class Secured
{
    public function __construct(
        public readonly bool $requiresAuthentication = true,
        public readonly array $roles = [],
        public readonly ?int $rateLimit = null,
        public readonly bool $dataAccessControl = false,
        public readonly bool $filterSensitiveData = true
    ) {}
}
```

### 2. データ暗号化インターセプター

```php
class EncryptionInterceptor implements MethodInterceptor
{
    public function __construct(
        private EncryptionServiceInterface $encryptionService,
        private KeyManagementInterface $keyManager
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $encryptAttrs = $method->getAttributes(Encrypt::class);
        
        if (empty($encryptAttrs)) {
            return $invocation->proceed();
        }
        
        $config = $encryptAttrs[0]->newInstance();
        
        // 引数の暗号化
        $encryptedArgs = $this->encryptArguments($invocation->getArguments(), $config);
        
        // 暗号化された引数で実行
        $result = $this->invokeWithEncryptedArgs($invocation, $encryptedArgs);
        
        // 結果の暗号化/復号化
        return $this->processResult($result, $config);
    }
    
    private function encryptArguments(array $arguments, Encrypt $config): array
    {
        if (!$config->encryptInput) {
            return $arguments;
        }
        
        return array_map(function ($arg) use ($config) {
            if ($this->shouldEncrypt($arg, $config)) {
                return $this->encryptionService->encrypt($arg, $this->getEncryptionKey($config));
            }
            return $arg;
        }, $arguments);
    }
    
    private function processResult(mixed $result, Encrypt $config): mixed
    {
        if ($config->encryptOutput && $result !== null) {
            return $this->encryptionService->encrypt($result, $this->getEncryptionKey($config));
        }
        
        if ($config->decryptOutput && is_string($result)) {
            return $this->encryptionService->decrypt($result, $this->getEncryptionKey($config));
        }
        
        return $result;
    }
    
    private function shouldEncrypt(mixed $value, Encrypt $config): bool
    {
        if (is_array($value) || is_object($value)) {
            return in_array('complex', $config->types);
        }
        
        if (is_string($value)) {
            return in_array('string', $config->types);
        }
        
        return false;
    }
    
    private function getEncryptionKey(Encrypt $config): string
    {
        return $this->keyManager->getKey($config->keyId ?? 'default');
    }
    
    private function invokeWithEncryptedArgs(MethodInvocation $invocation, array $encryptedArgs): mixed
    {
        // 実装は元のinvocationの引数を置き換えて実行
        $method = $invocation->getMethod();
        $object = $invocation->getThis();
        
        return $method->invokeArgs($object, $encryptedArgs);
    }
}

#[Attribute]
class Encrypt
{
    public function __construct(
        public readonly bool $encryptInput = false,
        public readonly bool $encryptOutput = false,
        public readonly bool $decryptOutput = false,
        public readonly array $types = ['string', 'complex'],
        public readonly ?string $keyId = null
    ) {}
}
```

## キャッシュと最適化

### 1. インテリジェントキャッシュインターセプター

```php
class IntelligentCacheInterceptor implements MethodInterceptor
{
    private array $statistics = [];
    
    public function __construct(
        private CacheInterface $cache,
        private CacheStrategyInterface $strategy,
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $cacheConfig = $this->extractCacheConfig($invocation);
        
        if (!$cacheConfig) {
            return $invocation->proceed();
        }
        
        $cacheKey = $this->generateCacheKey($invocation, $cacheConfig);
        
        // キャッシュ統計の更新
        $this->updateStatistics($cacheKey, 'request');
        
        // キャッシュから取得
        $cached = $this->getFromCache($cacheKey, $cacheConfig);
        if ($cached !== null) {
            $this->updateStatistics($cacheKey, 'hit');
            return $cached;
        }
        
        // キャッシュミス
        $this->updateStatistics($cacheKey, 'miss');
        
        // 実際のメソッド実行
        $startTime = microtime(true);
        $result = $invocation->proceed();
        $executionTime = microtime(true) - $startTime;
        
        // キャッシュ戦略に基づいて保存判断
        if ($this->shouldCache($result, $executionTime, $cacheConfig)) {
            $this->saveToCache($cacheKey, $result, $cacheConfig);
        }
        
        return $result;
    }
    
    private function extractCacheConfig(MethodInvocation $invocation): ?CacheConfig
    {
        $method = $invocation->getMethod();
        
        // @Cacheable アトリビュート
        $cacheableAttrs = $method->getAttributes(Cacheable::class);
        if (!empty($cacheableAttrs)) {
            return CacheConfig::fromCacheable($cacheableAttrs[0]->newInstance());
        }
        
        // @CacheEvict アトリビュート
        $evictAttrs = $method->getAttributes(CacheEvict::class);
        if (!empty($evictAttrs)) {
            $evict = $evictAttrs[0]->newInstance();
            $this->evictCache($invocation, $evict);
            return null;
        }
        
        return null;
    }
    
    private function generateCacheKey(MethodInvocation $invocation, CacheConfig $config): string
    {
        if ($config->key) {
            return $this->parseKeyExpression($config->key, $invocation);
        }
        
        $class = get_class($invocation->getThis());
        $method = $invocation->getMethod()->getName();
        $args = $invocation->getArguments();
        
        // 引数に基づくキー生成
        $argKey = $this->generateArgumentKey($args, $config);
        
        return "cache:{$config->cacheName}:{$class}:{$method}:{$argKey}";
    }
    
    private function generateArgumentKey(array $args, CacheConfig $config): string
    {
        if ($config->includeArgs === false) {
            return 'no-args';
        }
        
        // 特定の引数のみを含める
        if (is_array($config->includeArgs)) {
            $filteredArgs = array_intersect_key($args, array_flip($config->includeArgs));
            return md5(serialize($filteredArgs));
        }
        
        return md5(serialize($args));
    }
    
    private function parseKeyExpression(string $expression, MethodInvocation $invocation): string
    {
        // {引数名} を実際の値に置換
        $args = $invocation->getArguments();
        $method = $invocation->getMethod();
        $params = $method->getParameters();
        
        $replacements = [];
        foreach ($params as $index => $param) {
            if (isset($args[$index])) {
                $replacements['{' . $param->getName() . '}'] = (string)$args[$index];
            }
        }
        
        return strtr($expression, $replacements);
    }
    
    private function getFromCache(string $key, CacheConfig $config): mixed
    {
        $value = $this->cache->get($key);
        
        if ($value !== null && $config->condition) {
            // 条件付きキャッシュの検証
            if (!$this->evaluateCondition($config->condition, $value)) {
                $this->cache->delete($key);
                return null;
            }
        }
        
        return $value;
    }
    
    private function shouldCache(mixed $result, float $executionTime, CacheConfig $config): bool
    {
        // null値のキャッシュ設定
        if ($result === null && !$config->cacheNull) {
            return false;
        }
        
        // 実行時間による判断
        if ($config->minExecutionTime && $executionTime < $config->minExecutionTime) {
            return false;
        }
        
        // カスタム戦略による判断
        return $this->strategy->shouldCache($result, $executionTime, $this->statistics);
    }
    
    private function saveToCache(string $key, mixed $value, CacheConfig $config): void
    {
        $ttl = $this->calculateTTL($config, $value);
        $this->cache->set($key, $value, $ttl);
        
        $this->logger->debug("Cached result", [
            'key' => $key,
            'ttl' => $ttl,
            'size' => $this->getValueSize($value)
        ]);
    }
    
    private function calculateTTL(CacheConfig $config, mixed $value): int
    {
        // 動的TTL計算
        if ($config->dynamicTTL) {
            return $this->strategy->calculateTTL($value, $this->statistics);
        }
        
        return $config->ttl;
    }
    
    private function evictCache(MethodInvocation $invocation, CacheEvict $evict): void
    {
        if ($evict->allEntries) {
            $this->cache->clear($evict->cacheName);
        } else {
            $key = $this->parseKeyExpression($evict->key, $invocation);
            $this->cache->delete($key);
        }
    }
    
    private function updateStatistics(string $key, string $event): void
    {
        if (!isset($this->statistics[$key])) {
            $this->statistics[$key] = [
                'requests' => 0,
                'hits' => 0,
                'misses' => 0
            ];
        }
        
        switch ($event) {
            case 'request':
                $this->statistics[$key]['requests']++;
                break;
            case 'hit':
                $this->statistics[$key]['hits']++;
                break;
            case 'miss':
                $this->statistics[$key]['misses']++;
                break;
        }
    }
    
    private function getValueSize(mixed $value): int
    {
        return strlen(serialize($value));
    }
    
    private function evaluateCondition(string $condition, mixed $value): bool
    {
        // 条件評価ロジック
        return true;
    }
}

#[Attribute]
class CacheEvict
{
    public function __construct(
        public readonly string $cacheName = 'default',
        public readonly string $key = '',
        public readonly bool $allEntries = false,
        public readonly bool $beforeInvocation = false
    ) {}
}

class CacheConfig
{
    public function __construct(
        public readonly string $cacheName,
        public readonly int $ttl,
        public readonly ?string $key,
        public readonly mixed $includeArgs,
        public readonly bool $cacheNull,
        public readonly ?float $minExecutionTime,
        public readonly bool $dynamicTTL,
        public readonly ?string $condition
    ) {}
    
    public static function fromCacheable(Cacheable $cacheable): self
    {
        return new self(
            cacheName: $cacheable->cacheName,
            ttl: $cacheable->ttl,
            key: $cacheable->key,
            includeArgs: $cacheable->includeArgs,
            cacheNull: $cacheable->cacheNull,
            minExecutionTime: $cacheable->minExecutionTime,
            dynamicTTL: $cacheable->dynamicTTL,
            condition: $cacheable->condition
        );
    }
}
```

## バリデーションとサニタイゼーション

### 1. 包括的バリデーションインターセプター

```php
class ComprehensiveValidationInterceptor implements MethodInterceptor
{
    public function __construct(
        private ValidatorInterface $validator,
        private SanitizerInterface $sanitizer,
        private ValidationErrorHandlerInterface $errorHandler
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $validateAttrs = $method->getAttributes(Validate::class);
        
        if (empty($validateAttrs)) {
            return $invocation->proceed();
        }
        
        $validationConfig = $validateAttrs[0]->newInstance();
        
        // 1. 引数のサニタイゼーション
        $sanitizedArgs = $this->sanitizeArguments($invocation, $validationConfig);
        
        // 2. バリデーション実行
        $validationResult = $this->validateArguments($method, $sanitizedArgs, $validationConfig);
        
        // 3. エラーハンドリング
        if (!$validationResult->isValid()) {
            return $this->handleValidationErrors($validationResult, $invocation);
        }
        
        // 4. サニタイズされた引数で実行
        $result = $this->invokeWithSanitizedArgs($invocation, $sanitizedArgs);
        
        // 5. 結果のバリデーション
        if ($validationConfig->validateResult) {
            $this->validateResult($result, $validationConfig);
        }
        
        return $result;
    }
    
    private function sanitizeArguments(MethodInvocation $invocation, Validate $config): array
    {
        $arguments = $invocation->getArguments();
        $method = $invocation->getMethod();
        $parameters = $method->getParameters();
        
        $sanitized = [];
        foreach ($parameters as $index => $param) {
            if (!isset($arguments[$index])) {
                continue;
            }
            
            $value = $arguments[$index];
            $rules = $config->rules[$param->getName()] ?? [];
            
            // サニタイゼーションルールの適用
            $sanitized[$index] = $this->sanitizer->sanitize($value, $this->extractSanitizationRules($rules));
        }
        
        return $sanitized;
    }
    
    private function validateArguments(\ReflectionMethod $method, array $arguments, Validate $config): ValidationResult
    {
        $parameters = $method->getParameters();
        $errors = [];
        
        foreach ($parameters as $index => $param) {
            $paramName = $param->getName();
            $value = $arguments[$index] ?? null;
            $rules = $config->rules[$paramName] ?? [];
            
            if (empty($rules)) {
                continue;
            }
            
            // 型アトリビュートからのバリデーション
            $typeValidation = $this->validateType($param, $value);
            if (!$typeValidation->isValid()) {
                $errors[$paramName] = $typeValidation->getErrors();
                continue;
            }
            
            // カスタムルールのバリデーション
            $customValidation = $this->validator->validate($value, $rules);
            if (!$customValidation->isValid()) {
                $errors[$paramName] = $customValidation->getErrors();
            }
        }
        
        return new ValidationResult(empty($errors), $errors);
    }
    
    private function validateType(\ReflectionParameter $param, mixed $value): ValidationResult
    {
        $type = $param->getType();
        if (!$type) {
            return new ValidationResult(true);
        }
        
        $typeName = $type->getName();
        $errors = [];
        
        // null値の処理
        if ($value === null) {
            if (!$type->allowsNull()) {
                $errors[] = "Parameter must not be null";
            }
            return new ValidationResult(empty($errors), $errors);
        }
        
        // 型チェック
        $isValid = match($typeName) {
            'int' => is_int($value),
            'float' => is_float($value) || is_int($value),
            'string' => is_string($value),
            'bool' => is_bool($value),
            'array' => is_array($value),
            'object' => is_object($value),
            default => $value instanceof $typeName
        };
        
        if (!$isValid) {
            $errors[] = "Expected {$typeName}, got " . gettype($value);
        }
        
        return new ValidationResult(empty($errors), $errors);
    }
    
    private function handleValidationErrors(ValidationResult $result, MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $errors = $result->getErrors();
        
        // エラーハンドラーによる処理
        $handlerResult = $this->errorHandler->handle($errors, $invocation);
        
        if ($handlerResult->shouldProceed()) {
            return $invocation->proceed();
        }
        
        if ($handlerResult->hasDefaultValue()) {
            return $handlerResult->getDefaultValue();
        }
        
        throw new ValidationException('Validation failed', $errors);
    }
    
    private function validateResult(mixed $result, Validate $config): void
    {
        if (!isset($config->resultRules)) {
            return;
        }
        
        $validation = $this->validator->validate($result, $config->resultRules);
        if (!$validation->isValid()) {
            throw new ResultValidationException('Result validation failed', $validation->getErrors());
        }
    }
    
    private function extractSanitizationRules(array $rules): array
    {
        return array_filter($rules, fn($rule) => str_starts_with($rule, 'sanitize:'));
    }
    
    private function invokeWithSanitizedArgs(MethodInvocation $invocation, array $sanitizedArgs): mixed
    {
        $method = $invocation->getMethod();
        $object = $invocation->getThis();
        
        return $method->invokeArgs($object, $sanitizedArgs);
    }
}

#[Attribute]
class Validate
{
    public function __construct(
        public readonly array $rules = [],
        public readonly bool $validateResult = false,
        public readonly array $resultRules = [],
        public readonly bool $stopOnFirstError = false
    ) {}
}
```

## トランザクション管理

### 1. 分散トランザクションインターセプター

```php
class DistributedTransactionInterceptor implements MethodInterceptor
{
    private array $activeTransactions = [];
    
    public function __construct(
        private TransactionManagerInterface $transactionManager,
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $transactionalAttrs = $invocation->getMethod()->getAttributes(Transactional::class);
        
        if (empty($transactionalAttrs)) {
            return $invocation->proceed();
        }
        
        $config = $transactionalAttrs[0]->newInstance();
        $transactionId = $this->generateTransactionId();
        
        try {
            // トランザクション開始
            $this->beginTransaction($transactionId, $config);
            
            // メイン処理実行
            $result = $invocation->proceed();
            
            // コミット
            $this->commitTransaction($transactionId);
            
            return $result;
            
        } catch (Exception $e) {
            // ロールバック
            $this->rollbackTransaction($transactionId, $e);
            
            // 例外の再スロー判断
            if ($this->shouldRethrow($e, $config)) {
                throw $e;
            }
            
            return $config->defaultValue;
        }
    }
    
    private function beginTransaction(string $transactionId, Transactional $config): void
    {
        $transaction = new DistributedTransaction($transactionId, $config);
        
        // データベーストランザクション
        if ($config->includeDatabase) {
            $dbTransaction = $this->transactionManager->beginDatabaseTransaction($config->isolation);
            $transaction->addResource('database', $dbTransaction);
        }
        
        // メッセージキュートランザクション
        if ($config->includeMessageQueue) {
            $mqTransaction = $this->transactionManager->beginMessageQueueTransaction();
            $transaction->addResource('message_queue', $mqTransaction);
        }
        
        // キャッシュトランザクション
        if ($config->includeCache) {
            $cacheTransaction = $this->transactionManager->beginCacheTransaction();
            $transaction->addResource('cache', $cacheTransaction);
        }
        
        $this->activeTransactions[$transactionId] = $transaction;
        
        $this->logger->info("Transaction started", [
            'transaction_id' => $transactionId,
            'resources' => array_keys($transaction->getResources())
        ]);
    }
    
    private function commitTransaction(string $transactionId): void
    {
        $transaction = $this->activeTransactions[$transactionId];
        
        // 2フェーズコミット
        if ($transaction->getConfig()->twoPhaseCommit) {
            $this->performTwoPhaseCommit($transaction);
        } else {
            $this->performSimpleCommit($transaction);
        }
        
        unset($this->activeTransactions[$transactionId]);
        
        $this->logger->info("Transaction committed", ['transaction_id' => $transactionId]);
    }
    
    private function performTwoPhaseCommit(DistributedTransaction $transaction): void
    {
        // Phase 1: Prepare
        $preparedResources = [];
        foreach ($transaction->getResources() as $name => $resource) {
            try {
                if ($resource->prepare()) {
                    $preparedResources[] = $name;
                } else {
                    throw new TransactionException("Resource {$name} failed to prepare");
                }
            } catch (Exception $e) {
                // Prepareに失敗した場合、準備済みリソースをアボート
                foreach ($preparedResources as $prepared) {
                    $transaction->getResource($prepared)->abort();
                }
                throw $e;
            }
        }
        
        // Phase 2: Commit
        foreach ($transaction->getResources() as $name => $resource) {
            $resource->commit();
        }
    }
    
    private function performSimpleCommit(DistributedTransaction $transaction): void
    {
        foreach ($transaction->getResources() as $name => $resource) {
            $resource->commit();
        }
    }
    
    private function rollbackTransaction(string $transactionId, Exception $e): void
    {
        if (!isset($this->activeTransactions[$transactionId])) {
            return;
        }
        
        $transaction = $this->activeTransactions[$transactionId];
        
        foreach ($transaction->getResources() as $name => $resource) {
            try {
                $resource->rollback();
            } catch (Exception $rollbackException) {
                $this->logger->error("Failed to rollback resource", [
                    'transaction_id' => $transactionId,
                    'resource' => $name,
                    'error' => $rollbackException->getMessage()
                ]);
            }
        }
        
        unset($this->activeTransactions[$transactionId]);
        
        $this->logger->warning("Transaction rolled back", [
            'transaction_id' => $transactionId,
            'reason' => $e->getMessage()
        ]);
    }
    
    private function generateTransactionId(): string
    {
        return uniqid('tx_', true);
    }
    
    private function shouldRethrow(Exception $e, Transactional $config): bool
    {
        // 設定されたnoRollbackFor例外の場合はロールバックしない
        foreach ($config->noRollbackFor as $exceptionClass) {
            if ($e instanceof $exceptionClass) {
                return false;
            }
        }
        
        return true;
    }
}

#[Attribute]
class Transactional
{
    public function __construct(
        public readonly bool $includeDatabase = true,
        public readonly bool $includeMessageQueue = false,
        public readonly bool $includeCache = false,
        public readonly string $isolation = 'READ_COMMITTED',
        public readonly bool $twoPhaseCommit = false,
        public readonly array $noRollbackFor = [],
        public readonly mixed $defaultValue = null
    ) {}
}

class DistributedTransaction
{
    private array $resources = [];
    
    public function __construct(
        private string $id,
        private Transactional $config
    ) {}
    
    public function addResource(string $name, TransactionalResource $resource): void
    {
        $this->resources[$name] = $resource;
    }
    
    public function getResources(): array
    {
        return $this->resources;
    }
    
    public function getResource(string $name): ?TransactionalResource
    {
        return $this->resources[$name] ?? null;
    }
    
    public function getConfig(): Transactional
    {
        return $this->config;
    }
}
```

## 統合AOPモジュール

### 1. 横断的関心事の統合管理

```php
class CrossCuttingConcernsModule extends AbstractModule
{
    protected function configure(): void
    {
        // ログ・モニタリング
        $this->configureLoggingAndMonitoring();
        
        // セキュリティ
        $this->configureSecurity();
        
        // キャッシュ・最適化
        $this->configureCachingAndOptimization();
        
        // バリデーション
        $this->configureValidation();
        
        // トランザクション
        $this->configureTransactions();
        
        // エラーハンドリング
        $this->configureErrorHandling();
    }
    
    private function configureLoggingAndMonitoring(): void
    {
        // 構造化ログ
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Logged::class),
            [StructuredLoggingInterceptor::class]
        );
        
        // メトリクス収集
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Monitored::class),
            [MetricsCollectorInterceptor::class]
        );
        
        // 全サービスクラスにログを適用
        $this->bindInterceptor(
            $this->matcher->subclassesOf(ServiceInterface::class),
            $this->matcher->any(),
            [StructuredLoggingInterceptor::class]
        );
    }
    
    private function configureSecurity(): void
    {
        // セキュリティチェック
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Secured::class),
            [SecurityInterceptor::class]
        );
        
        // 暗号化
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Encrypt::class),
            [EncryptionInterceptor::class]
        );
        
        // APIエンドポイントにセキュリティを適用
        $this->bindInterceptor(
            $this->matcher->subclassesOf(ApiControllerInterface::class),
            $this->matcher->any(),
            [SecurityInterceptor::class]
        );
    }
    
    private function configureCachingAndOptimization(): void
    {
        // インテリジェントキャッシュ
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->logicalOr(
                $this->matcher->annotatedWith(Cacheable::class),
                $this->matcher->annotatedWith(CacheEvict::class)
            ),
            [IntelligentCacheInterceptor::class]
        );
        
        // リポジトリメソッドに自動キャッシュ
        $this->bindInterceptor(
            $this->matcher->subclassesOf(RepositoryInterface::class),
            $this->matcher->startsWith('find'),
            [IntelligentCacheInterceptor::class]
        );
    }
    
    private function configureValidation(): void
    {
        // 包括的バリデーション
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Validate::class),
            [ComprehensiveValidationInterceptor::class]
        );
        
        // コントローラーの全publicメソッドにバリデーション
        $this->bindInterceptor(
            $this->matcher->subclassesOf(ControllerInterface::class),
            $this->matcher->isPublic(),
            [ComprehensiveValidationInterceptor::class]
        );
    }
    
    private function configureTransactions(): void
    {
        // 分散トランザクション
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Transactional::class),
            [DistributedTransactionInterceptor::class]
        );
        
        // サービス層の更新メソッドに自動トランザクション
        $this->bindInterceptor(
            $this->matcher->subclassesOf(ServiceInterface::class),
            $this->matcher->logicalOr(
                $this->matcher->startsWith('create'),
                $this->matcher->startsWith('update'),
                $this->matcher->startsWith('delete')
            ),
            [DistributedTransactionInterceptor::class]
        );
    }
    
    private function configureErrorHandling(): void
    {
        // リトライ
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Retry::class),
            [RetryInterceptor::class]
        );
        
        // サーキットブレーカー
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(CircuitBreaker::class),
            [CircuitBreakerInterceptor::class]
        );
        
        // 外部サービスコールに自動リトライ
        $this->bindInterceptor(
            $this->matcher->subclassesOf(ExternalServiceInterface::class),
            $this->matcher->any(),
            [RetryInterceptor::class, CircuitBreakerInterceptor::class]
        );
    }
}
```

## 次のステップ

共通の横断的関心事の実装方法を理解したので、次に進む準備が整いました。

1. **実世界の例での実践**: E-commerceプラットフォームの完全実装
2. **テスト戦略の学習**: AOPを活用したテスト手法
3. **ベストプラクティスの確認**: 大規模システムでの活用方法

**続きは:** [Webアプリケーション アーキテクチャ](../06-real-world-examples/web-application-architecture.html)

## 重要なポイント

- **横断的関心事**を適切に識別し分離
- **構造化ログ**と**メトリクス**で可観測性を向上
- **多層セキュリティ**で堅牢なアプリケーション構築
- **インテリジェントキャッシュ**でパフォーマンス最適化
- **包括的バリデーション**でデータ整合性を保証
- **分散トランザクション**で一貫性を維持

---

横断的関心事の適切な実装により、ビジネスロジックをクリーンに保ちながら、エンタープライズグレードの機能を提供できます。AOPはこれらの関心事を効率的に管理するための強力なツールです。