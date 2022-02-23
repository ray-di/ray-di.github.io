---
layout: docs-ja
title: Injecting Providers
category: Manual
permalink: /manuals/1.0/ja/injecting_providers.html
---
# Injecting Providers

With normal dependency injection, each type gets exactly *one instance* of each
of its dependent types. The `RealBillingService` gets one `CreditCardProcessor`
and one `TransactionLog`. Sometimes you want more than one instance of your
dependent types. When this flexibility is necessary, Guice binds a provider.
Providers produce a value when the `get()` method is invoked:

```php
interface Provider
{
    public function get();
}
```

Provider types are marked with a qualifier to distinguish `Provider<TransactionLog>` from `Provider<CreditCardProcessor>`. Wherever you inject a value, you can inject a provider for that value.

```php
public class RealBillingService implements BillingServiceInterface
{
    public __construct(
        #[QureditCardProcessor] private Provider $processorProvider,
        #[TransactionLog] private Provider $transactionLogProvider
    ) {}

    public chargeOrder(PizzaOrder $order, CreditCard $creditCard): Receipt
    {
        $processor = $this->processorProvider->get();
        $transactionLog = $this->transactionLogProvider->get();
        
        /* use the processor and transaction log here */
    }
}
```

```php
use Attribute;
use Ray\Di\Di\Qualifier;

#[Attribute, Qualifier]
final class QureditCardProcessor
{
}
```

```php
use Attribute;
use Ray\Di\Di\Qualifier;

#[Attribute, Qualifier]
final class TransactionLog
{
}
```

## Providers for multiple instances

Use providers when you need multiple instances of the same type. Suppose your
application saves a summary entry and a details when a pizza charge fails. With
providers, you can get a new entry whenever you need one:

```php
class LogFileTransactionLog implements TransactionLogInterface
{
    private readonly Provider $logFileProvider;
    
    public __construct(#[TransactionLog] Provider $logFileProvider) {
        $this->logFileProvider = $logFileProvider;
    }
    
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
        #[Connection] private Provider $connectionProvider
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
public class ConsoleTransactionLog implements TransactionLogInterface
{
    public function __construct(
        #[User] private readonly Provider $userProvider
    ) {}
    
    public function logConnectException(UnreachableException $e): void
    {
        $user = $this->userProvider->get();
        echo "Connection failed for " . $user . ": " . $e->getMessage();
    }
}
```
