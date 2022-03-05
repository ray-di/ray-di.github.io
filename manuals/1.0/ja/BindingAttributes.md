---
  layout: docs-ja
title: 束縛アトリビュート
category: Manual
permalink: /manuals/1.0/ja/binding_attributes.html
---
# 束縛アトリビュート

場合によっては、同じ型複数の束縛が必要になることがあります。たとえば、PayPal のクレジットカード決済と Google Checkout の決済の両方を行いたい場合などです。
このような場合に備えて、オプションの束縛アトリビュートという束縛が用意されています。このアトリビュートと型を組み合わせることで、バインディングを一意に識別します。

### 束縛アトリビュートの定義

束縛アトリビュートは `Qualifier` アトリビュートが付与されたPHPのアトリビュートです。

```php
use Ray\Di\Di\Qualifier;

#[Attribute, Qualifier]
final class PayPal
{
}
```

指定した束縛に依存するには、注入されるパラメータにそのアトリビュートを割り当てます。

```php
public function __construct(
    #[Paypal] private readonly CreditCardProcessorInterface $processor
){}
```

最後に、そのアトリビュートを使用する束縛を作成します。これは bind() 文のオプションのannotatedWith` 節を使用します。

```php
$this->bind(CreditCardProcessorInterface::class)
  ->annotatedWith(PayPal::class)
  ->to(PayPalCreditCardProcessor::class);
```

## #[Named]

Qualifier アトリビュートの最も一般的な使用法は、メソッドの引数に特定のラベルを付けることです。このラベルは、インスタンス化するクラスを正しく選択するために束縛で使用されます。

カスタムのQualifier アトリビュートを作成する他に、Ray.Diには文字列を受け取るビルトインのバインディングアトリビュート `#[Named]` が用意されています。

```php
use Ray\Di\Di\Inject;
use Ray\Di\Di\Named;

public function __construct(
    #[Named('checkout')] private CreditCardProcessorInterface $processor
){}
```

特定の名前をバインドするには、`annotatedWith()` メソッドを用いてその文字列を渡します。

```php
$this->bind(CreditCardProcessorInterface::class)
    ->annotatedWith('checkout')
    ->to(CheckoutCreditCardProcessor::class);
```

パラメータを指定するには、`#[Named]`アトリビュートを付ける必要があります。

```php
use Ray\Di\Di\Inject;
use Ray\Di\Di\Named;

public function __construct(
    #[Named('checkout')] private CreditCardProcessorInterface $processor,
    #[Named('backup')] private CreditCardProcessorInterface $subProcessor
){}
```

## カスタムインジェクタアトリビュート

通常、セッターインジェクションで束縛アトリビュートを行う時は`#[Inject]`アトリビュートと束縛アトリビュートの２つが必要です。これをカスタムインジェクタアトリビュートを使って１つにすることができます。

カスタムインジェクタアトリビュートは`InjectInterface` を実装する必要があります。

```php
use Ray\Di\Di\InjectInterface;
use Ray\Di\Di\Qualifier;

#[Attribute, Qualifier]
final class PaymentProcessorInject implements InjectInterface
{
    public function isOptional()
    {
        return $this->optional;
    }
    
    public function __construct(
        public readonly bool $optional = true
        public readonly string $type;
    ){}
}
```

このインターフェースでは、`isOptional()` メソッドの実装が必須です。このメソッドを実行するかどうかは、その束縛が存在するかどうかで決定されます。

これでカスタムインジェクタアトリビュートが作成できたので、任意のメソッドで使用することができます。

```php
#[PaymentProcessorInject(type: 'paypal')]
public setPaymentProcessor(CreditCardProcessorInterface $processor)
{
 ....
}
```

最後に、新しいアノテーション情報を使って、インターフェイスを実装にバインドすることができます。

```php
$this->bind(CreditCardProcessorInterface::class)
    ->annotatedWith(PaymentProcessorInject::class)
    ->toProvider(PaymentProcessorProvider::class);
```


## 束縛アノテーション

Ray.Di はPHP7.xのために [doctrine/annotation](https://github.com/doctrine/annotations) と共に使用できます。アノテーションコードの例は古い[README(v2.10)](https://github.com/ray-di/Ray.Di/tree/2.10.5/README.md)をご覧ください。アトリビュートに対する前方互換性のあるアノテーションを作成するには、 [カスタムアノテーションクラス](https://github.com/kerveros12v/sacinta4/blob/e976c143b3b7d42497334e76c00fdf38717af98e/vendor/doctrine/annotations/docs/en/custom.rst#optional-constructors-with-named-parameters) を参照してください。

アノテーションは引数に対して適用することができないので、カスタムアノテーションの最初の引数に変数名を指定します。なおメソッドに引数が１つのしかない場合には不要です。

```php
/**
 * @Paypal('processor')
 */
public function setCreditCardProcessor(
	 CreditCardProcessorInterface $processor
   OtherDepedeciyInterface $depedency
){
```
