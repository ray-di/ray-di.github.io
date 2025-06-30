---
layout: docs-ja
title: モチベーション
category: Manual
permalink: /manuals/1.0/ja/motivation.html
---
# モチベーション

アプリケーションの開発で、すべてをまとめ上げるのは面倒な作業です。データクラス、サービスクラス、プレゼンテーションクラスを互いに接続するには、いくつかのアプローチがあります。これらのアプローチを対比させるために、ピザの注文サイトの課金コードを書いてみましょう。

```php
interface BillingServiceInterface
{
    /**
    * オーダーをクレジットカードにチャージしようとします。成功した取引と失敗した取引の両方が記録されます。
    *
    * @return Receipt 取引の領収書。チャージが失敗した場合は、理由を説明する断り書きがレシートに記載されます。
    */
    public function chargeOrder(PizzaOrder order, CreditCard creditCard): Receipt;
}
```

実装と並行して、コードの単体テストを書きます。
テストでは、本物のクレジットカードへの課金を避けるために、`FakeCreditCardProcessor`が必要です。

## コンストラクターの直接呼び出し

以下は、クレジットカードプロセッサーとトランザクションロガーを `new` したときのコードです。

```php
class RealBillingService implements BillingServiceInterface
{
    public function chargeOrder(PizzaOrder $order, CreditCard $creditCard): Receipt
    {
        $processor = new PaypalCreditCardProcessor();
        $transactionLog = new DatabaseTransactionLog();

        try {
            $result = $processor->charge($creditCard, $order->getAmount());
            $transactionLog->logChargeResult($result);

            return $result->wasSuccessful()
                ? Receipt::forSuccessfulCharge($order->getAmount())
                : Receipt::forDeclinedCharge($result->getDeclineMessage());
        } catch (UnreachableException $e) {
            $transactionLog->logConnectException($e);

            return Receipt::forSystemFailure($e->getMessage());
        }
    }
}
```

このコードは、モジュール性とテスト容易性の点で問題があります。実際のクレジットカード・プロセッサーに直接依存すると、このコードをテストするとクレジットカードに課金されてしまいます！また、チャージが拒否されたときやサービスが利用できないときに何が起こるかをテストするのは厄介です。

## ファクトリー

ファクトリークラスは、クライアントと実装クラスを切り離します。単純なファクトリーでは、静的メソッドを使用してインターフェースのモック実装を取得したり設定したりします。ファクトリーはいくつかの定型的なコードで実装されます。

```php
class CreditCardProcessorFactory
{
    private static CreditCardProcessor $instance;
    
    public static setInstance(CreditCardProcessor $processor): void 
    {
        self::$instance = $processor;
    }
    
    public static function getInstance(): CreditCardProcessor
    {
        if (self::$instance == null) {
            return new SquareCreditCardProcessor();
        }
        
        return self::$instance;
    }
}
```

クライアントコードでは、`new`の呼び出しをファクトリーの呼び出しに置き換えるだけです。

```php
class RealBillingService implements BillingServiceInterface
{
    public function chargeOrder(PizzaOrder $order, CreditCard $creditCard): Receipt
    {
        $processor = CreditCardProcessorFactory::getInstance();
        $transactionLog = TransactionLogFactory::getInstance();
        
        try {
            $result = $processor->charge($creditCard, $order->getAmount());
            $transactionLog->logChargeResult($result);
            
            return $result->wasSuccessful()
                ? Receipt::forSuccessfulCharge($order->getAmount())
                : Receipt::forDeclinedCharge($result->getDeclineMessage());
        } catch (UnreachableException $e) {
            $transactionLog->logConnectException($e);
            return Receipt::forSystemFailure($e->getMessage());
        }
    }
}
```

ファクトリーを利用することで、適切なユニットテストを書くことが可能になります。

```php
class RealBillingServiceTest extends TestCase 
{
    private PizzaOrder $order;
    private CreditCard $creditCard;
    private InMemoryTransactionLog $transactionLog;
    private FakeCreditCardProcessor $processor;
    
    public function setUp(): void
    {
        $this->order = new PizzaOrder(100);
        $this->creditCard = new CreditCard('1234', 11, 2010);
        $this->processor = new FakeCreditCardProcessor();
        TransactionLogFactory::setInstance($transactionLog);
        CreditCardProcessorFactory::setInstance($this->processor);
    }
    
    public function tearDown(): void
    {
        TransactionLogFactory::setInstance(null);
        CreditCardProcessorFactory::setInstance(null);
    }
    
    public function testSuccessfulCharge()
    {
        $billingService = new RealBillingService();
        $receipt = $billingService->chargeOrder($this->order, $this->creditCard);

        $this->assertTrue($receipt->hasSuccessfulCharge());
        $this->assertEquals(100, $receipt->getAmountOfCharge());
        $this->assertEquals($creditCard, $processor->getCardOfOnlyCharge());
        $this->assertEquals(100, $processor->getAmountOfOnlyCharge());
        $this->assertTrue($this->transactionLog->wasSuccessLogged());
    }
}
```

しかしこのコードはあまり良くありません。グローバル変数にはモックの実装が格納されているので、その設定と削除には注意が必要です。もし `tearDown` が失敗したら、グローバル変数は私たちのテストインスタンスを指し続けることになります。これは、他のテストに問題を引き起こす可能性がありますし、複数のテストを並行して実行することもできなくなります。

