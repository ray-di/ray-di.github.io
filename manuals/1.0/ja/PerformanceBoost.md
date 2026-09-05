---
layout: docs-ja
title: パフォーマンス向上
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

## ランタイムサーバーでのシングルトンのウォームアップ

リフレクションで解決する `Injector` は、解決中の依存の連なりといまの注入点をプロセス全体で持っています。provider の中でコルーチンが待ちに入る（接続プールの空きを待つなど）と、別のコルーチンが同じ状態に入り込み、循環していない連なりで `CircularDependency` が投げられます。コルーチンサーバーはコンパイル済みインジェクターで動かします。

コンパイル時には、呼び出し側のコンテキストなしでインスタンス化できるシングルトン束縛の一覧 `singletons.json` も生成されます。`CompiledInjector::warmup()` はこれらを全て事前にインスタンス化します。

```php
use Ray\Compiler\CompiledInjector;

$injector = new CompiledInjector($tmpDir);
$injector->warmup(); // ワーカー起動時に一度だけ呼び出します
```

Swoole や OpenSwoole のような長寿命・コルーチンランタイムでは、シングルトンの遅延初期化が構築中に yield すると競合し、インスタンスが重複して生成されることがあります。並行リクエスト処理の開始前に `warmup()` を呼び出すことで、この競合の余地をなくせます。この対策は1つのプロセス内でリクエストを並行処理するランタイムでのみ必要です。通常の PHP-FPM ワーカーは一度に1リクエストしか処理しないため、ウォームアップは不要です。

インジェクションポイントに依存するシングルトンは、最初に構築したコンシューマーのコンテキストを取り込んでしまい、共有インスタンスが順序依存になります。そのような束縛はプロトタイプスコープにするか、インジェクションポイントへの依存を取り除く必要があります。

- インジェクションポイントに依存するシングルトンがあると、コンパイル時に `SingletonRequiresInjectionPoint` がスローされます。
- `$tmpDir` に `singletons.json` がないと、`warmup()` は `SingletonsFileNotFound` をスローします。いまの Ray.Compiler でコンパイルし直してください。

## キャッシュインジェクター

インジェクターはシリアライズ可能で、コンテナをリクエストを跨いで保持できます。

```php

// save
$injector = new Injector(new ListerModule);
$cachedInjector = serialize($injector);

// load
$injector = unserialize($cachedInjector);
$lister = $injector->getInstance(ListerInterface::class);

```

ただし `unserialize()` はプロセスごとにコンテナを組み立て直すので、コストは束縛の数に比例して増えます。コンパイル済みスクリプト約 600 本の本番アプリでは、php-fpm のコールドな 1 リクエストでシリアライズ版が約 29ms、コンパイル版が約 5ms でした（約 6 倍）。ウォームなワーカーでは差は数 ms に縮みます。計測条件は [Performance & OPcache](https://github.com/ray-di/Ray.Compiler/blob/1.x/docs/performance.md) にあります。
