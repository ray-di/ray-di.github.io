---
layout: docs-ja
title: プロバイダーパターン - オブジェクト生成パターン
category: Manual
permalink: /manuals/1.0/ja/tutorial/02-object-creation-patterns/provider-pattern.html
---

# プロバイダーパターン - オブジェクト生成パターン

## 学習目標

- 複雑な初期化ロジックが必要な場合の課題を理解する
- プロバイダーパターンで初期化をカプセル化する方法を学ぶ
- ファクトリーパターンとの違いを理解する

## 問題：複雑な初期化ロジックによるコンストラクタの肥大化

オブジェクト生成時に環境変数の読み取り、複数の設定、条件分岐が必要な場合、コンストラクタが肥大化します。

```php
class DatabaseConnection
{
    public function __construct()
    {
        // ❌ 問題：初期化ロジックが複雑すぎる
        $host = getenv('DB_HOST') ?: 'localhost';
        $port = getenv('DB_PORT') ?: '3306';
        $dsn = "mysql:host={$host};port={$port};...";

        $this->pdo = new PDO($dsn, getenv('DB_USER'), getenv('DB_PASS'));
        $this->pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $this->pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

        // 接続プーリング、ロギング設定...
    }
}
```

### なぜこれが問題なのか

1. **コンストラクタでのロジック実行**
   - コンストラクタは代入のみが推奨
   - 複雑なロジックはテストが困難

2. **環境依存の設定**
   - 環境変数への直接アクセス
   - テストで異なる設定を使いづらい

3. **関心事の混在**
   - 「接続の使用」と「接続の初期化」が混在
   - 単一責任原則違反

## 解決策：プロバイダーパターン

**プロバイダーの役割**：複雑な初期化ロジックをカプセル化

```php
// 1. シンプルなエンティティクラス
class DatabaseConnection
{
    public function __construct(
        private PDO $pdo  // シンプルに！
    ) {}

    public function query(string $sql, array $params = []): array
    {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }
}

// 2. プロバイダーで複雑な初期化を担当
class DatabaseConnectionProvider implements ProviderInterface
{
    public function get(): DatabaseConnection
    {
        // 複雑な初期化ロジックをここに集約
        $dsn = $this->buildDsn();
        $username = getenv('DB_USER') ?: 'root';
        $password = getenv('DB_PASS') ?: '';

        $pdo = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);

        return new DatabaseConnection($pdo);
    }

    private function buildDsn(): string
    {
        return sprintf(
            "mysql:host=%s;port=%s;dbname=%s",
            getenv('DB_HOST') ?: 'localhost',
            getenv('DB_PORT') ?: '3306',
            getenv('DB_NAME') ?: 'app'
        );
    }
}

// 3. DIモジュールで束縛
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(DatabaseConnection::class)
            ->toProvider(DatabaseConnectionProvider::class)
            ->in(Singleton::class);
    }
}
```

## パターンの本質

```
通常のDI:
DI Container → New Object (シンプルなコンストラクタ)

プロバイダー束縛:
DI Container → Provider.get() → 複雑な初期化 → New Object
```

### プロバイダーが解決すること

1. **関心事の分離**
   - エンティティ：ビジネスロジック
   - プロバイダー：複雑な初期化

2. **コンストラクタをシンプルに**
   - コンストラクタは代入のみ
   - ロジックはプロバイダーに

3. **環境ごとの切り替え**
   ```php
   // 開発環境用
   class DevDatabaseConnectionProvider implements ProviderInterface
   {
       public function get(): DatabaseConnection
       {
           return new DatabaseConnection(new PDO('sqlite::memory:'));
       }
   }

   // 本番環境用
   class ProdDatabaseConnectionProvider implements ProviderInterface
   {
       public function get(): DatabaseConnection
       {
           // 本番用の複雑な設定
       }
   }
   ```

## ファクトリーとプロバイダーの違い

| 特徴 | ファクトリーパターン | プロバイダーパターン |
|------|-------------------|-------------------|
| **目的** | 実行時パラメータの注入 | 複雑な初期化のカプセル化 |
| **パラメータ** | 実行時に決定 | 設定時に決定 |
| **生成頻度** | 必要なたびに生成 | 通常はシングルトン |
| **Ray.Di** | ファクトリークラス | `toProvider()`束縛 |

## 使い分けの判断基準

```
オブジェクト生成が必要
│
├─ 実行時パラメータが必要？
│  ├─ YES → ファクトリーパターン
│  └─ NO  ↓
│
├─ 初期化が複雑？
│  ├─ YES → ✅ プロバイダー束縛
│  └─ NO  → 通常のDI束縛
```

### プロバイダーを使うべき場合

| 状況 | 例 |
|------|-----|
| **環境変数の読み取り** | データベース接続、API設定 |
| **多段階の設定** | クライアントの初期化、設定の組み立て |
| **条件分岐** | 環境ごとに異なる実装 |
| **外部リソース接続** | DB、ファイルシステム、API |

## よくあるアンチパターン

### プロバイダーでの状態保持

```php
// ❌ プロバイダーが状態を持つ
class DatabaseConnectionProvider implements ProviderInterface
{
    private ?DatabaseConnection $instance = null;  // 状態保持

    public function get(): DatabaseConnection
    {
        if ($this->instance === null) {
            $this->instance = $this->createConnection();
        }
        return $this->instance;
    }
}

// ✅ スコープでシングルトンを管理
$this->bind(DatabaseConnection::class)
    ->toProvider(DatabaseConnectionProvider::class)
    ->in(Singleton::class);  // Ray.Diがシングルトンを管理
```

**なぜ問題か**：スコープ管理の責任が不明確、DIコンテナの機能と重複

### 実行時パラメータの誤用

```php
// ❌ 実行時パラメータが必要ならファクトリーを使うべき
class OrderProcessorProvider implements ProviderInterface
{
    public function get(): OrderProcessor
    {
        $orderId = $_GET['order_id'];  // グローバル変数参照
        return new OrderProcessor($orderId, ...);
    }
}

// ✅ ファクトリーパターンを使用
interface OrderProcessorFactoryInterface
{
    public function create(int $orderId): OrderProcessor;
}
```

**なぜ問題か**：プロバイダーとファクトリーの責任が混同

## SOLID原則との関係

- **SRP**：プロバイダーは「複雑な初期化」のみを担当
- **DIP**：インターフェースに依存、初期化の詳細を隠蔽
- **OCP**：環境ごとに異なるプロバイダーを作成し拡張

## まとめ

### プロバイダーパターンの核心

- **複雑な初期化をカプセル化**：コンストラクタをシンプルに保つ
- **環境ごとの設定**：開発/本番で異なるプロバイダー
- **テスト可能性**：インメモリ実装への切り替え

### 選択ガイド

- **実行時パラメータ** → ファクトリーパターン
- **複雑な初期化** → プロバイダー束縛
- **シンプルな依存関係** → 通常のDI束縛

### 次のステップ

オブジェクト生成パターンを理解したので、次は実行時の振る舞いを切り替える方法を学びます。

**続きは:** [ストラテジーパターン](../03-behavior-patterns/strategy-pattern.html)

---

プロバイダーパターンは、**初期化の複雑さをカプセル化**することで、エンティティクラスをシンプルに保ちます。
