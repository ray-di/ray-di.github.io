---
layout: docs-ja
title: Adapter Pattern
category: Manual
permalink: /manuals/1.0/ja/study/04-architecture/adapter-pattern.html
---
# Adapterパターン：外部APIの適合

## 問題

サードパーティAPIや外部サービスを直接使用すると、そのAPIに密結合してしまいます。決済サービスとしてStripeを使う場合を考えてみましょう。サービス層でStripe SDKを直接呼び出すと、どうなるでしょうか：

```php
class OrderService
{
    public function processPayment(Order $order): void
    {
        // Stripe APIを直接使用
        $stripe = new \Stripe\StripeClient($_ENV['STRIPE_SECRET_KEY']);

        try {
            $charge = $stripe->charges->create([
                'amount' => $order->getTotal() * 100, // Stripeは最小通貨単位
                'currency' => 'jpy',
                'source' => $order->getPaymentToken(),
                'description' => "Order {$order->getId()}"
            ]);

            $order->setPaymentId($charge->id);
            $order->setStatus('paid');
        } catch (\Stripe\Exception\CardException $e) {
            throw new PaymentFailedException($e->getMessage());
        }

        $this->orderRepository->save($order);
    }
}
```

## なぜ問題なのか

この設計には根本的な問題があります。ビジネスロジックがStripeの具体的な実装の詳細を知りすぎています。Stripeは金額を最小通貨単位で扱う、特定の例外型を投げる、`source`パラメータで支払い情報を受け取る—これらはすべてStripe固有の知識です。

PayPalに切り替えたくなったらどうでしょうか？OrderServiceを書き換え、すべてのテストを修正し、異なるエラーハンドリングを実装する必要があります。テスト時に実際のStripe APIを呼ばずにテストすることも困難です。モックを作成するには、Stripeの内部実装の詳細を知る必要があります。

このコードの問題は、本来であればビジネスロジックに集中すべき`OrderService`が、外部APIの複雑さに晒されていることです。外部APIとの統合の複雑さがアプリケーション全体に漏れ出しています。

## 解決策：Adapterパターン

Adapterパターンは、外部APIをアプリケーション独自のインターフェイスに適合させることで、この問題を解決します。このパターンは、互換性のないインターフェイス同士を橋渡しし、**複雑さをクライアントから見えなくする**ことを目的としています。

### Adapterパターンの構造

Adapterパターンは3つの要素で構成されます：

1. **Target（対象）** - アプリケーションが期待するインターフェイス
2. **Adaptee（適合対象）** - 既存の外部API（Targetと互換性がない）
3. **Adapter（適合器）** - TargetとAdapteeを橋渡しする変換層

```
Client (OrderService)
    ↓ 依存
Target (PaymentGatewayInterface)
    ↓ 実装
Adapter (StripeAdapter)
    ↓ 委譲
Adaptee (Stripe\StripeClient)
```

クライアント（Client）はTarget型の抽象が持つメソッドを呼び出します。Adapterクラスは、Target型の抽象を実装したクラスです。クライアントがTargetのメソッドを呼び出すと、本来であればAdapteeクラスのメソッドを呼び出したいのですが、AdapteeクラスはTargetと互換性がないため、その呼び出しを直接行うことはできません。

そこで、Adapterクラスが両者のあいだに入り、Targetのメソッド呼び出しをAdapteeのメソッド呼び出しに変換することで、目的の処理を実行できるようになります。

### 実装例

