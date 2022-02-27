---
layout: docs-ja
title: AOP
category: Manual
permalink: /manuals/1.0/ja/aop.html
---
# アスペクト指向プログラミング

依存性の注入を補完するために、Ray.Diはメソッドインターセプションをサポートしています。この機能により、一致するメソッドが呼び出されるたびに実行されるコードを書くことができます。これは、トランザクション、セキュリティ、ロギングなど、横断的な関心事（アスペクト）に適しています。インターセプターは問題をオブジェクトではなくアスペクトに分割するため、その使用はアスペクト指向プログラミング（AOP）と呼ばれています。

[Matcher](https://github.com/ray-di/Ray.Aop/blob/2.x/src/MatcherInterface.php)は、値を受け入れるか拒否するかの簡単なインタフェースです。Ray.Di AOPでは、2つのマッチャーが必要です。1つはどのクラスが適用されるかを定義し、もう1つはそれらのクラスのメソッドのために定義します。

[MethodInterceptors](https://github.com/ray-di/Ray.Aop/blob/2.x/src/MethodInterceptor.php)は、一致するメソッドが呼び出されるたびに実行されます。このインターセプターは
メソッド、その引数、および受信側のインスタンスなど、呼び出しを検査します。横断的なロジックを実行し、次にベースとなるメソッドに委譲することができます。最後に、戻り値または例外を調べて戻ることができます。インターセプターは多くのメソッドに適用され、多くの呼び出しがあるので、その実装は効率的で邪魔にならないものであるべきです。

## 例 週末にメソッド呼び出しを禁止する

Ray.Diでメソッドインターセプターがどのように機能するかを説明するために、週末にピザの請求システムを呼び出すことを禁止してみましょう。配達員は月曜から金曜までしか働かないので、配達できない時にピザが注文されるのを防ごうと思います この例は、AOPを使った権限付与と構造的に似ています。

選択したメソッドを平日限定とするために、属性を定義しています。

```php
#[Attribute(Attribute::TARGET_METHOD)]
final class NotOnWeekends
{
}
```

...そして、それを傍受する必要のあるメソッドに適用します。

```php
class BillingService implements BillingServiceInterface
{
    #[NotOnWeekends]
    public function chargeOrder(PizzaOrder $order, CreditCard $creditCard)
    {
```

次に、`MethodInterceptor` インターフェースを実装し、インターセプターを定義します。メソッドを呼び出す必要がある場合は、 `$invocation->proceed()` を呼び出して行います。

```php

use Ray\Aop\MethodInterceptor;
use Ray\Aop\MethodInvocation;

class WeekendBlocker implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation)
    {
        $today = getdate();
        if ($today['weekday'][0] === 'S') {
            throw new \RuntimeException(
                $invocation->getMethod()->getName() . " not allowed on weekends!"
            );
        }
        return $invocation->proceed();
    }
}
```

最後に、すべての設定を行います。この場合、どのクラスにもマッチしますが、`#[NotOnWeekends]` 属性を持つメソッドにのみマッチします。

```php

use Ray\Di\AbstractModule;

class WeekendModule extends AbstractModule
{
    protected function configure()
    {
        $this->bind(BillingServiceInterface::class)->to(BillingService::class);
        $this->bindInterceptor(
            $this->matcher->any(),                           // any class
            $this->matcher->annotatedWith('NotOnWeekends'),  // #[NotOnWeekends] attributed method
            [WeekendBlocker::class]                          // apply WeekendBlocker interceptor
        );
    }
}

$injector = new Injector(new WeekendModule);
$billing = $injector->getInstance(BillingServiceInterface::class);
try {
    echo $billing->chargeOrder();
} catch (\RuntimeException $e) {
    echo $e->getMessage() . "\n";
    exit(1);
}
```
それをすべてまとめると、（土曜日まで待つとして）メソッドがインターセプトされ、注文が拒否されたことがわかります。

```php
RuntimeException: chargeOrder not allowed on weekends! in /apps/pizza/WeekendBlocker.php on line 14

Call Stack:
    0.0022     228296   1. {main}() /apps/pizza/main.php:0
    0.0054     317424   2. Ray\Aop\Weaver->chargeOrder() /apps/pizza/main.php:14
    0.0054     317608   3. Ray\Aop\Weaver->__call() /libs/Ray.Aop/src/Weaver.php:14
    0.0055     318384   4. Ray\Aop\ReflectiveMethodInvocation->proceed() /libs/Ray.Aop/src/Weaver.php:68
    0.0056     318784   5. Ray\Aop\Sample\WeekendBlocker->invoke() /libs/Ray.Aop/src/ReflectiveMethodInvocation.php:65
```

## インターセプターの無効化

インターセプターを無効にするには、NullInterceptorを束縛します。

```php
use Ray\Aop\NullInterceptor;

protected function configure()
{
    // ...
    $this->bind(LoggerInterface::class)->to(NullInterceptor::class);
}
```

## 制限事項

背後では、実行前にPHPコードを生成してメソッドインターセプションを実装しています。Ray.Diは、メソッドをオーバーライドすることでインターセプターを適用するサブクラスを動的に作成します。

このアプローチでは、インターセプト可能なクラスとメソッドに制限が生まれます。

* クラスは`final`でないこと
* メソッドは`public`または`protected`でなければならない
* メソッドは`final`でないこと
* インスタンスは、Ray.Di.によって作成される必要があります。

## AOPアライアンス

Ray.Diが実装しているメソッドインターセプターのAPIは、Javaの[AOP Alliance](http://aopalliance.sourceforge.net/)と呼ばれるAPI仕様とほぼ同じです。
