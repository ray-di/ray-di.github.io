---
layout: docs-en
title: Minimize mutability
category: Manual
permalink: /manuals/1.0/en/bp/minimize_mutability.html
---
# Minimize mutability

Wherever possible, use constructor injection to create immutable objects.
Immutable objects are simple, shareable, and can be composed. Follow this
pattern to define your injectable types:

```java
public class RealPaymentService implements PaymentService {

   private final PaymentQueue paymentQueue;
   private final Notifier notifier;

   @Inject
   RealPaymentRequestService(
       PaymentQueue paymentQueue,
       Notifier notifier) {
     this.paymentQueue = paymentQueue;
     this.notifier = notifier;
   }

   ...
```

All fields of this class are final and initialized by a single
`@Inject`-annotated constructor.
[Effective Java](http://www.amazon.com/Effective-Java-Edition-Joshua-Bloch/dp/0321356683)
discusses other benefits of immutability.

## Injecting methods and fields

*Constructor injection* has some limitations:

*   Injected constructors may not be optional.
*   It cannot be used unless objects are created by Guice. This is a dealbreaker
    for certain frameworks.
*   Subclasses must call `super()` with all dependencies. This makes constructor
    injection cumbersome, especially as the injected base class changes.

*Method injection* is most useful when you need to initialize an instance that
is not constructed by Guice. Extensions like [AssistedInject](AssistedInject)
and Multibinder use method injection to initialize bound objects.

*Field injection* has the most compact syntax, so it shows up frequently on
slides and in examples. It is neither encapsulated nor testable. Never inject
[final fields](https://github.com/google/guice/issues/245); the JVM doesn't
guarantee that the injected value will be visible to all threads.
