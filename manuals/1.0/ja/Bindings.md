---
layout: docs-ja
title: 束縛
category: Manual
permalink: /manuals/1.0/ja/bindings.html
---
# Bindings
_Ray.Diにおける束縛の概要_

**束縛**とは、[Ray.Di map](mental_model.html) のエントリに対応するオブジェクトのことです。束縛を作成することで、Ray.Diマップに新しいエントリーを追加します。

## 束縛の作成

束縛を作成するには、`AbstractModule` を継承して、その `configure` メソッドをオーバーライドします。メソッド本体では、`bind()` を呼び出して各束縛を指定します。これらのメソッドはコンパイル時に型チェックを行い、間違った型を使用した場合はエラーを報告します。モジュールを作成したら、それを `Injector` に引数として渡して、インジェクタを構築します。

モジュールを使って、[リンク束縛](linked_bindings.html)、 [インスタンス束縛](instance_bindings.html)、 [プロバイダ束縛](provider_bindings.html)、 [コンストラクタ束縛](constructor_bindings.html)、 [ターゲット外束縛](untargeted_bindings.html)を作成してください。

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

## その他の束縛

指定した束縛の他に、インジェクターは [ビルトイン束縛](BuiltinBindings.md) を含んでいます。依存関係が要求されたが見つからない場合、ジャストインタイム束縛を作成しようとします。また、インジェクタは他の束縛の [プロバイダ](injecting_providers.html) の束縛も含んでいます。

## モジュールのインストール

モジュールは、他のモジュールをインストールすることで、より多くの束縛を設定することができます。

* 同じ束縛が後から作られたとしても、先に作られた束縛が優先されます。
* そのモジュールの `override` 束縛が優先されます。

```php
protected function configure()
{
    $this->install(new OtherModule);
    $this->override(new CustomiseModule);
}
```
