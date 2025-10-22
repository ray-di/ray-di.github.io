---
layout: docs-ja
title: Providerパターン
category: Manual
permalink: /manuals/1.0/ja/tutorial/provider-pattern.html
---
# 依存性注入におけるProviderパターン

## 問題

オブジェクト作成にコンストラクタに属さない複雑な初期化ロジックが必要です:

```php
class DatabaseConnection
{
    public function __construct(
        private string $host,
        private string $database,
        private string $username,
        private string $password
    ) {
        // 問題: コンストラクタで処理が多すぎる
        $this->connection = new PDO(
            "mysql:host={$host};dbname={$database}",
            $username,
            $password
        );
        $this->connection->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $this->connection->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        $this->connection->exec("SET NAMES utf8mb4");
        $this->connection->exec("SET time_zone = '+00:00'");

        if ($_ENV['DB_PROFILING']) {
            $this->connection->setAttribute(PDO::ATTR_STATEMENT_CLASS, [ProfilingStatement::class]);
        }
        // さらに多くの設定手順...
    }
}
```

## なぜ問題なのか

1. **コンストラクタの肥大化**: コンストラクタは依存関係の割り当てのみを行うべきで、複雑なロジックを実行すべきではない
2. **テストの困難**: 実際のデータベース接続なしで初期化をテストできない
3. **SRP違反**: コンストラクタが初期化と割り当ての両方を行っている
4. **設定の結合**: 環境に基づいて初期化を変更するのが難しい

コンストラクタでロジックを実行 = テストが困難、設定が困難、保守が困難。

## 解決策: Providerパターン

```php
// Providerインターフェース（Ray.Di組み込み）
use Ray\Di\ProviderInterface;

class DatabaseConnectionProvider implements ProviderInterface
{
    public function __construct(
        private DatabaseConfigInterface $config
    ) {}

    public function get(): DatabaseConnection
    {
        $pdo = new PDO(
            $this->config->getDsn(),
            $this->config->getUsername(),
            $this->config->getPassword()
        );

        // 複雑な初期化ロジックをここに配置
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        $pdo->exec("SET NAMES utf8mb4");

        if ($this->config->isProfiling()) {
            $pdo->setAttribute(PDO::ATTR_STATEMENT_CLASS, [ProfilingStatement::class]);
        }

        return new DatabaseConnection($pdo);
    }
}

// クリーンなコンストラクタ - 割り当てのみ！
class DatabaseConnection
{
    public function __construct(private PDO $pdo) {}

    public function query(string $sql, array $params = []): array
    {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }
}
```

**DI設定:**
```php
$this->bind(DatabaseConnection::class)
     ->toProvider(DatabaseConnectionProvider::class)
     ->in(Singleton::class);
```

## パターンの本質

```
DIコンテナ ──> Provider.get() ──> 複雑な初期化 ──> オブジェクト
                                  (多段階、条件付き、
                                   環境固有)
```

**重要な洞察**: Providerはコンストラクタの外で複雑なオブジェクト作成ロジックをカプセル化します。

## 判断基準

### ✅ Providerを使用する場合

- オブジェクトに**多段階の初期化**が必要
- 初期化に**条件付きロジック**が含まれる
- **環境固有**のセットアップが必要（開発 vs 本番 vs テスト）
- 初期化に**他の依存関係**が必要
- オブジェクト作成を**遅延**させたい（遅延ロード）

### ❌ Providerを使用しない場合

- シンプルなコンストラクタインジェクションで機能する
- 条件付きや複雑なロジックが不要
- オブジェクト作成が1行で済む

**不要なProviderの例:**
```php
// 悪い例: 過剰設計
class UserServiceProvider implements ProviderInterface
{
    public function get(): UserService
    {
        return new UserService($this->repository); // ただのコンストラクタ呼び出し！
    }
}

// 良い例: 直接バインディング
$this->bind(UserServiceInterface::class)->to(UserService::class);
```

## アンチパターン

### 1. ビジネスロジックを含むProvider

```php
// ❌ 悪い例 - Providerにビジネスロジック
class OrderProvider implements ProviderInterface
{
    public function get(): Order
    {
        $order = new Order();
        if ($this->customer->isPremium()) { // ビジネスロジック！
            $order->applyDiscount(0.1);
        }
        return $order;
    }
}

// ✅ 良い例 - Providerは初期化のみを扱う
class OrderProvider implements ProviderInterface
{
    public function get(): Order
    {
        return new Order($this->validator, $this->calculator);
    }
}
```

**なぜ悪いのか**: Providerはオブジェクトを作成し、サービスはビジネス操作を処理します。

### 2. シングルトンの代替としてのProvider

```php
// ❌ 悪い例 - Provider内でシングルトンを再実装
class CacheProvider implements ProviderInterface
{
    private ?Cache $instance = null;

    public function get(): Cache
    {
        if ($this->instance === null) {
            $this->instance = new Cache();
        }
        return $this->instance; // これをしてはいけない！
    }
}

// ✅ 良い例 - スコープを使用
$this->bind(CacheInterface::class)
     ->toProvider(CacheProvider::class)
     ->in(Singleton::class); // DIにライフサイクルを処理させる
```

**なぜ悪いのか**: スコープがオブジェクトのライフサイクルを処理します - 再実装しないでください。

## Provider vs Factory

| 側面 | Provider | Factory |
|------|----------|---------|
| 目的 | 複雑な初期化 | 実行時パラメータ + DI |
| 呼び出し元 | DIコンテナ | あなたのコード |
| パラメータ | なし（DIを使用） | 実行時パラメータ |
| 使用時期 | 多段階セットアップ | 実行時データが必要 |

**違いを示す例:**

```php
// Provider: DIが呼び出し、パラメータなし
class LoggerProvider implements ProviderInterface
{
    public function get(): LoggerInterface // ← パラメータなし
    {
        // 環境固有の初期化
        if ($this->env === 'production') {
            return new FileLogger('/var/log/app.log');
        }
        return new ConsoleLogger();
    }
}

// Factory: あなたが呼び出し、パラメータあり
interface OrderFactoryInterface
{
    public function create(Customer $customer, array $items): Order; // ← パラメータ
}
```

## SOLID原則

- **単一責任原則**: Providerは作成を処理し、オブジェクトは振る舞いを処理
- **開放閉鎖原則**: オブジェクトを変更せずに初期化を変更
- **依存性逆転の原則**: Providerインターフェースに依存し、作成ロジックには依存しない

## テスト

Providerは独立してテストしやすいです:

```php
public function testProductionLogger(): void
{
    $provider = new LoggerProvider('production', '/var/log/app.log');
    $logger = $provider->get();

    $this->assertInstanceOf(FileLogger::class, $logger);
}

public function testDevelopmentLogger(): void
{
    $provider = new LoggerProvider('development', '/tmp/dev.log');
    $logger = $provider->get();

    $this->assertInstanceOf(ConsoleLogger::class, $logger);
}
```

## 重要なポイント

- **Providerパターン**は複雑なオブジェクト初期化をカプセル化
- 作成に**多段階セットアップ**や**条件付きロジック**が必要な場合に使用
- Providerは**コンストラクタをクリーンに保つ**（割り当てのみ、ロジックなし）
- Factoryとは異なる: Providerには**実行時パラメータがない**
- **環境固有**の設定（開発/本番/テスト）に最適

---

**次:** [Strategyパターン](../03-behavioral/strategy-pattern.html) - 切り替え可能な振る舞い

**前:** [Factoryパターン](factory-pattern.html)
