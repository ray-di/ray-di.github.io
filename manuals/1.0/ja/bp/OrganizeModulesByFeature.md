---
layout: docs-ja
title: 機能別にモジュールを整理する
category: Manual
permalink: /manuals/1.0/ja/bp/organize_modules_by_feature.html
---
# クラスタイプではなく、機能別にモジュールを整理する

バインディングをフィーチャーにグループ化する。
理想的には、インジェクタにモジュールを1つインストールするかしないかだけで、動作機能全体を有効化/無効化できるようにすることです。

例えば、`Filter` を実装するすべてのクラスのバインディングを含む `FiltersModule` や、 `Graph` を実装するすべてのクラスを含む `GraphsModule` などは作らないようにしましょう。
例えば、サーバーへのリクエストを認証する `AuthenticationModule` や、サーバーから Foo バックエンドへのリクエストを可能にする `FooBackendModule` のようにです。

この原則は、「水平ではなく、垂直にモジュールを編成する」としても知られている。
