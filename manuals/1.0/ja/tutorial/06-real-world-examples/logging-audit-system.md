---
layout: docs-ja
title: ロギング・監査システム
category: Manual
permalink: /manuals/1.0/ja/tutorial/06-real-world-examples/logging-audit-system.html
---

# ロギング・監査システム

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diを使った包括的なロギングシステムの構築
- 監査ログとセキュリティイベントの記録
- 構造化ログとログアグリゲーションの実装
- アラートとモニタリングシステムの統合
- ログのパフォーマンス最適化と管理

## ロギングシステムの設計

### 1. ロギングインターフェース設計

```php
// 基本ロガーインターフェース
interface LoggerInterface extends \Psr\Log\LoggerInterface
{
    public function withContext(array $context): LoggerInterface;
    public function withUser(User $user): LoggerInterface;
    public function withRequest(Request $request): LoggerInterface;
    public function structured(string $event, array $data = []): void;
    public function metric(string $name, float $value, array $tags = []): void;
}

// 監査ログインターフェース
interface AuditLoggerInterface
{
    public function log(string $event, array $data = []): void;
    public function security(string $event, array $data = []): void;
    public function business(string $event, array $data = []): void;
    public function compliance(string $event, array $data = []): void;
    public function query(AuditLogQuery $query): array;
}

// ログアグリゲーションインターフェース
interface LogAggregatorInterface
{
    public function aggregate(string $field, string $function, array $filters = []): array;
    public function count(array $filters = []): int;
    public function search(string $query, array $filters = []): array;
    public function timeline(string $field, string $interval, array $filters = []): array;
}

// アラートインターフェース
interface AlertManagerInterface
{
    public function registerRule(AlertRule $rule): void;
    public function checkRules(LogEntry $entry): void;
    public function sendAlert(Alert $alert): void;
    public function getActiveAlerts(): array;
}
```

### 2. 構造化ログエントリ

```php
class LogEntry
{
    public function __construct(
        private string $level,
        private string $message,
        private array $context = [],
        private DateTime $timestamp = new DateTime(),
        private ?string $channel = null,
        private ?string $requestId = null,
        private ?string $userId = null,
        private ?string $sessionId = null,
        private ?string $ipAddress = null,
        private ?string $userAgent = null,
        private array $tags = []
    ) {}

    public function getLevel(): string { return $this->level; }
    public function getMessage(): string { return $this->message; }
    public function getContext(): array { return $this->context; }
    public function getTimestamp(): DateTime { return $this->timestamp; }
    public function getChannel(): ?string { return $this->channel; }
    public function getRequestId(): ?string { return $this->requestId; }
    public function getUserId(): ?string { return $this->userId; }
    public function getSessionId(): ?string { return $this->sessionId; }
    public function getIpAddress(): ?string { return $this->ipAddress; }
    public function getUserAgent(): ?string { return $this->userAgent; }
    public function getTags(): array { return $this->tags; }

    public function toArray(): array
    {
        return [
            'level' => $this->level,
            'message' => $this->message,
            'context' => $this->context,
            'timestamp' => $this->timestamp->format('Y-m-d H:i:s.u'),
            'channel' => $this->channel,
            'request_id' => $this->requestId,
            'user_id' => $this->userId,
            'session_id' => $this->sessionId,
            'ip_address' => $this->ipAddress,
            'user_agent' => $this->userAgent,
            'tags' => $this->tags
        ];
    }
}

class AuditLogEntry extends LogEntry
{
    public function __construct(
        string $event,
        array $data = [],
        private ?string $actor = null,
        private ?string $target = null,
        private ?string $outcome = null,
        private ?array $changes = null,
        DateTime $timestamp = new DateTime()
    ) {
        parent::__construct('audit', $event, $data, $timestamp);
    }

    public function getActor(): ?string { return $this->actor; }
    public function getTarget(): ?string { return $this->target; }
    public function getOutcome(): ?string { return $this->outcome; }
    public function getChanges(): ?array { return $this->changes; }

    public function toArray(): array
    {
        return array_merge(parent::toArray(), [
            'actor' => $this->actor,
            'target' => $this->target,
            'outcome' => $this->outcome,
            'changes' => $this->changes
        ]);
    }
}
```

