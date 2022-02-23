---
layout: docs-en
title: Getting Started
category: Manual
permalink: /manuals/1.0/en/getting_started.html
---
# GettingStarted

_How to start doing dependency injection with Ray.Di._

## はじめに

Ray.Diは、あなたのアプリケーションで依存性注入（DI）パターンを簡単に使用できるようにするフレームワークです。このスタートガイドでは、Ray.Di を使ってアプリケーションに依存性注入を取り入れる方法を、簡単な例で説明します。

### 依存性注入とは何ですか？

[Dependency injection](https://en.wikipedia.org/wiki/Dependency_injection)は、クラスが依存関係を引数として宣言するデザインパターンです。
を直接作成するのではありません。例えば、あるサービスを呼び出したいクライアントは、サービスを構築する方法を知る必要はありません。むしろ、外部のコードがクライアントにサービスを提供する責任を負うのです。

依存性注入を使用しないコードの簡単な例を示します。

```php
class Foo
{
    private Database $database;  // We need a Database to do some work
    
    public function __construct()
    {
        // Ugh. How could I test this? What if I ever want to use a different
        // database in another application?
        $this->database = new Database('/path/to/my/data');
    }
}
```

上記の `Foo` クラスは、固定の `Database` オブジェクトを直接作成します。このため、このクラスを他の `Database` オブジェクトと一緒に使うことはできません。また、テスト時に実際のデータベースをテスト用のデータベースと交換することもできません。テストできないコードや柔軟性に欠けるコードを書く代わりに、依存性注入パターンを使用することで、これらの問題すべてに対処することができます。

以下は同じ例で、今回は依存性注入を使用しています。

```php
class Foo {
    private Database $database;  // We need a Database to do some work
    
    public function __construct(Database $database)
    {
        // The database comes from somewhere else. Where? That's not my job, that's
        // the job of whoever constructs me: they can choose which database to use.
        $this->database = $database;
    }
}
```

上記の `Foo` クラスは、`Database` がどのように作成されたかを知らないので、任意の `Database` オブジェクトを使用することができます。例えば、インメモリデータベースを使用する `Database` の実装のテスト版をテストで作成すると、テストの密閉性と高速性を高めることができる。

Motivation](Motivation.md) ページでは、アプリケーションが依存性注入パターンを使用すべき理由について、より詳しく説明しています。

## コアとなるRay.Diのコンセプト

### コンストラクタ

PHPクラスのコンストラクタは、[コンストラクタ注入](Injections.md#constructor-injection)という処理によってRay.Diから呼び出すことができ、その際にコンストラクタの引数はRay.Diによって作成・提供されることになります。(Guiceとは異なり、Ray.Diはコンストラクタに「Inject」アノテーションを必要としません)。

以下は、コンストラクタ注入を使用するクラスの例です。

```php
class Greeter
{
    // Greeter declares that it needs a string message and an integer
    // representing the number of time the message to be printed.
    // The @Inject annotation marks this constructor as eligible to be used by
    // Ray.Di.
    public function __construfct(
        #[Message] readonly string $message,
        #[Count] readonly int $count
    ) {}

    public function sayHello(): void
    {
        for ($i=0; $i < $this->count; $i++) {
            echo $message;
        }
    }
}
```

上記の例では、アプリケーションが Ray.Di に `Greeter` のインスタンスを作成するように要求したときに呼び出されるコンストラクタが `Greeter` クラスに含まれています。Ray.Diは必要な2つの引数を作成し、それからコンストラクタを呼び出します。Greeter` クラスのコンストラクタの引数は依存関係にあり、アプリケーションは `Module` を使用して Ray.Di に依存関係を満たす方法を伝えます。

### Ray.Di モジュール

アプリケーションには、他のオブジェクトへの依存を宣言するオブジェクトが含まれ、それらの依存関係はグラフを形成します。例えば、上記の `Greeter` クラスは 2 つの依存関係を持っています (コンストラクタで宣言されています)。

* 印刷されるメッセージのための `string` 値
* メッセージを印刷する回数を示す `int` 値

Ray.Diモジュールでは、これらの依存関係を満たす方法をアプリケーションで指定することができます。例えば、以下の `DemoModule` は `Greeter` クラスに必要なすべての依存関係を設定する。

```php
class CountProvider implements ProviderInterface
{
    public function get(): int
    {
        return 3;
    }
}

class MessageProvider implements ProviderInterface
{
    public function get(): int
    {
        return 'hello world';
    }
}

/**
 * Ray.Di module that provides bindings for message and count used in
 * {@link Greeter}.
 */
class DemoModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind()->annotatedWith(Count::class)->toProvider(CountProvider::class);
        $this->bind()->annotatedWith(Message::class)->toProvider(MessageProvider::class);
    }
}
```

In a real application, the dependency graph for objects will be much more complicated and Ray.Di makes すべての相互依存関係を自動的に作成することで、複雑なオブジェクトを簡単に作成できます。

### Ray.Diインジェクター

アプリケーションをブートストラップするために、1つ以上のモジュールを含む Ray.Di `Injector` を作成する必要があります。例えば、ウェブサーバースクリプトは以下のようなものであろう。

```php
final class MyWebServer {
    public function __construct(
        private readonyly RequestLoggingInterface $requestLogging,
        private readonyly RequestHandlerInterface $requestHandler,
        private readonyly AuthenticationInterface $authentication,
        private readonyly Database $database
    ) {}

