---
layout: docs-en
title: Linked Bindings
category: Manual
permalink: /manuals/1.0/en/linked_bindings.html
---
## Linked Bindings

Linked bindings map a type to its implementation. This example maps the interface TransactionLogInterface to the implementation DatabaseTransactionLog:

```php
$this->bind(TransactionLogInterface::class)->to(DatabaseTransactionLog::class);
```
