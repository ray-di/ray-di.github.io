---
layout: docs-ja
title: バインディング
category: Manual
permalink: /manuals/1.0/ja/bindings.html
---
# Bindings
_Ray.Diにおけるバインディングの概要_

**バインディング**とは、[Ray.Di map](mental_model.html) のエントリに対応するオブジェクトのことです。バインディングを作成することで、Ray.Diマップに新しいエントリーを追加します。

## バインディングの作成

バインディングを作成するには、`AbstractModule` を継承して、その `configure` メソッドをオーバーライドします。メソッド本体では、`bind()` を呼び出して各バインディングを指定します。これらのメソッドはコンパイル時に型チェックを行い、間違った型を使用した場合はエラーを報告します。モジュールを作成したら、それを `Injector` に引数として渡して、インジェクタを構築します。

モジュールを使って、[リンクバインディング](linked_bindings.html)、 [インスタンスバインディング](instance_bindings.html)、 [プロバイダバインディング](provider_bindings.html)、 [コンストラクタバインディング](constructor_bindings.html)、 [ターゲット外バインディング](untargetted_bindings.html)を作成してください。

```php
class TweetModule extends AbstractModule
{
    protected function configure()
    {
        $this->bind(TweetClient::class);
        $this->bind(TweeterInterface::class)->to(SmsTweeter::class)->in(Scope::SINGLETON);
        $this->bind(UrlShortenerInterface)->toProvider(TinyUrlShortener::class)
        $this->bind('')->annotatedWith(Username::class)->toInstance("koriym")
    }
}
```

## その他のバインディング

指定したバインディングの他に、インジェクターは [ビルトインバインディング] (BuiltinBindings.md) を含んでいます。依存関係が要求されたが見つからない場合、ジャストインタイムバインディングを作成しようとします。また、インジェクタは他のバインディングの [プロバイダ](injecting_providers.html) のバインディングも含んでいます。

## モジュールのインストール

モジュールは、他のモジュールをインストールすることで、より多くのバインディングを設定することができます。

* 同じバインディングが後から作られたとしても、先に作られたバインディングが優先されます。
* そのモジュールの `override` バインディングが優先されます。

```php
protected function configure()
{
    $this->install(new OtherModule);
    $this->override(new CustomiseModule);
}
```
