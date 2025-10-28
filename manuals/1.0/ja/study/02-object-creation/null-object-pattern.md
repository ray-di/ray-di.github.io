---
layout: docs-ja
title: Null Object Pattern
category: Manual
permalink: /manuals/1.0/ja/study/02-object-creation/null-object-pattern.html
---
# Null Objectパターン：オプショナルな依存関係の扱い

## 問題

オプショナルな依存関係を持つクラスでは、nullチェックがコード全体に散らばります。ロガーが設定されている場合もされていない場合もある注文サービスを考えてみましょう：

```php
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private ?LoggerInterface $logger = null,
        private ?NotificationServiceInterface $notifier = null
    ) {}

    public function processOrder(Order $order): void
    {
        if ($this->logger !== null) {  // nullチェック
            $this->logger->info("Processing order: {$order->getId()}");
        }

        $this->orderRepository->save($order);

        if ($this->notifier !== null) {  // nullチェック
            $this->notifier->send(new OrderConfirmation($order));
        }

        if ($this->logger !== null) {  // nullチェック
            $this->logger->info("Order processed successfully");
        }
    }
}
```

## なぜ問題なのか

これはビジネスロジックとインフラストラクチャの存在チェックという根本的な混在を生み出します。3行のビジネスロジックに対して、3つのnullチェックがあります。オプショナルな依存関係の数に比例して複雑になり、すべてのメソッドで同じnullチェックを繰り返さなければなりません。

**コードパスの爆発的増加**: 各nullチェックはコードパスを2つに分岐させます。2つのオプショナルな依存関係は、4つのコードパス（2²）を意味します。テストでこれらすべてのパスをカバーする必要があり、パスが増えるほどバグが潜む可能性が高まります。Null Objectを使えば、パスは1つになり、自然にカバレッジが100%になります。**少ないパスほど安定したプログラム**です。

さらに悪いことに、多くの開発者はnullチェックの代わりに環境チェックのif文を使用します：

```php
// ❌ さらに悪い例：if文でコンテキストをチェック
class OrderService
{
    public function processOrder(Order $order): void
    {
        $this->orderRepository->save($order);

        // 環境チェックがビジネスロジックに混在！
        if ($_ENV['APP_ENV'] === 'production') {
            $this->notifier->send(new OrderConfirmation($order));
        }
    }
}
```

これはビジネスロジックに環境依存のコードを直接埋め込んでしまい、テストが非常に困難になります。`$_ENV`を操作しなければテストできず、すべてのメソッドで同じ環境チェックを繰り返さなければなりません。

## 解決策：Null Objectパターン

Null Objectパターンは、何もしない実装を提供することでこの問題を解決します。オプショナルな依存関係の代わりに、常に有効なオブジェクトを注入します。依存関係が不要な場合、Null Object—インターフェースを実装しているが何もしないオブジェクト—を使用します。

重要なのは、**if文でコンテキストをチェックするのではなく、DIバインディングでコンテキストに応じた実装を注入する**ことです：

```php
// Null Object実装 - インターフェースを満たすが何もしない
class NullLogger implements LoggerInterface
{
    public function info(string $message): void {}
    public function error(string $message): void {}
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
        // 開発環境ではNull Objectを使用
        $this->bind(LoggerInterface::class)->to(NullLogger::class);
        $this->bind(NotificationServiceInterface::class)->to(NullNotificationService::class);
    }
}

class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        // 本番環境では実際の実装を使用
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
        $this->bind(NotificationServiceInterface::class)->to(EmailNotificationService::class);
    }
}

// ✅ コードからnullチェックも環境チェックも完全に消える！
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private LoggerInterface $logger,           // 常に存在
        private NotificationServiceInterface $notifier  // 常に存在
    ) {}

    public function processOrder(Order $order): void
    {
        // if文不要 - 実行するかしないかはDIバインディングで決まる
        $this->logger->info("Processing order: {$order->getId()}");
        $this->orderRepository->save($order);
        $this->notifier->send(new OrderConfirmation($order));
        // 開発: NullNotificationService = 何もしない
        // 本番: EmailNotificationService = メール送信
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
2. 何もしない（何も返さない）Null Objectクラスを生成
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

## SOLID原則

Null Objectパターンはオプショナルな依存関係を必須の依存関係として扱うことで**依存性逆転の原則**を強制します。コードは常にインターフェースに依存し、nullには決して依存しません。**単一責任原則**をサポートします—サービスはビジネスロジックを処理し、依存関係の存在チェックは処理しません。**開放/閉鎖原則**を支持します—ビジネスロジックを変更せずにDIバインディングで新しいNull Object実装を追加できます。

## 重要なポイント

Null Objectパターンは**nullよりNullオブジェクト**という設計判断です。nullチェック（`if ($logger !== null)`）を何もしない実装で置き換え、コードパスを1つにします。ログ記録、通知、メトリクス収集などの真にオプショナルな依存関係に使用します—アプリケーションがこれらのサービスなしで正常に動作する場合です。

Ray.Diの`toNull()`メソッドはNull Objectクラスを自動生成し、手動実装の必要性を排除します。このパターンはDIバインディングを通じて環境固有の振る舞いを可能にします—開発環境ではNullオブジェクト、本番環境では実装を注入します。少ないコードパスはより安定したプログラムを意味します。

## 興味深い組み合わせ：より高度な使い方

Null ObjectとAOPを組み合わせると、さらに興味深いパターンが生まれます。**これは高度な例です**が、パターンを組み合わせることで何ができるかを示しています：

```php
// 1. インターフェイスだけを定義（実装クラスは書かない）
interface TodoQueryInterface
{
    #[DbQuery('todo_item')]
    public function item(string $id): Todo;
}

// 2. Null Objectをバインド + インターセプターを適用
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(TodoQueryInterface::class)->toNull();
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(DbQuery::class),
            [DbQueryInterceptor::class]
        );
    }
}

// 3. インターセプターがメソッド呼び出しを横取りしてSQL実行
class DbQueryInterceptor implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation): mixed
    {
        $attr = $invocation->getMethod()->getAttributes(DbQuery::class)[0];
        $sql = "SELECT * FROM {$attr->table} WHERE id = ?";
        return $this->pdo->execute($sql, $invocation->getArguments());
    }
}

// 使用 - 普通のメソッド呼び出しだが、実際にはSQLが実行される
$todo = $todoQuery->item('123');
```

Null Objectは「何もしない」だけでなく、インターセプターと組み合わせることで「実装を動的に提供する器」にもなります。メソッドシグネチャがAPI契約となり、属性がメタデータを提供し、インターセプターが実際のロジックを実行します。

このパターンは[Ray.MediaQuery](https://github.com/ray-di/Ray.MediaQuery)で使われています。詳細に興味がある方は、基礎パターン（Null Object、AOP、Repository）をすべて学んだ後に探求してみてください。パターンの組み合わせが生み出す可能性を感じられるはずです。

---

**次へ：** [Strategy Pattern](../03-behavioral/strategy-pattern.html) - 切り替え可能な振る舞い

**前へ：** [Provider Pattern](provider-pattern.html)
