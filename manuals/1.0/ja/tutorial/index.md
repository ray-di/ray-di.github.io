---
layout: docs-ja
title: Ray.Di スタディ
category: Manual
permalink: /manuals/1.0/ja/tutorial.html
---

# Ray.Di スタディ: 依存注入の原則から実践まで

このスタディでは、依存注入の基本原則から始まり、実世界のE-commerceプラットフォームの実装例を通じて、Ray.Diの高度な機能とベストプラクティスを段階的に学習します。

## 学習内容

- **依存注入の原則**: DI、IoC、SOLID原則の理解
- **Ray.Diの基礎**: すべてのバインディングタイプ、スコープ、高度な機能
- **実世界のアプリケーション**: 完全なE-commerceプラットフォームの構築
- **デザインパターン**: Factory、Strategy、Observerなど、DIを使った実装
- **アスペクト指向プログラミング**: 横断的関心事とインターセプター
- **テスト戦略**: 単体テスト、モッキング、統合テスト
- **ベストプラクティス**: パフォーマンス、トラブルシューティング、保守可能なコード

## スタディ構造

各セクションは独立して設計されており、ニーズに応じてどこからでも開始できます。

### Part 1: 基礎
- [依存注入の原則](/manuals/1.0/ja/tutorial/01-foundations/dependency-injection-principles.html)
- [SOLID原則の実践](/manuals/1.0/ja/tutorial/01-foundations/solid-principles.html)
- [Ray.Diの基礎](/manuals/1.0/ja/tutorial/01-foundations/raydi-fundamentals.html)

### Part 2: 基本的な束縛
- [インスタンス束縛](/manuals/1.0/ja/tutorial/02-basic-bindings/instance-binding.html)
- [リンク束縛](/manuals/1.0/ja/tutorial/02-basic-bindings/linked-binding.html)
- [プロバイダー束縛](/manuals/1.0/ja/tutorial/02-basic-bindings/provider-binding.html)
- [モジュールの分割と結合](/manuals/1.0/ja/tutorial/02-basic-bindings/module-composition.html)
- [束縛DSL](/manuals/1.0/ja/tutorial/02-basic-bindings/binding-dsl.html)

### Part 3: 高度な束縛
- [マルチ束縛](/manuals/1.0/ja/tutorial/03-advanced-bindings/multi-binding.html)
- [アシスト束縛](/manuals/1.0/ja/tutorial/03-advanced-bindings/assisted-injection.html)
- [インジェクションポイントの利用](/manuals/1.0/ja/tutorial/03-advanced-bindings/injection-point.html)

### Part 4: スコープとライフサイクル
- [シングルトンスコープとオブジェクトライフサイクル](/manuals/1.0/ja/tutorial/04-scopes-lifecycle/singleton-scope.html)
- [プロトタイプスコープとインスタンス管理](/manuals/1.0/ja/tutorial/04-scopes-lifecycle/prototype-scope.html)

### Part 5: AOP & インターセプター
- [アスペクト指向プログラミング](/manuals/1.0/ja/tutorial/05-aop-interceptors/aspect-oriented-programming.html)
- [横断的関心事](/manuals/1.0/ja/tutorial/05-aop-interceptors/cross-cutting-concerns.html)
- [メソッドインターセプター](/manuals/1.0/ja/tutorial/05-aop-interceptors/method-interceptors.html)

### Part 6: 実世界の例
- [Webアプリケーション アーキテクチャ](/manuals/1.0/ja/tutorial/06-real-world-examples/web-application-architecture.html)
- [データアクセス層](/manuals/1.0/ja/tutorial/06-real-world-examples/data-access-layer.html)
- [認証・認可](/manuals/1.0/ja/tutorial/06-real-world-examples/authentication-authorization.html)
- [ロギング・監査システム](/manuals/1.0/ja/tutorial/06-real-world-examples/logging-audit-system.html)
### Part 7: テスト戦略
- [DIを使った単体テスト](/manuals/1.0/ja/tutorial/07-testing-strategies/unit-testing-with-di.html)
- [依存関係のモッキング](/manuals/1.0/ja/tutorial/07-testing-strategies/dependency-mocking.html)
- [統合テスト](/manuals/1.0/ja/tutorial/07-testing-strategies/integration-testing.html)

### Part 8: ベストプラクティス
- [DIを使ったデザインパターン](/manuals/1.0/ja/tutorial/08-best-practices/design-patterns-with-di.html)
- [パフォーマンス考慮事項](/manuals/1.0/ja/tutorial/08-best-practices/performance-considerations.html)
- [トラブルシューティングガイド](/manuals/1.0/ja/tutorial/08-best-practices/troubleshooting-guide.html)
## ケーススタディ: E-commerceプラットフォーム

このスタディでは、**"ShopSmart"** というE-commerceプラットフォームを題材に、Ray.Diの実践的な活用方法を学びます。

各セクションで、以下のようなE-commerceプラットフォームの実装例を通じて原則を理解します：

- **ユーザー管理**: 登録、認証、プロファイル
- **商品カタログ**: カテゴリ、在庫、検索
- **注文処理**: カート、チェックアウト、支払い
- **管理機能**: 分析、レポート、管理
- **インフラ**: キャッシュ、ログ、監視

