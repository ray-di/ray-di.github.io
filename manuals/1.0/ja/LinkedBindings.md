---
layout: docs-ja
title: リンク束縛
category: Manual
permalink: /manuals/1.0/ja/linked_bindings.html
---
## リンク束縛

リンク束縛は、型とその実装をマッピングします。この例では、インターフェース `TransactionLogInterface` を実装クラス `DatabaseTransactionLog` に紐付けています。

```php
$this->bind(TransactionLogInterface::class)->to(DatabaseTransactionLog::class);
```