しかし、最大の問題は依存関係がコードの中に **隠されていること** です。もし私たちが `CreditCardFraudTracker` への依存関係を追加したら、どのテストが壊れるか見つけるためにテストを再実行しなければなりません。もし、プロダクションサービスのファクトリーを初期化するのを忘れた場合、課金が行われるまでそのことに気がつきません。アプリケーションが大きくなるにつれて、ファクトリーの子守は生産性をどんどん低下させることになります。

品質の問題は、QAや受け入れテストによって発見されることは発見されるでしょう。しかし、もっといい方法があるはずです。

## 依存性注入(Dependency Injection)

ファクトリーと同様、依存性注入も単なるデザインパターンに過ぎません。核となる原則は、依存関係の解決から振る舞いを **分離する** ことです。この例では、 `RealBillingService` は `TransactionLog` と `CreditCardProcessor` を探す責任はありません。代わりに、コンストラクターのパラメータとして渡されます。

```php
class RealBillingService implements BillingServiceInterface
{
    public function __construct(
        private readonly CreditCardProcessor $processor,
        private readonly TransactionLog $transactionLog
    ) {}
    
    public function chargeOrder(PizzaOrder $order, CreditCard $creditCard): Receipt
    {
        try {
            $result = $this->processor->charge($creditCard, $order->getAmount());
            $this->transactionLog->logChargeResult(result);
        
            return $result->wasSuccessful()
                ? Receipt::forSuccessfulCharge($order->getAmount())
                : Receipt::forDeclinedCharge($result->getDeclineMessage());
        } catch (UnreachableException $e) {
            $this->transactionLog->logConnectException($e);

            return Receipt::forSystemFailure($e->getMessage());
        }
    }
}
```

ファクトリーは必要ありませんし、`setUp` と `tearDown` の定型的なコードを削除することで、テストケースを簡素化することができます。

```php
class RealBillingServiceTest extends TestCase
{
    private PizzaOrder $order;
    private CreditCard $creditCard;
    private InMemoryTransactionLog $transactionLog;
    private FakeCreditCardProcessor $processor;

    public function setUp(): void
    {
        $this->order = new PizzaOrder(100);
        $this->creditCard = new CreditCard("1234", 11, 2010);
        $this->transactionLog = new InMemoryTransactionLog();
        $this->processor = new FakeCreditCardProcessor();      
    }
    
    public function testSuccessfulCharge()
    {
        $billingService= new RealBillingService($this->processor, $this->transactionLog);
        $receipt = $billingService->chargeOrder($this->order, $this->creditCard);
        
        $this->assertTrue($receipt->hasSuccessfulCharge());
        $this->assertSame(100, $receipt->getAmountOfCharge());
        $this->assertSame($this->creditCard, $this->processor->getCardOfOnlyCharge());
        $this->assertSame(100, $this->processor->getAmountOfOnlyCharge());
        $this->assertTrue($this->transactionLog->wasSuccessLogged());
    }
}
```

これで、依存関係を追加したり削除したりするたびに、コンパイラはどのテストを修正する必要があるかを思い出させてくれるようになりました。依存関係はAPIシグネチャで**公開**されます。（コンストラクターに何が必要かが表されています）

`BillingService` のクライアントはその依存関係を調べないといけないようになってしまいましたが、このパターンをもう一度適用することで修正することができます!  これで必要とするクラスはコンストラクターで `BillingService` サービスを受け入れることができます。トップレベルのクラスでは、フレームワークがあると便利です。そうでなければ、サービスを使う必要があるときに、再帰的に依存関係を構築する必要があります。

```php
<?php
$processor = new PaypalCreditCardProcessor();
$transactionLog = new DatabaseTransactionLog();
$billingService = new RealBillingService($processor, $transactionLog);
// ...
```

## Ray.Diによる依存性注入

依存性注入パターンは、モジュール化されたテスト可能なコードを導き、Ray.Diで簡単にコードを書けるようにします。課金の例でRay.Diを使うには、まずインターフェースとその実装をどのように対応付けるかを指示する必要があります。設定は`Module`インターフェースを実装したRay.Diモジュールクラスで行われます。

```php
class BillingModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(TransactionLog::class)->to(DatabaseTransactionLog::class);
        $this->bind(CreditCardProcessor::class)->to(PaypalCreditCardProcessor::class);
        $this->bind(BillingServiceInterface::class)->to(RealBillingService::class);
    }
}
```

Ray.Diはコンストラクターを検査し、各引数の値を検索します。

```php
class RealBillingService implements BillingServiceInterface
{
    public function __construct(
        private readonly CreditCardProcessor $processor,
        private readonly TransactionLog $transactionLog
    ) {}

    public function chargeOrder(PizzaOrder $order, CreditCard $creditCard): Receipt
    {
        try {
            $result = $this->processor->charge($creditCard, $order->getAmount());
            $this->transactionLog->logChargeResult($result);
        
            return $result->wasSuccessful()
                ? Receipt::forSuccessfulCharge($order->getAmount())
                : Receipt::forDeclinedCharge($result->getDeclineMessage());
        } catch (UnreachableException $e) {
            $this->transactionLog->logConnectException($e);
            
            return Receipt::forSystemFailure($e->getMessage());
        }
    }
}
```

最後にすべてをまとめられ、`Injector`がバインドされたクラスのインスタンスを取得します。

```php
<?php
$injector = new Injector(new BillingModule());
$billingService = $injector->getInstance(BillingServiceInterface::class);
//...

```

[はじめに](getting_started.html) では、この仕組みを説明します。
