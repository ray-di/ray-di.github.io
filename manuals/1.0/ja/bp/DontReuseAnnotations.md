---
layout: docs-ja
title: 束縛アトリビュートを再利用しない
category: Manual
permalink: /manuals/1.0/ja/bp/dont_reuse_annotations.html
---
# 束縛アトリビュートを再利用しない (`#[Qualifier]`)

もちろん、関連性の高い束縛を同じアトリビュートでバインドすることは適切です。 例) `#[ServerName]`
例：`#[ServerName]`

しかしながら、ほとんどの束縛アトリビュートは1つの束縛だけを対象にします。
また、束縛アトリビュートを *無関係* の束縛に再利用することは絶対に避けてください。

迷ったときは、アトリビュートを再利用しないことです。作成するのは簡単です!

ボイラープレートコードを避けるために、アトリビュートの引数を使用して１つのアトリビュートから複数の区別をすれば良いでしょう。

例えば

```php
enum Thing
{
    case FOO;
    case BAR;
    case BAZ;
}

#[Attribute, \Ray\Di\Di\Qualifier]
final class MyThing
{
    public function __construct(
        public readonly Thing $value
    ) {}
}
```

それぞれを別々のアトリビュートを定義する代わりに、 `#[MyThing(Thing::FOO)]`, `#[MyThing(Thing::BAR)]`, `#[MyThing(Thing::BAZ)]`などと引数で区別します。
