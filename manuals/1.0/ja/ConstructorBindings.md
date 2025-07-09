---
layout: docs-ja
title: コンストラクター束縛
category: Manual
permalink: /manuals/1.0/ja/constructor_bindings.html
---

## コンストラクター束縛

時には対象のコンストラクターやセッターメソッドがサードパーティ製であるため`#[Inject]`アトリビュートが適用できない場合や、あるいは単にアトリビュートを使いたくない場合があります。

コンストラクター束縛はこの問題を解決します。つまり、対象となるコンストラクターの情報をアトリビュートではなく、ユーザー側で明示的に指定することでRay.DIにオブジェクトの生成方法を伝えます。

```php
$this->bind($interfaceName)
    ->toConstructor(
        $className,       // Class name
        $name,            // Qualifier
        $injectionPoint,  // Setter injection
        $postConstruct    // Initialize method
    );

(new InjectionPoints) 
    ->addMethod('setGuzzle')                 // Setter injection method name
    ->addOptionalMethod('setOptionalToken'); // Optional setter injection method name
```

### Parameter

**class_name**

クラス名

**name**

パラメーター名束縛

引数に識別子を追加する場合は、キーを変数名、値を識別子とする配列を指定します。

```php
[
	[$paramName1 => $named1],
	[$paramName2 => $named2],
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

**postConstruct**

コンストラクターとセッターメソッドが呼び出され、すべての依存関係が注入された後に`$postConstruct`メソッドが呼び出されます

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

PDOのコンストラクター引数は`$dsn`、`$username`などstring型の値を受け取り、その束縛を区別するために識別子が必要です。しかしPDOはPHP自体のビルトインクラスなのでアトリビュートを加えることができません。

`toConstructor()`の第2引数の`$name`で識別子(qualifier)を指定します。その識別子に対してあらためて束縛を行います。
上記の例では`username`という変数に`pdo_username`という識別子を与え、`toInstance`で環境変数の値を束縛しています。
