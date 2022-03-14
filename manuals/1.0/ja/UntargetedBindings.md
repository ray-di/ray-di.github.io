---
layout: docs-ja
title: アンターゲット束縛
category: Manual
permalink: /manuals/1.0/ja/untargeted_bindings.html
---
## アンターゲット束縛

具象クラスの束縛に用います。インジェクタに型に関する情報を提供し、依存関係を準備することができます。アンターゲット束縛には `to()` 節がありません。

```php
$this->bind(MyConcreteClass::class);
$this->bind(AnotherConcreteClass::class)->in(Scope::SINGLETON);
```

注：現在、アンターゲット束縛は`annotatedWith()`節をサポートしていません。