## 高度なロガー実装

### 1. 構造化ロガー

```php
class StructuredLogger implements LoggerInterface
{
    private array $context = [];
    private array $processors = [];
    private array $handlers = [];

    public function __construct(
        private string $name,
        private RequestContextInterface $requestContext,
        private SecurityContextInterface $securityContext,
        private MetricsCollectorInterface $metrics
    ) {}

    public function emergency(string|\Stringable $message, array $context = []): void
    {
        $this->log('emergency', $message, $context);
    }

    public function alert(string|\Stringable $message, array $context = []): void
    {
        $this->log('alert', $message, $context);
    }

    public function critical(string|\Stringable $message, array $context = []): void
    {
        $this->log('critical', $message, $context);
    }

    public function error(string|\Stringable $message, array $context = []): void
    {
        $this->log('error', $message, $context);
    }

    public function warning(string|\Stringable $message, array $context = []): void
    {
        $this->log('warning', $message, $context);
    }

    public function notice(string|\Stringable $message, array $context = []): void
    {
        $this->log('notice', $message, $context);
    }

    public function info(string|\Stringable $message, array $context = []): void
    {
        $this->log('info', $message, $context);
    }

    public function debug(string|\Stringable $message, array $context = []): void
    {
        $this->log('debug', $message, $context);
    }

    public function log($level, string|\Stringable $message, array $context = []): void
    {
        $entry = $this->createLogEntry($level, (string) $message, $context);
        
        // プロセッサーを適用
        foreach ($this->processors as $processor) {
            $entry = $processor->process($entry);
        }

        // ハンドラーに送信
        foreach ($this->handlers as $handler) {
            if ($handler->canHandle($entry)) {
                $handler->handle($entry);
            }
        }

        // メトリクスを記録
        $this->metrics->increment('log.entries', [
            'level' => $level,
            'channel' => $this->name
        ]);
    }

    public function withContext(array $context): LoggerInterface
    {
        $clone = clone $this;
        $clone->context = array_merge($this->context, $context);
        return $clone;
    }

    public function withUser(User $user): LoggerInterface
    {
        return $this->withContext([
            'user_id' => $user->getId(),
            'user_email' => $user->getEmail()
        ]);
    }

    public function withRequest(Request $request): LoggerInterface
    {
        return $this->withContext([
            'request_id' => $request->getId(),
            'method' => $request->getMethod(),
            'uri' => $request->getUri(),
            'ip' => $request->getClientIp()
        ]);
    }

    public function structured(string $event, array $data = []): void
    {
        $this->info($event, array_merge(['event' => $event], $data));
    }

    public function metric(string $name, float $value, array $tags = []): void
    {
        $this->metrics->gauge($name, $value, $tags);
        $this->debug("Metric recorded: {$name}", [
            'metric' => $name,
            'value' => $value,
            'tags' => $tags
        ]);
    }

    public function addProcessor(LogProcessorInterface $processor): void
    {
        $this->processors[] = $processor;
    }

    public function addHandler(LogHandlerInterface $handler): void
    {
        $this->handlers[] = $handler;
    }

    private function createLogEntry(string $level, string $message, array $context): LogEntry
    {
        $mergedContext = array_merge($this->context, $context);
        
        return new LogEntry(
            level: $level,
            message: $message,
            context: $mergedContext,
            timestamp: new DateTime(),
            channel: $this->name,
            requestId: $this->requestContext->getRequestId(),
            userId: $this->securityContext->getUser()?->getId(),
            sessionId: $this->requestContext->getSessionId(),
            ipAddress: $this->requestContext->getIpAddress(),
            userAgent: $this->requestContext->getUserAgent(),
            tags: $mergedContext['tags'] ?? []
        );
    }
}
```

