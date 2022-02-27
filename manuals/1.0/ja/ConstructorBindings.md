---
layout: docs-ja
title: Constructor Bindings
category: Manual
permalink: /manuals/1.0/ja/constructor_bindings.html
---

## コンストラクタ束縛

時には対象のコンストラクタやセッターメソッドがサードパーティ製であるため`#[Inject]`アトリビュートが適用できない場合や、あるいは単にアトリビュートを使いたくない場合があります。

コンストラクタ束縛はこの問題を解決します。つまり、対象となるコンストラクタをユーザー側で明示的に呼び出すことで、リフレクションやそれに関する面倒を考える必要がなくなります。

これに対処するため、Ray.Diには`toConstructor`束縛があります。

```php
$this->bind($interfaceName)
    ->toConstructor(
        $className,
        $name,
        $injectionPoint,
        $postConstruct
    );

(new InjectionPoints) // InjectionPoints $setter_injection
    ->addMethod('setGuzzle', 'token')
    ->addOptionalMethod('setOptionalToken', 'initialize'); // string $postCostruct
$this->bind()->annotated('user_id')->toInstance($_ENV['user_id']);
$this->bind()->annotated('user_password')->toInstance($_ENV['user_password']);

```

### Parameter

**class_name**

クラス名

**name**

パラメーター名束縛

引数に識別子を追加する場合は、キーを変数名、値を識別子とする配列を指定します。

```php
[
	[$param_name1 => $binding_name1],
	...
]
```

以下のストリングフォーマットもサポートされています。
`'param_name1=binding_name1&...'`

**setter_injection**

`InjectionPoints`オブジェクトでセッターインジェクションのメソッド名($methodName)と識別子($named)を指定します。

```php
(new InjectionPoints)
	->addMethod($methodName1)
	->addMethod($methodName2, $named)
  ->addOptionalMethod($methodName, $named);
```

**postCosntruct**

コンストラクタとセッターメソッドが呼び出され、すべての依存関係が注入された後に`$postCosntruct`メソッドが呼び出されます

### PDO Example

[PDO](http://php.net/manual/ja/pdo.construct.php)クラスの束縛の例です。

```php
public PDO::__construct(
    string $dsn,
    ?string $username = null,
    ?string $password = null,
    ?array $options = null
)
```

```php
$this->bind(\PDO::class)->toConstructor(
    \PDO::class,
    [
        'dsn' => 'pdo_dsn',
        'username' => 'pdo_username',
        'password' => 'pdo_password'
    ]
)->in(Scope::SINGLETON);

$this->bind()->annotatedWith('pdo_dsn')->toInstance($dsn);
$this->bind()->annotatedWith('pdo_username')->toInstance(getenv('db_user'));
$this->bind()->annotatedWith('pdo_password')->toInstance(getenv('db_password'));
```

PDOのコンストラクタ引数は`$dsn`, `$username`などstringの値を受け取り、その束縛を区別するために識別子が必要です。しかしPDOはPHP自体のビルトインクラスなのでアトリビュートを加えることができません。

`toConstructor()`の第2引数の`$name`で識別子を指定します。
