---
layout: docs-ja
title: チュートリアル1
category: Manual
permalink: /manuals/1.0/ja/tutorial1.html
---
# Ray.Di チュートリアル1

このチュートリアルでは、DIパターンの基礎やRay.Diのプロジェクトの始め方を学びます。
DIを使わないコードから手動のDIコードに変更し、次にRay.Diを使ったコードにして機能追加をします。

## 準備

チュートリアルのためのプロジェクトを作成します。

```
mkdir ray-tutorial
cd ray-tutorial
composer self-update
composer init --name=ray/tutorial --require=ray/di:^2 --autoload=src -n
composer update
```

`src/Greeter.php`を作成します。
`$users`に次々に挨拶するプログラムです。

```php
<?php
namespace Ray\Tutorial;

class Greeter
{
    public function sayHello(): void
    {
        $users = ['DI', 'AOP', 'REST'];
        foreach ($users as $user) {
            echo 'Hello ' . $user . '!' . PHP_EOL;
        }
    }
}
```

実行するためのスクリプトを`bin/run.php`に用意します。

```php
<?php
use Ray\Tutorial\Greeter;

require dirname(__DIR__) . '/vendor/autoload.php';

(new Greeter)->sayHello();
```

実行してみましょう。

```php
php bin/run.php

Hello DI!
Hello AOP!
Hello REST!
```

## ディペンデンシー・プル

`$users`を可変にする事を考えましょう。

例えば、グローバル変数？

```diff
-       $users = ['DI', 'AOP', 'REST'];
+       $users = $GLOBALS['users'];
```

ワイルドですね。 他の方法も考えてみましょう。

```php
define(USERS, ['DI', 'AOP', 'REST']);

$users = USERS;
```
```php
class User
{
    public const $names = ['DI', 'AOP', 'REST'];
};

$users = User::$names;
```

```php
$users = Config::get('users')
```

クラス定数を使っても、コンフィグクラスを使ってもスコープは`$GLOBALS`と同じです。コードのどこからでもアクセス可能な外部の依存を取得(dependency pull)していて、結局はグローバルな存在です。オブジェクト間の結合を密にし、テストを困難にします。

## ディペンデンシー・インジェクション

コードの外側から依存を注入(dependency injection)するのがDIパターンです。

```diff
class Greeter
{ 
+   public function __construct(
+       private readonly Users $users
+   ) {}
    public function sayHello(): void
    {
-       $users = ['DI', 'AOP', 'REST'];
-       foreach ($users as $user) {
+       foreach ($this->users as $user) {
            echo 'Hello ' . $user . '!' . PHP_EOL;
        }
    }
}
```

必要なデータだけでなく、出力も独立したサービスにして注入しましょう。

```diff
    public function __construct(
-       private readonly Users $users
+       private readonly Users $users,
+       private readonly PrinterInterface $printer
    ) {}

    public function sayHello()
    {
        foreach ($this->users as $user) {
-            echo 'Hello ' . $user . '!' . PHP_EOL;
+            ($this->printer)($user);
        }
    }
```

以下のクラスを用意します。

`src/Users.php`

```php
<?php
namespace Ray\Tutorial;

use ArrayObject;

final class Users extends ArrayObject
{
}
```

`src/PrinterInterface.php`

```php
<?php
namespace Ray\Tutorial;

interface PrinterInterface
{
    public function __invoke(string $user): void;
}
```

`src/Printer.php`

```php
<?php
namespace Ray\Tutorial;

class Printer implements PrinterInterface
{
    public function __invoke(string $user): void
    {
        echo 'Hello ' . $user . '!' . PHP_EOL;
    }
}
```

`src/GreeterInterface.php`

```php
<?php
namespace Ray\Tutorial;

interface GreeterInterface
{
    public function sayHello(): void;
}
```

`src/CleanGreeter.php`

```php
<?php
namespace Ray\Tutorial;

class CleanGreeter implements GreeterInterface
{
    public function __construct(
        private readonly Users $users,
        private readonly PrinterInterface $printer
    ) {}

    public function sayHello(): void
    {
        foreach ($this->users as $user) {
            ($this->printer)($user);
        }
    }
}
```

## 手動DI

これを実行するスクリプト`bin/run_di.php`を作成して実行しましょう。

```php
<?php

use Ray\Tutorial\CleanGreeter;
use Ray\Tutorial\Printer;
use Ray\Tutorial\Users;

require dirname(__DIR__) . '/vendor/autoload.php';

$greeter = new CleanGreeter(
    new Users(['DI', 'AOP', 'REST']),
    new Printer
);

$greeter->sayHello();
```