### 2. 監査ログシステム

```php
class AuditLogger implements AuditLoggerInterface
{
    private const SECURITY_EVENTS = [
        'login_success',
        'login_failure',
        'logout',
        'password_change',
        'permission_denied',
        'mfa_enabled',
        'mfa_disabled',
        'suspicious_activity'
    ];

    private const BUSINESS_EVENTS = [
        'order_created',
        'order_updated',
        'order_cancelled',
        'product_created',
        'product_updated',
        'product_deleted',
        'user_created',
        'user_updated',
        'user_deleted'
    ];

    public function __construct(
        private LoggerInterface $logger,
        private AuditLogRepositoryInterface $repository,
        private SecurityContextInterface $securityContext,
        private RequestContextInterface $requestContext,
        private MetricsCollectorInterface $metrics
    ) {}

    public function log(string $event, array $data = []): void
    {
        $entry = $this->createAuditEntry($event, $data);
        
        // データベースに保存
        $this->repository->save($entry);
        
        // ログファイルにも記録
        $this->logger->info("Audit: {$event}", $entry->toArray());
        
        // メトリクスを記録
        $this->metrics->increment('audit.events', [
            'event' => $event,
            'type' => $this->getEventType($event)
        ]);
    }

    public function security(string $event, array $data = []): void
    {
        $data['event_type'] = 'security';
        $this->log($event, $data);
        
        // セキュリティイベントは特別な処理
        if ($this->isCriticalSecurityEvent($event)) {
            $this->handleCriticalSecurityEvent($event, $data);
        }
    }

    public function business(string $event, array $data = []): void
    {
        $data['event_type'] = 'business';
        $this->log($event, $data);
    }

    public function compliance(string $event, array $data = []): void
    {
        $data['event_type'] = 'compliance';
        $this->log($event, $data);
        
        // コンプライアンスイベントは長期保存
        $this->repository->markForLongTermStorage($event, $data);
    }

    public function query(AuditLogQuery $query): array
    {
        return $this->repository->findByQuery($query);
    }

    private function createAuditEntry(string $event, array $data): AuditLogEntry
    {
        $user = $this->securityContext->getUser();
        
        return new AuditLogEntry(
            event: $event,
            data: $data,
            actor: $user?->getId(),
            target: $data['target'] ?? null,
            outcome: $data['outcome'] ?? 'success',
            changes: $data['changes'] ?? null,
            timestamp: new DateTime()
        );
    }

    private function getEventType(string $event): string
    {
        if (in_array($event, self::SECURITY_EVENTS)) {
            return 'security';
        }
        if (in_array($event, self::BUSINESS_EVENTS)) {
            return 'business';
        }
        return 'general';
    }

    private function isCriticalSecurityEvent(string $event): bool
    {
        return in_array($event, [
            'login_failure',
            'permission_denied',
            'suspicious_activity',
            'data_breach_detected'
        ]);
    }

    private function handleCriticalSecurityEvent(string $event, array $data): void
    {
        // 重要なセキュリティイベントの処理
        $this->logger->critical("Critical security event: {$event}", $data);
        
        // アラートを発信
        // 必要に応じて追加の処理を実行
    }
}
```

## ログハンドラーとプロセッサー

### 1. 複数出力ハンドラー

