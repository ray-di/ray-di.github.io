---
layout: docs-ja
title: リポジトリパターン - アーキテクチャパターン
category: Manual
permalink: /manuals/1.0/ja/tutorial/04-architecture-patterns/repository-pattern.html
---

# リポジトリパターン - アーキテクチャパターン

## 学習目標

- データアクセスロジックとビジネスロジックの混在を理解する
- リポジトリパターンでドメインとインフラを分離する方法を学ぶ
- ドメイン駆動設計（DDD）における重要性を理解する

## 問題：データアクセスロジックの散在

ビジネスロジックにSQLやデータベース操作が直接書かれています。

```php
class OrderService
{
    public function __construct(
        private PDO $pdo
    ) {}

    public function processOrder(int $orderId): void
    {
        // ❌ 問題：ビジネスロジックとデータアクセスが混在
        $stmt = $this->pdo->prepare('SELECT * FROM orders WHERE id = ?');
        $stmt->execute([$orderId]);
        $orderData = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$orderData) {
            throw new OrderNotFoundException();
        }

        // ビジネスロジック
        $orderData['status'] = 'processing';
        $orderData['processed_at'] = date('Y-m-d H:i:s');

        // データ更新
        $stmt = $this->pdo->prepare(
            'UPDATE orders SET status = ?, processed_at = ? WHERE id = ?'
        );
        $stmt->execute([
            $orderData['status'],
            $orderData['processed_at'],
            $orderId
        ]);
    }
}
```

### なぜこれが問題なのか

1. **単一責任原則違反**
   - `OrderService`がビジネスロジックとデータアクセスの両方を担当
   - SQLとビジネスルールが混在

2. **テストの困難さ**
   - ビジネスロジックのテストに実際のデータベースが必要
   - ユニットテストが遅い

3. **データベース技術への強い結合**
   - MySQLからPostgreSQLに変更 = すべてのサービスを修正
   - ORMへの移行が困難

## 解決策：リポジトリパターン

**リポジトリの役割**：データアクセスを抽象化し、コレクションのように扱う

```php
// 1. ドメインモデル（ビジネスルール）
class Order
{
    public function __construct(
        private int $id,
        private int $userId,
        private OrderStatus $status,
        private ?DateTimeImmutable $processedAt = null
    ) {}

    // ビジネスロジック
    public function process(): void
    {
        if ($this->status === OrderStatus::Cancelled) {
            throw new InvalidOperationException();
        }
        $this->status = OrderStatus::Processing;
        $this->processedAt = new DateTimeImmutable();
    }

    public function getId(): int { return $this->id; }
    public function getStatus(): OrderStatus { return $this->status; }
}

// 2. リポジトリインターフェース（ドメイン層）
interface OrderRepositoryInterface
{
    public function findById(int $id): ?Order;
    public function save(Order $order): void;
}

// 3. リポジトリ実装（インフラストラクチャ層）
class MySQLOrderRepository implements OrderRepositoryInterface
{
    public function __construct(
        private PDO $pdo
    ) {}

    public function findById(int $id): ?Order
    {
        $stmt = $this->pdo->prepare('SELECT * FROM orders WHERE id = ?');
        $stmt->execute([$id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);

        return $data ? $this->hydrate($data) : null;
    }

    public function save(Order $order): void
    {
        $data = $this->extract($order);

        if ($this->exists($order->getId())) {
            $this->update($data);
        } else {
            $this->insert($data);
        }
    }

    /** 配列をドメインオブジェクトに変換 */
    private function hydrate(array $data): Order
    {
        return new Order(
            id: (int) $data['id'],
            userId: (int) $data['user_id'],
            status: OrderStatus::from($data['status']),
            processedAt: $data['processed_at']
                ? new DateTimeImmutable($data['processed_at'])
                : null
        );
    }

    /** ドメインオブジェクト → データベース行 */
    private function extract(Order $order): array
    {
        return [
            'id' => $order->getId(),
            'user_id' => $order->getUserId(),
            'status' => $order->getStatus()->value,
            'processed_at' => $order->getProcessedAt()?->format('Y-m-d H:i:s')
        ];
    }
}

// 4. クリーンなサービス層
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository
    ) {}

    public function processOrder(int $orderId): void
    {
        // ✅ データアクセスの詳細を知らない
        $order = $this->orderRepository->findById($orderId);

        if (!$order) {
            throw new OrderNotFoundException();
        }

        // ビジネスロジック
        $order->process();

        // 永続化（詳細はリポジトリが担当）
        $this->orderRepository->save($order);
    }
}
```

## パターンの本質

```
階層化アーキテクチャ:
┌────────────────────┐
│  Application Layer │ ← OrderService（ビジネスロジック協調）
├────────────────────┤
│    Domain Layer    │ ← Order, OrderRepositoryInterface
├────────────────────┤
│ Infrastructure     │ ← MySQLOrderRepository（データアクセス）
└────────────────────┘

依存の方向:
Application → Domain ← Infrastructure
              ↑
         インターフェース
```

### リポジトリが解決すること

