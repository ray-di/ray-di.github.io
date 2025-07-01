---
layout: docs-ja
title: ミュータビリティの最小化
category: Manual
permalink: /manuals/1.0/ja/bp/minimize_mutability.html
---
# ミュータビリティの最小化

可能な限り、コンストラクターインジェクションを使用して、イミュータブルオブジェクトを作成します。
イミュータブルオブジェクトはシンプルで、共有可能で、合成できます。
このパターンに従って、注入可能な型を定義してください。

```php
class RealPaymentService implements PaymentServiceInterface
{
    public function __construct(
        private readonly PaymentQueue $paymentQueue,
        private readonly Notifier $notifier
    ){}
}
```

このクラスのすべてのフィールドは読み取り専用で、コンストラクターによって初期化されます。

## 注入方法

*コンストラクターインジェクション*には、いくつかの制限があります。

* 注入するオブジェクトはオプションにできません。
* Ray.Di が作成したオブジェクトでなければ使用できません。
* サブクラスは、すべての依存関係を使い `parent()` を呼び出す必要があります。これは、特に注入された基底クラスが変更された場合に、コンストラクターインジェクションを面倒なものにします。

*セッターインジェクション*は、Ray.Di によって構築されていないインスタンスを初期化する場合に最も便利です。