```php
// ElasticSearchハンドラー
class ElasticsearchHandler implements LogHandlerInterface
{
    public function __construct(
        private ElasticsearchClientInterface $client,
        private string $index,
        private string $type = '_doc'
    ) {}

    public function canHandle(LogEntry $entry): bool
    {
        return true; // すべてのログを処理
    }

    public function handle(LogEntry $entry): void
    {
        $document = $entry->toArray();
        
        $this->client->index([
            'index' => $this->index . '-' . $entry->getTimestamp()->format('Y-m'),
            'type' => $this->type,
            'body' => $document
        ]);
    }
}

// ファイルハンドラー
class FileHandler implements LogHandlerInterface
{
    public function __construct(
        private string $logPath,
        private string $dateFormat = 'Y-m-d'
    ) {}

    public function canHandle(LogEntry $entry): bool
    {
        return in_array($entry->getLevel(), ['error', 'warning', 'critical', 'emergency']);
    }

    public function handle(LogEntry $entry): void
    {
        $filename = $this->logPath . '/' . $entry->getTimestamp()->format($this->dateFormat) . '.log';
        
        $line = sprintf(
            "[%s] %s.%s: %s %s\n",
            $entry->getTimestamp()->format('Y-m-d H:i:s'),
            $entry->getChannel(),
            $entry->getLevel(),
            $entry->getMessage(),
            json_encode($entry->getContext())
        );

        file_put_contents($filename, $line, FILE_APPEND | LOCK_EX);
    }
}

// データベースハンドラー
class DatabaseHandler implements LogHandlerInterface
{
    public function __construct(
        private DatabaseInterface $database,
        private string $table = 'logs'
    ) {}

    public function canHandle(LogEntry $entry): bool
    {
        return $entry->getLevel() === 'audit' || 
               in_array($entry->getLevel(), ['error', 'critical', 'emergency']);
    }

    public function handle(LogEntry $entry): void
    {
        $sql = "
            INSERT INTO {$this->table} 
            (level, message, context, timestamp, channel, request_id, user_id, ip_address)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ";

        $params = [
            $entry->getLevel(),
            $entry->getMessage(),
            json_encode($entry->getContext()),
            $entry->getTimestamp()->format('Y-m-d H:i:s'),
            $entry->getChannel(),
            $entry->getRequestId(),
            $entry->getUserId(),
            $entry->getIpAddress()
        ];

        $this->database->execute($sql, $params);
    }
}
```

### 2. ログプロセッサー

```php
// PII（個人情報）サニタイザー
class PiiSanitizerProcessor implements LogProcessorInterface
{
    private const SENSITIVE_FIELDS = [
        'password',
        'token',
        'secret',
        'api_key',
        'credit_card',
        'ssn',
        'phone',
        'email'
    ];

    public function process(LogEntry $entry): LogEntry
    {
        $context = $entry->getContext();
        $sanitized = $this->sanitizeArray($context);
        
        return new LogEntry(
            level: $entry->getLevel(),
            message: $entry->getMessage(),
            context: $sanitized,
            timestamp: $entry->getTimestamp(),
            channel: $entry->getChannel(),
            requestId: $entry->getRequestId(),
            userId: $entry->getUserId(),
            sessionId: $entry->getSessionId(),
            ipAddress: $entry->getIpAddress(),
            userAgent: $entry->getUserAgent(),
            tags: $entry->getTags()
        );
    }

    private function sanitizeArray(array $data): array
    {
        $sanitized = [];
        
        foreach ($data as $key => $value) {
            if (is_array($value)) {
                $sanitized[$key] = $this->sanitizeArray($value);
            } elseif ($this->isSensitiveField($key)) {
                $sanitized[$key] = $this->maskValue($value);
            } else {
                $sanitized[$key] = $value;
            }
        }
        
        return $sanitized;
    }

    private function isSensitiveField(string $field): bool
    {
        $field = strtolower($field);
        
        foreach (self::SENSITIVE_FIELDS as $sensitive) {
            if (str_contains($field, $sensitive)) {
                return true;
            }
        }
        
        return false;
    }

    private function maskValue($value): string
    {
        if (is_string($value) && strlen($value) > 4) {
            return substr($value, 0, 2) . str_repeat('*', strlen($value) - 4) . substr($value, -2);
        }
        
        return '***';
    }
}

// エンリッチメントプロセッサー
class EnrichmentProcessor implements LogProcessorInterface
{
    public function __construct(
        private GeoLocationServiceInterface $geoService,
        private UserAgentParserInterface $userAgentParser
    ) {}

    public function process(LogEntry $entry): LogEntry
    {
        $context = $entry->getContext();
        
        // 地理的位置情報を追加
        if ($entry->getIpAddress()) {
            $location = $this->geoService->lookup($entry->getIpAddress());
            if ($location) {
                $context['geo'] = [
                    'country' => $location->getCountry(),
                    'region' => $location->getRegion(),
                    'city' => $location->getCity(),
                    'lat' => $location->getLatitude(),
                    'lon' => $location->getLongitude()
                ];
            }
        }

        // ユーザーエージェント情報を追加
        if ($entry->getUserAgent()) {
            $parsed = $this->userAgentParser->parse($entry->getUserAgent());
            $context['user_agent_info'] = [
                'browser' => $parsed->getBrowser(),
                'browser_version' => $parsed->getBrowserVersion(),
                'os' => $parsed->getOS(),
                'os_version' => $parsed->getOSVersion(),
                'device' => $parsed->getDevice()
            ];
        }

        return new LogEntry(
            level: $entry->getLevel(),
            message: $entry->getMessage(),
            context: $context,
            timestamp: $entry->getTimestamp(),
            channel: $entry->getChannel(),
            requestId: $entry->getRequestId(),
            userId: $entry->getUserId(),
            sessionId: $entry->getSessionId(),
            ipAddress: $entry->getIpAddress(),
            userAgent: $entry->getUserAgent(),
            tags: $entry->getTags()
        );
    }
}
```

