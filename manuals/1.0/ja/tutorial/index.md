---
layout: docs-ja
title: 完全チュートリアル
category: Manual
permalink: /manuals/1.0/ja/tutorial.html
---

# Ray.Di 完全チュートリアル: 実世界のE-commerceプラットフォーム構築

Ray.Diの包括的なチュートリアルへようこそ！このチュートリアルでは、実際のE-commerceプラットフォームを構築しながら、依存注入、デザインパターン、アスペクト指向プログラミングのすべての側面を学習します。

## 🎯 学習内容

- **依存注入の原則**: DI、IoC、SOLID原則の理解
- **Ray.Diの基礎**: すべてのバインディングタイプ、スコープ、高度な機能
- **実世界のアプリケーション**: 完全なE-commerceプラットフォームの構築
- **デザインパターン**: Factory、Strategy、Observerなど、DIを使った実装
- **アスペクト指向プログラミング**: 横断的関心事とインターセプター
- **テスト戦略**: 単体テスト、モッキング、統合テスト
- **ベストプラクティス**: パフォーマンス、トラブルシューティング、保守可能なコード

## 📋 チュートリアル構造

各セクションは独立して設計されており、ニーズに応じてどこからでも開始できます！

### 🔰 Part 1: 基礎
- [依存注入の原則](01-foundations/dependency-injection-principles.md)
- [SOLID原則の実践](01-foundations/solid-principles.md)
- [Ray.Diの基礎](01-foundations/raydi-fundamentals.md)

### 🏗️ Part 2: 基本的なバインディング
- [インスタンスバインディング](02-basic-bindings/instance-bindings.md)
- [クラスバインディング](02-basic-bindings/class-bindings.md)
- [プロバイダーバインディング](02-basic-bindings/provider-bindings.md)

### 🚀 Part 3: 高度なバインディング
- [条件付きバインディング](03-advanced-bindings/conditional-bindings.md)
- [マルチバインディング](03-advanced-bindings/multibindings.md)
- [アシストインジェクション](03-advanced-bindings/assisted-injection.md)

### ♻️ Part 4: スコープとライフサイクル
- [シングルトンスコープ](04-scopes-lifecycle/singleton-scope.md)
- [リクエストスコープ](04-scopes-lifecycle/request-scope.md)
- [カスタムスコープ](04-scopes-lifecycle/custom-scopes.md)

### 🎭 Part 5: AOP & インターセプター
- [アスペクト指向プログラミング](05-aop-interceptors/aspect-oriented-programming.md)
- [メソッドインターセプター](05-aop-interceptors/method-interceptors.md)
- [共通の横断的関心事](05-aop-interceptors/common-crosscutting-concerns.md)

### 🛒 Part 6: 実世界の例
- [Webアプリケーション アーキテクチャ](06-real-world-examples/web-application/)
- [データアクセス層](06-real-world-examples/data-access/)
- [認証・認可](06-real-world-examples/authentication/)
- [ロギング・監査システム](06-real-world-examples/logging-audit/)

### 🧪 Part 7: テスト戦略
- [DIを使った単体テスト](07-testing-strategies/unit-testing-with-di.md)
- [依存関係のモッキング](07-testing-strategies/mocking-dependencies.md)
- [統合テスト](07-testing-strategies/integration-testing.md)

### 💎 Part 8: ベストプラクティス
- [DIを使ったデザインパターン](08-best-practices/design-patterns.md)
- [パフォーマンス考慮事項](08-best-practices/performance-considerations.md)
- [トラブルシューティングガイド](08-best-practices/troubleshooting.md)

## 🛒 ケーススタディ: E-commerceプラットフォーム

このチュートリアル全体を通じて、**"ShopSmart"** という完全なE-commerceプラットフォームを構築します：

- **ユーザー管理**: 登録、認証、プロファイル
- **商品カタログ**: カテゴリ、在庫、検索
- **注文処理**: カート、チェックアウト、支払い
- **管理機能**: 分析、レポート、管理
- **インフラ**: キャッシュ、ログ、監視

