---
layout: docs-ja
title: Instance Bindings
category: Manual
permalink: /manuals/1.0/ja/instance_bindings.html
---
## インスタンス束縛

ある型をその型のインスタンスにバインドすることができます。これは通常、値オブジェクトのような、それ自体に依存性を持たないオブジェクトにのみ有用です。

```php
$this->bind(UserInterface::class)->toInstance(new User);
```

```php
$this->bind()->annotatedWith('login_id')->toInstance('bear');
```

アプリケーションの起動が遅くなる可能性があるため、作成が複雑なオブジェクトでは `toInstance()` を使用しないようにします。
