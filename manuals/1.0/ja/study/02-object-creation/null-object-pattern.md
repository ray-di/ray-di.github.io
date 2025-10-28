---
layout: docs-ja
title: Null Object Pattern
category: Manual
permalink: /manuals/1.0/ja/study/02-object-creation/null-object-pattern.html
---
# Null Objectパターン：オプショナルな依存関係の扱い

## 問題

オプショナルな依存関係を持つクラスでは、nullチェックがコード全体に散らばります。ロガーが設定されている場合もされていない場合もある注文サービスを考えてみましょう。nullチェックがビジネスロジックを圧倒しています：

```php
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private InventoryServiceInterface $inventoryService,
        private ?LoggerInterface $logger = null,
        private ?CacheInterface $cache = null,
        private ?NotificationServiceInterface $notifier = null
    ) {}

    public function processOrder(Order $order): void
    {
        // nullチェック #1
        if ($this->logger !== null) {
            $this->logger->info("Processing order: {$order->getId()}");
        }

        // 実際のビジネスロジック
        $this->orderRepository->save($order);
        $this->inventoryService->reserve($order->getItems());

        // nullチェック #2
        if ($this->cache !== null) {
            $this->cache->set("order_{$order->getId()}", $order);
        }

        // nullチェック #3
        if ($this->notifier !== null) {
            $this->notifier->send(new OrderConfirmation($order));
        }

        // nullチェック #4
        if ($this->logger !== null) {
            $this->logger->info("Order processed successfully");
        }
    }

    public function cancelOrder(int $orderId): void
    {
        // nullチェック #5
        if ($this->logger !== null) {
            $this->logger->info("Cancelling order: {$orderId}");
        }

        $order = $this->orderRepository->findById($orderId);
        $order->cancel();
        $this->orderRepository->save($order);

        // nullチェック #6
        if ($this->cache !== null) {
            $this->cache->delete("order_{$orderId}");
        }

        // nullチェック #7
        if ($this->notifier !== null) {
            $this->notifier->send(new OrderCancellation($order));
        }
    }
}
```

## なぜ問題なのか

これはビジネスロジックとインフラストラクチャの存在チェックという根本的な混在を生み出します。7行のビジネスロジックに対して、7つのnullチェックがあります。メソッドは注文処理を実行しながら、ロガー、キャッシュ、通知サービスが存在するかどうかも確認しています。

コードはオプショナルな依存関係の数に比例して複雑になります。3つのオプショナルな依存関係は、各メソッドで3つのnullチェックを意味します。4つ目のオプショナルな依存関係を追加すると、すべてのメソッドに4つ目のチェックを追加しなければなりません。

テストでは、nullパスと非nullパスの両方をカバーする必要があります。各オプショナルな依存関係は、テストケースを倍増させます。3つのオプショナルな依存関係は、8つの組み合わせ（2³）を意味します。コードを読むとき、nullチェックがビジネスロジックを遮断します。実際に何が起こっているのかを理解するには、各nullチェックを精神的に除外しなければなりません。

さらに悪いことに、多くの開発者はnullチェックの代わりに環境チェックのif文を使用します：

```php
// ❌ さらに悪い例：if文でコンテキストをチェック
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private NotificationServiceInterface $notifier
    ) {}

    public function processOrder(Order $order): void
    {
        $this->orderRepository->save($order);

        // 環境チェックがビジネスロジックに混在！
        if ($_ENV['APP_ENV'] === 'production') {
            $this->notifier->send(new OrderConfirmation($order));
        }
        // 開発環境では通知を送信しない
    }

    public function cancelOrder(int $orderId): void
    {
        $order = $this->orderRepository->findById($orderId);
        $order->cancel();
        $this->orderRepository->save($order);

        // 同じ環境チェックを繰り返す
        if ($_ENV['APP_ENV'] === 'production') {
            $this->notifier->send(new OrderCancellation($order));
        }
    }
}
```

これはビジネスロジックに環境依存のコードを直接埋め込んでしまい、テストが非常に困難になります。`$_ENV['APP_ENV']`を操作しなければ両方のパスをテストできません。さらに、新しい環境（ステージング環境など）を追加する際には、すべてのif文を更新しなければなりません。

## 解決策：Null Objectパターン

Null Objectパターンは、何もしない実装を提供することでこの問題を解決します。オプショナルな依存関係の代わりに、常に有効なオブジェクトを注入します。依存関係が不要な場合、Null Object—インターフェースを実装しているが何もしないオブジェクト—を使用します。

重要なのは、**if文でコンテキストをチェックするのではなく、DIバインディングでコンテキストに応じた実装を注入する**ことです：