```php
// Target - アプリケーション独自のインターフェイス
interface PaymentGatewayInterface
{
    public function charge(Money $amount, PaymentToken $token): PaymentResult;
}

// ドメインの値オブジェクト
class PaymentResult
{
    public function __construct(
        public readonly string $transactionId,
        public readonly bool $successful,
        public readonly ?string $errorMessage = null
    ) {}
}

// Adapter - TargetとAdapteeを橋渡し
class StripeAdapter implements PaymentGatewayInterface
{
    public function __construct(
        private \Stripe\StripeClient $stripe  // Adaptee
    ) {}

    public function charge(Money $amount, PaymentToken $token): PaymentResult
    {
        try {
            // Adapteeの呼び出しに変換（複雑さをカプセル化）
            $charge = $this->stripe->charges->create([
                'amount' => $amount->getMinorUnits(), // 円→銭の変換
                'currency' => strtolower($amount->getCurrency()->getCode()),
                'source' => $token->getValue(),
                'description' => $token->getDescription()
            ]);

            // Adapteeの結果をTargetの形式に変換
            return new PaymentResult(
                transactionId: $charge->id,
                successful: true
            );
        } catch (\Stripe\Exception\CardException $e) {
            // Stripe固有の例外をドメインの結果に変換
            return new PaymentResult(
                transactionId: '',
                successful: false,
                errorMessage: $e->getMessage()
            );
        }
    }
}

// Client - クリーンなビジネスロジック
class OrderService
{
    public function __construct(
        private PaymentGatewayInterface $paymentGateway,  // Targetに依存
        private OrderRepositoryInterface $orderRepository
    ) {}

    public function processPayment(Order $order): void
    {
        // Stripe固有の知識が不要
        $result = $this->paymentGateway->charge(
            $order->getTotal(),
            $order->getPaymentToken()
        );

        if (!$result->successful) {
            throw new PaymentFailedException($result->errorMessage);
        }

        $order->markAsPaid($result->transactionId);

        $this->orderRepository->save($order);
    }
}
```

DIコンテナでの設定：

```php
$this->bind(PaymentGatewayInterface::class)->to(StripeAdapter::class);
```

## パターンの本質

### 現実世界のアナロジー：USBアダプター

USB Type-CポートしかないノートPCで、USB Type-Aのマウスを使いたい場合を考えてみましょう：

- **Target（対象）**: USB Type-Cポート（PCが期待するインターフェイス）
- **Adaptee（適合対象）**: USB Type-Aマウス（互換性のない既存デバイス）
- **Adapter（適合器）**: USB Type-C to Type-A変換アダプター

アダプターは両者の違いを吸収します。PCはType-Cとしか通信しませんし、マウスはType-Aしか理解しません。アダプターが間に入ることで、両者は互いの存在を知らないまま連携できます。

これがまさにAdapterパターンの役割です：互換性のないインターフェイス同士を橋渡しし、**複雑さをクライアントから隠蔽する**のです。

### パターンの目的

Adapterパターンの目的は、**複雑さをクライアントから隠蔽する**ことにあります。外部APIとの統合には、多くの場合、複雑な変換作業が伴います：

- データ形式の変換（円→銭、配列→オブジェクト）
- エラーハンドリングの統一化（例外→結果オブジェクト）
- プロトコルの違いの吸収（REST→SOAP、同期→非同期）
- 認証・認可の処理

これらの複雑さをAdapterクラスがカプセル化することで、クライアントコードはシンプルになり、外部APIの詳細に依存する必要がなくなります。

変換が単純であっても複雑であっても、Adapterパターンを適用することは一般的に容易です。仮に複雑な変換が求められても驚かないでください。なぜなら、そもそもAdapterパターンの目的は、この複雑さをクライアントから見えなくすることにあるからです。

```
外部API（Stripe） → Adapter → アプリケーションのインターフェイス
  (彼らの言語)      (翻訳者)     (私たちの言語)
  (複雑)          (複雑さを隠蔽)  (シンプル)
```

なぜこれが重要なのでしょうか？StripeからPayPalに切り替える際、OrderServiceには一切触れません。新しい`PayPalAdapter`を作成し、バインディングを変更するだけです。テスト時は`MockPaymentGateway`を注入します。外部APIの変更は、Adapterクラス内に隔離されます。それぞれの変更に明確な場所があるのです。

## Adapterパターンをいつ使うか

外部サービスやサードパーティAPIを統合する際にAdapterパターンを使用します。これには決済ゲートウェイ、メールサービス、クラウドストレージ、SNS投稿、地図サービスなど、アプリケーションが制御できない外部システムが含まれます。

Adapterは、レガシーコードと新しいコードの橋渡しにも有効です。古いシステムが独自のインターフェイスを持つ場合、Adapterを介して新しいコードから利用できます。既存システムを書き換えることなく、新しいアーキテクチャに統合できるのです。

環境ごとに異なる実装が必要な場合にも価値があります。開発環境では`LocalFileAdapter`、本番環境では`S3Adapter`を使用します。テストでは`InMemoryAdapter`を使用し、外部サービスへの実際の呼び出しを避けます。

複雑な変換や統合ロジックが必要な場合、Adapterはその複雑さをカプセル化する最適な場所です。クライアントコードをシンプルに保ちながら、必要な変換作業を一箇所に集約できます。

