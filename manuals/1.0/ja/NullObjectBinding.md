---
layout: docs-ja
title: Nullオブジェクト束縛
category: Manual
permalink: /manuals/1.0/ja/null_object_binding.html
---
## Nullオブジェクト束縛

Nullオブジェクトとは、インターフェースを実装していてもメソッドの中で何もしないオブジェクトです。`toNull()`で束縛するとインターフェースからNullオブジェクトクラスのPHPコードが生成され、そのインスタンスにバインドされます。

テストやAOPで役に立ちます。

```php
$this->bind(CreditCardProcessorInterface::class)->toNull();
```
