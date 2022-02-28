---
layout: docs-en
title: DocumentPublicBindings
category: Manual
permalink: /manuals/1.0/en/bp/document_public_bindings.html
---
# Document the public bindings provided by modules

To document a Guice module, a good strategy is to describe the public bindings
that that module installs, for example:

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


