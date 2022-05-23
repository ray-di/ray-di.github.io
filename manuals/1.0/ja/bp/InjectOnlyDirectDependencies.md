---
layout: docs-ja
title: 直接依存するものだけを注入する
category: Manual
permalink: /manuals/1.0/ja/bp/inject_only_direct_dependencies.html
---
# 直接依存するものだけを注入する

他のオブジェクトを取得するためだけに、オブジェクトを注入することは避けてください。
例えば、 `Account` オブジェクトを取得するために `Customer` オブジェクトをインジェクトするのはやめましょう。

```php
class ShowBudgets
{
    private readonly Account $account;

    public function __construct(Customer $customer)
    {
        $this->account = $customer->getPurchasingAccount();
    }
}
```

その代わり、依存関係を直接インジェクトします。
これにより、テストケースは顧客について気にする必要がなくなり、テストが容易になります。
`Provider` クラスを使用して、 `Customer` の束縛を使用する `Account` の束縛を作成します。

```php
use Ray\Di\AbstractModule;
use Ray\Di\ProviderInterface;

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

依存関係を直接注入することで、コードがよりシンプルになります。

```php
class ShowBudgets
{
    public function __construct(
        private readonly Account $account
   ) {}
}
```