## アラートとモニタリング

### 1. アラートシステム

```php
class AlertManager implements AlertManagerInterface
{
    private array $rules = [];
    private array $channels = [];

    public function __construct(
        private LoggerInterface $logger,
        private CacheInterface $cache,
        private MetricsCollectorInterface $metrics
    ) {}

    public function registerRule(AlertRule $rule): void
    {
        $this->rules[] = $rule;
    }

    public function checkRules(LogEntry $entry): void
    {
        foreach ($this->rules as $rule) {
            if ($rule->matches($entry)) {
                $this->processAlert($rule, $entry);
            }
        }
    }

    public function sendAlert(Alert $alert): void
    {
        foreach ($this->channels as $channel) {
            if ($channel->supports($alert->getSeverity())) {
                $channel->send($alert);
            }
        }

        $this->metrics->increment('alerts.sent', [
            'severity' => $alert->getSeverity(),
            'type' => $alert->getType()
        ]);
    }

    public function getActiveAlerts(): array
    {
        $cacheKey = 'active_alerts';
        return $this->cache->get($cacheKey, []);
    }

    private function processAlert(AlertRule $rule, LogEntry $entry): void
    {
        // レート制限チェック
        if ($this->isRateLimited($rule)) {
            return;
        }

        $alert = new Alert(
            id: uniqid(),
            rule: $rule,
            entry: $entry,
            severity: $rule->getSeverity(),
            timestamp: new DateTime()
        );

        $this->sendAlert($alert);
        $this->updateAlertCache($alert);
        $this->updateRateLimit($rule);
    }

    private function isRateLimited(AlertRule $rule): bool
    {
        $key = "alert_rate_limit:{$rule->getId()}";
        $count = $this->cache->get($key, 0);
        
        return $count >= $rule->getMaxOccurrences();
    }

    private function updateRateLimit(AlertRule $rule): void
    {
        $key = "alert_rate_limit:{$rule->getId()}";
        $count = $this->cache->get($key, 0);
        
        $this->cache->set($key, $count + 1, $rule->getTimeWindow());
    }

    private function updateAlertCache(Alert $alert): void
    {
        $activeAlerts = $this->getActiveAlerts();
        $activeAlerts[] = $alert->toArray();
        
        $this->cache->set('active_alerts', $activeAlerts, 3600);
    }

    public function addChannel(AlertChannelInterface $channel): void
    {
        $this->channels[] = $channel;
    }
}

// アラートルール
class AlertRule
{
    public function __construct(
        private string $id,
        private string $name,
        private string $condition,
        private string $severity,
        private int $maxOccurrences = 10,
        private int $timeWindow = 300
    ) {}

    public function getId(): string { return $this->id; }
    public function getName(): string { return $this->name; }
    public function getSeverity(): string { return $this->severity; }
    public function getMaxOccurrences(): int { return $this->maxOccurrences; }
    public function getTimeWindow(): int { return $this->timeWindow; }

    public function matches(LogEntry $entry): bool
    {
        // 条件評価ロジック
        return $this->evaluateCondition($entry);
    }

    private function evaluateCondition(LogEntry $entry): bool
    {
        // 簡単な条件評価の実装
        switch ($this->condition) {
            case 'level:error':
                return $entry->getLevel() === 'error';
            case 'level:critical':
                return $entry->getLevel() === 'critical';
            case 'failed_login':
                return $entry->getMessage() === 'login_failure';
            default:
                return false;
        }
    }
}

// Slack通知チャンネル
class SlackAlertChannel implements AlertChannelInterface
{
    public function __construct(
        private string $webhookUrl,
        private array $supportedSeverities = ['critical', 'high']
    ) {}

    public function supports(string $severity): bool
    {
        return in_array($severity, $this->supportedSeverities);
    }

    public function send(Alert $alert): void
    {
        $payload = [
            'text' => "Alert: {$alert->getRule()->getName()}",
            'attachments' => [
                [
                    'color' => $this->getSeverityColor($alert->getSeverity()),
                    'fields' => [
                        [
                            'title' => 'Severity',
                            'value' => $alert->getSeverity(),
                            'short' => true
                        ],
                        [
                            'title' => 'Message',
                            'value' => $alert->getEntry()->getMessage(),
                            'short' => false
                        ],
                        [
                            'title' => 'Timestamp',
                            'value' => $alert->getTimestamp()->format('Y-m-d H:i:s'),
                            'short' => true
                        ]
                    ]
                ]
            ]
        ];

        $this->sendWebhook($payload);
    }

    private function getSeverityColor(string $severity): string
    {
        return match ($severity) {
            'critical' => 'danger',
            'high' => 'warning',
            'medium' => 'good',
            default => '#808080'
        };
    }

    private function sendWebhook(array $payload): void
    {
        $ch = curl_init($this->webhookUrl);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        
        curl_exec($ch);
        curl_close($ch);
    }
}
```

