---
layout: docs-ja
title: Null Object Binding
category: Manual
permalink: /manuals/1.0/ja/null_object_binding.html
---
## Nullオブジェクトのバインディング

Nullオブジェクトとは、あるインターフェースを実装しているが、そのメソッドは何もしないオブジェクトのことです。
toNull()` で束縛すると、Null Object のコードはインターフェースから生成され、生成されたインスタンスに束縛されます。
これはテストやAOPに便利です。

```php
$this->bind(CreditCardProcessorInterface::class)->toNull();
```
