---
layout: docs-ja
title: Untargeted Bindings
category: Manual
permalink: /manuals/1.0/ja/untargeted_bindings.html
---
## ターゲット外バインディング

ターゲットを指定せずにバインディングを作成することができます。これは具象クラスで最も有用です。ターゲットを指定しないバインディングは、インジェクタに型に関する情報を提供し、依存関係を熱心に準備することができます。アンターゲットバインディングには _to_ 節がありません。

```php
$this->bind(MyConcreteClass::class);
$this->bind(AnotherConcreteClass::class)->in(Scope::SINGLETON);
```

注：現在、annotatedWith()メソッドはUntargeted Bindingsには対応していません。
