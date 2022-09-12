---
layout: docs-ja
title: コンテキストプロバイダー束縛
category: Manual
permalink: /manuals/1.0/ja/contextual_bindings.html
---
# コンテキストプロバイダー束縛

Providerとバインドする際に、同じようなインスタンスを少しづつ変えて返したい時があります。
例えば、異なる接続先の同じDBオブジェクトをインジェクトしたい場合です。そのような場合には、`toProvider()`で文字列のコンテキストを指定して束縛することができます。



```php
$dbConfig = ['user' => $userDsn, 'job'=> $jobDsn, 'log' => $logDsn];
$this->bind()->annotatedWith('db_config')->toInstance(dbConfig);
$this->bind(Connection::class)->annotatedWith('usr_db')->toProvider(DbalProvider::class, 'user');
$this->bind(Connection::class)->annotatedWith('job_db')->toProvider(DbalProvider::class, 'job');
$this->bind(Connection::class)->annotatedWith('log_db')->toProvider(DbalProvider::class, 'log');
```

それぞれのコンテキストのプロバイダーがつくられます。

```php
use Ray\Di\Di\Inject;
use Ray\Di\Di\Named;

class DbalProvider implements ProviderInterface, SetContextInterface
{
    private $dbConfigs;

    public function setContext($context)
    {
        $this->context = $context;
    }

    public function __construct(#[Named('db_config') array $dbConfigs)
    {
        $this->dbConfigs = $dbConfigs;
    }

    /**
     * {@inheritdoc}
     */
    public function get()
    {
        $config = $this->dbConfigs[$this->context];
        $conn = DriverManager::getConnection($config);

        return $conn;
    }
}
```

`Provider`によって作られた異なるコネクションを受け取ることができます。

```php
public function __construct(
    #[Named('user')] private readonly Connection $userDb,
    #[Named('job')] private readonly Connection $jobDb,
    #[Named('log') private readonly Connection $logDb)
) {}
```
