---
layout: docs-en
title: Binding Attributes
category: Manual
permalink: /manuals/1.0/en/binding_attributes.html
---
## Binding Attributes

Occasionally you'll want multiple bindings for a same type. For example, you might want both a PayPal credit card processor and a Google Checkout processor.
To enable this, bindings support an optional binding attribute. The attribute and type together uniquely identify a binding. This pair is called a key.

### Defining binding attributes

Define qualifier attribute first. It needs to be annotated with `Qualifier` attribute.

```php
use Ray\Di\Di\Qualifier;

#[Attribute, Qualifier]
final class PayPal
{
}
```

To depend on the annotated binding, apply the attribute to the injected parameter:

```php
public function __construct(
    #[Paypal] private readonly CreditCardProcessorInterface $processor
){}
```
You can specify parameter name with qualifier. Qualifier applied all parameters without it.

```php
public function __construct(
    #[Paypal('processor')] private readonly CreditCardProcessorInterface $processor
){}
```
Lastly we create a binding that uses the attribute. This uses the optional `annotatedWith` clause in the bind() statement:

```php
$this->bind(CreditCardProcessorInterface::class)
  ->annotatedWith(PayPal::class)
  ->to(PayPalCreditCardProcessor::class);
```

### Binding Attributes in Setters

In order to make your custom `Qualifier` attribute inject dependencies by default in any method the
attribute is added, you need to implement the `Ray\Di\Di\InjectInterface`:

```php
use Ray\Di\Di\InjectInterface;
use Ray\Di\Di\Qualifier;

#[Attribute, Qualifier]
final class PaymentProcessorInject implements InjectInterface
{
    public function isOptional()
    {
        return $this->optional;
    }
    
    public function __construct(
        public readonly bool $optional = true
        public readonly string $type;
    ){}
}
```

The interface requires that you implement the `isOptional()` method. It will be used to determine whether
or not the injection should be performed based on whether there is a known binding for it.

Now that you have created your custom injector attribute, you can use it on any method.

```php
#[PaymentProcessorInject(type: 'paypal')]
public setPaymentProcessor(CreditCardProcessorInterface $processor)
{
 ....
}
```

Finally, you can bind the interface to an implementation by using your new annotated information:

```php
$this->bind(CreditCardProcessorInterface::class)
    ->annotatedWith(PaymentProcessorInject::class)
    ->toProvider(PaymentProcessorProvider::class);
```

The provider can now use the information supplied in the qualifier attribute in order to instantiate
the most appropriate class.

## #[Named]

The most common use of a Qualifier attribute is tagging arguments in a function with a certain label,
the label can be used in the bindings in order to select the right class to be instantiated. For those
cases, Ray.Di comes with a built-in binding attribute `#[Named]` that takes a string.

```php
use Ray\Di\Di\Inject;
use Ray\Di\Di\Named;

public function __construct(
    #[Named('checkout')] private CreditCardProcessorInterface $processor
){}
```

To bind a specific name, pass that string using the `annotatedWith()` method.

```php
$this->bind(CreditCardProcessorInterface::class)
    ->annotatedWith('checkout')
    ->to(CheckoutCreditCardProcessor::class);
```

You need to put the `#[Named]` attribuet in order to specify the parameter.

```php
use Ray\Di\Di\Inject;
use Ray\Di\Di\Named;

public function __construct(
    #[Named('checkout')] private CreditCardProcessorInterface $processor,
    #[Named('backup')] private CreditCardProcessorInterface $subProcessor
){}
```

## Binding Annotation

Ray.Di can be used with [doctrine/annotation](https://github.com/doctrine/annotations) for PHP 7.x. See the old [README(v2.10)](https://github.com/ray-di/Ray.Di/tree/2.10.5/README.md) for annotation code examples. To create forward-compatible annotations for attributes, see [custom annotation classes](https://github.com/kerveros12v/sacinta4/blob/e976c143b3b7d42497334e76c00fdf 38717af98e/vendor/doctrine/annotations/docs/en/custom.rst#optional-constructors-with-named-parameters).

Since annotations cannot be applied to arguments, the first argument of a custom annotation should be the name of the variable. This is not necessary if the method has only one argument.

```php
/**
 * @Paypal('processor')
 */
public function setCreditCardProcessor(
	 CreditCardProcessorInterface $processor
   OtherDependencyInterface $dependency
){
```