```php
// Null Object実装 - インターフェースを満たすが何もしない
class NullLogger implements LoggerInterface
{
    public function info(string $message): void {}
    public function error(string $message): void {}
    public function warning(string $message): void {}
}

class NullCache implements CacheInterface
{
    public function get(string $key): mixed { return null; }
    public function set(string $key, mixed $value, ?int $ttl = null): void {}
    public function delete(string $key): void {}
}

class NullNotificationService implements NotificationServiceInterface
{
    public function send(Notification $notification): void {}
}

// DIモジュールで環境別にバインド
class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(InventoryServiceInterface::class)->to(InventoryService::class);

        // 開発環境ではNull Objectを使用
        $this->bind(LoggerInterface::class)->to(NullLogger::class);
        $this->bind(CacheInterface::class)->to(NullCache::class);
        $this->bind(NotificationServiceInterface::class)->to(NullNotificationService::class);
    }
}

class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(InventoryServiceInterface::class)->to(InventoryService::class);

        // 本番環境では実際の実装を使用
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
        $this->bind(CacheInterface::class)->to(RedisCache::class);
        $this->bind(NotificationServiceInterface::class)->to(EmailNotificationService::class);
    }
}

// ✅ コードからnullチェックも環境チェックも完全に消える！
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private InventoryServiceInterface $inventoryService,
        private LoggerInterface $logger,                          // 常に存在
        private CacheInterface $cache,                            // 常に存在
        private NotificationServiceInterface $notifier            // 常に存在
    ) {}

    public function processOrder(Order $order): void
    {
        // if文不要 - 実行するかしないかはDIバインディングで決まる
        $this->logger->info("Processing order: {$order->getId()}");

        $this->orderRepository->save($order);
        $this->inventoryService->reserve($order->getItems());

        $this->cache->set("order_{$order->getId()}", $order);
        $this->notifier->send(new OrderConfirmation($order));
        // 開発環境ではNullNotificationService = 何もしない
        // 本番環境ではEmailNotificationService = メール送信

        $this->logger->info("Order processed successfully");
    }

    public function cancelOrder(int $orderId): void
    {
        $this->logger->info("Cancelling order: {$orderId}");

        $order = $this->orderRepository->findById($orderId);
        $order->cancel();
        $this->orderRepository->save($order);

        $this->cache->delete("order_{$orderId}");
        $this->notifier->send(new OrderCancellation($order));
        // コードは同じ、振る舞いはバインディングで決まる
    }
}
```

## Ray.DiのtoNull()メソッド

Ray.Diは`toNull()`という便利なメソッドを提供しており、Null Objectクラスを手動で作成する必要がありません。Ray.Diがインターフェースから自動的にNull Objectを生成します：

```php
class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(InventoryServiceInterface::class)->to(InventoryService::class);

        // toNull()でNull Objectを自動生成
        $this->bind(LoggerInterface::class)->toNull();
        $this->bind(CacheInterface::class)->toNull();
        $this->bind(NotificationServiceInterface::class)->toNull();
    }
}
```

`toNull()`を使うと、Ray.Diは：
1. インターフェースのすべてのメソッドを解析
2. 各メソッドの戻り値の型に基づいて適切なデフォルト値を返すNull Objectクラスを生成
3. そのNull Objectインスタンスをバインド

これにより、手動でNull Objectクラスを書く必要がなくなり、インターフェースが変更されてもNull Objectは自動的に更新されます。

## パターンの本質

Null Objectパターンは2つの重要な変換を実現します：

1. **条件付きの存在から無条件の存在へ**: 依存関係を「存在するかもしれない」ものから「常に存在する」ものに変換
2. **コード内の条件分岐からDI設定での選択へ**: if文をコードから排除し、バインディングで振る舞いを決定

```
変更前：
if (logger != null) logger.log()           // nullチェック
if ($_ENV['APP_ENV'] === 'prod') send()    // 環境チェック

変更後：
logger.log()      // NullLoggerは何もしない、FileLoggerはファイルに書く
notifier.send()   // NullNotifierは何もしない、EmailNotifierはメール送信
```

なぜこれが重要なのでしょうか？

**DIの本質を体現**: ビジネスロジックは「何をする」かを記述し、DIバインディングが「どう実行する」かを決定します。コードは`notifier.send()`と書くだけで、実際に通知が送られるかどうかは実行時のコンテキスト（開発/本番）によってDIが決定します。

**環境切り替えが簡単**: 新しい環境（ステージング、テスト、ローカル）を追加する際、コードを一切変更せずモジュールだけを追加します。環境チェックのif文が1000箇所あっても、DIバインディングは1箇所です。

**テストが簡単**: `$_ENV`を操作する代わりに、テスト用のモジュールで適切な実装をバインドします。ビジネスロジックはコンテキストを知らず、純粋にドメインロジックに集中できます。

## Null Objectパターンを使用するとき

ビジネスロジックに影響を与えない、真にオプショナルな依存関係に対してNull Objectパターンを使用します。これにはログ記録、キャッシング、メトリクス収集、通知、分析が含まれます—これらのサービスが存在しないときにアプリケーションが正常に動作する場合です。

Null Objectは環境間で異なる依存関係に優れています。開発環境では通知を送信せず、メトリクスを収集せず、外部APIを呼び出さないかもしれません。本番環境では、これらすべてが有効です。Null Objectを使えば、コードを変更せずにDIバインディングで環境を切り替えることができます。

## Null Objectを避けるとき

