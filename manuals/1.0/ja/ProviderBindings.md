---
layout: docs-ja
title: プロバイダー束縛
category: Manual
permalink: /manuals/1.0/ja/provider_bindings.html
---
## プロバイダー束縛

プロバイダー束縛は型に対してそのプロバイダーをマッピングします。

```php
$this->bind(TransactionLogInterface::class)->toProvider(DatabaseTransactionLogProvider::class);
```
プロバイダーは `ProviderInterface` を実装しています。このインターフェースは値を供給するだけのシンプルなインターフェースです。

```php
namespace Ray\Di;

interface ProviderInterface
{
    public function get();
}
```
プロバイダーはそれ自身でも依存性を持っており、コンストラクターを介して依存性を受け取ります。
以下の例では `ProviderInterface` を実装し、型の安全性が保証された値を返します。

```php

use Ray\Di\Di\Inject;
use Ray\Di\ProviderInterface;

class DatabaseTransactionLogProvider implements ProviderInterface
{
    public function __construct(
        private readonly ConnectionInterface $connection
    ) {}

    public function get()
    {
        $transactionLog = new DatabaseTransactionLog;
        $transactionLog->setConnection($this->connection);

        return $transactionLog;
    }
}
```

最後に `toProvider()` メソッドを用いてプロバイダーを束縛します。

```php
$this->bind(TransactionLogInterface::class)->toProvider(DatabaseTransactionLogProvider::class);
```

## インジェクションポイント

`InjectionPoint`オブジェクトは、注入が行われる箇所（インジェクションポイント）のメタ情報を保持するクラスです。プロバイダーは、注入箇所のクラス名や変数名などのインジェクションポイントのメタデータを使って依存インスタンスを作成する事ができます。

### 例：インスタンス生成にインジェクションポイントのクラス名を使用

インジェクションポイントのクラス名を`$this->ip->getClass()->getName()`で取得して依存インスタンスを生成しています。

```php
class Psr3LoggerProvider implements ProviderInterface
{
    public function __construct(
        private InjectionPointInterface $ip
    ) {}

    public function get()
    {
        $logger = new \Monolog\Logger($this->ip->getClass()->getName());
        $logger->pushHandler(new StreamHandler('path/to/your.log', Logger::WARNING));

        return $logger;
    }
}
```
`InjectionPointInterface` は以下のメソッドを提供します。

```php
$ip->getClass();      // \ReflectionClass
$ip->getMethod();     // \ReflectionMethod
$ip->getParameter();  // \ReflectionParameter
$ip->getQualifiers(); // (array) $qualifierAnnotations
```
