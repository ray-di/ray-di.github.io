---
layout: docs-ja
title: プロバイダーバインディング
category: Manual
permalink: /manuals/1.0/ja/tutorial/02-basic-bindings/provider-binding.html
---

# プロバイダーバインディング

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- プロバイダーバインディングとは何か、いつ使用するか
- 複雑なオブジェクト作成ロジックの実装方法
- 遅延初期化とファクトリーパターンの活用
- プロバイダーでの依存注入の利用
- 実践的なE-commerceアプリケーションでの使用例

## プロバイダーバインディングとは

**プロバイダーバインディング**は、オブジェクトの作成ロジックが複雑な場合に、その作成を専用のプロバイダークラスに委譲するバインディング方法です。プロバイダーは`get()`メソッドを通じてオブジェクトを提供し、作成時の複雑な処理や条件分岐を隠蔽します。

### 基本的な使用方法

```php
use Ray\Di\ProviderInterface;
use Ray\Di\AbstractModule;

// プロバイダーの実装
class DatabaseConnectionProvider implements ProviderInterface
{
    public function get(): PDO
    {
        $dsn = $_ENV['DATABASE_URL'] ?? 'sqlite::memory:';
        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ];
        
        return new PDO($dsn, null, null, $options);
    }
}

// モジュールでのバインディング
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(PDO::class)->toProvider(DatabaseConnectionProvider::class);
    }
}
```

## 複雑なオブジェクト作成ロジック

### 1. 条件分岐を持つ作成ロジック

```php
class EmailServiceProvider implements ProviderInterface
{
    public function get(): EmailServiceInterface
    {
        $environment = $_ENV['APP_ENV'] ?? 'production';
        
        return match($environment) {
            'development' => new MockEmailService(),
            'testing' => new LogEmailService('/tmp/emails.log'),
            'staging' => new SMTPEmailService([
                'host' => 'smtp.staging.example.com',
                'port' => 587,
                'encryption' => 'tls'
            ]),
            'production' => new SendGridEmailService([
                'api_key' => $_ENV['SENDGRID_API_KEY'],
                'from_email' => $_ENV['FROM_EMAIL']
            ]),
            default => throw new InvalidArgumentException("Unknown environment: {$environment}")
        };
    }
}

class SMTPEmailService implements EmailServiceInterface
{
    public function __construct(private array $config) {}
    
    public function send(string $to, string $subject, string $body): bool
    {
        $mailer = new PHPMailer(true);
        $mailer->isSMTP();
        $mailer->Host = $this->config['host'];
        $mailer->Port = $this->config['port'];
        $mailer->SMTPSecure = $this->config['encryption'];
        
        $mailer->setFrom($this->config['from_email']);
        $mailer->addAddress($to);
        $mailer->Subject = $subject;
        $mailer->Body = $body;
        
        return $mailer->send();
    }
}

class SendGridEmailService implements EmailServiceInterface
{
    public function __construct(private array $config) {}
    
    public function send(string $to, string $subject, string $body): bool
    {
        $email = new \SendGrid\Mail\Mail();
        $email->setFrom($this->config['from_email']);
        $email->addTo($to);
        $email->setSubject($subject);
        $email->addContent('text/html', $body);
        
        $sendgrid = new \SendGrid($this->config['api_key']);
        $response = $sendgrid->send($email);
        
        return $response->statusCode() === 202;
    }
}
```

### 2. 複数ステップの初期化