### 2. ログ分析とメトリクス

```php
class LogAnalyzer implements LogAggregatorInterface
{
    public function __construct(
        private LogRepositoryInterface $repository,
        private CacheInterface $cache,
        private MetricsCollectorInterface $metrics
    ) {}

    public function aggregate(string $field, string $function, array $filters = []): array
    {
        $cacheKey = "log_agg:" . md5(serialize([$field, $function, $filters]));
        $cached = $this->cache->get($cacheKey);
        
        if ($cached !== null) {
            return $cached;
        }

        $result = $this->repository->aggregate($field, $function, $filters);
        
        $this->cache->set($cacheKey, $result, 300); // 5分間キャッシュ
        
        return $result;
    }

    public function count(array $filters = []): int
    {
        return $this->repository->count($filters);
    }

    public function search(string $query, array $filters = []): array
    {
        return $this->repository->search($query, $filters);
    }

    public function timeline(string $field, string $interval, array $filters = []): array
    {
        return $this->repository->timeline($field, $interval, $filters);
    }

    public function generateReport(string $type, array $params = []): array
    {
        return match ($type) {
            'error_summary' => $this->generateErrorSummary($params),
            'user_activity' => $this->generateUserActivityReport($params),
            'security_events' => $this->generateSecurityReport($params),
            'performance_metrics' => $this->generatePerformanceReport($params),
            default => []
        };
    }

    private function generateErrorSummary(array $params): array
    {
        $filters = [
            'level' => ['error', 'critical', 'emergency'],
            'timestamp' => [
                'gte' => $params['start_date'] ?? date('Y-m-d H:i:s', strtotime('-24 hours')),
                'lte' => $params['end_date'] ?? date('Y-m-d H:i:s')
            ]
        ];

        $totalErrors = $this->count($filters);
        $errorsByLevel = $this->aggregate('level', 'count', $filters);
        $errorsByChannel = $this->aggregate('channel', 'count', $filters);
        $timeline = $this->timeline('timestamp', 'hour', $filters);

        return [
            'total_errors' => $totalErrors,
            'by_level' => $errorsByLevel,
            'by_channel' => $errorsByChannel,
            'timeline' => $timeline,
            'period' => [
                'start' => $params['start_date'] ?? date('Y-m-d H:i:s', strtotime('-24 hours')),
                'end' => $params['end_date'] ?? date('Y-m-d H:i:s')
            ]
        ];
    }

    private function generateUserActivityReport(array $params): array
    {
        $filters = [
            'user_id' => ['not_null' => true],
            'timestamp' => [
                'gte' => $params['start_date'] ?? date('Y-m-d H:i:s', strtotime('-7 days')),
                'lte' => $params['end_date'] ?? date('Y-m-d H:i:s')
            ]
        ];

        $activeUsers = $this->aggregate('user_id', 'count_distinct', $filters);
        $actionsByUser = $this->aggregate('user_id', 'count', $filters);
        $timeline = $this->timeline('timestamp', 'day', $filters);

        return [
            'active_users' => $activeUsers,
            'actions_by_user' => $actionsByUser,
            'timeline' => $timeline
        ];
    }

    private function generateSecurityReport(array $params): array
    {
        $filters = [
            'event_type' => 'security',
            'timestamp' => [
                'gte' => $params['start_date'] ?? date('Y-m-d H:i:s', strtotime('-24 hours')),
                'lte' => $params['end_date'] ?? date('Y-m-d H:i:s')
            ]
        ];

        $securityEvents = $this->count($filters);
        $eventTypes = $this->aggregate('event', 'count', $filters);
        $failedLogins = $this->count(array_merge($filters, ['event' => 'login_failure']));
        $suspiciousActivity = $this->count(array_merge($filters, ['event' => 'suspicious_activity']));

        return [
            'total_security_events' => $securityEvents,
            'event_types' => $eventTypes,
            'failed_logins' => $failedLogins,
            'suspicious_activity' => $suspiciousActivity
        ];
    }

    private function generatePerformanceReport(array $params): array
    {
        $filters = [
            'message' => ['like' => '%duration%'],
            'timestamp' => [
                'gte' => $params['start_date'] ?? date('Y-m-d H:i:s', strtotime('-1 hour')),
                'lte' => $params['end_date'] ?? date('Y-m-d H:i:s')
            ]
        ];

        $avgDuration = $this->aggregate('context.duration', 'avg', $filters);
        $maxDuration = $this->aggregate('context.duration', 'max', $filters);
        $slowRequests = $this->count(array_merge($filters, ['context.duration' => ['gt' => 1000]]));

        return [
            'avg_duration' => $avgDuration,
            'max_duration' => $maxDuration,
            'slow_requests' => $slowRequests
        ];
    }
}
```