これらの実例を通じて、Ray.Diがどのように以下を実現するかを学びます：
- **モジュール性**: 関心事の明確な分離
- **テスト可能性**: 簡単な単体テストと統合テスト
- **保守性**: 疎結合と高凝集
- **拡張性**: 適切なスコープ管理とパフォーマンス
- **拡張可能性**: プラグインアーキテクチャとインターセプター

## 学習パス

### 初心者向け
1. [依存注入の原則](/manuals/1.0/ja/tutorial/01-foundations/dependency-injection-principles.html)から始める
2. [Ray.Diの基礎](/manuals/1.0/ja/tutorial/01-foundations/raydi-fundamentals.html)を学ぶ
3. [基本的なバインディング](/manuals/1.0/ja/tutorial/02-basic-bindings/instance-binding.html)で練習する
4. [実世界の例](/manuals/1.0/ja/tutorial/06-real-world-examples/web-application-architecture.html)を探索する

### 経験豊富な開発者向け
1. [高度なバインディング](/manuals/1.0/ja/tutorial/03-advanced-bindings/multi-binding.html)にジャンプする
2. [AOP & インターセプター](/manuals/1.0/ja/tutorial/05-aop-interceptors/aspect-oriented-programming.html)をマスターする
3. [デザインパターン](/manuals/1.0/ja/tutorial/08-best-practices/design-patterns-with-di.html)を学ぶ
4. [ベストプラクティス](/manuals/1.0/ja/tutorial/08-best-practices/performance-considerations.html)を確認する

### アーキテクト向け
1. [SOLID原則](/manuals/1.0/ja/tutorial/01-foundations/solid-principles.html)に焦点を当てる
2. [スコープとライフサイクル](/manuals/1.0/ja/tutorial/04-scopes-lifecycle/singleton-scope.html)を学ぶ
3. [Webアプリケーション アーキテクチャ](/manuals/1.0/ja/tutorial/06-real-world-examples/web-application-architecture.html)を調べる
4. [パフォーマンス考慮事項](/manuals/1.0/ja/tutorial/08-best-practices/performance-considerations.html)を確認する

## 前提条件

- PHP 8.1+
- Composer
- OOP概念の基本的な理解
- インターフェースと抽象クラスの知識

## クイックスタート

```bash
# スタディの例をクローン
git clone https://github.com/ray-di/tutorial-examples.git
cd tutorial-examples

# 依存関係をインストール
composer install

# 最初の例を実行
php examples/01-basics/hello-world.php
```

## コード例

すべての例は以下の特徴があります：
- **実行可能**: 完全で動作するコード
- **段階的**: 複雑さを段階的に構築
- **実践的**: 実世界のシナリオに基づく
- **十分に文書化**: 詳細なコメントと説明

## カバーされる主要概念

### 依存注入パターン
- コンストラクタインジェクション
- メソッドインジェクション
- プロパティインジェクション
- インターフェース分離

### 設計原則
- **単一責任**: 変更の理由は一つ
- **オープン・クローズド**: 拡張に対してオープン、変更に対してクローズド
- **リスコフの置換**: 派生クラスは置換可能でなければならない
- **インターフェース分離**: 使用しないインターフェースへの強制的な依存なし
- **依存性逆転**: 抽象に依存し、具象に依存しない

### Ray.Diの機能
- **バインディングDSL**: 流暢な設定API
- **スコープ**: シングルトン、プロトタイプ
- **プロバイダー**: ファクトリーパターンと遅延初期化
- **インターセプター**: 横断的関心事のためのAOP
- **マルチバインディング**: 実装のセットとマップ
- **環境固有の設定**: 開発・本番環境の切り替え

### ソフトウェアアーキテクチャパターン
- **階層化アーキテクチャ**: プレゼンテーション、ビジネス、データ
- **リポジトリパターン**: データアクセスの抽象化
- **サービス層**: ビジネスロジックの協調
- **ファクトリーパターン**: オブジェクト作成戦略
- **ストラテジーパターン**: 交換可能なアルゴリズム
- **オブザーバーパターン**: イベント駆動プログラミング
- **デコレーターパターン**: 動作の拡張

## 成功のためのヒント

1. **コードを実行する**: 読むだけでなく、例を実行する
2. **実験する**: 例を変更して異なる動作を見る
3. **質問する**: 問題やディスカッションでヘルプを求める
4. **練習する**: パターンを使って独自の例を構築する
5. **復習する**: 経験を積みながら概念に戻る

## フィードバック

エラーを発見したり、改善提案がある場合は：
- [GitHubでイシューを開く](https://github.com/ray-di/Ray.Di/issues)
- [プルリクエストを提出する](https://github.com/ray-di/Ray.Di/pulls)

## 追加リソース

- [Ray.Diドキュメント](/manuals/1.0/ja/)
- [Ray.Di APIリファレンス](https://github.com/ray-di/Ray.Di)
- [PHPでの依存注入](https://www.php-di.org/doc/)
- [PHPでのデザインパターン](https://designpatternsphp.readthedocs.io/)

---

上記の開始点を選んで、より良いソフトウェアアーキテクチャの学習を開始してください。