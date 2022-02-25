---
layout: docs-ja
title: Mental Model
category: Manual
permalink: /manuals/1.0/ja/mental_model.html
---
# Ray.Di メンタルモデル

_`Key`や`Provider`について、そしてRay.Diがどうのようにして単なるマップと考えられるかについて_

依存性注入（Dependency Injection）について調べていると、多くのバズワード（"制御の反転"、"ハリウッド原則"、"インジェクション"）を目にし混乱することがあります。しかし、依存性注入という専門用語に対してコンセプトはそれほど複雑ではありません。実際、あなたはすでによく似たことを書いているかもしれません。
このページでは、Ray.Diの実装の簡略化されたモデルについて説明しどのように働くかの理解を助けます。

## Ray.Diはマップ

基本的にRay.Diは、アプリケーションが使用するオブジェクトの作成と取得を支援します。アプリケーションが必要とするこれらのオブジェクトは **依存や依存性(dependencies)** と呼ばれます。

Ray.Diはマップ[^raydi-map]であると考えることができます。アプリケーションのコードが必要な依存関係を宣言すると、Ray.Diはそのマップからそれらを取得します。"Ray.Diマップ"の各エントリーは、2つの部分から構成されています。

*   **Ray.Di キー**: マップから特定の値を取得するために使用されるマップのキー
*   **プロバイダ**: アプリケーションのオブジェクトを作成するために使用されるマップの値

