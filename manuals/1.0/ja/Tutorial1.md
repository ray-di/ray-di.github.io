---
layout: docs-ja
title: チュートリアル1
category: Manual
permalink: /manuals/1.0/ja/tutorial1.html
---
# Ray.Di チュートリアル1

## 準備

チュートリアルのためのプロジェクトを作成します。

```
mkdir ray-tutorial
cd ray-tutorial
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
    public function sayHello()
    {
        $users = ['DI', 'AOP', 'REST'];
        foreach ($users as $user) {
            echo 'Hello ' . $user . '!' . PHP_EOL;
        }
    }
}
```

実行するためのスクリプトを`bin/run_tutorial.php`に用意します。

```php
<?php

use Ray\Tutorial\Greeting;

require dirname(__DIR__) . '/vendor/autoload.php';

(new Greeter)->sayHello();
```

実行してみましょう。

```php
php bin/run_tutorial.php

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
```
```php
class Users
{
    public const $names = ['DI', 'AOP', 'REST'];
};

$users = Users:$names;
```

```php
$users = Config::get('users')
```

クラス定数を使っても、コンフィグクラスを使ってもスコープは`$GLOBALS`と同じです。コードのどこからでもアクセス可能な外部の依存を取得(dependency pull)していて、結局はグローバルな存在です。オブジェクト間の結合を密にし、テストを困難にします。

## ディペンデンシー・インジェクション

コードの外側から依存を注入(dependency injection)するのがDIパターンです。

```php
    public function __construct(
        private readonly Users $users
    ) {}

    public function sayHello()
    {
        foreach ($this->users as $user) {
            echo 'Hello ' . $user . '!' . PHP_EOL;
        }
    }
```

必要なデータだけでなく、出力も独立したサービスにして注入しましょう。

```diff
    public function __construct(
        private readonly Users $users,
+        private readonly PrinterInterface $printer
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
    public function sayHello(string $user);
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

use Ray\Tutorial\CleanGreeting;
use Ray\Tutorial\Printer;
use Ray\Tutorial\Users;

require dirname(__DIR__) . '/vendor/autoload.php';

$greeter = new CleanGreeter(
    new Users(['DI', 'AOP', 'REST']),
    new Printer
);

$greeter();
```

ファイル数が増え全体としては複雑になっているように見えますが、個々のスクリプトはこれ以上単純にするのが難しいぐらい単純です。それぞれのクラスはただ１つの責務しか担っていませんし[^srp]、実装ではなく抽象に依存して[^dip]、テストや拡張も用意です。

[^srp]: [単一責任原則](https://ja.wikipedia.org/wiki/SOLID)
[^dip]: [依存性逆転の法則](https://ja.wikipedia.org/wiki/%E4%BE%9D%E5%AD%98%E6%80%A7%E9%80%86%E8%BB%A2%E3%81%AE%E5%8E%9F%E5%89%87)

`bin`は**コンパイルタイム**で依存を構成し、`src`以下のコードは**ランタイムタイム**での実行します。PHPはスクリプト言語ですが、このようにコンパイルタイム・ランタイムタイムの区別を考えることができます。

DIのコードは基本的にこのように依存をコンストラクタで渡してオブジェクトが相互依存するオブジェクトグラフを生成します。オブジェクトは他から所有されているか、他を所有しているか、あるいは双方のいずれかです。

`$object = new A(new B, new C(new D(new E, new F, new G)))`

小さなオブジェクトグラフ生成をこのように手動で行うことは問題ありません。しかし深いネストの依存解決、シングルトン管理、再利用性、メンテナンス性、それらの問題が現実化してきます。その問題を解決するのがRay.Diです。

### モジュール

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
use Ray\Tutorial\GreetingInterface;
use Ray\Tutorial\Users;

require dirname(__DIR__) . '/vendor/autoload.php';

$module = new AppModule();
$injector = new Injector($module);
$greeter = $injector->getInstance(GreeterInterface::class);
$greeter->sayHello();
```

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

コンストラクタは挨拶のメッセージ文字列を受け取りますが、この束縛を特定するために`#[Message]`アトリビュートを付加します。そのための`src/Message.php`も作成します。

```php
<?php
namespace Ray\Tutorial;

use Ray\Di\Di\Qualifier;

#[Attribute, Qualifier]
class Message
{
}
```

束縛を変更。

```diff
-        $this->bind(PrinterInterface::class)->to(Printer::class);
+        $this->bind(PrinterInterface::class)->to(IntlPrinter::class);
+        $this->bind()->annotatedWith(Message::class)->toInstance('Hello %s !' . PHP_EOL);
```

実行して変わらない事を確認しましょう。以下のような束縛を`SpanishModule`として作ってTestModuleと同じように上書きしてみましょう。

```php
final class SpanishModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind()->annotatedWith(Message::class)->toInstance('¡Hola %s !' . PHP_EOL);
    }
}
```

## まとめ

ここまでが、DIパターンとRay.Diの基本です。オブジェクト指向のアプリケーションは相互に関係のある複雑なオブジェクトグラフ（網）を持ちます。依存をpullするのではなく注入、その依存解決をRay.Diが行いオブジェクトグラフを生成します。

コンパイルタイムでオブジェクトの構成や依存の束縛は完了していて、ランタイムではインターフェイスに依存したコードが実行されます。

---
