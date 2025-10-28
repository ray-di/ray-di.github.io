---
layout: docs-ja
title: Repositoryパターン
category: Manual
permalink: /manuals/1.0/ja/study/04-architecture/repository-pattern.html
---
# Repositoryパターン：データアクセスの分離

## 問題

データアクセスコードがビジネスロジックに直接混在しています。注文を永続化する必要がある注文サービスを考えてみましょう。サービスにはビジネスルールと並んで、SQLクエリ、スキーマの知識、データベース固有の詳細が含まれています：

```php
class OrderService
{
    public function __construct(private PDO $database) {}

    public function processOrder(Order $order): void
    {
        // ビジネスロジックとSQLが混在！
        $stmt = $this->database->prepare(
            'INSERT INTO orders (customer_id, total, status) VALUES (?, ?, ?)'
        );
        $stmt->execute([
            $order->getCustomerId(),
            $order->getTotal(),
            $order->getStatus()
        ]);

        $orderId = $this->database->lastInsertId();

        foreach ($order->getItems() as $item) {
            $stmt = $this->database->prepare(
                'INSERT INTO order_items (order_id, product_id, quantity) VALUES (?, ?, ?)'
            );
            $stmt->execute([$orderId, $item->getProductId(), $item->getQuantity()]);
        }
    }
}
```

## なぜ問題なのか

これはビジネスロジックとデータストレージの間に根本的な結合を生み出します。サービスはテーブル名、カラム名、SQL構文を知っています。MySQLからMongoDBに変更する際にサービスを書き直さなければなりません。注文処理のテストには実際のデータベースとテストデータが必要です。

サービスはドメインの動作と永続化のメカニズムの両方を処理することで単一責任原則に違反しています。クエリロジックは再利用できません—注文が必要なすべてのサービスは独自のSQLを書かなければなりません。スキーマの変更は注文に触れるすべてのサービスメソッドに波及します。

## 解決策：Repositoryパターン

Repositoryパターンは、コレクションのようなインターフェースの背後にデータアクセスをカプセル化することで、この問題を解決します。サービスはリポジトリメソッドを通じてドメインオブジェクトを操作します。データベースの詳細はリポジトリ実装の内部に隠れています：

```php
// Repositoryインターフェース - データアクセスを抽象化
interface OrderRepositoryInterface
{
    public function save(Order $order): void;
    public function findById(int $id): ?Order;
    public function findByCustomer(int $customerId): array;
}

// 実装 - データベースの詳細は隠蔽
class MySQLOrderRepository implements OrderRepositoryInterface
{
    public function __construct(private PDO $database) {}

    public function save(Order $order): void
    {
        if ($order->getId() === null) {
            $this->insert($order);
        } else {
            $this->update($order);
        }
    }

    public function findById(int $id): ?Order
    {
        $stmt = $this->database->prepare('SELECT * FROM orders WHERE id = ?');
        $stmt->execute([$id]);
        $data = $stmt->fetch();

        return $data ? $this->hydrate($data) : null;
    }

    private function insert(Order $order): void { /* SQL INSERT ロジック */ }
    private function update(Order $order): void { /* SQL UPDATE ロジック */ }
    private function hydrate(array $data): Order { /* 配列をOrderに変換 */ }
}

// クリーンなビジネスロジック - データベースの知識なし！
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository
    ) {}

    public function processOrder(Order $order): void
    {
        $this->orderRepository->save($order);
    }
}
```

## パターンの本質

Repositoryパターンは明確な分離を生み出します：サービスは「何を」必要とするか（save、find、delete）を知り、リポジトリは「どのように」実行するか（SQL、MongoDB、キャッシュ）を知ります。インターフェースはインメモリコレクションを操作するかのように操作を定義します。

```
変更前：Service → SQL → Database
変更後：Service → Repository Interface → Implementation → Database
```

なぜこれが重要なのでしょうか？MySQLからMongoDBに切り替える際、リポジトリ実装だけを変更します。キャッシングを追加する際、CachingOrderRepositoryデコレーターを作成します。ビジネスロジックをテストする際、データベースなしでリポジトリインターフェースをモックします。各データアクセスの関心事には単一の場所があります—それを実装するリポジトリ。

