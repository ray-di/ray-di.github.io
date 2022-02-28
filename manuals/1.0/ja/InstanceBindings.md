---
layout: docs-ja
title: Instance Bindings
category: Manual
permalink: /manuals/1.0/ja/instance_bindings.html
---
## インスタンス束縛

値を直接束縛できます。定数の束縛に使います。

```php
$this->bind()->annotatedWith('login_id')->toInstance('bear');
```

オブジェクトの束縛にも使用できますが、注意が必要です。

```php
$this->bind(UserInterface::class)->toInstance(new User);
```

注意：アプリケーションの起動パフォーマンスへの影響があるため、単純な値オブジェクトのような、それ自体に依存性を持たないオブジェクトにのみ使用してください。
