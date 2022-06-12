---
layout: docs-ja
title: モジュールは高速で副作用がないこと
category: Manual
permalink: /manuals/1.0/ja/bp/modules_should_be_fast_and_side_effect_free.html
---
# モジュールは高速で副作用がないこと

Ray.Diのモジュールは、設定に外部XMLファイルを使用するのではなく、通常のPHPコードで記述されます。
PHPは使い慣れ、IDEで動作し、リファクタリングに耐える。

しかし、PHP言語のフルパワーは代償として、モジュール内で _多くのこと_ をやりすぎてしまいがちです。
Ray.Diモジュールの中で、データベース接続やHTTPサーバーを起動したくなりますよね。

こんなことしちゃダメ モジュール内で重量物を扱うのは問題があります。

* **モジュールは起動するが、シャットダウンしない。** モジュール内でデータベース接続を開いた場合、それを閉じるためのフックがありません。
* **モジュールはテストする必要があります。** モジュールの実行過程でデータベースを開くと、そのモジュールの単体テストを書くのが難しくなる。
* **モジュールはオーバーライド可能です。** Ray.Diモジュールはオーバーライドをサポートしており、本番サービスを軽量サービスやテストサービスで代用することができます。Ray.Diのモジュールはオーバーライドをサポートしており、本番サービスを軽量サービスやテストサービスに置き換えることができます。

モジュール自体で作業を行うのではなく、適切な抽象度で作業を行えるインターフェースを定義する。
私たちのアプリケーションでは、このインターフェイスを使用しています。

```php
interface ServiceInterface
{
    /**
     * Starts the service. This method blocks until the service has completely started.
     */
    public function start(): void;
    
    /**
     * Stops the service. This method blocks until the service has completely shut down.
     */
    public function stop(): void;
}
```

Injector を作成した後、サービスを開始することでアプリケーションのブートストラップを完了します。
また、アプリケーションを停止したときにリソースをきれいに解放するために、シャットダウンフックを追加します。

```php
class Main
{
    public function __invoke()
        $injector = new Injector([
            new DatabaseModule(),
            new WebserverModule(),
            // ..
        ]);
        $databaseConnectionPool = $injector->getInstance(ServiceInterface::class, DatabaseService::class);
        $databaseConnectionPool->start();
        $this->addShutdownHook($databaseConnectionPool);

        $webserver = $injector->getInstance(ServiceInterface::class, WebserverService::class);
        $webserver->start();
        $this->addShutdownHook($webserver);
    );
}
```
