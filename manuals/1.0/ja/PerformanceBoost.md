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

`CachedInejctorFactory` は、2つのインジェクターをハイブリッドで使用することで、開発時と運用時の両方で最高のパフォーマンスを発揮することができます。

インジェクターはシングルトンオブジェクトを **リクエストを跨ぎ** 注入することができます。
その結果テストの速度は大幅に向上します。テスト中に連続したPDO接続によって接続リソースが枯渇することもありません。

詳しくは、[CachedInjectorFactory](https://github.com/ray-di/Ray.Compiler/issues/75)をご覧ください。

## Attribute Reader

Doctrineアノテーションを利用しない時はPHP8のアトリビュートリーダーだけを使用することで開発時のパフォーマンスが改善します。

`composer.json`にオートローダーとして登録するか

```json
  "autoload": {
    "files": [
      "vendor/ray/aop/attribute_reader.php"
    ]
```

ブートストラップのスクリプトでセットします。

```php
declare(strict_types=1);

use Koriym\Attributes\AttributeReader;
use Ray\ServiceLocator\ServiceLocator;

ServiceLocator::setReader(new AttributeReader());
```
