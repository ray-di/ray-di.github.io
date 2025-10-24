---
layout: docs-ja
title: プロバイダーバインディング
category: Manual
permalink: /manuals/1.0/ja/tutorial/02-basic-bindings/provider-binding.html
---

# プロバイダーバインディング：複雑な初期化の解決策

## なぜプロバイダーが必要なのか

データベース接続を初期化するとき、環境変数の読み込み、接続オプションの設定、エラーハンドリング、接続プールの構成など、多くのステップが必要になったことはありませんか？このような複雑な初期化ロジックをコンストラクタに書くと、クラスの責任が曖昧になり、テストが困難になります。

プロバイダーバインディングは、この問題をエレガントに解決します。複雑なオブジェクト生成ロジックを専用のプロバイダークラスに分離し、DIコンテナがそのプロバイダーを通じてオブジェクトを取得するようにします。

## 基本構造：プロバイダーインターフェース

プロバイダーは`ProviderInterface`を実装し、`get()`メソッドでオブジェクトを返します：

```php
use Ray\Di\ProviderInterface;

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

// モジュールでバインド
$this->bind(PDO::class)->toProvider(DatabaseConnectionProvider::class);
```

この例では、データベース接続の複雑な設定をプロバイダーに隠蔽しています。使用側はPDOインスタンスを受け取るだけで、その初期化プロセスを知る必要がありません。

## 環境に応じた実装の切り替え

プロバイダーの最も強力な使用例の一つは、環境に応じて異なる実装を返すことです。開発環境ではモックサービスを使い、本番環境では実際のサービスを使う—この切り替えをプロバイダーが担当します：

```php
class EmailServiceProvider implements ProviderInterface
{
    public function get(): EmailServiceInterface
    {
        $environment = $_ENV['APP_ENV'] ?? 'production';

        return match($environment) {
            'development' => new MockEmailService(),
            'testing' => new LogEmailService('/tmp/emails.log'),
            'production' => new SendGridEmailService($_ENV['SENDGRID_API_KEY']),
            default => throw new InvalidArgumentException("Unknown environment: {$environment}")
        };
    }
}
```

このパターンにより、環境変数を一箇所で管理し、適切なサービス実装を選択できます。開発中にメールを実際に送信してしまう事故を防ぎ、テスト環境では動作を検証可能にします。

## プロバイダーへの依存注入

プロバイダー自身も依存性を持つことができます。これにより、複雑な初期化ロジックを柔軟に構成できます：

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
            'stripe' => new StripePaymentGateway(
                $this->config->getStripeApiKey()
            ),
            'paypal' => new PayPalPaymentGateway(
                $this->config->getPayPalClientId(),
                $this->config->getPayPalClientSecret()
            ),
            default => throw new InvalidArgumentException("Unknown payment provider: {$provider}")
        };
    }
}
```

プロバイダーのコンストラクタで`AppConfig`と`LoggerInterface`を受け取ることで、設定の管理とロギングを統一的に行えます。この依存性はRay.Diが自動的に注入します。

## 複雑な初期化プロセス

データベース接続のように、複数のステップを経て初期化が必要なオブジェクトこそ、プロバイダーの真価が発揮される場面です：

```php
class DatabaseConnectionProvider implements ProviderInterface
{
    public function __construct(private DatabaseConfig $config) {}

    public function get(): PDO
    {
        $dsn = $this->config->getDsn();
        [$username, $password] = $this->config->getCredentials();

        $connection = new PDO($dsn, $username, $password);

        // 接続後の設定
        $connection->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $connection->exec("SET NAMES utf8mb4");
        $connection->exec("SET time_zone = '+00:00'");

        return $connection;
    }
}
```

この例では、接続文字列の構築、認証情報の取得、接続後のオプション設定という複数のステップを、プロバイダーが一手に引き受けています。使用側は完全に設定されたPDOインスタンスを受け取るだけです。

## プロバイダーとファクトリーの違い

プロバイダーとファクトリーは似ていますが、重要な違いがあります。プロバイダーは引数を取らず、DIコンテナから呼び出されます。ファクトリーは実行時の引数を受け取り、アプリケーションコードから呼び出されます。

プロバイダーが適している場合は、オブジェクトの生成に複雑なロジックが必要で、環境に応じて異なる実装を返し、外部リソースの初期化が必要で、引数なしでオブジェクトを生成できる時です。

一方、ファクトリーが適している場合は、実行時のパラメータが必要で、ユーザー入力に基づいてオブジェクトを生成し、同じ型の複数のインスタンスを異なる設定で作成する時です。

## エラーハンドリングとフォールバック

プロバイダーでは、オブジェクト生成時のエラーを適切に処理し、必要に応じてフォールバック実装を返すことができます：

```php
class RobustServiceProvider implements ProviderInterface
{
    public function __construct(
        private AppConfig $config,
        private LoggerInterface $logger
    ) {}

    public function get(): ServiceInterface
    {
        try {
            $apiKey = $this->config->getApiKey();

            if (empty($apiKey)) {
                throw new InvalidArgumentException('API key is required');
            }

            return new ExternalService($apiKey);
        } catch (Exception $e) {
            $this->logger->error("Service creation failed: {$e->getMessage()}");

            // フォールバック実装を返す
            return new MockService();
        }
    }
}
```

この例では、外部サービスの初期化に失敗した場合、エラーをログに記録してモック実装を返します。これにより、開発環境でAPIキーがなくてもアプリケーションが動作します。

## テスト戦略

プロバイダーを使用することで、テストが劇的に簡単になります。本番用の複雑なプロバイダーの代わりに、テスト用の簡単なモックプロバイダーを使用できます：

```php
class TestModule extends AbstractModule
{
    protected function configure(): void
    {
        // テスト用のシンプルなプロバイダー
        $this->bind(PaymentGatewayInterface::class)
             ->toProvider(MockPaymentGatewayProvider::class);
    }
}

class MockPaymentGatewayProvider implements ProviderInterface
{
    public function get(): PaymentGatewayInterface
    {
        return new MockPaymentGateway();
    }
}
```

テスト環境では、このモジュールを使用することで、外部サービスに依存せずにビジネスロジックをテストできます。

## ベストプラクティス

プロバイダーを効果的に使用するためのポイントがいくつかあります。

まず、プロバイダーはシンプルに保つことです。オブジェクトの生成と初期化に集中し、ビジネスロジックを含めないようにします。複雑すぎるプロバイダーは、それ自体が保守の負担になります。

次に、プロバイダー自身もテスト可能にすることです。外部依存をコンストラクタインジェクションで受け取ることで、モックを使ったテストが容易になります。

最後に、エラーハンドリングを適切に行うことです。プロバイダーでのエラーは、アプリケーション全体に影響する可能性があるため、適切なフォールバックやエラーログを実装します。

## まとめ

プロバイダーバインディングは、複雑な初期化ロジックを持つオブジェクトの生成を、エレガントに解決します。環境固有の設定、複数ステップの初期化、外部リソースの管理など、実際のアプリケーションで頻繁に遭遇する問題に対する実践的な解決策です。

プロバイダー自身も依存性注入を受けられるため、柔軟で再利用可能な設計が可能です。また、テスト時には簡単にモック実装に切り替えられるため、テスタブルなコードを維持できます。

---

**次へ：** [マルチバインディング](../03-advanced-bindings/multi-binding.html)

**前へ：** [リンクバインディング](linked-binding.html)