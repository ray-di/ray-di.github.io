---
layout: docs-ja
title: インスタンス束縛
category: Manual
permalink: /manuals/1.0/ja/instance_bindings.html
---
## インスタンス束縛

ある型をその型のインスタンスに束縛できます。これは通常、値オブジェクトのような、それ自体に依存性がないオブジェクトにのみ使用します。

```php
$this->bind(UserInterface::class)->toInstance(new User);
```

```php
$this->bind()->annotatedWith('login_id')->toInstance('bear');
```

作成が複雑なオブジェクトではインスタンス束縛を使用しないでください。インスタンスはシリアライズ保存されるため、シリアライズ不可能なものはインスタンス束縛を使うことができません。代わりにプロバイダー束縛を使用することができます。
