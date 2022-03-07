---
layout: docs-ja
title: オブジェクトライフサイクル
category: Manual
permalink: /manuals/1.0/ja/object_life_cycle.html
---
# Object Life Cycle

`[PostConstruct]`は、依存性注入が完了した後に実行される必要があるメソッドで使用され、余分な初期化を実行します。

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