[^raydi-map]: [PHPの配列](https://www.php.net/manual/ja/language.types.array.php)はマップです。また、Ray.Diの実際の実装ははるかに複雑ですが、マップはRay.Diがどのように動作するかおおよそを表しています。

### Ray.Diキー

Ray.Diは`Key`を使って、Ray.Diマップから依存関係を解決します。

[はじめに](getting_started.html) で使用されている `Greeter` クラスは、コンストラクタで2つの依存関係を宣言していて、それらの依存関係は Ray.Di では `Key` として表されます。

*   `#[Message] string` --> `$map[$messageKey]`
*   `#[Count] int` --> `$map[$countKey]`

最も単純な形の `Key` は、PHP の型で表されます。

```php
// Identifies a dependency that is an instance of string.
/** @var string $databaseKey */
$databaseKey = $map[$key];
```

しかし、アプリケーションには同じ型の依存関係があることがあります。

```php
class Message
{
    public function __construct(
    	  public readonly string $text
    ){}
}

class MultilingualGreeter
{
    public function __construct(
      private readonly Message $englishGreeting,
      private readonly Message $spanishGreeting
    ) {}
}
```

Ray.Diでは、同じタイプの依存関係を区別するために、[アトリビュート束縛](binding_attributes.htnl) を使用しています。

```php
class MultilingualGreeter
{
    public function __construct(
      #[English] private readonly Message $englishGreeting,
      #[Spanish] private readonly Message $spanishGreeting
    ) {}
}
```

バインディングアノテーションを持つ `Key` は、次のように作成することができます。

```php
$englishGreetingKey = $map[Message::class . English::class];
$spanishGreetingKey = $map[Message::class . Spanish::class];
```

アプリケーションが `$injector->getInstance(MultilingualGreeter::class)` を呼び出したとき、
`MultilingualGreeter`のインスタンスを生成しますが、以下と同じ事を行っています。

```php
// Ray.Diは内部でこれを行うので、手動でこれらの依存関係を解決する必要はありません。
$english = $injector->getInstance(Message::class, English::class));
$spanish = $injector->getInstance(Message::class, Spanish::class));
$greeter = new MultilingualGreeter($english, $spanish);
```

つまり**Ray.Diの `Key` はPHPの型と依存関係を識別するためのアトリビュート（オプション）を合わせたものです**。

### Ray.Diプロバイダ

Ray.Diでは依存関係を満たすオブジェクトを生成するファクトリーのために、"Ray.Diマップ"で[`ProviderInterface`](https://github.com/ray-di/Ray.Di/blob/2.x/src/di/ProviderInterface.php)を使用します。

`Provider` は単一のメソッドを持つインターフェースです。

```php
interface ProviderInterface
{
  /** インスタンスを用意する */
  public function get();
}
```

`ProviderInterface` を実装している各クラスは、 インスタンスを生成する方法を知っている簡単なコードです。`new`を呼び出したり、他の方法で依存を構築したり、キャッシュから事前に計算されたインスタンスを返したりすることができます。値の型は限定されずmixedです。

以下は 2 つの `ProviderInterface` の実装例です。

```php
class countProvicer implements ProviderInterface
{
    public function get(): int
    {
        return 3;
    }
}

class messageProvider implements ProviderInterface
{
    public function get(): string
    {
        return 'hello world';
    }
}

class DemoModule extends AbstractModule
{
   protected function configure(): void
   {
       $this->bind()->annotatedWith(Count::class)->toProvider(CountProvicer::class);
       $this->bind()->annotatedWith(Message::class)->toProvider(MessageProvicer::class);
   }
}
```

*   `MessageProvicer::get()`メソッドが呼び出され 'hello world’を返します。
*   `CountProvicer::get()` メソッドが呼び出され3を返します。

## Ray.Diの使用

Ray.Diの利用には2つのパートがあります。

1.  **コンフィギュレーション**：アプリケーションが"Ray.Diマップ"に何か追加します。
1.  **インジェクション**：アプリケーションがRay.Diにマップからのオブジェクトの作成と取得を依頼します。

以下に説明します。

### コンフィギュレーション

Ray.Diのマップは、Ray.Diモジュールを使って設定されます。**Ray.Diモジュール**は、Ray.Diマップに何かを追加する設定ロジックユニットです。Ray.Di ドメイン固有言語（DSL）を使用して設定を行います。

これらのAPIは単にRay.Dマップを操作する方法を提供するものです。これらのAPIが行う操作は簡単で、以下は簡潔なPHPのシンタックスを使用した説明です。

| Ray.Di DSL シンタックス                   | メンタルモデル                                                                       |
| ---------------------------------- | ---------------------------------------------------------------------------------- |
| `bind($key)->toInstance($value)`  | `$map[$key] = $value;`  <br>(インスタンス束縛)          |
| `bind($key)->toProvider($provider)` | `$map[$key] = fn => $value;` <br>(プロバイダ束縛) |
| `bind(key)->to(anotherKey)`       | `$map[$key] = $map[$anotherKey];` <br>(リンク束縛) |

`DemoModule` は Ray.Di マップに2つのエントリーを追加します。

*   `#[Message] string` --> `(new MessageProvicer())->get()`
*   `#[Count] int` --> `(new CountProvider())->get()`

### インジェクション

マップから物事を **プル** するのではなく、それらが必要であることを **宣言** します。これが依存性注入の本質です。何かが必要なとき、どこかからそれを取りに行ったり、クラスから何かを返してもらったりすることはありません。その代わりにあなたは単にそれなしでは仕事ができないと宣言し、必要とするものを与えるのがRay.Diの役割です。

このモデルは、多くの人がコードについて考える方法とは逆で、「命令的」ではなく「宣言的」なモデルと言えます。依存性注入がしばしば一種の**[制御の反転](https://ja.wikipedia.org/wiki/制御の反転)** (IoC)と表されるのはこのためです。

何かを必要とすることを宣言するにはいくつか方法があります。

1. コンストラクタの引数:

    ```php
    class Foo
    {
      // どこからかデータベースが必要
      public function __construct(
            private Database $database
       ) {}
    }
    ```

2. `Provider`コンストラクタの引数

    ```php
    class DatabaseProvider implements ProviderInterface
    {
        public function __construct(
            #[Dsn] private string $dsn
        ){}
      
        public function get(): Database
        {
            return new Database($this->dsn);
        }
    }
    ```

この例は、[はじめに](getting_started.html)のサンプルFooクラスと同じです。

注：Ray.Di は Guice とは異なり、コンストラクタに _Inject_は必要はありません。

## 依存関係がグラフを形成

それ自体に依存性があるものを注入する場合、Ray.Diは再帰的に依存関係を注入します。上記のように `Foo` のインスタンスをインジェクトするために、Ray.Di は以下のような `ProviderInterface` の実装を作成する考えることができます。

```php
class FooProvider implements ProviderInterface
{
    public function get(): Foo
    {
        global $map;
        
        $databaseProvider = $map[Database::class]);
        $database = $databaseProvider->get();
        
        return new Foo($database);
    }
}

class DatabaseProvider implements Provider
{
    public function get(): Database
    {
        global $map;
        
        $dsnProvider = $map[Dsn::class];
        $dsn = $dsnProvider->get();
        
        return new Database($dsn);
    }
}  

class DsnProvider implements Provider
{
    public function get(): string
    {
        return getenv(DB_DSN);
    }
}  
```

依存関係は **有向グラフ[^direct-graph]** を形成し、インジェクションは、必要なオブジェクトからそのすべての依存関係を介してグラフの[深さ優先探索](https://ja.wikipedia.org/wiki/深さ優先探索)を実行することによって動作します。

[^direct-graph]: 頂点と向きを持つ辺（矢印）により構成された[グラフ](https://ja.wikibooks.org/wiki/グラフ理論)です。

Ray.Di の `Injector` オブジェクトは、依存関係グラフ全体を表します。`インジェクター`を作成するために、Ray.Diはグラフ全体が動作することを検証する必要があります。依存関係が必要なのに提供されていない「ぶら下がり」ノードがあってはいけません[^3] もしグラフのどこかで束縛が不完全だと、Ray.Di は `Unbound` 例外を投げます。

[^3]: その逆もまた然りで、何も使わなくても、何かを提供することは問題ありません。とはいえ、デッドコードと同じように、どこからも使われなくなったプロバイダーは削除するのが一番です。

## 次に

Ray.Di が作成したオブジェクトのライフサイクルを管理するための [Scopes](scopes.html) の使い方と、さまざまな[Ray.Di マップにエントリを追加](bindings.html)する方法について学びましょう。

---

