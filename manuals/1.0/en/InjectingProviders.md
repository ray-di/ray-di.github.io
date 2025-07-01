---
layout: docs-en
title: Injecting Providers
category: Manual
permalink: /manuals/1.0/en/injecting_providers.html
---
# Injecting Providers

With normal dependency injection, each type gets exactly *one instance* of each
of its dependent types. The `RealBillingService` gets one `CreditCardProcessor`
and one `TransactionLog`. Sometimes you want more than one instance of your
dependent types. When this flexibility is necessary, Ray.Di binds a provider.
Providers produce a value when the `get()` method is invoked:

```php
/**
 * @template T
 */
interface ProviderInterface
{
    /**
     * @return T
     */
    public function get();
}
```

The type provided by the provider is specified by the `#[Set]` attribute.

```php
class RealBillingService implements BillingServiceInterface
{
    /**
     * @param ProviderInterface<CreditCardProcessorInterface> $processorProvider
     * @param ProviderInterface<TransactionLogInterface>      $transactionLogProvider
     */
    public function __construct(
        #[Set(CreditCardProcessorInterface::class)] private ProviderInterface $processorProvider,
        #[Set(TransactionLogInterface::class)] private ProviderInterface $transactionLogProvider
    ) {}

    public chargeOrder(PizzaOrder $order, CreditCard $creditCard): Receipt
    {
        $transactionLog = $this->transactionLogProvider->get();
        $processor = $this->processorProvider->get();
        
        /* use the processor and transaction log here */
    }
}
```

To support generics in static analysis, you need to set `@param` in phpdoc to `ProviderInterface<TransactionLogInterface>` or `ProviderInterface<Cre ditCardProcessorInterface>` and so on. The type of the instance obtained by the `get()` method is specified and checked by static analysis.

## Providers for multiple instances

Use providers when you need multiple instances of the same type. Suppose your
application saves a summary entry and a details when a pizza charge fails. With
providers, you can get a new entry whenever you need one:

```php
class LogFileTransactionLog implements TransactionLogInterface
{
    public function __construct(
        #[Set(TransactionLogInterface::class)] private readonly ProviderInterface $logFileProvider
    ) {}
    
    public logChargeResult(ChargeResult $result): void {
        $summaryEntry = $this->logFileProvider->get();
        $summaryEntry->setText("Charge " + (result.wasSuccessful() ? "success" : "failure"));
        $summaryEntry->save();
        
        if (! $result->wasSuccessful()) {
            $detailEntry = $this->logFileProvider->get();
            $detailEntry->setText("Failure result: " + result);
            $detailEntry->save();
        }
    }
}
```

## Providers for lazy loading

If you've got a dependency on a type that is particularly *expensive to
produce*, you can use providers to defer that work. This is especially useful
when you don't always need the dependency:

```php
class LogFileTransactionLog implements TransactionLogInterface
{
    public function __construct(
        #[Set(Connection::class)] private ProviderInterface $connectionProvider
    ) {}
    
    public function logChargeResult(ChargeResult $result) {
        /* only write failed charges to the database */
        if (! $result->wasSuccessful()) {
            $connection = $connectionProvider->get();
        }
    }
```

## Providers for Mixing Scopes

Directly injecting an object with a _narrower_ scope usually causes unintended
behavior in your application. In the example below, suppose you have a singleton
`ConsoleTransactionLog` that depends on the request-scoped current user. If you
were to inject the user directly into the `ConsoleTransactionLog` constructor,
the user would only be evaluated once for the lifetime of the application. This
behavior isn't correct because the user changes from request to request.
Instead, you should use a Provider. Since Providers produce values on-demand,
they enable you to mix scopes safely:

```php
class ConsoleTransactionLog implements TransactionLogInterface
{
    public function __construct(
        #[Set(User::class)] private readonly ProviderInterface $userProvider
    ) {}
    
    public function logConnectException(UnreachableException $e): void
    {
        $user = $this->userProvider->get();
        echo "Connection failed for " . $user . ": " . $e->getMessage();
    }
}
```
