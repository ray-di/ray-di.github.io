---
layout: docs-ja
title: Mental Model
category: Manual
permalink: /manuals/1.0/ja/mental_model.html
---
# Ray.Di メンタルモデル

_Key`、`Provider`について、そしてRay.Diがいかに単なる地図であるかについて学ぶ_

依存性注入（Dependency Injection）について調べていると、多くのバズワード（「制御逆転」、「ハリウッド原理」）を目にし、混乱することが多いようです。しかし、依存性注入の専門用語の下では、コンセプトはそれほど複雑ではありません。実際、あなたはすでによく似たことを書いているかもしれません。
このページでは、Ray.Diの実装の簡略化されたモデルについて説明し、それがどのように機能するかを考えやすくします。

## Ray.Diはマップ

基本的にRay.Diは、アプリケーションが使用するオブジェクトの作成と取得を支援します。アプリケーションが必要とするこれらのオブジェクトは **dependencies** と呼ばれます。

Ray.Diはマップ[^Ray.Di-map]であると考えることができます。アプリケーションのコードが必要な依存関係を宣言すると、Ray.Diはそのマップからそれらを取得します。Ray.Diマップ」の各エントリーは、2つの部分から構成されています。

*   **Ray.Di key**: マップから特定の値を取得するために使用される、マップのキー。
*   **Provider**: アプリケーションのオブジェクトを作成するために使用されるマップの値です。

Ray.Diのキーとプロバイダーについて、以下に説明します。

[^Ray.Di-map]: Ray.Diの実際の実装ははるかに複雑ですが、マップはRay.Diがどのように動作するかの合理的な近似値となっています。

### Ray.Diのキー

Ray.Diは[`Dependecy Key`]を使って、「Ray.Diマップ」を使って解決できる依存関係を特定します。

Getting Started](GettingStarted.md) で使用されている `Greeter` クラスは、コンストラクタで2つの依存関係を宣言しており、それらの依存関係は Ray.Di では `Key` として表現されています。

*   `#[Message] string` --> `(string) $map[$messageKey]`
*   `#[Count] int` --> `(int) $map[$countKey]`

最も単純な形の `Key` は、php の型を表す。

```php
// Identifies a dependency that is an instance of string.
/** @var string $databaseKey */
$databaseKey = $map[$key];
```

しかし、アプリケーションには、同じ種類の依存関係があることが多い。

```php
final class MultilingualGreeter
{
    public function __construct(
      private readonly string $englishGreeting,
      private readonly string $spanishGreeting
    ) {}
}
```

Ray.Diでは、同じタイプの依存関係を区別するために、[binding Attributes](BindingAttributes.md) を使用しています。

```php
final class MultilingualGreeter
{
    public function __construct(
      #[English] private readonly string $englishGreeting,
      #[Spanish] private readonly string $spanishGreeting
    ) {}
}
```

バインディングアノテーションを持つ `Key` は、次のように作成することができる。

```php
$englishGreetingKey = $map[English::class];
$spanishGreetingKey = $map[Spanish::class];
```

