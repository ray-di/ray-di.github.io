---
layout: docs-ja
title: スコープ
category: Manual
permalink: /manuals/1.0/ja/scopes.html
---
# スコープ

デフォルトでは、Ray.Diは値を供給するたびに新しいインスタンスを返します。この動作は、スコープで設定可能です。

```php
use Ray\Di\Scope;
```
```php
$this->bind(TransactionLogInterface::class)->to(InMemoryTransactionLog::class)->in(Scope::SINGLETON);
```
    
