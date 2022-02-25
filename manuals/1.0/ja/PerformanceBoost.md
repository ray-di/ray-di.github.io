---
layout: docs-ja
title: Performance boost
category: Manual
permalink: /manuals/1.0/ja/performance_boost.html
---
# パフォーマンス

全ての依存の束縛を知っているインジェクターはその束縛から単純なPHPのファクトリーコードをコンパイルして最高のパフォーマンスを提供します。 また束縛に無名関数を使わないインジェクターはシリアライズ可能で、パフォーマンスを向上することが出来ます。

いずれにしてもプロダクションでリクエストの度にコンテナを初期化する必要はありません。

## スクリプトインジェクター

`ScriptInjector` は、パフォーマンスを向上させ、インスタンスの生成方法を明確にするために、生のファクトリーコードを生成します。

```php

use Ray\Di\ScriptInjector;
use Ray\Compiler\DiCompiler;
use Ray\Compiler\Exception\NotCompiled;

try {
    $injector = new ScriptInjector($tmpDir);
    $instance = $injector->getInstance(ListerInterface::class);
} catch (NotCompiled $e) {
    $compiler = new DiCompiler(new ListerModule, $tmpDir);
    $compiler->compile();
    $instance = $injector->getInstance(ListerInterface::class);
}
```
インスタンスが生成されると、生成されたファクトリファイルを `$tmpDir` に確認できます。

## キャッシュインジェクター

インジェクターはシリアライズ可能で、パフォーマンスを向上します。

```php

// save
$injector = new Injector(new ListerModule);
$cachedInjector = serialize($injector);

// load
$injector = unserialize($cachedInjector);
$lister = $injector->getInstance(ListerInterface::class);

```

## CachedInjectorFactory

`CachedInejctorFactory` は、2つのインジェクタをハイブリッドで使用することで、開発時と運用時の両方で最高のパフォーマンスを発揮することができます。

インジェクターはシングルトンオブジェクトを **リクエストを跨ぎ** 注入することができます。
その結果テストの速度は大幅に向上しす。テスト中に連続したPDO接続によって接続リソースが枯渇することもありません。

詳しくは、[CachedInjectorFactory](https://github.com/ray-di/Ray.Compiler/issues/75)をご覧ください。