```php
class CacheServiceProvider implements ProviderInterface
{
    public function get(): CacheInterface
    {
        $driver = $_ENV['CACHE_DRIVER'] ?? 'redis';
        
        switch ($driver) {
            case 'redis':
                return $this->createRedisCache();
            case 'memcached':
                return $this->createMemcachedCache();
            case 'file':
                return $this->createFileCache();
            default:
                throw new InvalidArgumentException("Unsupported cache driver: {$driver}");
        }
    }
    
    private function createRedisCache(): CacheInterface
    {
        $redis = new Redis();
        $redis->connect($_ENV['REDIS_HOST'] ?? 'localhost', $_ENV['REDIS_PORT'] ?? 6379);
        
        if (!empty($_ENV['REDIS_PASSWORD'])) {
            $redis->auth($_ENV['REDIS_PASSWORD']);
        }
        
        $redis->select($_ENV['REDIS_DB'] ?? 0);
        
        return new RedisCache($redis);
    }
    
    private function createMemcachedCache(): CacheInterface
    {
        $memcached = new Memcached();
        $memcached->addServer($_ENV['MEMCACHED_HOST'] ?? 'localhost', $_ENV['MEMCACHED_PORT'] ?? 11211);
        
        return new MemcachedCache($memcached);
    }
    
    private function createFileCache(): CacheInterface
    {
        $cachePath = $_ENV['CACHE_PATH'] ?? '/tmp/cache';
        
        // ディレクトリが存在しない場合は作成
        if (!is_dir($cachePath)) {
            mkdir($cachePath, 0755, true);
        }
        
        return new FileCache($cachePath);
    }
}
```

### 3. 外部リソースの初期化

```php
class StorageServiceProvider implements ProviderInterface
{
    public function get(): StorageInterface
    {
        $provider = $_ENV['STORAGE_PROVIDER'] ?? 'local';
        
        return match($provider) {
            'local' => $this->createLocalStorage(),
            'aws' => $this->createAwsS3Storage(),
            'gcs' => $this->createGoogleCloudStorage(),
            default => throw new InvalidArgumentException("Unknown storage provider: {$provider}")
        };
    }
    
    private function createLocalStorage(): StorageInterface
    {
        $path = $_ENV['STORAGE_PATH'] ?? '/app/storage';
        
        if (!is_dir($path)) {
            mkdir($path, 0755, true);
        }
        
        return new LocalStorage($path);
    }
    
    private function createAwsS3Storage(): StorageInterface
    {
        $s3Client = new S3Client([
            'version' => 'latest',
            'region' => $_ENV['AWS_REGION'] ?? 'us-east-1',
            'credentials' => [
                'key' => $_ENV['AWS_ACCESS_KEY_ID'],
                'secret' => $_ENV['AWS_SECRET_ACCESS_KEY']
            ]
        ]);
        
        return new S3Storage($s3Client, $_ENV['AWS_S3_BUCKET']);
    }
    
    private function createGoogleCloudStorage(): StorageInterface
    {
        $storage = new StorageClient([
            'projectId' => $_ENV['GOOGLE_CLOUD_PROJECT_ID'],
            'keyFilePath' => $_ENV['GOOGLE_CLOUD_KEY_FILE']
        ]);
        
        return new GoogleCloudStorage($storage, $_ENV['GOOGLE_CLOUD_BUCKET']);
    }
}
```

## プロバイダーでの依存注入

### 1. プロバイダーへの依存注入

```php
class LoggerProvider implements ProviderInterface
{
    public function __construct(
        private AppConfig $config,
        private StorageInterface $storage
    ) {}
    
    public function get(): LoggerInterface
    {
        $logLevel = $this->config->getLogLevel();
        $logPath = $this->config->getLogPath();
        
        // ストレージサービスを使用してログファイルを管理
        $logger = new FileLogger($logPath);
        $logger->setLevel($logLevel);
        
        // 日次ローテーションの設定
        if ($this->config->isLogRotationEnabled()) {
            $rotatedLogger = new RotatingFileLogger($logger, $this->storage);
            $rotatedLogger->setMaxFiles($this->config->getLogMaxFiles());
            return $rotatedLogger;
        }
        
        return $logger;
    }
}

class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(LoggerInterface::class)->toProvider(LoggerProvider::class);
        $this->bind(StorageInterface::class)->toProvider(StorageServiceProvider::class);
    }
}
```

### 2. 設定に基づくプロバイダー

