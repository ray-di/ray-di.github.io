---
layout: docs-ja
title: MinimizeMutability
category: Manual
permalink: /manuals/1.0/ja/bp/minimize_mutability.html
---
# Minimize mutability

Wherever possible, use constructor injection to create immutable objects.
Immutable objects are simple, shareable, and can be composed. Follow this
pattern to define your injectable types:

```php
class RealPaymentService implements PaymentServiceInterface
{
    public function __construct(
        private readnonly PaymentQueue $paymentQueue,
        private readnonly Notifier $notifier;
    ){}
```

All fields of this class are readonly and initialized by a constructor.

## Injecting methods

*Constructor injection* has some limitations:

*   Injected constructors may not be optional.
*   It cannot be used unless objects are created by Ray.Di.
*   Subclasses must call `parent()` with all dependencies. This makes constructor
    injection cumbersome, especially as the injected base class changes.

*Setter injection* is most useful when you need to initialize an instance that
is not constructed by Ray.Di.
