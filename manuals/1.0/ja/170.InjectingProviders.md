---
layout: docs-ja
title: プロバイダー注入
category: Manual
permalink: /manuals/1.0/ja/injecting_providers.html
---
# プロバイダー注入

通常の依存性注入では、各タイプは依存するタイプのそれぞれのインスタンスを正確に*1つ*取得します。
例えば`RealBillingService` は`CreditCardProcessor` と`TransactionLog` を一つずつ取得します。しかし時には依存する型のインスタンスを複数取得したいこともあるでしょう。
このような場合、Ray.Diはプロバイダーを束縛します。プロバイダーは `get()` メソッドが呼び出されたときに値を生成します。

```php
/**
 * @template T
 */
interface ProviderInterface
{
    /**
     * @return T
     */
    public function get();
}
```

プロバイダーによって提供される型を`#[Set]`アトリビュートで指定します。

```php
class RealBillingService implements BillingServiceInterface
{
    /**
     * @param ProviderInterface<TransactionLogInterface>      $processorProvider
     * @param ProviderInterface<CreditCardProcessorInterface> $transactionLogProvider
     */
    public __construct(
        #[Set(TransactionLogInterface::class)] private ProviderInterface $processorProvider,
        #[Set(CreditCardProcessorInterface::class)] private ProviderInterface $transactionLogProvider
    ) {}

    public chargeOrder(PizzaOrder $order, CreditCard $creditCard): Receipt
    {
        $transactionLog = $this->transactionLogProvider->get();
        $processor = $this->processorProvider->get();
        
        /* プロセッサとトランザクションログをここで使用する */
    }
}
```

静的解析でジェネリクスをサポートをするためにはphpdocの`@param`で`ProviderInterface<TransactionLogInterface>` や `ProviderInterface<CreditCardProcessorInterface>`などと表記します。`get()`メソッドで取得して得られるインスタンスの型が指定され、静的解析でチェックされます。

## 複数インスタンスのためのプロバイダー

同じ型のインスタンスが複数必要な場合の時もプロバイダーを使用します。例えば、ピザのチャージに失敗したときに、サマリーエントリと詳細情報を保存するアプリケーションを考えてみましょう。
プロバイダーを使えば、必要なときにいつでも新しいエントリを取得することができます。

```php
class LogFileTransactionLog implements TransactionLogInterface
{
    public function __construct(
        #[Set(TransactionLogInterface::class)] private readonly ProviderInterface $logFileProvider
    ) {}
    
    public logChargeResult(ChargeResult $result): void {
        $summaryEntry = $this->logFileProvider->get();
        $summaryEntry->setText("Charge " + (result.wasSuccessful() ? "success" : "failure"));
        $summaryEntry->save();
        
        if (! $result->wasSuccessful()) {
            $detailEntry = $this->logFileProvider->get();
            $detailEntry->setText("Failure result: " + result);
            $detailEntry->save();
        }
    }
}
```

## 遅延ロードのためのプロバイダー

もしある型に依存していて、その型を作るのが特に**高価**な場合、プロバイダーを使ってその作業を先延ばしに、つまり遅延生成することができます。
これはその依存が不必要な時がある場合に特に役立ちます。

```php
class LogFileTransactionLog implements TransactionLogInterface
{
    public function __construct(
        #[Set(Connection::class)] private ProviderInterface $connectionProvider
    ) {}
    
    public function logChargeResult(ChargeResult $result) {
        /* 失敗した時だけをデータベースに書き込み */
        if (! $result->wasSuccessful()) {
            $connection = $connectionProvider->get();
        }
    }
```

## 混在するスコープのためのプロバイダー

より狭いスコープを持つオブジェクトを直接注入すると、アプリケーションで意図しない動作が発生することがあります。
以下の例では、現在のユーザーに依存するシングルトン`ConsoleTransactionLog`があるとします。
もし、ユーザーを `ConsoleTransactionLog` のコンストラクターに直接注入したとすると、ユーザーはアプリケーションで一度だけ評価されることになってしまいます。
ユーザーはリクエストごとに変わるので、この動作は正しくありません。その代わりに、プロバイダーを使用する必要があります。プロバイダーはオンデマンドで値を生成するので、安全にスコープを混在させることができるようになります。

```php
class ConsoleTransactionLog implements TransactionLogInterface
{
    public function __construct(
        #[Set(User::class)] private readonly ProviderInterface $userProvider
    ) {}
    
    public function logConnectException(UnreachableException $e): void
    {
        $user = $this->userProvider->get();
        echo "Connection failed for " . $user . ": " . $e->getMessage();
    }
}
```