アプリケーションが `$injector->getInstance(MultilingualGreeter::class)` を呼び出したとき。
MultilingualGreeter` のインスタンスを生成する。これは、することと同じである。

```php
// Ray.Di internally does this for you so you don't have to wire up those
// dependencies manually.
/** @var string $english */
$english = $injector->getInstance('', English::class));
/** @var string $spanish */
$spanish = $injector->getInstance('', Spanish::class));
/** @var MultilingualGreeter $greeter */
$greeter = new MultilingualGreeter($english, $spanish);
```

要約すると、以下のようになります。**Ray.Di `Key` は、依存関係を識別するために使用されるオプションのバインディングアノテーションと組み合わされたタイプです。

### Ray.Di `Provider`s

Ray.Diでは、「Ray.Diマップ」において、依存関係を満たすオブジェクトを生成できるファクトリーを表すために、[`Provider`](https://google.github.io/Ray.Di/api-docs/latest/javadoc/com/google/inject/Provider.html)を使用します。

`Provider` はメソッドを1つ持つインターフェースである。

```php
interface Provider
{
  /** Provides an instance/
  public function get();
}
```

Provider` を実装している各クラスは、 `T` のインスタンスを生成する方法を知っているちょっとしたコードです。new T()` を呼び出したり、他の方法で `T` を構築したり、キャッシュから事前に計算されたインスタンスを返したりすることができます。

ほとんどのアプリケーションは `Provider` インターフェースを直接実装しません。彼らは `Module` を使って Ray.Di インジェクタを設定し、Ray.Di インジェクタは内部で生成方法を知っている全てのオブジェクトに対して `Provider` を生成します。

例えば、以下の Ray.Di モジュールは 2 つの `Provider` を作成します。

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

*   `MessageProvicer` that calls the `get()` method and returns "hello
    world"
*   `CountProvicer` that calls the `get()` method and returns `3`

## Ray.Diの使用

Ray.Diを使うには2つのパートがあります。

1.  **コンフィギュレーション**：アプリケーションが「Ray.Diマップ」に追加するもの。
1.  1. **インジェクション**：アプリケーションがRay.Diにマップからのオブジェクトの作成と取得を依頼します。

コンフィギュレーションとインジェクションの説明は以下の通りです。

### コンフィギュレーション

Ray.Diのマップは、Ray.Diモジュールを使って設定されます。Ray.Diモジュール**は、Ray.Diマップに何かを追加する設定ロジックの単位です。これを行うには2つの方法があります。

* Ray.Di Domain Specific Language（DSL）を使用する。

概念的には、これらのAPIは単にRay.Diマップを操作する方法を提供するものです。これらのAPIが行う操作は非常に簡単です。以下は、簡潔で分かりやすくするためにJava 8のシンタックスを使用した翻訳例です。

| Ray.Di DSL syntax                   | Mental model                                                                       |
| ---------------------------------- | ---------------------------------------------------------------------------------- |
| `bind($key)->toInstance($value)`  | `$map[$key] = $value;`  <br>(instance binding)          |
| `bind($key)->toProvider($provider)` | `$map[$key] = fn => $value;` <br>(provider  binding) |
| `bind(key)->to(anotherKey)`       | `$map[$key] = $map[$anotherKey];` <br>(linked binding) |

`DemoModule` adds two entries into the Ray.Di map:

*   `#[Message] string` --> `fn() => (new MessageProvicer)->get()`
*   `#[Count] int` --> `fn() => (new CountProvicer)->get()`

### インジェクション

マップから物事を *pull* するのではなく、それらが必要であることを *declare* するのです。これが依存性注入の本質です。何かが必要なとき、どこかからそれを取りに行ったり、クラスから何かを返してもらったりすることはありません。その代わりに、あなたは単にそれなしでは仕事ができないと宣言し、あなたが必要とするものを与えるためにRay.Diに依存するのです。

このモデルは、多くの人がコードについて考える方法とは逆で、「命令的」ではなく「宣言的」なモデルなのです。依存性注入がしばしば一種の*制御の逆転* (IoC)と表現されるのは、このためです。

何かを必要とすることを宣言するいくつかの方法。

1. An argument to a constructor:

    ```php
    class Foo
    {
      // We need a database, from somewhere
      public function __construct(
            private Database $database
       ) {}
    }
    ```

2. 2. `DatabaseProvider::get()` メソッドへの引数。

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

のサンプル `Foo` クラスと意図的に同じにしています。
[Getting Started#what-is-dependency-injection) を参照してください。
Ray.Di は Guice とは異なり、コンストラクタに `Inject` 属性を追加する必要はありません。

## 依存関係はグラフを形成する

それ自体に依存性があるものを注入する場合、Ray.Diは再帰的に
は依存関係を注入します。上記のように `Foo` のインスタンスをインジェクトするために、Ray.Di は以下のような `Provider` の実装を作成すると想像できる。

```php
class FooProvider implements Provider
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

依存関係は *有向グラフ* を形成し、インジェクションは、必要なオブジェクトからそのすべての依存関係を介してグラフの深さ優先のトラバースを実行することによって動作します。

Ray.Di の `Injector` オブジェクトは、依存関係グラフ全体を表します。インジェクター`を作成するために、Ray.Diはグラフ全体が動作することを検証する必要があります。依存関係が必要なのに提供されていない「ぶら下がり」ノードがあってはいけません[^3] もしグラフのどこかで結合が不完全だと、Ray.Di は `Unbound` 例外を投げます。

[^3]: その逆のケースはエラーにはなりません。
この場合、デッドコードになります。つまり、デッドコードと同じように、誰も使わなくなったプロバイダは削除するのが一番です。

## 次はどうする？

Ray.Di が作成したオブジェクトのライフサイクルを管理するための [`Scopes`] (Scopes) の使い方と、Ray.Di マップにエントリを追加するさまざまな方法 (Bindings) について学びましょう。