## Adapterパターンを避けるべき時

自分が制御できるコードにはAdapterを使用しないでください。アプリケーション内部のクラスであれば、直接インターフェイスを実装すればよいのです。自分のコードを自分のインターフェイスに「適合」させるためにAdapterを作成する必要はありません。

外部APIが既にアプリケーションのニーズに完全に一致している場合も、Adapterは不要な間接化となります。ただし、これは稀です。ほとんどの外部APIは、何らかの適合作業を必要とします。

## よくある間違い：過度な抽象化

頻繁なアンチパターンは、すべての外部依存関係を「念のため」Adapterでラップすることです：

```php
// ❌ 悪い例 - 不要な抽象化
interface LoggerAdapterInterface {
    public function log(string $message): void;
}

class MonologAdapter implements LoggerAdapterInterface {
    public function __construct(private \Monolog\Logger $logger) {}

    public function log(string $message): void {
        $this->logger->info($message); // 単なる転送、変換なし
    }
}

// ✅ 良い例 - PSR-3を直接使用
class OrderService {
    public function __construct(
        private \Psr\Log\LoggerInterface $logger // 標準インターフェイス
    ) {}
}
```

外部ライブラリが既に標準インターフェイス（PSR-3の`LoggerInterface`、PSR-6の`CacheInterface`など）を実装している場合、追加のAdapterは不要です。標準インターフェイスを直接使用してください。

Adapterは**実際の変換作業が必要な場合にのみ**作成します。単なる転送であれば、それは無駄な間接化です。Adapterの目的は複雑さのカプセル化であり、単なるラッピングではありません。

## RepositoryパターンもAdapterの一種

実は、Repositoryパターンは特殊なAdapterパターンと見なすことができます。**Target**（コレクション的なインターフェイス）、**Adapter**（MySQLRepositoryなど）、**Adaptee**（PDO、Eloquentなど）という構造で、データベースAPIをドメインモデルに適合させます。Repositoryは「データベースをオブジェクトコレクションのように見せる」Adapterなのです。この観点から理解すると、Adapterパターンの威力がより明確になります。

## SOLID原則

Adapterパターンは**単一責任原則**を実施します。外部APIの統合ロジックをビジネスロジックから分離します。各Adapterは1つの外部サービスとの統合という単一の責任を持ちます。

**開放/閉鎖原則**をサポートします。新しいAdapterを作成することで、既存コードを変更せずに新しいサービスを追加できます。StripeからPayPalへの移行は、新しい`PayPalAdapter`の追加とバインディング変更だけで完了します。

最も重要なのは、**依存性逆転原則**を体現することです。具体的な外部SDKではなく、アプリケーション定義のインターフェイスに依存します。依存の方向が逆転しています：外部サービスがアプリケーションに適合するのであって、その逆ではありません。

## テスト

Adapterはテストを劇的に簡素化します。Adapterなしでは、OrderServiceのテストに実際のStripe APIキーが必要になり、ネットワークの問題でテストが失敗し、外部サービスのダウンタイムでCI/CDパイプライン全体が停止します。

Adapterを使用すれば、`PaymentGatewayInterface`をモックするだけです。テスト用の`FakePaymentGateway`を作成し、成功や失敗を簡単にシミュレートできます。Adapter自体も独立してテストできます。テスト対象は外部APIの複雑さからドメインインターフェイスの簡潔さへと縮小します。

## 重要なポイント

Adapterパターンは、互換性のないインターフェイス同士を橋渡しします。その目的は、外部システムとの統合の複雑さをクライアントから隠蔽することにあります。

3つの要素で構成されます：Target（アプリケーションのインターフェイス）、Adaptee（外部API）、Adapter（両者を橋渡しする変換層）。

サードパーティAPI、レガシーコード、環境固有の実装に使用します。Adapterは複雑な変換作業をカプセル化する最適な場所です。仮に複雑な変換が求められても驚かないでください。それこそがAdapterの存在理由だからです。

実際の変換作業が必要な場合にのみ作成してください。単なる転送は不要な間接化です。Repositoryも実質的にAdapterです—データベースAPIをドメインモデルに適合させる特殊なAdapterと見なせます。

---

**次へ：** [Repository Pattern](repository-pattern.html) - データアクセスの分離（Adapterの特殊ケース）

**前へ：** [Decorator Pattern & AOP](../03-behavioral/decorator-aop.html)