ファイル数が増え全体としては複雑になっているように見えますが、個々のスクリプトはこれ以上単純にするのが難しいぐらい単純です。それぞれのクラスはただ１つの責務しか担っていませんし[^srp]、実装ではなく抽象に依存して[^dip]、テストや拡張、それに再利用も容易です。

[^srp]: [単一責任原則 (SRP)](https://ja.wikipedia.org/wiki/SOLID)
[^dip]: [依存性逆転の原則 (DIP)](https://ja.wikipedia.org/wiki/%E4%BE%9D%E5%AD%98%E6%80%A7%E9%80%86%E8%BB%A2%E3%81%AE%E5%8E%9F%E5%89%87)

`bin/`以下のコードが**コンパイルタイム**で依存関係を構成し、`src/`以下のコードは**ランタイムタイム**で実行されます。PHPはスクリプト言語ですが、このようにコンパイルタイムとランタイムタイムの区別を考えることができます。

DIのコードは依存を外部から渡して、コンストラクタで受け取ります。

`$object = new A(new B, new C(new D(new E, new F, new G)))`

上記の例だとAを生成するに必要なのものはA自身は取得しないで、コンストラクタにBとCが渡されて（注入されて）います。Cを生成するにはDが、Dを生成するにはE,F,Gが..と依存は他の依存を必要とし、オブジェクトが依存オブジェクトを含むオブジェクトグラフ[^og]が生成されます。

プロジェクトが規模を伴うようになると、このようなファクトリーコードを使った手動のDIは、深いネストの依存解決、シングルトンなどインスタンス管理、再利用性、メンテナンス性などの問題が現実化してきます。その依存解決の問題を解決するのがRay.Diです。

### モジュール

モジュールは束縛の集合です。束縛にはいくつか種類がありますが、ここでは最も基本のインターフェイスにクラスを束縛する[リンク束縛](https://ray-di.github.io/manuals/1.0/ja/linked_bindings.html) 、バリューオブジェクトなど実態への束縛を行う[インスタンス束縛](https://ray-di.github.io/manuals/1.0/ja/instance_bindings.html)を行います。

`src/AppModule.php`を用意します。

```php
<?php
namespace Ray\Tutorial;

use Ray\Di\AbstractModule;

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(Users::class)->toInstance(new Users(['DI', 'AOP', 'REST']));
        $this->bind(PrinterInterface::class)->to(Printer::class);
        $this->bind(GreeterInterface::class)->to(CleanGreeter::class);
    }
}
```

実行する`bin/run_di.php`を作成して、実行します。

```php
<?php

use Ray\Di\Injector;
use Ray\Tutorial\AppModule;
use Ray\Tutorial\GreeterInterface;

require dirname(__DIR__) . '/vendor/autoload.php';

$module = new AppModule();
$injector = new Injector($module);
$greeter = $injector->getInstance(GreeterInterface::class);
$greeter->sayHello();
```

うまくいきましたか？ おかしい時は[tutorial1](https://github.com/ray-di/tutorial1/tree/master/src)と見比べてみてください。

## 依存の置き換え

ユニットテストの時だけ、開発時だけ、など実行コンテキストによって束縛を変更したい時があります。

例えばテストの時だけの束縛`src/TestModule.php`があったとします。

```php
<?php

namespace Ray\Tutorial;

use Ray\Di\AbstractModule;

final class TestModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(Users::class)->toInstance(new Users(['TEST1', 'TEST2']));
    }
}
```

この束縛を上書きするために`bin/run_di.php`スクリプトを変更します。

```diff
use Ray\Tutorial\AppModule;
+use Ray\Tutorial\TestModule;
use Ray\Tutorial\GreeterInterface;

require dirname(__DIR__) . '/vendor/autoload.php';

$module = new AppModule();
+$module->override(new TestModule());
```

実行してみましょう。

```
Hello TEST1!
Hello TEST2!
```

## 依存の依存

次に今`Printer`で固定している挨拶のメッセージも多国語対応するために注入するように変更します。


`src/IntlPrinter.php`を作成します。

```php
<?php
namespace Ray\Tutorial;

use Ray\Di\Di\Named;

class IntlPrinter implements PrinterInterface
{
    public function __construct(
        #[Message] private string $message
    ){}

    public function __invoke(string $user): void
    {
        printf($this->message, $user);
    }
}
```

コンストラクタは挨拶のメッセージ文字列を受け取りますが、この束縛を特定するために[アトリビュート束縛](https://ray-di.github.io/manuals/1.0/ja/binding_attributes.html)のための`#[Message]`アトリビュート、`src/Message.php`を作成します。

```php
<?php
namespace Ray\Tutorial;

use Attribute;
use Ray\Di\Di\Qualifier;

#[Attribute, Qualifier]
class Message
{
}
```

束縛を変更。

```diff
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(Users::class)->toInstance(new Users(['DI', 'AOP', 'REST']));
-       $this->bind(PrinterInterface::class)->to(Printer::class);
+       $this->bind(PrinterInterface::class)->to(IntlPrinter::class);
+       $this->bind()->annotatedWith(Message::class)->toInstance('Hello %s!' . PHP_EOL);
        $this->bind(GreeterInterface::class)->to(CleanGreeter::class);
    }
}
```

実行して変わらない事を確認しましょう。

次にエラーを試してみましょう。`configure()`メソッドの中の`Message::class`の束縛をコメントアウトしてください。

```diff
-        $this->bind()->annotatedWith(Message::class)->toInstance('Hello %s!' . PHP_EOL);
+        // $this->bind()->annotatedWith(Message::class)->toInstance('Hello %s!' . PHP_EOL);
```

これではRay.Diは`#[Message]`とアトリビュートされた依存に何を注入すれば良いかわかりません。

実行すると以下のようなエラーが出力されます。

```
PHP Fatal error:  Uncaught exception 'Ray\Di\Exception\Unbound' with message '-Ray\Tutorial\Message'
- dependency '' with name 'Ray\Tutorial\Message' used in /tmp/tutorial/src/IntlPrinter.php:8 ($message)
- dependency 'Ray\Tutorial\PrinterInterface' with name '' /tmp/tutorial/src/CleanGreeter.php:6 ($printer)
```

これは`IntlPrinter.php:8`の`$message`が依存解決できないので、それに依存する`CleanGreeter.php:6`の`$printer`も依存解決できなくて注入が失敗しましたというエラーです。このように依存の依存が解決できない時はその依存のネストも表示されます。

最後に、以下のような束縛を`src/SpanishModule.php`として作成してTestModuleと同じように上書きしてみましょう。

```php
<?php
namespace Ray\Tutorial;

use Ray\Di\AbstractModule;

class SpanishModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind()->annotatedWith(Message::class)->toInstance('¡Hola %s!' . PHP_EOL);
    }
}
```

```diff
use Ray\Tutorial\AppModule;
-use Ray\Tutorial\TestModule;
+use Ray\Tutorial\SpanishModule;
use Ray\Tutorial\GreeterInterface;

require dirname(__DIR__) . '/vendor/autoload.php';

$module = new AppModule();
-$module->override(new TestModule());
+$module->override(new SpanishModule());
```

以下のようにスペイン語の挨拶に変わりましたか？

```
¡Hola DI!
¡Hola AOP!
¡Hola REST!
```

## まとめ

ここまでが、DIパターンとRay.Diの基本です。

オブジェクト指向のアプリケーションは相互に関係のある複雑なオブジェクトグラフ[^og]を持ちます。依存はユーザーコードが外からpullするのではなくRay.Diによって注入されることで、オブジェクトグラフが生成されます。DIパターンに従う事で、SRP原則[^srp]やDIP原則[^dip]を守る事も自然になりました。

[^og]: "コンピュータサイエンスにおいて、オブジェクト指向のアプリケーションは相互に関係のある複雑なオブジェクト網を持ちます。オブジェクトはあるオブジェクトから所有されているか、他のオブジェクト（またはそのリファレンス）を含んでいるか、そのどちらかでお互いに接続されています。このオブジェクト網をオブジェクトグラフと呼びます。" [Object Graph](https://en.wikipedia.org/wiki/Object_graph)

コンパイルタイムでオブジェクトの構成や依存の束縛は完了していて、ランタイムではインターフェイスに依存したコードが実行されます。 ランタイムで依存を確保する責務が無くなることで、変更に対しても柔軟になりテストも容易になりました。コードは安定していて、拡張に対しては開いていても修正に対しては閉じています。[^ocp]

[^ocp]: [開放/閉鎖原則 (OCP)](https://ja.wikipedia.org/wiki/%E9%96%8B%E6%94%BE/%E9%96%89%E9%8E%96%E5%8E%9F%E5%89%87)

---