1. **関心事の分離**
   - ドメイン層：ビジネスルールとエンティティ
   - インフラ層：データベース、外部API

2. **テスト可能性**
   ```php
   // テスト用インメモリリポジトリ
   class InMemoryOrderRepository implements OrderRepositoryInterface
   {
       private array $orders = [];

       public function findById(int $id): ?Order
       {
           return $this->orders[$id] ?? null;
       }

       public function save(Order $order): void
       {
           $this->orders[$order->getId()] = $order;
       }
   }

   // ユニットテスト
   $repository = new InMemoryOrderRepository();
   $service = new OrderService($repository);
   // 高速なテスト、データベース不要
   ```

3. **データベース技術の切り替え**
   ```php
   // PostgreSQLへの切り替え
   class PostgreSQLOrderRepository implements OrderRepositoryInterface
   {
       // 同じインターフェース、異なる実装
   }

   // モジュールで切り替え
   $this->bind(OrderRepositoryInterface::class)
       ->to(PostgreSQLOrderRepository::class);
   ```

## 使い分けの判断基準

```
データアクセスが必要
│
├─ ビジネスロジックが複雑？
│  ├─ YES → 複数のデータソース？
│  │         ├─ YES → ✅ リポジトリパターン
│  │         └─ NO  → テスト容易性が重要？
│  │                   ├─ YES → ✅ リポジトリパターン
│  │                   └─ NO  → ORMで十分
│  └─ NO  → 単純なCRUD？
│            ├─ YES → アクティブレコード
│            └─ NO  → ✅ リポジトリパターン
```

### リポジトリパターンを使うべき場合

| 状況 | 理由 |
|------|------|
| **ドメイン駆動設計** | ビジネスロジックをインフラから分離 |
| **複数のデータソース** | MySQL、MongoDB、外部APIなど |
| **テスト駆動開発** | インメモリリポジトリで高速テスト |
| **複雑なクエリ** | 仕様パターンでクエリをカプセル化 |

### リポジトリが過剰な場合

| 状況 | 代替手段 |
|------|---------|
| **単純なCRUD** | アクティブレコードパターン |
| **小規模プロジェクト** | ORMの直接使用 |
| **読み取り専用** | クエリサービス |

## よくあるアンチパターン

### リークする抽象化

```php
// ❌ PDOStatementを返す（実装詳細が漏れている）
interface OrderRepositoryInterface
{
    public function findById(int $id): PDOStatement;
}

// ✅ ドメインオブジェクトを返す
interface OrderRepositoryInterface
{
    public function findById(int $id): ?Order;
}
```

**なぜ問題か**：インターフェースがインフラの詳細に依存

### 汎用リポジトリ

```php
// ❌ すべてのエンティティに対する汎用リポジトリ
interface GenericRepositoryInterface
{
    public function find(string $entityClass, int $id): ?object;
}

// ✅ エンティティ固有のリポジトリ
interface OrderRepositoryInterface
{
    public function findById(int $id): ?Order;
    public function findByUserId(int $userId): array;
}
```

**なぜ問題か**：型安全性の喪失、ドメイン固有の操作を表現できない

### リポジトリでのビジネスロジック

```php
// ❌ リポジトリがビジネスロジックを持つ
class OrderRepository implements OrderRepositoryInterface
{
    public function save(Order $order): void
    {
        // リポジトリでビジネスロジックを実行しない！
        if ($order->getTotal() > 10000) {
            $this->sendNotification($order);
        }
        $this->persist($order);
    }
}

// ✅ リポジトリはデータアクセスのみ
class OrderRepository implements OrderRepositoryInterface
{
    public function save(Order $order): void
    {
        $this->persist($order);  // データアクセスのみ
    }
}
```

**なぜ問題か**：責任が不明確、ビジネスルールがインフラ層に漏れる

## SOLID原則との関係

- **SRP**：リポジトリはデータアクセスのみ、サービスはビジネスロジックのみ
- **OCP**：新しいデータソースの追加時、既存コードを変更しない
- **LSP**：すべてのリポジトリ実装が同じインターフェースを実装
- **ISP**：エンティティごとに専用のリポジトリインターフェース
- **DIP**：サービス層はリポジトリインターフェースに依存、具象実装に依存しない

## まとめ

### リポジトリパターンの核心

- **データアクセスの抽象化**：ドメイン層がインフラの詳細を知らない
- **テスト可能性**：インメモリリポジトリで高速テスト
- **データベース技術の切り替え**：サービス層に影響しない

### パターンの効果

- ✅ ビジネスロジックがデータアクセスの詳細を知らない
- ✅ データベース技術の変更がサービス層に影響しない
- ✅ 高速なユニットテスト（インメモリ実装）
- ✅ SQLクエリの重複を排除

### 次のステップ

データアクセス層を抽象化したので、次はビジネスロジックの協調を学びます。

**続きは:** [サービス層](service-layer.html)

---

リポジトリパターンは、**ドメイン駆動設計の中核パターン**の一つです。ドメインモデルをインフラストラクチャから保護し、ビジネスロジックをクリーンに保つことができます。
