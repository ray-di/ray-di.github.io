---
layout: docs-ja
title: バインディングアトリビュートを再利用しない
category: Manual
permalink: /manuals/1.0/ja/bp/dont_reuse_annotations.html
---
# バインディングアトリビュートを再利用しない (`#[Qualifier]`)

もちろん、いくつかの関連性の高いバインディングを同じ属性でバインドすることが理にかなっている場合もあります。
例：`#[ServerName]`

とはいえ、ほとんどのバインディング属性は、1つのバインディングだけを修飾する必要があります。
また、バインディングの属性を *無関係* のバインディングに再利用することは絶対に避けてください。

迷ったときは、属性を再利用しないことです!

定型的な表現を避けるために、属性パラメータを使用して、単一の宣言から個別のアノテーションインスタンスを作成することが理にかなっている場合があります。

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

そうすると、それぞれを別々の属性型として定義するのではなく、 `#[MyThing(Thing::FOO)]`, `#[MyThing(Thing::BAR)]`, `#[MyThing(Thing::BAZ)]` を使うことができるようになります。