```php
class PaymentGatewayProvider implements ProviderInterface
{
    public function __construct(
        private AppConfig $config,
        private LoggerInterface $logger
    ) {}
    
    public function get(): PaymentGatewayInterface
    {
        $provider = $this->config->getPaymentProvider();
        
        $this->logger->info("Initializing payment gateway: {$provider}");
        
        return match($provider) {
            'stripe' => $this->createStripeGateway(),
            'paypal' => $this->createPayPalGateway(),
            'square' => $this->createSquareGateway(),
            default => throw new InvalidArgumentException("Unknown payment provider: {$provider}")
        };
    }
    
    private function createStripeGateway(): PaymentGatewayInterface
    {
        $apiKey = $this->config->getStripeApiKey();
        
        if (empty($apiKey)) {
            throw new InvalidArgumentException('Stripe API key is required');
        }
        
        return new StripePaymentGateway($apiKey);
    }
    
    private function createPayPalGateway(): PaymentGatewayInterface
    {
        $clientId = $this->config->getPayPalClientId();
        $clientSecret = $this->config->getPayPalClientSecret();
        $sandbox = $this->config->isPayPalSandbox();
        
        return new PayPalPaymentGateway($clientId, $clientSecret, $sandbox);
    }
    
    private function createSquareGateway(): PaymentGatewayInterface
    {
        $accessToken = $this->config->getSquareAccessToken();
        $locationId = $this->config->getSquareLocationId();
        
        return new SquarePaymentGateway($accessToken, $locationId);
    }
}
```

## 遅延初期化とファクトリーパターン

### 1. 遅延初期化プロバイダー

```php
class DatabaseConnectionProvider implements ProviderInterface
{
    private ?PDO $connection = null;
    
    public function __construct(private DatabaseConfig $config) {}
    
    public function get(): PDO
    {
        if ($this->connection === null) {
            $this->connection = $this->createConnection();
        }
        
        return $this->connection;
    }
    
    private function createConnection(): PDO
    {
        $dsn = $this->config->getDsn();
        [$username, $password] = $this->config->getCredentials();
        $options = $this->config->getOptions();
        
        $connection = new PDO($dsn, $username, $password, $options);
        
        // 接続設定の調整
        $connection->exec("SET time_zone = '+00:00'");
        $connection->exec("SET names utf8mb4");
        
        return $connection;
    }
}
```

### 2. ファクトリーオブジェクトのプロバイダー

```php
class NotificationChannelFactory
{
    public function __construct(
        private array $channels = []
    ) {}
    
    public function create(string $type): NotificationChannelInterface
    {
        if (!isset($this->channels[$type])) {
            throw new InvalidArgumentException("Unknown notification channel: {$type}");
        }
        
        return $this->channels[$type];
    }
    
    public function getAvailableChannels(): array
    {
        return array_keys($this->channels);
    }
}

class NotificationChannelFactoryProvider implements ProviderInterface
{
    public function __construct(
        private AppConfig $config,
        private LoggerInterface $logger
    ) {}
    
    public function get(): NotificationChannelFactory
    {
        $channels = [];
        
        // 設定に基づいてチャンネルを初期化
        if ($this->config->isEmailNotificationEnabled()) {
            $channels['email'] = new EmailNotificationChannel(
                $this->config->getEmailConfig(),
                $this->logger
            );
        }
        
        if ($this->config->isSmsNotificationEnabled()) {
            $channels['sms'] = new SmsNotificationChannel(
                $this->config->getSmsConfig(),
                $this->logger
            );
        }
        
        if ($this->config->isSlackNotificationEnabled()) {
            $channels['slack'] = new SlackNotificationChannel(
                $this->config->getSlackConfig(),
                $this->logger
            );
        }
        
        return new NotificationChannelFactory($channels);
    }
}
```

## E-commerceプラットフォームでの実践例

### 1. 決済システムプロバイダー

