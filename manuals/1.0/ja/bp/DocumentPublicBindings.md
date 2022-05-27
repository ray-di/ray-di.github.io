---
layout: docs-ja
title: DocumentPublicBindings
category: Manual
permalink: /manuals/1.0/ja/bp/document_public_bindings.html
---
# モジュールが提供するパブリックバインディングを文書化する

Ray.Diモジュールを文書化するには、例えばそのモジュールがインストールするパブリックバインディングを記述するのが良い戦略です。

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