この実世界の例は、Ray.Diがどのように以下を可能にするかを示します：
- **モジュール性**: 関心事の明確な分離
- **テスト可能性**: 簡単な単体テストと統合テスト
- **保守性**: 疎結合と高凝集
- **拡張性**: 適切なスコープ管理とパフォーマンス
- **拡張可能性**: プラグインアーキテクチャとインターセプター

## 🎓 学習パス

### 初心者向け
1. [依存注入の原則](01-foundations/dependency-injection-principles.md)から始める
2. [Ray.Diの基礎](01-foundations/raydi-fundamentals.md)を学ぶ
3. [基本的なバインディング](02-basic-bindings/)で練習する
4. [実世界の例](06-real-world-examples/)を探索する

### 経験豊富な開発者向け
1. [高度なバインディング](03-advanced-bindings/)にジャンプする
2. [AOP & インターセプター](05-aop-interceptors/)をマスターする
3. [デザインパターン](08-best-practices/design-patterns.md)を学ぶ
4. [ベストプラクティス](08-best-practices/)を確認する

### アーキテクト向け
1. [SOLID原則](01-foundations/solid-principles.md)に焦点を当てる
2. [スコープとライフサイクル](04-scopes-lifecycle/)を学ぶ
3. [Webアプリケーション アーキテクチャ](06-real-world-examples/web-application/)を調べる
4. [パフォーマンス考慮事項](08-best-practices/performance-considerations.md)を確認する

## 🔧 前提条件

- PHP 8.1+
- Composer
- OOP概念の基本的な理解
- インターフェースと抽象クラスの知識

## 🚀 クイックスタート

```bash
# チュートリアルの例をクローン
git clone https://github.com/ray-di/tutorial-examples.git
cd tutorial-examples

# 依存関係をインストール
composer install

# 最初の例を実行
php examples/01-basics/hello-world.php
```

## 📖 コード例

すべての例は以下の特徴があります：
- **実行可能**: 完全で動作するコード
- **段階的**: 複雑さを段階的に構築
- **実践的**: 実世界のシナリオに基づく
- **十分に文書化**: 詳細なコメントと説明

## 🎯 カバーされる主要概念

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
- **スコープ**: シングルトン、プロトタイプ、リクエスト、セッション
- **プロバイダー**: ファクトリーパターンと遅延初期化
- **インターセプター**: 横断的関心事のためのAOP
- **マルチバインディング**: 実装のセットとマップ
- **条件付きバインディング**: 環境固有の設定

### ソフトウェアアーキテクチャパターン
- **階層化アーキテクチャ**: プレゼンテーション、ビジネス、データ
- **リポジトリパターン**: データアクセスの抽象化
- **サービス層**: ビジネスロジックの協調
- **ファクトリーパターン**: オブジェクト作成戦略
- **ストラテジーパターン**: 交換可能なアルゴリズム
- **オブザーバーパターン**: イベント駆動プログラミング
- **デコレーターパターン**: 動作の拡張

## 💡 成功のためのヒント

1. **コードを実行する**: 読むだけでなく、例を実行する
2. **実験する**: 例を変更して異なる動作を見る
3. **質問する**: 問題やディスカッションでヘルプを求める
4. **練習する**: パターンを使って独自の例を構築する
5. **復習する**: 経験を積みながら概念に戻る

## 🤝 貢献

エラーを発見したり、チュートリアルを改善したいですか？
- GitHubでイシューを開く
- プルリクエストを提出する
- 独自の例を共有する

## 📚 追加リソース

- [Ray.Diドキュメント](../manuals/1.0/ja/)
- [Ray.Di APIリファレンス](https://github.com/ray-di/Ray.Di)
- [PHPでの依存注入](https://www.php-di.org/doc/)
- [PHPでのデザインパターン](https://designpatternsphp.readthedocs.io/)

---

**Ray.Diをマスターする準備はできましたか？** 上記の開始点を選んで、より良いソフトウェアアーキテクチャへの旅を始めましょう！