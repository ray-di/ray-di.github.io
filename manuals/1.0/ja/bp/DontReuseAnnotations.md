---
layout: docs-ja
title: 束縛アトリビュートを再利用しない
category: Manual
permalink: /manuals/1.0/ja/bp/dont_reuse_annotations.html
---
# 束縛アトリビュートを再利用しない (`#[Qualifier]`)

もちろん、関連性の高い束縛を同じアトリビュートでバインドすることは適切です。 例) `#[ServerName]`
例：`#[ServerName]`

とはいえ、ほとんどの束縛アトリビュートは、1つの束縛だけを修飾する必要があります。
また、束縛アトリビュートを *無関係* の束縛に再利用することは絶対に避けてください。

迷ったときは、属性を再利用しないことです。作成するのは簡単です!

ボイラープレートコードを避けるために、属性パラメータを使用して、単一の宣言から個別のアノテーションインスタンスを作成することが理にかなっている場合があります。

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

それぞれを別々の属性型として定義する代わりに、 `#[MyThing(Thing::FOO)]`, `#[MyThing(Thing::BAR)]`, `#[MyThing(Thing::BAZ)]` を使えます。
