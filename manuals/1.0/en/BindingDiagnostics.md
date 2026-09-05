---
layout: docs-en
title: Binding Diagnostics
category: Manual
permalink: /manuals/1.0/en/binding_diagnostics.html
---
# Binding Diagnostics

_Overview of bindings.md and the provenance log_

When an `Injector` is created with an explicit writable directory, Ray.Di records how the container was composed and writes `bindings.md` into that directory.

```php
$injector = new Injector(new AppModule(), $tmpDir); // writes $tmpDir/bindings.md
```

The file lists the resolved bindings, the modules that composed them, and a provenance log of what happened during composition:

- `bind` — a binding was registered
- `replace` — a later binding replaced an earlier one (for example via `override()`)
- `keep` — a later binding for the same key was discarded
- `move` — a binding was renamed

Entries that lost a collision are shown as discarded, so you can see which binding actually won.

Writing is best-effort and atomic: diagnostics never break injection, and an unchanged binding surface is not rewritten.

## HTML viewer

The [ray/bindings](https://github.com/ray-di/Ray.Bindings) package renders `bindings.md` as an interactive HTML page with an object graph.

```bash
composer require --dev ray/bindings
vendor/bin/bindings-html var/tmp/bindings.md composer.lock > bindings.html
```

<img src="/images/bindings.png" alt="bindings.html: object graph, summary, and binding list" width="100%">

BEAR.Sunday applications can generate the same page with the `bindings` format of [BEAR.ApiDoc](https://github.com/bearsunday/BEAR.ApiDoc).

Note: the `Ray\Bindings\*` classes and `bin/bindings-html` that shipped in 2.22.1–2.22.2 moved out of core in 2.23.0. The package above is their continuation.
