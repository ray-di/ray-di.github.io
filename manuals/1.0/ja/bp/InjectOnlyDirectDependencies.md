---
layout: docs-ja
title: InjectOnlyDirectDependencies
category: Manual
permalink: /manuals/1.0/ja/bp/inject_only_direct_dependencies.html
---
# Inject only direct dependencies

Avoid injecting an object only as a means to get at another object. For example, don't inject a `Customer` as a means to get at an `Account`:

```php
class ShowBudgets
{
    private readonly Account $account;

    public function __construct(Customer $customer)
    {
        $this->account = $customer->getPurchasingAccount();
    }
```

Instead, inject the dependency directly. This makes testing easier; the test case doesn't need to concern itself with the customer. Use an `Provider` class to create the binding for `Account` that uses the binding for `Customer`:

```php
class CustomersModule extends AbstractModule
{
    protected function configure()
    {
        $this->bind(Account::class)->toProvider(PurchasingAccountProvider::class);
    }
}

class PurchasingAccountProvider implements ProviderInterface
{
    public function __construct(
        private readonly Customer $customer
    ) {}
    
    public function get(): Account
    {
        return $this->customer->getPurchasingAccount();
    }
}
```

By injecting the dependency directly, our code is simpler.

```php
class ShowBudgets
{
    public function __construct(
        private readonly Account $account
   ) {}
```