アプリケーションの正しい動作に必要な依存関係にはNull Objectを避けてください。注文サービスはリポジトリなしでは動作できません—注文を保存する必要があります。ロガーはオプショナルです—ログがなくても注文は処理されます。必須の依存関係に対してNull Objectを使用すると、サイレントな失敗が発生します。

戻り値が重要な場合、Null Objectは誤解を招きます。キャッシュの`get()`がnullを返すとき、キャッシュミスを意味するのか、Null Objectを意味するのかは区別できません。エラーが重要なフィードバックを提供する場合、Null Objectはそれを隠してしまいます。

## よくある間違い：ビジネスロジックの隠蔽

頻繁に見られるアンチパターンは、ビジネスロジックを持つサービスにNull Objectを使用することです：

```php
// ❌ 悪い例 - ビジネスロジックにNull Object
interface PaymentProcessorInterface
{
    public function charge(Money $amount): PaymentResult;
}

class NullPaymentProcessor implements PaymentProcessorInterface
{
    public function charge(Money $amount): PaymentResult
    {
        return PaymentResult::success(); // 嘘！実際には課金されていない
    }
}

// サイレントな失敗 - 注文は成功するが支払いは処理されない
class OrderService
{
    public function processOrder(Order $order): void
    {
        $result = $this->paymentProcessor->charge($order->getTotal());
        // $resultは常に成功 - しかし実際の課金は行われていない！
    }
}

// ✅ 良い例 - 必須の依存関係には実装が必要
class OrderService
{
    public function __construct(
        private PaymentProcessorInterface $paymentProcessor  // 必須
    ) {
        // DIが存在を保証 - Null Objectは使用しない
    }

    public function processOrder(Order $order): void
    {
        $result = $this->paymentProcessor->charge($order->getTotal());
        // 実際の課金結果を取得
    }
}
```

Null Objectはビジネスロジックを持たないインフラストラクチャサービスのためのものです。支払い処理、在庫管理、認証などのドメインサービスは、Null Objectの候補ではありません—これらはアプリケーションの正しい動作に不可欠です。

## テスト戦略

Null Objectはテストを簡素化しますが、慎重に使う必要があります。テストで外部サービスへの呼び出しを無効にするためにNull Objectを使用します：

```php
// テストモジュール - 外部依存関係を無効化
class TestModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(OrderRepositoryInterface::class)->to(InMemoryOrderRepository::class);
        $this->bind(InventoryServiceInterface::class)->to(InventoryService::class);

        // テストでは外部サービスを無効化
        $this->bind(EmailServiceInterface::class)->toNull();
        $this->bind(SmsServiceInterface::class)->toNull();
        $this->bind(ExternalApiClientInterface::class)->toNull();
    }
}

// ビジネスロジックのテスト - 外部呼び出しなし
class OrderServiceTest extends TestCase
{
    public function testProcessOrder(): void
    {
        $injector = new Injector(new TestModule());
        $service = $injector->getInstance(OrderService::class);

        $order = new Order(/* ... */);
        $service->processOrder($order);

        // 外部サービスの呼び出しを心配せずにビジネスロジックをテスト
    }
}
```

しかし、Null Objectは振る舞いの検証を妨げます。メールが送信されたことを確認する必要がある場合、Null Objectではなくモックを使用します：

```php
// 振る舞いの検証にはモックを使用
public function testOrderConfirmationEmailIsSent(): void
{
    $emailService = $this->createMock(EmailServiceInterface::class);
    $emailService->expects($this->once())
        ->method('send')
        ->with($this->isInstanceOf(OrderConfirmation::class));

    $service = new OrderService(
        $this->orderRepository,
        $this->inventoryService,
        $this->logger,
        $this->cache,
        $emailService  // モック、Null Objectではない
    );

    $service->processOrder($order);
}
```

## SOLID原則

Null Objectパターンはオプショナルな依存関係を必須の依存関係として扱うことで**依存性逆転の原則**を強制します。コードは常にインターフェースに依存し、nullには決して依存しません。**単一責任原則**をサポートします—サービスはビジネスロジックを処理し、依存関係の存在チェックは処理しません。**開放/閉鎖原則**を支持します—ビジネスロジックを変更せずにDIバインディングで新しいNull Object実装を追加できます。

## 重要なポイント

Null Objectパターンはnullチェックを何もしない実装で置き換えます。ログ記録、キャッシング、通知などの真にオプショナルな依存関係に使用します—アプリケーションがこれらのサービスなしで正常に動作する場合です。Ray.Diの`toNull()`メソッドはNull Objectクラスを自動生成し、手動実装の必要性を排除します。支払い処理、認証、必須のビジネスロジックなど、アプリケーションの正しい動作に不可欠なサービスには決してNull Objectを使用しないでください。このパターンはコードからnullチェックを排除し、DIバインディングを通じて環境固有の振る舞いを可能にします。

---

**次へ：** [Strategy Pattern](../03-behavioral/strategy-pattern.html) - 切り替え可能な振る舞い

**前へ：** [Provider Pattern](provider-pattern.html)