## Repositoryパターンを使用するとき

複数のサービスがアクセスする永続ドメインオブジェクトがある場合にRepositoryパターンを使用します。これには注文、顧客、製品のような、クエリ、保存、複雑な取得ロジックが必要なエンティティが含まれます。リポジトリはビジネスロジックからデータベースを抽象化したり、ストレージ実装を切り替えたりする必要がある場合に優れています。

データアクセスロジックが再利用可能な場合、リポジトリは価値を提供します。3つのサービスが顧客別に注文を検索する必要がある場合、1つのリポジトリメソッドがすべてに対応します。テストにデータベースの抽象化が必要な場合、リポジトリはフィクスチャなしでビジネスロジックをテスト可能にします。

## Repositoryを避けるとき

ビジネスロジックがないシンプルなCRUD操作にはリポジトリを避けてください。データアクセスが1つの場所でしか発生せず、再利用されない場合、シンプルなデータアクセスクラスで十分です。DoctrineやEloquentのようにすでにリポジトリパターンを提供するORMを使用している場合、冗長な抽象化を作成しないでください。静的なルックアップテーブルや読み取り専用の参照データにリポジトリを作成しないでください—シンプルなクエリメソッドの方が適しています。

## よくある間違い：汎用リポジトリ

頻繁に見られるアンチパターンは、すべてのエンティティに対して1つの汎用リポジトリを作成することです：

```php
// ❌ 悪い例 - 汎用リポジトリは型安全性を失う
interface GenericRepositoryInterface
{
    public function find(int $id): mixed;
    public function save(mixed $entity): void;
}

// ✅ 良い例 - 型固有のリポジトリ
interface OrderRepositoryInterface
{
    public function findById(int $id): ?Order;
    public function save(Order $order): void;
    public function findByCustomer(int $customerId): array;
}
```

汎用リポジトリは型安全性とドメイン固有のクエリメソッドを失います。汎用リポジトリに`findByCustomer()`を持つことはできません—各エンティティには異なるクエリがあります。型ヒントは`mixed`になり、静的解析の利点が失われます。リポジトリはエンティティ固有であるべきで、そのエンティティの永続化操作への型安全なアクセスを提供します。

## SOLID原則

Repositoryパターンはデータアクセスをビジネスロジックから分離することで**単一責任原則**を強制します。**開放/閉鎖原則**をサポートします—ビジネスサービスではなく、リポジトリバインディングだけを変更することでMySQLからMongoDBに切り替えます。すべてのリポジトリ実装がインターフェースを通じて交換可能であるため、**リスコフの置換原則**を支持します。具体的なPDO、MongoDB、キャッシュ実装ではなく、リポジトリインターフェースに依存することで**依存性逆転の原則**を例示します。

## テスト

リポジトリはテストを劇的に簡素化します。リポジトリがない場合、注文処理のテストにはすべてのテストの後にデータベースセットアップ、フィクスチャ、トランザクション、クリーンアップが必要です。すべてのテストには実際のデータベース接続が必要です。リポジトリを使えば、リポジトリインターフェースをモックします。注文処理のテストにはリポジトリモックだけが必要です。テスト対象はデータベースインフラストラクチャからゼロの外部依存に縮小されます。

## 重要なポイント

Repositoryパターンはコレクションのようなインターフェースを通じてデータアクセスをビジネスロジックから分離します。複数のサービスが同じ永続エンティティにアクセスし、データベースの抽象化またはテスト容易性が必要な場合に使用します。リポジトリはCRUD操作を処理し、ビジネスロジックはサービスに留まります。汎用リポジトリを避けてください—ドメイン関連のクエリメソッドを提供する型固有のリポジトリを作成します。このパターンはビジネスコードに触れずにMySQLからMongoDBからキャッシングへの実装切り替えを可能にします。

---

**次へ：** [Service Layer](service-layer.html) - ビジネスロジックの調整

**前へ：** [Adapterパターン](adapter-pattern.html)
