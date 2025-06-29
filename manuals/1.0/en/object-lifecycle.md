---
layout: docs-en
title: Object Life Cycle
category: Manual
permalink: /manuals/1.0/en/object-life-cycle.html
---
# Object Life Cycle

`#[PostConstruct]` is used on methods that need to get executed after dependency injection has finalized to perform any extra initialization.

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
