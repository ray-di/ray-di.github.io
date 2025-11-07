---
layout: docs-ja
title: Decoratorパターン & AOP
category: Manual
permalink: /manuals/1.0/ja/study/03-behavioral/decorator-aop.html
---
# DecoratorパターンとAOP：横断的関心事の分離

## 問題

横断的関心事がビジネスロジック全体に散らばっています。ログ記録、トランザクション管理、キャッシュの無効化が必要な注文サービスを考えてみましょう。インフラストラクチャコードが実際のビジネスロジックを圧倒しています：

```php
class OrderService
{
    public function processOrder(Order $order): void
    {
        $this->logger->info("Processing order: {$order->getId()}");

        try {
            $this->db->beginTransaction();

            // 実際のビジネスロジック（たった2行！）
            $this->orderRepository->save($order);
            $this->inventoryService->reserve($order->getItems());

            $this->db->commit();
        } catch (Exception $e) {
            $this->db->rollback();
            $this->logger->error("Order failed: {$e->getMessage()}");
            throw $e;
        }

        $this->cache->delete("order_{$order->getId()}");
        $this->logger->info("Order processed");
    }
}
```

## なぜ問題なのか

これはビジネスロジックとインフラストラクチャの関心事の間に根本的な衝突を生み出します。このメソッドは注文処理を行いながら、ログ記録、トランザクション、キャッシングも管理しています。ログフォーマットを変更する際にビジネスロジックに触れないわけにはいきません。注文処理のテストにはロガー、データベース、キャッシュのモックが必要です。

コードはすべてのサービスメソッドでインフラストラクチャパターンを重複させています。トランザクションが必要なメソッドは同じtry-catch-commit-rollbackパターンを繰り返します。ログ記録が必要なメソッドは同じinfo-errorパターンを繰り返します。ビジネスロジック—実際のドメイン動作の2行—は12行のインフラストラクチャノイズに埋もれています。

## 解決策：Decoratorパターン

Decoratorパターンは、ビジネスロジックと横断的関心事を分離することで、この問題を解決します。コアサービスにはドメインロジックのみが含まれます。デコレーターがサービスをラップしてインフラストラクチャの動作を独立して追加します：

```php
// コアインターフェース
interface OrderServiceInterface
{
    public function processOrder(Order $order): void;
}

// 純粋なビジネスロジック - インフラストラクチャなし！
class OrderService implements OrderServiceInterface
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private InventoryServiceInterface $inventoryService
    ) {}

    public function processOrder(Order $order): void
    {
        $this->orderRepository->save($order);
        $this->inventoryService->reserve($order->getItems());
    }
}

// デコレーターがサービスをラップしてログ記録を追加
class LoggingOrderServiceDecorator implements OrderServiceInterface
{
    public function __construct(
        private OrderServiceInterface $inner,
        private LoggerInterface $logger
    ) {}

    public function processOrder(Order $order): void
    {
        $this->logger->info("Processing order: {$order->getId()}");
        try {
            $this->inner->processOrder($order);
            $this->logger->info("Order processed");
        } catch (Exception $e) {
            $this->logger->error("Order failed: {$e->getMessage()}");
            throw $e;
        }
    }
}
```

トランザクション、キャッシング、その他の横断的関心事に対しても同様のデコレーターを作成できます。各デコレーターは独立してコアサービスをラップします。

## DecoratorからAOPへ

サービスをデコレーターで手動ラップするのは面倒です。AOPは属性を通じてデコレーターの適用を自動化します。明示的なラップの代わりに、属性で関心事を宣言し、Ray.Diに適用させます：

```php
// インターセプター（自動化されたデコレーター）を定義
class LoggingInterceptor implements MethodInterceptor
{
    public function __construct(private LoggerInterface $logger) {}

    public function invoke(MethodInvocation $invocation): mixed
    {
        $this->logger->info("Calling: {$invocation->getMethod()->getName()}");
        $result = $invocation->proceed();
        $this->logger->info("Completed");
        return $result;
    }
}

// 属性で適用
class OrderService
{
    #[Log]
    #[Transactional]
    public function processOrder(Order $order): void
    {
        $this->orderRepository->save($order);
        $this->inventoryService->reserve($order->getItems());
    }
}
```

## パターンの本質

Decoratorパターンはコアオブジェクトの周りに動作のレイヤーを作成します。各デコレーターは同じインターフェースを実装し、別の実装をラップします。AOPは属性を検出してデコレーター（インターセプターと呼ばれる）を自動的に適用することで、これを自動化します。

```
手動：Service → TransactionDecorator → LoggingDecorator → Client
AOP：Service + #[Attributes] → Ray.Diがラッパーを生成 → Client
```

