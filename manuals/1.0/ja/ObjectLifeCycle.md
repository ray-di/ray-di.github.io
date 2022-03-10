---
layout: docs-ja
title: オブジェクトライフサイクル
category: Manual
permalink: /manuals/1.0/ja/object_life_cycle.html
---
# Object Life Cycle

依存性注入が完了した後に`[PostConstruct]`メソッドがコールされます。注入された依存で初期化を実行するのに役立ちます。

```php
use Ray\Di\Di\PostConstruct;
```
```php
#[PostConstruct]
public function init()
{
    //....
}
```
