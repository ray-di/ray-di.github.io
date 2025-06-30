---
layout: docs-en
title: Scopes
category: Manual
permalink: /manuals/1.0/en/scopes.html
---
# Scopes

By default, Ray returns a new instance each time it supplies a value. This behaviour is configurable via scopes.

```php
use Ray\Di\Scope;
```
```php
$this->bind(TransactionLogInterface::class)->to(InMemoryTransactionLog::class)->in(Scope::SINGLETON);
```
    