なぜこれが重要なのでしょうか？5つのサービスにキャッシングを追加する際、5つのデコレーターを書く代わりに、各メソッドに1つの属性を追加します。ログフォーマットを変更する際、すべてのサービスを更新する代わりに、1つのインターセプターを変更します。ビジネスロジックをテストする際、インフラストラクチャ依存なしでコアサービスをテストします。各関心事は1つの場所に存在します—それを実装するデコレーターまたはインターセプター。

## Decorator/AOPを使用するとき

複数のクラスが同じ横断的関心事を必要とする場合にDecoratorパターンまたはAOPを使用します。これにはログ記録、トランザクション管理、キャッシング、セキュリティチェック、パフォーマンス監視が含まれます—アプリケーション全体に広く適用されるビジネスロジックに直交する関心事です。

デコレーターは複数の動作を組み合わせたり、環境に基づいて切り替えたりする必要がある場合に優れています。開発環境ではキャッシングをスキップするが、詳細なログ記録を有効にするかもしれません。本番環境ではキャッシングとトランザクションを有効にするが、ログ記録を減らすかもしれません。デコレーターを使えば、ビジネスロジックを変更せずにこれらの動作を組み合わせることができます。

## Decoratorを避けるとき

横断的でない関心事に対してはデコレーターを避けてください。1つのクラスだけが必要とする動作であれば、依存性として注入します。動作がメソッドの目的と密接に結合したコアビジネスロジックである場合、デコレーターに隠すのではなく、サービス内で明示的にします。ドメイン計算、検証、ワークフローにAOPを使用しないでください—これらは可視でテスト可能なサービスメソッドに属します。

## よくある間違い：インターセプター内のビジネスロジック

頻繁に見られるアンチパターンは、インターセプター内にビジネスロジックを配置することです：

```php
// ❌ 悪い例 - インターセプター内のビジネスロジック
class ValidationInterceptor implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation): mixed
    {
        $order = $invocation->getArguments()[0];
        if ($order->getTotal() > 10000) {
            $order->applyFraudCheck(); // ビジネスロジックはここに属さない！
        }
        return $invocation->proceed();
    }
}

// ✅ 良い例 - サービス内の明示的なビジネスロジック
class OrderService
{
    public function processOrder(Order $order): void
    {
        if ($order->getTotal() > 10000) {
            $this->fraudChecker->check($order); // 可視でテスト可能
        }
        $this->orderRepository->save($order);
    }
}
```

インターセプターはインフラストラクチャの関心事を処理します—ログ記録、トランザクション、キャッシング、メトリクス。サービスはビジネスルールを処理します。これらを混在させると分離が台無しになります。不正検出がインターセプターに存在する場合、サービスコードを読む開発者には見えません。ビジネスルールはフレームワークレベルのインターセプターに隠されるのではなく、ドメインサービス内で明示的かつ発見可能であるべきです。

## SOLID原則

Decoratorパターンはビジネスロジックと横断的関心事を分離することで**単一責任原則**を強制します。**開放/閉鎖原則**をサポートします—ビジネスサービスを変更せずに新しいインターセプターを追加できます。サービスインターフェースではなく具体的な実装に依存することで**依存性逆転の原則**を支持し、デコレーターが任意の実装を透過的にラップできるようにします。

## テスト

デコレーターはテストを劇的に簡素化します。デコレーターがない場合、注文処理のテストにはリポジトリ、在庫サービス、ロガー、データベース、キャッシュのモックが必要です—5つのインフラストラクチャモックとドメインロジック。デコレーターを使えば、ドメイン依存のみでコアサービスをテストします。注文処理のテストにはリポジトリと在庫のモックだけが必要です。テスト対象は5つのインフラストラクチャの関心事からゼロに縮小されます。

## 重要なポイント

Decoratorパターンはオブジェクトを変更せずに動作を追加するためにラップします。AOPは属性を通じてデコレーターの適用を自動化し、Ray.Diインターセプターを宣言的なDecoratorパターンの実装にします。ログ記録、トランザクション、キャッシング、セキュリティなどの横断的関心事にデコレーターを使用します—ビジネスロジックには決して使用しません。この分離はビジネスロジックをクリーンで、テスト可能で、ドメイン動作に焦点を当てた状態に保ちます。インターセプターはインフラストラクチャを処理します。サービスはビジネスルールを処理します。

---

**次へ：** [Adapterパターン](../04-architecture/adapter-pattern.html) - 外部APIの適合

**前へ：** [Strategyパターン](strategy-pattern.html)