## 統合モジュール設定

### 1. ロギング・監査モジュール

```php
class LoggingModule extends AbstractModule
{
    protected function configure(): void
    {
        // 基本ロガー
        $this->bind(LoggerInterface::class)
            ->to(StructuredLogger::class)
            ->in(Singleton::class);

        // 監査ロガー
        $this->bind(AuditLoggerInterface::class)
            ->to(AuditLogger::class)
            ->in(Singleton::class);

        // ログアナライザー
        $this->bind(LogAggregatorInterface::class)
            ->to(LogAnalyzer::class)
            ->in(Singleton::class);

        // アラートマネージャー
        $this->bind(AlertManagerInterface::class)
            ->to(AlertManager::class)
            ->in(Singleton::class);

        // ログハンドラー
        $this->bind(LogHandlerInterface::class)
            ->annotatedWith(Named::class, 'file')
            ->to(FileHandler::class);

        $this->bind(LogHandlerInterface::class)
            ->annotatedWith(Named::class, 'database')
            ->to(DatabaseHandler::class);

        $this->bind(LogHandlerInterface::class)
            ->annotatedWith(Named::class, 'elasticsearch')
            ->to(ElasticsearchHandler::class);

        // プロセッサー
        $this->bind(LogProcessorInterface::class)
            ->annotatedWith(Named::class, 'pii_sanitizer')
            ->to(PiiSanitizerProcessor::class);

        $this->bind(LogProcessorInterface::class)
            ->annotatedWith(Named::class, 'enrichment')
            ->to(EnrichmentProcessor::class);

        // リポジトリ
        $this->bind(AuditLogRepositoryInterface::class)
            ->to(MySQLAuditLogRepository::class);

        $this->bind(LogRepositoryInterface::class)
            ->to(ElasticsearchLogRepository::class);

        // 設定
        $this->bind('logging.path')
            ->toInstance($_ENV['LOG_PATH'] ?? '/var/log/app');

        $this->bind('logging.level')
            ->toInstance($_ENV['LOG_LEVEL'] ?? 'info');

        $this->bind('elasticsearch.host')
            ->toInstance($_ENV['ELASTICSEARCH_HOST'] ?? 'localhost:9200');
    }
}
```

