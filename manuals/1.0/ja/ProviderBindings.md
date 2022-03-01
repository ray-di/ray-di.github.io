---
layout: docs-ja
title: プロバイダ束縛
category: Manual
permalink: /manuals/1.0/ja/provider_bindings.html
---
## プロバイダ束縛

プロバイダ束縛は型に対してそのプロバイダをマッピングします。

```php
$this->bind(TransactionLogInterface::class)->toProvider(DatabaseTransactionLogProvider::class);
```
プロバイダ class は `ProviderInterface` を実装しています。このインターフェイスは値を供給するだけのシンプルなインターフェイスです。

```php
namespace Ray\Di;

interface ProviderInterface
{
    public function get();
}
```
プロバイダはそれ自身でも依存性を持っており、コンストラクタを介して依存性を受け取ります。  
以下の例では `ProviderInterface` を実装し、型の安全性が保証された値を返します。

```php

use Ray\Di\Di\Inject;
use Ray\Di\ProviderInterface;

class DatabaseTransactionLogProvider implements ProviderInterface
{
    public function __construct(
        private readonly ConnectionInterface $connection)
    ){}

    public function get()
    {
        $transactionLog = new DatabaseTransactionLog;
        $transactionLog->setConnection($this->connection);

        return $transactionLog;
    }
}
```

最後に `toProvider()` メソッドを用いてプロバイダを束縛します。

```php
$this->bind(TransactionLogInterface::class)->toProvider(DatabaseTransactionLogProvider::class);
```

## インジェクションポイント

**InjectionPoint** はインジェクションポイントに関する情報をもつクラスです。  
メタデータへのアクセスは、 `RefrectionParameter` または `Provider` 属性によって行われます。

例えば、 `Psr3LoggerProvier` クラスの `get()` メソッドは、インジェクト可能なLoggerを作成します。  
Loggerのログカテゴリは、それがインジェクトされる対象のオブジェクトのクラスに依存しています。

```php
class Psr3LoggerProvider implements ProviderInterface
{
    public function __construct(
        private InjectionPointInterface $ip
    ){}

    public function get()
    {
        $logger = new \Monolog\Logger($this->ip->getClass()->getName());
        $logger->pushHandler(new StreamHandler('path/to/your.log', Logger::WARNING));

        return $logger;
    }
}
```
`InjectionPointInterface` は次のメソッドを提供します。

```php
$ip->getClass();      // \ReflectionClass
$ip->getMethod();     // \ReflectionMethod
$ip->getParameter();  // \ReflectionParameter
$ip->getQualifiers(); // (array) $qualifierAnnotations
```
