---
layout: docs-ja
title: 束縛
category: Manual
permalink: /manuals/1.0/ja/bindings.html
---
# 束縛
_Ray.Diにおける束縛の概要_

**束縛**とは、[Ray.Di map](mental_model.html) のエントリに対応するオブジェクトのことです。束縛を作成することで、Ray.Diマップに新しいエントリーを追加できます。

## 束縛の作成

束縛を作成するには、`AbstractModule` を継承して `configure` メソッドをオーバーライドします。メソッド本体では、`bind()` を呼び出してそれぞれの束縛を指定します。これらのメソッドはコンパイル時に型チェックを行い、間違った型を使用した場合はエラーを報告します。モジュールを作成したら、それを `Injector` に引数として渡し、インジェクターを構築します。

モジュールを使って、[リンク束縛](linked_bindings.html)、 [インスタンス束縛](instance_bindings.html)、 [プロバイダー束縛](provider_bindings.html)、 [コンストラクター束縛](constructor_bindings.html)、 [アンターゲット束縛](untargeted_bindings.html)を作成しましょう。

```php
class TweetModule extends AbstractModule
{
    protected function configure()
    {
        $this->bind(TweetClient::class);
        $this->bind(TweeterInterface::class)->to(SmsTweeter::class)->in(Scope::SINGLETON);
        $this->bind(UrlShortenerInterface::class)->toProvider(TinyUrlShortener::class);
        $this->bind()->annotatedWith(Username::class)->toInstance("koriym");
    }
}
```

## その他の束縛

インジェクターは指定した束縛の他に [ビルトイン束縛](builtin_bindings.html) と [プロバイダー注入](injecting_providers.html) の束縛も含みます。

## モジュールのインストール

モジュールは、他のモジュールをインストールすることで、より多くの束縛を設定できます。

* 同じ束縛が後から作られた場合、先に作られた束縛が優先されます。
* そのモジュールの `override` 束縛が優先されます。

```php
protected function configure()
{
    $this->install(new OtherModule);
    $this->override(new CustomiseModule);
}
```
