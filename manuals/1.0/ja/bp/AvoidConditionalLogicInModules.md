---
layout: docs-ja
title: AvoidConditionalLogicInModules
category: Manual
permalink: /manuals/1.0/ja/bp/avoid_conditional_logic_in_modules.html
---
# モジュールの条件付きロジックは避ける

環境ごとに異なる動作を設定できるような動的なモジュールを作りたくなる事があります。

```php
class FooModule extends AbstractModule
{
  public function __construct(
    private readonly ?string $fooServer
  }{}

  protected function configure(): void
  {
    if ($this->fooServer != null) {
        $this->bind(String::class)->annotatedWith(ServerName::class)->toInstance($this->fooServer);
        $this->bind(FooService::class)->to(RemoteFooService::class);
    } else {
        $this->bind(FooService::class)->to(InMemoryFooService::class);
    }
  }
}
```

条件付きロジック自体はそれほど悪いものではありません。 しかし、構成が未検証の場合に問題が発生します。
この例では、`InMemoryFooService` を開発用に使用し、`RemoteFooService` を本番用に使用しますが、その本番用の特定のケースをテストしないと、統合アプリケーションで `RemoteFooService` が動作することを確認することはできません。

この問題を解決するには、アプリケーションの**個別の設定の数を最小限**にします。本番環境と開発環境を個別のモジュールに分割すれば、本番環境のコードパス全体をテストすることが容易になります。
この例では、`FooModule` を `RemoteFooModule` と `InMemoryFooModule` に分割します。これにより、実運用中のクラスがテストコードにコンパイル時に依存するのを防ぐこともできます。

もうひとつ、上の例に関連する問題です。`#[ServerName]`に対する束縛があるときとないときがあります。そのようにあるキーが束縛されたりしてなかったりする事があるのは避けるべきでしょう。
