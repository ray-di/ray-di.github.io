---
layout: docs-ja
title: Instance Bindings
category: Manual
permalink: /manuals/1.0/ja/instance_bindings.html
---
## インスタンス束縛

ある型をその型のインスタンスにバインドすることができます。これは通常、値オブジェクトのような、それ自体に依存性がないオブジェクトにのみ使用します。

```php
$this->bind(UserInterface::class)->toInstance(new User);
```

```php
$this->bind()->annotatedWith('login_id')->toInstance('bear');
```

作成が複雑なオブジェクトではインスタンス束縛を使用しないようにしてください。インスタンスはシリアライズ保存されるので、シリアライズ不可能なものはインスタンス束縛を使う事ができません。代わりにプロバイダ束縛を使用することができます。
