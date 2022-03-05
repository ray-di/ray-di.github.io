---
layout: docs-ja
title: はじめに
category: Manual
permalink: /manuals/1.0/ja/getting_started.html
---
# GettingStarted

_Ray.Di.を使ったDIの始め方_

## はじめに

Ray.Diは、あなたのアプリケーションで依存性注入（DI）パターンを簡単に使用できるようにするフレームワークです。このスタートガイドでは、Ray.Di を使ってアプリケーションに依存性注入を取り入れる方法を簡単な例で説明します。

### 依存性の注入とは何ですか？

[依存性の注入 (dependency injection)](https://ja.wikipedia.org/wiki/依存性の注入)は、クラスが依存関係を直接作成するのではなく、引数として宣言するデザインパターンです。あるサービスを呼び出したいクライアントはサービスを構築する方法を知る必要はなく、外部のコードがクライアントにサービスを提供する役割を担います。

依存性注入を使用しないコードの例を簡単な示します。

```php
class Foo
{
    private Database $database;  // 仕事を完了させるためにはデータベースが必要
    
    public function __construct()
    {
        // うっ。どうやってテストすればいいんでしょうか？
        // 他のアプリケーションで別のデータベースを使いたい場合はどうすればいいのでしょうか？
        $this->database = new Database('/path/to/my/data');
    }
}
```

上記の `Foo` クラスは、固定の `Database` オブジェクトを直接作成します。このため、このクラスを他の `Database` オブジェクトと一緒に使うことはできません。また、テスト時に実際のデータベースをテスト用のデータベースと交換することもできません。テストできないコードや柔軟性に欠けるコードを書く代わりに、依存性注入パターンを使用することで、これらの問題すべてに対処することができます。

以下は同じ例で、今回は依存性注入を使用しています。

```php
class Foo {
    private Database $database;  //　仕事を完了させるためにはデータベースが必要
    
    public function __construct(Database $database)
    {
        // データベースは別のところから来ている。どこかって？それは私の仕事ではありません。
        // どのデータベースを使うかは、私を構築する人の仕事です。
        $this->database = $database;
    }
}
```

上記の `Foo` クラスは、`Database` がどのように作成されたかを知らないので、任意の `Database` オブジェクトを使用することができます。例えば、テスト用にインメモリデータベースを使用する `Database` の実装を作成すると、テストの密閉性と高速性を高めることができます。

[モチベーション](Motivation.md) ページでは、アプリケーションが依存性注入パターンを使用すべき理由について、より詳しく説明しています。

## Ray.Diのコアコンセプト

### コンストラクタ

PHPクラスのコンストラクタは、[コンストラクタ注入](Injections.md#constructor-injection)という処理によってRay.Diから呼び出すことができ、その際にコンストラクタの引数はRay.Diによって作成・提供されることになります。(Guiceとは異なり、Ray.Diはコンストラクタに`Inject`アノテーションを必要としません)

以下は、コンストラクタ注入を使用するクラスの例です。

```php
class Greeter
{
    // Greeterは、文字列メッセージと、メッセージを表示する回数を表す整数が必要であると宣言しています。
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

上記の例の`Greeter` にはコンストラクタがあり、Ray.Diが`Greeter`のインスタンスを作成する時に呼び出されます。Ray.Diはそのために必要な2つの引数を作成し、それからコンストラクタを呼び出します。`Greeter`クラスのコンストラクタの引数は依存関係にあり、アプリケーションは `Module` を使用して Ray.Di に依存関係を解決する方法を伝えます。

### Ray.Di モジュール

アプリケーションには、他のオブジェクトへの依存を宣言するオブジェクトが含まれ、それらの依存関係でグラフを形成します。例えば、上記の `Greeter` クラスは 2 つの依存関係を持っているのがコンストラクタで宣言されています。

* プリントされるメッセージのための `string` 値
* メッセージをプリントする回数を示す `int` 値

Ray.Diモジュールでは、これらの依存関係を満たす方法をアプリケーションで指定することができます。例えば、以下の `DemoModule` は `Greeter` クラスに必要なすべての依存関係を設定しています。

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
 * メッセージとカウントの束縛を提供するRayDiモジュール
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

実際のアプリケーションでは、オブジェクトの依存関係グラフはもっと複雑になりますが、Ray.Diはすべての推移的依存関係[^transitive_dependencies]を自動的に作成し、複雑なオブジェクトを簡単に作成することができます。

[^transitive_dependencies]: 推移的依存関係とは、プログラムが直接参照するコンポーネントによって誘発される依存関係のことです。例えば、log()関数の呼び出しは、通常、ログメッセージをファイルに書き込むためのI/Oを管理するライブラリへの"推移的依存関係"を誘発します。☞ [Transitive_dependency](https://en.wikipedia.org/wiki/Transitive_dependency)

### Ray.Diインジェクター

アプリケーションをブートストラップするために、1つ以上のモジュールを含む Ray.Di `Injector` を作成する必要があります。例えば、ウェブサーバースクリプトは以下のようなものでしょう。

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
        // サーバーを構築するために必要なすべての依存関係を持つインジェクタを作成します。
        $injector = new Injector([
            new RequestLoggingModule(),
            new RequestHandlerModule(),
            new AuthenticationModule(),
            new DatabaseModule()
        ]);
    
        // サーバーのインスタンスを作成してアプリケーションをブートストラップし
        // 受信したリクエストを処理するためにサーバーを開始します。
        $injector->getInstance(MyWebServer::class)->start();
    }
}

(new MyWebServer)();
```

インジェクターは、アプリケーションで記述された依存関係グラフを内部で保持します。指定した型のインスタンスを要求すると、インジェクタはどのオブジェクトを作成すべきかを判断し、依存関係を解決してすべてを結びつけます。依存関係の解決方法を指定するために、[束縛](bindings.html)を使用してインジェクタを設定します。

## シンプルなRay.Diアプリケーション

以下は、必要なものをまとめたシンプルなRay.Diアプリケーションです。

```php
<?php
require __DIR__ . '/vendor/autoload.php';

use Ray\Di\AbstractModule;
use Ray\Di\Di\Qualifier;
use Ray\Di\ProviderInterface;
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
    public function get(): string
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
        #[Message] private string $message,
        #[Count] private int $count
    ) {}

    public function sayHello(): void
    {
        for ($i = 0; $i < $this->count ; $i++) {
            echo $this->message . PHP_EOL;
        }
    }
}

/*
 * インジェクタのコンストラクタは、モジュールを受け取ります。
 * ほとんどのアプリケーションは、起動時にこのメソッドを一度だけ呼び出します。
 */
$injector = new Injector(new DemoModule);

/*
 * 入手したインジェクタで、オブジェクトを作成します。
 */
$greeter = $injector->getInstance(Greeter::class);

// コンソールに 'hello world'を3回表示。
$greeter->sayHello();
```

`RayDiDemo` アプリケーションは、`Greeter` クラスのインスタンスを構築することができる Ray.Di を使用して小さな依存関係グラフを構築しています。通常、大規模なアプリケーションは複雑なオブジェクトを構築することができる多くの `Module` を持っています。

## 次に

シンプルな [メンタルモデル](mental_model.html)でRay.Diをもっと深く理解する方法を探索してください。

---