### 2. アラート設定モジュール

```php
class AlertModule extends AbstractModule
{
    protected function configure(): void
    {
        // アラートチャンネル
        $this->bind(AlertChannelInterface::class)
            ->annotatedWith(Named::class, 'slack')
            ->to(SlackAlertChannel::class);

        $this->bind(AlertChannelInterface::class)
            ->annotatedWith(Named::class, 'email')
            ->to(EmailAlertChannel::class);

        // アラートルール
        $this->bind(AlertRule::class)
            ->annotatedWith(Named::class, 'critical_errors')
            ->toInstance(new AlertRule(
                'critical_errors',
                'Critical Errors',
                'level:critical',
                'critical',
                5,
                300
            ));

        $this->bind(AlertRule::class)
            ->annotatedWith(Named::class, 'failed_logins')
            ->toInstance(new AlertRule(
                'failed_logins',
                'Failed Login Attempts',
                'failed_login',
                'high',
                10,
                600
            ));
    }
}
```

## 次のステップ

包括的なロギング・監査システムを完成させました。これで実世界の例は完了し、次はテスト戦略に進む準備が整いました。

1. **DIを使った単体テスト**: 効率的なテスト手法
2. **依存関係のモッキング**: テスト用のモック実装
3. **統合テスト**: 全体システムのテスト戦略

**続きは:** [DIを使った単体テスト](../07-testing-strategies/unit-testing-with-di.html)

## 重要なポイント

- **構造化ログ**により検索・分析が容易
- **監査ログ**でコンプライアンスとセキュリティを確保
- **複数出力**でログの冗長性を実現
- **PII サニタイゼーション**でプライバシーを保護
- **リアルタイムアラート**で問題を早期発見
- **メトリクス収集**でシステムの健全性を監視

---

堅牢なロギング・監査システムにより、運用中のアプリケーションを効果的に監視し、問題の早期発見と解決を実現できます。