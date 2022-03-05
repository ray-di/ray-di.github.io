---
layout: docs-ja
title: Binding Attributes
category: Manual
permalink: /manuals/1.0/ja/binding_attributes.html
---
## バインディングの属性

場合によっては、同じタイプで複数のバインディングが必要になることがあります。たとえば、PayPal のクレジットカード決済と Google Checkout の決済の両方を行いたい場合などです。
このような場合に備えて、バインディングではオプションのバインディング属性を用意しています。この属性と型を組み合わせることで、バインディングを一意に識別します。このペアをキーと呼びます。

### バインディング属性の定義

まず、qualifier 属性を定義します。この属性は `Qualifier` 属性でアノテーションする必要があります。

```php
use Ray\Di\Di\Qualifier;

#[Attribute, Qualifier]
final class PayPal
{
}
```

アノテーションされたバインディングに依存するには、注入されたパラメータにその属性を適用します。

```php
public function __construct(
    #[Paypal] private readonly CreditCardProcessorInterface $processor
){}
```

パラメータ名を修飾子で指定することができます。修飾子は、それがないパラメータにも適用されます。

```php
public function __construct(
    #[Paypal('processor')] private readonly CreditCardProcessorInterface $processor
){}
```

最後に、その属性を使用するバインディングを作成します。これは bind() 文のオプションである `annotatedWith` 節を使用します。

```php
$this->bind(CreditCardProcessorInterface::class)
  ->annotatedWith(PayPal::class)
  ->to(PayPalCreditCardProcessor::class);
```

### セッターでの属性の束縛

カスタムの `Qualifier` 属性を、どのメソッドでもデフォルトで依存性を注入するようにするには、次のようにします。
属性を追加するには、 `RayDi⇄InjectInterface` を実装する必要があります。

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

このインターフェースでは、`isOptional()` メソッドを実装することが必須です。このメソッドは
を実行するかどうかは、そのバインディングが既知であるかどうかに基づいて決定されます。

これでカスタムインジェクタ属性が作成できたので、任意のメソッドで使用することができます。

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

プロバイダは、qualifier 属性で指定された情報を使って、最も適切なクラスをインスタンス化できるようになります。

## Qualifier

Qualifier 属性の最も一般的な使用法は、関数内の引数に特定のラベルを付けることです。このラベルは、インスタンス化するクラスを正しく選択するためにバインディングで使用されます。このような場合、Ray.Diには文字列を受け取るビルトインのバインディング属性 `#[Named]` が用意されています。

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

## アノテーション／アトリビュート

Ray.Di は、PHP 7/8 では [doctrine/annotation](https://github.com/doctrine/annotations) と共に、PHP8 では [Attributes](https://www.php.net/manual/en/language.attributes.overview.php) と共に使用することができます。
古い[README(v2.10)](https://github.com/ray-di/Ray.Di/tree/2.10.5/README.md)にあるアノテーションコードの例をご覧ください。
属性に対する前方互換性のあるアノテーションを作成するには、 [カスタムアノテーションクラス](https://github.com/kerveros12v/sacinta4/blob/e976c143b3b7d42497334e76c00fdf38717af98e/vendor/doctrine/annotations/docs/en/custom.rst#optional-constructors-with-named-parameters) を参照してください。
