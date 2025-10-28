---
layout: docs-ja
title: Ray.Di Study
category: Manual
permalink: /manuals/1.0/ja/study.html
---

# Ray.Di Study: 実践的なオブジェクト指向設計パターン

このスタディでは**どの問題にどのパターンを使うか**を学びます。Ray.Diを使ってSOLID原則と設計パターンの実践的な理解を深め、保守性と拡張性の高いアーキテクチャを構築する判断力を養います。

## 学習の焦点

- **問題からパターンへ**: 密結合、肥大化したコントローラー、混在したデータアクセスなどの問題を適切なパターンで解決
- **判断基準**: いつFactoryを使い、いつStrategyを使い、いつRepositoryを使うかを学習
- **実践的なSOLID**: 実際のコードを通じて単一責任、開放閉鎖、依存性逆転の各原則を理解
- **アーキテクチャ設計**: レイヤー分離、関心の分離、モジュール設計

> このチュートリアルは設計パターンの学習に焦点を当てています。Ray.Diの機能リファレンスは[マニュアル](../)を参照してください。

## チュートリアル構成

### Part 1: 基礎 - なぜDIが必要か

**問題:** 密結合、テストが困難、変更に脆弱
**学習内容:** 依存性注入とSOLID原則がこれらの問題をどう解決するか

- [依存性注入の原則](study/01-foundations/dependency-injection-principles.html) - 制御の反転、疎結合の実現
- [SOLID原則の実践](study/01-foundations/solid-principles.html) - 実際のコードを通じた5つの原則の理解

### Part 2: オブジェクト生成パターン

**問題:** 肥大化したコンストラクタ、実行時パラメータの扱い
**学習内容:** オブジェクト生成責任を分離する判断基準

- [Factoryパターン](study/02-object-creation/factory-pattern.html) - 使用時期: 実行時パラメータが必要な場合
- [Providerパターン](study/02-object-creation/provider-pattern.html) - 使用時期: 複雑な初期化が必要な場合

### Part 3: 振る舞いパターン

**問題:** 条件分岐の増殖、横断的関心事の散在
**学習内容:** 振る舞いを切り替え可能にし、関心事を分離する方法

- [Strategyパターン](study/03-behavioral/strategy-pattern.html) - 使用時期: 実行時にアルゴリズムを切り替える場合
- [Decoratorパターン & AOP](study/03-behavioral/decorator-aop.html) - 使用時期: ログ、トランザクションなどを分離する場合

### Part 4: アーキテクチャパターン

**問題:** データアクセスの混在、肥大化したコントローラー、肥大化したDI設定
**学習内容:** レイヤーを分離し責任を明確化するアーキテクチャ設計

- [Adapterパターン](study/04-architecture/adapter-pattern.html) - 使用時期: 外部APIやライブラリを適合させる場合
- [Repositoryパターン](study/04-architecture/repository-pattern.html) - 使用時期: データアクセスをビジネスロジックから分離する場合
- [Service Layer](study/04-architecture/service-layer.html) - 使用時期: ビジネスロジックを調整する場合
- [モジュール設計](study/04-architecture/module-design.html) - 使用時期: DI設定が100行を超える場合

## 学習アプローチ

各セクションは以下の一貫した構成に従います:

1. **問題** - 実際のコードにおける具体的な課題（10-20行）
2. **なぜ問題なのか** - 保守性、テスト容易性、拡張性への影響
3. **解決策** - パターンの核となる実装（30-50行）
4. **パターンの本質** - 図解による視覚的理解
5. **判断基準** - このパターンをいつ使うか、いつ使わないか
6. **アンチパターン** - よくある間違いとその理由
7. **SOLIDとの関連** - このパターンが実現する原則

## どこから始めるか

**OOP初心者の方**
推奨順序: [依存性注入の原則](study/01-foundations/dependency-injection-principles.html) → [SOLID原則](study/01-foundations/solid-principles.html) → [Factoryパターン](study/02-object-creation/factory-pattern.html)

**経験豊富な開発者の方**
どこからでも開始できます！各セクションは独立しています。

**アーキテクト向け**
推奨: [SOLID原則](study/01-foundations/solid-principles.html) → [アーキテクチャパターン](study/04-architecture/repository-pattern.html)

## カバーする主要パターン

| パターン | 解決する問題 | いつ使うか |
|---------|---------------|-------------|
| Factory | 実行時パラメータとDI依存関係の混在 | オブジェクト生成に実行時の値が必要な場合 |
| Provider | コンストラクタの肥大化 | 複雑な初期化ロジックが必要な場合 |
| Strategy | 条件分岐の増殖 | 実行時にアルゴリズムを切り替える場合 |
| Decorator/AOP | 横断的関心事の散在 | ログ、トランザクションなどを分離する場合 |
| Adapter | 外部APIとアプリケーションの不一致 | 外部サービスをアプリケーションに適合させる場合 |
| Repository | データアクセスの混在 | ビジネスロジックからデータアクセスを分離する場合 |
| Service Layer | 肥大化したコントローラー | ビジネスロジックを調整する場合 |
| Module Design | 肥大化したDI設定 | 設定が100行を超える場合 |

## 前提条件

- PHP 8.1+
- Composer
- OOPの基本的な理解
- インターフェースに関する知識

## 追加リソース

- [Ray.Diマニュアル](../) - 機能リファレンス
- [Ray.Di GitHub](https://github.com/ray-di/Ray.Di)
- [Design Patterns in PHP](https://designpatternsphp.readthedocs.io/)

---

**開始:** [依存性注入の原則](study/01-foundations/dependency-injection-principles.html)

> 設計パターンは暗記するものではありません - 判断基準を理解することが重要です。このチュートリアルで、各状況に適したパターンを選ぶ判断力を養いましょう。