    public function start(): void
    {
        //　...
    }
    
    public function __invoke(): void
    {
        // Creates an injector that has all the necessary dependencies needed to
        // build a functional server.
        $injector = new Injector([
            new RequestLoggingModule(),
            new RequestHandlerModule(),
            new AuthenticationModule(),
            new DatabaseModule()
        ]);
    
        // Bootstrap the application by creating an instance of the server then
        // start the server to handle incoming requests.
        $injector->getInstance(MyWebServer::class)->start();
    }
}

(new MyWebServer)();
```

The injector internally holds the dependency graphs described in your application. When you request an instance of a given type, the injector figures out what objects to construct, resolves their dependencies, and wires everything together. To specify how dependencies are resolved, configure your injector with
[bindings](Bindings).

[`Injector`]: https://github.com/ray-di/Ray.Di/blob/2.x/src/di/InjectorInterface.php

## A simple Ray.Di application

The following is a simple Ray.Di application with all the necessary pieces put
together:

```php
<?php
require __DIR__ . '/vendor/autoload.php';

use Ray\Di\AbstractModule;
use Ray\Di\Di\Qualifier;
use Ray\Di\Injector;

#[Attribute, Qualifier]
class Message
{
}

#[Attribute, Qualifier]
class Count
{
}

class CountProvider implements ProviderInterface
{
    public function get(): int
    {
        return 3;
    }
}

class MessageProvider implements ProviderInterface
{
    public function get(): int
    {
        return 'hello world';
    }
}

class DemoModule extends AbstractModule
{
    protected function configure()
    {
        $this->bind()->annotatedWith(Count::class)->toProvider(CountProvider::class);
        $this->bind()->annotatedWith(Message::class)->toProvider(MessageProvider::class);
    }
}

class Greeter
{
    public function __construct(
        #[Greeting] private string $greerting,
        #[Count] private int $count
    ) {}

    public function sayHello(): void
    {
        for ($i = 0; $i < $this->count ; $i++) {
            echo $this->greerting . PHP_EOL;
        }
    }
}

/*
 * Injector's constructor takes one modules.
 * Most applications will call this method exactly once in bootstrap.
 */
$injector = new Injector(new DemoModule);

/*
 * Now that we've got the injector, we can build objects.
 */
$greeter = $injector->getInstance(Greeter::class);

// Prints "hello world" 3 times to the console.
$greeter->sayHello();
```

`RayDiDemo` アプリケーションは、`Greeter` クラスのインスタンスを構築することができる Ray.Di を使用して小さな依存関係グラフを構築しています。大規模なアプリケーションは通常、複雑なオブジェクトを構築することができる多くの `Module` を持っています。

## 次はどうする？

Ray.Diを簡単な[メンタルモデル]で概念化する方法(mental_model.html)はこちらをご覧ください。
