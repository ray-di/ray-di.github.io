---
layout: docs-ja
title: 機能別にモジュールを整理する
category: Manual
permalink: /manuals/1.0/ja/bp/organize_modules_by_feature.html
---
# クラスタイプではなく、機能別にモジュールを整理する

束縛を機能別にグループ化します。
理想は、モジュールをインストールするかしないかだけで、機能全体の有効化/無効化ができることです。

例えば、`Filter` を実装するすべてのクラスのバインディングを含む `FiltersModule` や `Graph` を実装するすべてのクラスを含む `GraphsModule` などは作らないようにしましょう。

その代わり、例えば、サーバーへのリクエストを認証する `AuthenticationModule` やサーバーから Fooバックエンドへのリクエストを可能にする `FooBackendModule` のように作りましょう。

この原則は、「モジュールを水平ではなく、垂直に整理する」としても知られています。