```php
class PaymentProcessorProvider implements ProviderInterface
{
    public function __construct(
        private AppConfig $config,
        private LoggerInterface $logger,
        private DatabaseInterface $database
    ) {}
    
    public function get(): PaymentProcessorInterface
    {
        $processor = new CompositePaymentProcessor();
        
        // 設定されたプロバイダーを追加
        $providers = $this->config->getEnabledPaymentProviders();
        
        foreach ($providers as $provider) {
            $gateway = $this->createPaymentGateway($provider);
            $processor->addGateway($provider, $gateway);
        }
        
        // フォールバック設定
        $processor->setFallbackOrder($this->config->getPaymentFallbackOrder());
        
        return $processor;
    }
    
    private function createPaymentGateway(string $provider): PaymentGatewayInterface
    {
        $this->logger->info("Creating payment gateway: {$provider}");
        
        return match($provider) {
            'stripe' => new StripePaymentGateway(
                $this->config->getStripeConfig(),
                $this->logger,
                $this->database
            ),
            'paypal' => new PayPalPaymentGateway(
                $this->config->getPayPalConfig(),
                $this->logger,
                $this->database
            ),
            'square' => new SquarePaymentGateway(
                $this->config->getSquareConfig(),
                $this->logger,
                $this->database
            ),
            default => throw new InvalidArgumentException("Unknown payment provider: {$provider}")
        };
    }
}

class CompositePaymentProcessor implements PaymentProcessorInterface
{
    private array $gateways = [];
    private array $fallbackOrder = [];
    
    public function addGateway(string $name, PaymentGatewayInterface $gateway): void
    {
        $this->gateways[$name] = $gateway;
    }
    
    public function setFallbackOrder(array $order): void
    {
        $this->fallbackOrder = $order;
    }
    
    public function processPayment(PaymentRequest $request): PaymentResult
    {
        $lastError = null;
        
        foreach ($this->fallbackOrder as $gatewayName) {
            if (!isset($this->gateways[$gatewayName])) {
                continue;
            }
            
            try {
                $result = $this->gateways[$gatewayName]->processPayment($request);
                
                if ($result->isSuccess()) {
                    return $result;
                }
                
                $lastError = $result->getError();
            } catch (Exception $e) {
                $lastError = $e->getMessage();
            }
        }
        
        return new PaymentResult(false, null, $lastError);
    }
}
```

### 2. 検索エンジンプロバイダー

```php
class SearchEngineProvider implements ProviderInterface
{
    public function __construct(
        private AppConfig $config,
        private LoggerInterface $logger
    ) {}
    
    public function get(): SearchEngineInterface
    {
        $engine = $this->config->getSearchEngine();
        
        $this->logger->info("Initializing search engine: {$engine}");
        
        return match($engine) {
            'elasticsearch' => $this->createElasticsearchEngine(),
            'solr' => $this->createSolrEngine(),
            'database' => $this->createDatabaseEngine(),
            default => throw new InvalidArgumentException("Unknown search engine: {$engine}")
        };
    }
    
    private function createElasticsearchEngine(): SearchEngineInterface
    {
        $client = ClientBuilder::create()
            ->setHosts($this->config->getElasticsearchHosts())
            ->build();
        
        return new ElasticsearchEngine($client, $this->logger);
    }
    
    private function createSolrEngine(): SearchEngineInterface
    {
        $config = [
            'endpoint' => [
                'localhost' => [
                    'host' => $this->config->getSolrHost(),
                    'port' => $this->config->getSolrPort(),
                    'path' => $this->config->getSolrPath()
                ]
            ]
        ];
        
        $client = new SolrClient($config);
        
        return new SolrEngine($client, $this->logger);
    }
    
    private function createDatabaseEngine(): SearchEngineInterface
    {
        // フォールバック用のデータベース検索
        return new DatabaseSearchEngine($this->database, $this->logger);
    }
}
```

### 3. 画像処理プロバイダー

