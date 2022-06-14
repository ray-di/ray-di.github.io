---
layout: docs-ja
title: モジュールは高速で副作用がないこと
category: Manual
permalink: /manuals/1.0/ja/bp/modules_should_be_fast_and_side_effect_free.html
---
# モジュールは高速で副作用がないこと

Ray.Diのモジュールは、設定に外部XMLファイルを使用せずに通常のPHPコードで記述します。
PHPは使い慣れ、お使いのIDEで動作し、リファクタリングに耐えることができます。

しかし、PHP言語のフルパワーは代償として、モジュール内で _多くのこと_ をやりすぎてしまいがちです。
例えば、Ray.Diモジュールの中で、データベースの接続やHTTPサーバーの起動をすることです。
しかし、それはやめましょう。このような処理をモジュールの中で実行するには以下の問題があります。

* **モジュールは起動するが、シャットダウンしません。** モジュール内でデータベース接続を開いた場合、それを閉じるためのフックがありません。
* **モジュールはテストをする必要があります。** モジュールの実行過程でデータベースを開くと、そのモジュールの単体テストを書くのが難しくなります。
* **モジュールはオーバーライドが可能です。** Ray.Diモジュールは `オーバーライド` をサポートしており、本番サービスを軽量サービスやテストサービスで代用することができます。モジュール実行の一部として本番サービスが作成される場合、このようなオーバーライドは効果的ではありません。

モジュール自体で作業を行うのではなく、適切な抽象度で作業を行えるようなインターフェースを定義しましょう。
例えば、次のようなインターフェースを定義します。

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

Injector を作成した後、サービスを開始してアプリケーションのブートストラップを完了します。
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
