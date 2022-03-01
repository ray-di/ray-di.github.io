---
layout: docs-ja
title: Null Object Binding
category: Manual
permalink: /manuals/1.0/ja/null_object_binding.html
---
## Nullオブジェクト束縛

Nullオブジェクトとは、インターフェイスを実装していてもメソッドの中で何もしないオブジェクトです。`toNull()`で束縛するとインターフェイスからNullオブジェクトクラスのPHPコードが生成され、そのインスタンスにバインドされます。

テストやAOPで役に立ちます。

```php
$this->bind(CreditCardProcessorInterface::class)->toNull();
```
