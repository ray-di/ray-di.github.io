---
layout: docs-ja
title: Provider Pattern
category: Manual
permalink: /manuals/1.0/ja/study/02-object-creation/provider-pattern.html
---
# Providerパターン：複雑な初期化の分離

## 問題

オブジェクトの生成に複雑な初期化ロジックが必要になったことはありませんか？データベース接続を考えてみてください。接続パラメータの設定、エラーモードの構成、文字セットの指定、タイムゾーンの設定など、多くのステップが必要です。このロジックをコンストラクタに書くと、コードが肥大化します：

```php
class DatabaseConnection
{
    public function __construct(
        private string $host,
        private string $database,
        private string $username,
        private string $password
    ) {
        // 問題：コンストラクタが多くの処理を実行
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
        // さらに多くの設定ステップ...
    }
}
```

## なぜ問題なのか

これはコンストラクタのシンプルさと初期化の複雑さという根本的な対立を生み出します。コンストラクタは依存関係を代入するだけであるべきで、ロジックを実行すべきではありません。しかしこのコンストラクタは、接続設定、属性の構成、条件付き初期化を実行しています。実際のデータベースなしにはテストできません。

コンストラクタが依存関係の代入と環境固有の初期化という2つの異なる責任を持っています。初期化ロジックの変更にはコンストラクタの修正が必要となり、クラスが脆弱で保守困難になります。

## 解決策：Providerパターン

Providerパターンは、初期化と構築を分離することでこの問題を解決します。専用のProviderが複雑なセットアップを処理し、コンストラクタはシンプルに保たれます。Ray.DiはProviderの`get()`メソッドを呼び出して初期化を実行し、設定済みのオブジェクトを返します：

```php
use Ray\Di\ProviderInterface;

// Providerが複雑な初期化を処理
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

        // コンストラクタではなく、ここで多段階の初期化
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        $pdo->exec("SET NAMES utf8mb4");

        if ($this->config->isProfiling()) {
            $pdo->setAttribute(PDO::ATTR_STATEMENT_CLASS, [ProfilingStatement::class]);
        }

        return new DatabaseConnection($pdo);
    }
}

// コンストラクタはクリーンに - 代入のみ
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

Providerバインディングの設定：
```php
$this->bind(DatabaseConnection::class)
     ->toProvider(DatabaseConnectionProvider::class)
     ->in(Singleton::class);
```

## パターンの本質

Providerパターンは明確な分離を作り出します：コンストラクタは「何を」（依存関係）を受け取り、Providerは「どのように」（初期化）を制御します。DIコンテナがProviderを呼び出し、Providerが複雑なセットアップを実行してから設定済みのオブジェクトを返します。

```
DIコンテナ ──> Provider.get() ──> 多段階初期化 ──> オブジェクト
                                 (条件ロジック、
                                  環境設定)
```

なぜこれが重要なのでしょうか？開発環境から本番環境に切り替える際、設定オブジェクトだけを変更します。プロファイリングを追加する際、Providerだけを修正します。接続プールを調整する際、ドメインクラスには触れません。各変更には単一の場所があります。ドメインオブジェクトのコンストラクタは依存関係の代入に集中したシンプルなものに保たれます。

## Providerパターンをいつ使うか

オブジェクト生成に多段階の初期化が必要な場合にProviderパターンを使用します。環境に基づく条件付き設定、順序が重要な段階的セットアップ、他の依存関係が必要な初期化などが含まれます。

Providerは環境固有の設定に優れています。開発環境は本番環境とは異なる接続タイムアウトが必要です。テスト環境はステージング環境とは異なるリトライポリシーが必要です。Providerはこれらのバリエーションを一箇所に集約します。

## Providerを避けるべき場合

シンプルなケースではProviderを避けてください。複雑なセットアップなしにコンストラクタインジェクションが機能する場合は、それを直接使用します。単にコンストラクタを呼び出すだけのProviderを作成しないでください。それは不必要な間接化を追加します。

## よくある間違い：状態を持つProvider

Providerはステートレスであるべきです。頻繁に見られるアンチパターンは、Provider内でインスタンスをキャッシュすることです：

```php
// ❌ 悪い例 - Providerがインスタンスのライフサイクルを管理
class CacheProvider implements ProviderInterface
{
    private ?Cache $instance = null;

    public function get(): Cache
    {
        if ($this->instance === null) {
            $this->instance = new Cache();
        }
        return $this->instance; // これをやってはいけません！
    }
}

// ✅ 良い例 - ライフサイクル管理にスコープを使用
$this->bind(CacheInterface::class)
     ->toProvider(CacheProvider::class)
     ->in(Singleton::class); // DIがライフサイクルを処理
```

オブジェクトのライフサイクルはスコープを通じてDIコンテナに管理させましょう。DIコンテナは並行性とキャッシングを正しく処理します。各Provider呼び出しは新しいオブジェクトを作成するか、キャッシュされたインスタンスを返します—スコープが決定し、あなたのコードではありません。Providerは構築と初期化だけに集中すべきです。

## ProviderとFactoryの違い

ProviderとFactoryは異なる問題を解決します：

| 側面 | Provider | Factory |
|-----|----------|---------|
| 目的 | 複雑な初期化 | 実行時パラメータ + DI |
| 呼び出し元 | DIコンテナ | あなたのコード |
| パラメータ | なし（注入された依存関係を使用） | 実行時パラメータ |
| 使用場面 | 環境固有のセットアップ | 実行時データが必要なオブジェクト |

Providerはパラメータを持ちません。DIコンテナがオブジェクトグラフ構築時に呼び出します。Factoryは実行時パラメータを受け取り、必要なときにあなたのコードが呼び出します。

## SOLID原則

Providerパターンは初期化をドメインロジックから分離することで**単一責任原則**を実施します。Providerだけを修正し、ドメインクラスには触れないことで**開放/閉鎖原則**をサポートします。具体的な初期化ロジックではなくProviderインターフェースに依存することで**依存性逆転原則**を支持します。

## テスト

Providerは初期化ロジックの独立したテストを可能にします。Providerなしでは、環境固有のセットアップをテストするには、PDO、データベース接続、設定リーダーをモックする必要があります。Providerを使用すれば、異なる設定オブジェクトだけでテストできます。テスト対象が劇的に縮小します。

本番設定でProviderを作成し、本番設定が適用されることを確認します。開発設定で別のProviderを作成し、開発設定が適用されることを確認します。複雑なモックは不要です。ドメインオブジェクトはシンプルに保たれ、環境固有のテストケースは必要ありません。

## 重要なポイント

Providerパターンは複雑なオブジェクト初期化をコンストラクタの外で処理します。多段階のセットアップ、条件付き設定、環境固有の初期化に使用します。Providerをステートレスに保ち、オブジェクトのライフサイクルはDIに管理させます。ProviderはFactoryと異なります：実行時パラメータなし、DIによる呼び出し、初期化の複雑さに焦点を当てます。

---

**次へ：** [Strategy Pattern](../03-behavioral/strategy-pattern.html) - 切り替え可能な振る舞い

**前へ：** [Factory Pattern](factory-pattern.html)