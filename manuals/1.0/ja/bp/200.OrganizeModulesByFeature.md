---
layout: docs-ja
title: 機能別にモジュールを整理する
category: Manual
permalink: /manuals/1.0/ja/bp/organize_modules_by_feature.html
---
# クラスタイプではなく、機能別にモジュールを整理する

束縛を機能別にまとめます。
理想は、モジュールをインストールするか否かで機能全体の有効化/無効化ができることです。

例えば、`Filter` を実装するすべてのクラスの束縛を含む `FiltersModule` や `Graph` を実装するすべてのクラスを含む `GraphsModule` などは作らないようにしましょう。

その代わりに例えば、サーバーへのリクエストを認証する`AuthenticationModule`や、サーバーからFooバックエンドへのリクエストを可能にする`FooBackendModule`のように機能でまとめまめられたモジュールを作りましょう。

この原則は、「モジュールを水平ではなく、垂直に配置する(organize modules vertically, not horizontally)」としても知られています。
