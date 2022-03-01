---
layout: docs-ja
title: Null Object Binding
category: Manual
permalink: /manuals/1.0/ja/null_object_binding.html
---
## Nullオブジェクト束縛

Nullオブジェクトとは、「あるインターフェースを実装しているが、そのメソッドは特に何もしない」といった性質を備えたオブジェクトのことです。

`toNull()` は、まず与えられたインターフェースを実装したNull Objectのコードを生成します。そして、出来上がったNullオブジェクトのインスタンスと、元になったインターフェースとを束縛します。

これはテストやAOPに際して有用な機能です。

```php
$this->bind(CreditCardProcessorInterface::class)->toNull();
```
