---
layout: docs-ja
title: インジェクション
category: Manual
permalink: /manuals/1.0/ja/injections.html
---
# インジェクション
_Ray.Diはどのようにオブジェクトを初期化するか？_

依存性注入パターンは、依存性の解決から振る舞いを分離します。
このパターンでは、依存を直接調べたり、ファクトリーから調べたりするよりも、むしろ、
依存関係を渡すことを推奨しています。
オブジェクトに依存をセットするプロセスを *インジェクション* と呼びます。

## コンストラクターインジェクション


コンストラクターインジェクションは、インスタンス生成と注入を組み合わせたものです。このコンストラクターは、クラスの依存をパラメータとして受け取る必要があります。ほとんどのコンストラクターは、パラメータをプロパティに代入します。コンストラクターに `#[Inject]` 属性は必要ありません。

```php
public function __construct(DbInterface $db)
{
    $this->db = $db;
}
```

## セッターインジェクション

Ray.Diは `#[Inject]` 属性を持つメソッドをインジェクトすることができます。依存関係はパラメータの形で表され、インジェクターはメソッドを呼び出す前にそれを解決します。注入されるメソッドは任意の数のパラメータを持つことができ、メソッド名は注入に影響を与えません。

```php
use Ray\Di\Di\Inject;
```

```php
#[Inject]
public function setDb(DbInterface $db)
{
    $this->db = $db;
}
```

## プロパティインジェクション

Ray.Diはプロパティインジェクションをサポートしていません。

## アシストインジェクション

メソッドコールインジェクション、アクションインジェクション、インボケーションインジェクションとも呼ばれます。この場合、引数リストの最後に依存関係を追加し、パラメータに `#[Assisted]` を追加してください。そのパラメータには、デフォルトで `null` が必要です。

_この Assisted Injection は、Google Guice のものとは異なることに注意してください。_
```php
use Ray\Di\Di\Assisted;
```

```php
public function doSomething(string $id, #[Assisted] DbInterface $db = null)
{
    $this->db = $db;
}
```

また、メソッド呼び出しの際に、他の動的パラメータに依存する依存関係を指定できます。`MethodInvocationProvider` は [MethodInvocation](https://github.com/ray-di/Ray.Aop/blob/2.x/src/MethodInvocation.php) オブジェクトを提供します。

```php
class HorizontalScaleDbProvider implements ProviderInterface
{
    public function __construct(
        private readonly MethodInvocationProvider $invocationProvider
    ) {}

    public function get()
    {
        $methodInvocation = $this->invocationProvider->get();
        [$id] = $methodInvocation->getArguments()->getArrayCopy();
        
        return UserDb::withId($id); // $id for database choice.
    }
}
```

このAOPで行うインジェクションは強力で、上記のようにメソッド実行時にしか確定しないオブジェクトをインジェクションするのに便利です。しかし、このインジェクションは本来のIOCの範囲外であり、本当に必要なときだけ使うべきです。

## オプションのインジェクション

依存関係が存在する場合はそれを使用し、存在しない場合はデフォルトにフォールバックするのが便利な場合があります。セッターインジェクションはオプションで、依存関係が利用できないとき、Ray.Diはそれらを黙って無視するようになります。
オプションインジェクションを使用するには、 `#[Inject(optional: true)]`属性を加えます。

```php
class PayPalCreditCardProcessor implements CreditCardProcessorInterface
{
    private const SANDBOX_API_KEY = "development-use-only";
    private string $apiKey = self::SANDBOX_API_KEY;
    
    #[Inject(optional: true)]
    public function setApiKey(#[Named('paypal-apikey')] string $apiKey): void
    {
       $this->apiKey = $apiKey;
    }
}
```