```php
class ImageProcessorProvider implements ProviderInterface
{
    public function __construct(
        private AppConfig $config,
        private StorageInterface $storage,
        private LoggerInterface $logger
    ) {}
    
    public function get(): ImageProcessorInterface
    {
        $processor = new ImageProcessor($this->storage, $this->logger);
        
        // 設定に基づいて画像処理オプションを設定
        $processor->setQuality($this->config->getImageQuality());
        $processor->setMaxWidth($this->config->getMaxImageWidth());
        $processor->setMaxHeight($this->config->getMaxImageHeight());
        $processor->setAllowedFormats($this->config->getAllowedImageFormats());
        
        // 透かし設定
        if ($this->config->isWatermarkEnabled()) {
            $watermark = new Watermark(
                $this->config->getWatermarkPath(),
                $this->config->getWatermarkPosition(),
                $this->config->getWatermarkOpacity()
            );
            $processor->setWatermark($watermark);
        }
        
        // サムネイル生成設定
        $thumbnailSizes = $this->config->getThumbnailSizes();
        foreach ($thumbnailSizes as $size) {
            $processor->addThumbnailSize($size['width'], $size['height'], $size['name']);
        }
        
        return $processor;
    }
}
```

## ベストプラクティス

### 1. プロバイダーの設計指針

```php
// 良い：シンプルで再利用可能
class LoggerProvider implements ProviderInterface
{
    public function __construct(
        private AppConfig $config
    ) {}
    
    public function get(): LoggerInterface
    {
        $logger = new FileLogger($this->config->getLogPath());
        $logger->setLevel($this->config->getLogLevel());
        
        return $logger;
    }
}

// 悪い：複雑すぎる責任を持つ
class ComplexProvider implements ProviderInterface
{
    public function get(): mixed
    {
        $service = $this->createService();
        $this->configureService($service);
        $this->initializeDatabase($service);
        $this->setupCaching($service);
        $this->registerEventListeners($service);
        $this->startBackgroundTasks($service);
        
        return $service;
    }
}
```

### 2. エラーハンドリング

```php
class RobustProvider implements ProviderInterface
{
    public function __construct(
        private AppConfig $config,
        private LoggerInterface $logger
    ) {}
    
    public function get(): ServiceInterface
    {
        try {
            return $this->createService();
        } catch (Exception $e) {
            $this->logger->error("Failed to create service: {$e->getMessage()}");
            
            // フォールバック実装を返す
            return new MockService();
        }
    }
    
    private function createService(): ServiceInterface
    {
        $apiKey = $this->config->getApiKey();
        
        if (empty($apiKey)) {
            throw new InvalidArgumentException('API key is required');
        }
        
        return new ExternalService($apiKey);
    }
}
```

### 3. テストしやすい設計

```php
class TestableProvider implements ProviderInterface
{
    public function __construct(
        private AppConfig $config,
        private ExternalApiClient $apiClient
    ) {}
    
    public function get(): ServiceInterface
    {
        return new ExternalService($this->apiClient, $this->config);
    }
}

// テスト用のモックプロバイダー
class MockProvider implements ProviderInterface
{
    public function get(): ServiceInterface
    {
        return new MockService();
    }
}
```

## 次のステップ

プロバイダーバインディングの使用方法を理解したので、次に進む準備が整いました。

1. **マルチバインディングの学習**: 複数の実装を同時にバインディング
2. **アシストインジェクションの探索**: ファクトリーパターンの高度な実装
3. **実世界の例での練習**: 複合的なバインディングの使用方法

**続きは:** [マルチバインディング](../03-advanced-bindings/multi-binding.html)

## 重要なポイント

- **プロバイダーバインディング**は複雑な作成ロジックを隠蔽
- **依存注入**をプロバイダー内でも使用可能
- **遅延初期化**とファクトリーパターンを効果的に活用
- **環境固有の設定**を柔軟に処理
- **エラーハンドリング**とフォールバック機構を実装
- **テスト**では簡単にモックプロバイダーに切り替え可能

---

プロバイダーバインディングは、複雑な初期化ロジックを持つオブジェクトの作成に非常に有用です。適切に使用することで、保守しやすく柔軟なアプリケーションを構築できます。