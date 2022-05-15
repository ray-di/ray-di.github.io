---
layout: docs-ja
title: ミュータビリティの最小化
category: Manual
permalink: /manuals/1.0/ja/bp/minimize_mutability.html
---
# ミュータビリティの最小化

可能な限り、コンストラクター注入を使用して、イミュータブルオブジェクトを作成します。
イミュータブルなオブジェクトはシンプルで、共有可能で、合成することができます。
このパターンに従って、注入可能な型を定義してください。

```php
class RealPaymentService implements PaymentServiceInterface
{
    public function __construct(
        private readnonly PaymentQueue $paymentQueue,
        private readnonly Notifier $notifier;
    ){}
```

このクラスのすべてのフィールドは読み取り専用で、コンストラクタによって初期化されます。

## 注入方法

*コンストラクター注入*には、いくつかの制限があります。

* 注入されたコンストラクタはオプションであってはならない。
* Ray.Diでオブジェクトが作成されていないと使用できません。
* サブクラスは、すべての依存性を持って `parent()` を呼び出さなければなりません。これは、特に注入された基底クラスが変更された場合に、コンストラクタ注入を面倒なものにします。

*セッターインジェクション*は、Ray.Diによって構築されていないインスタンスを初期化する必要がある場合に最も便利です。
