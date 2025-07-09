---
layout: docs-ja
title: 公開束縛のドキュメント化
category: Manual
permalink: /manuals/1.0/ja/bp/document_public_bindings.html
---
# モジュールが提供する束縛を文書化する

Ray.Diモジュールのドキュメンテーションとして、そのモジュールが提供する束縛を記述します。

```php
/**
 * Provides FooServiceClient and derived bindings
 *
 * [...]
 *
 * The following bindings are provided:
 *
 *  FooServiceClient
 *  FooServiceClientAuthenticator
 */
final class FooServiceClientModule extends AbstractModule
{
  // ...
}
```


