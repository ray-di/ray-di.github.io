---
layout: docs-ja
title: Module Design
category: Manual
permalink: /manuals/1.0/ja/tutorial/module-design.html
---
# 依存性注入によるModule Design

## 問題

DI設定が1つの巨大なモジュールで管理されています。アプリケーションが成長すると、すべてのバインディングが混在します。ユーザー管理、注文処理、決済、通知のバインディングがすべて同じファイルに存在します。設定が組織化されていないため、開発者は関連する構成を見つけられません：

```php
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // ユーザー管理のバインディング
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(UserServiceInterface::class)->to(UserService::class);
        
        // 注文処理のバインディング
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        
        // 決済のバインディング
        $this->bind(PaymentGatewayInterface::class)->to(StripeGateway::class);
        $this->bind(PaymentServiceInterface::class)->to(PaymentService::class);
        
        // 通知のバインディング
        $this->bind(NotificationServiceInterface::class)->to(EmailNotificationService::class);
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
        
        // さらに50個のバインディング...すべてが混在！
    }
}
```

## なぜ問題なのか

これは機能の凝集性と設定の保守性の間に根本的な組織上の問題を生み出します。注文機能を理解する際、ユーザー、決済、通知の設定を読み飛ばして、関連するバインディングを見つけ出す必要があります。決済ゲートウェイをStripeからPayPalに変更する際、アプリケーション全体の設定を検索して、変更すべき行を見つけなければなりません。

モジュールは複数の関心事を管理することで単一責任原則に違反しています。開発中に注文機能だけをテストしたくても、ユーザー、決済、通知のすべてのバインディングが有効になります—機能を選択的に有効化できません。設定変更のたびに、すべての機能に影響を与える巨大なモジュールに触れるリスクがあります。

## 解決策：Feature-Based Modules

Module Designパターンは、機能別にバインディングを整理することで、この問題を解決します。各機能には、関連する構成をカプセル化する独自のモジュールがあります。アプリケーションモジュールは、これらの小さな焦点を絞ったモジュールを組み合わせます：

```php
// ユーザー管理モジュール - ユーザーに関連するバインディングのみ
class UserModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(UserServiceInterface::class)->to(UserService::class);
    }
}

// 注文処理モジュール - 注文に関連するバインディングのみ
class OrderModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        $this->bind(ShippingServiceInterface::class)->to(ShippingService::class);
    }
}

// 決済モジュール - 決済に関連するバインディングのみ
class PaymentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(PaymentGatewayInterface::class)->to(StripeGateway::class);
        $this->bind(PaymentServiceInterface::class)->to(PaymentService::class);
    }
}

// アプリケーションモジュール - 機能モジュールを組み合わせる
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new UserModule());
        $this->install(new OrderModule());
        $this->install(new PaymentModule());
    }
}
```

## パターンの本質

Module Designパターンは明確な組織的分離を生み出します：1つのモジュールがすべての構成を知る代わりに、各モジュールは1つの機能を知ります。機能は独立して開発、テスト、有効化できます。`install()`メソッドはモジュール構成を可能にします。

```
変更前：1つのモジュール、すべてのバインディング（混沌）
変更後：多数のモジュール、機能別にグループ化（整理）
```

なぜこれが重要なのでしょうか？決済ゲートウェイを変更する際、PaymentModuleだけに触れます—他の機能には影響しません。注文処理をテストする際、OrderModuleだけをインストールします—不要な依存関係はありません。新しい開発者がユーザー管理を理解する際、UserModuleを読みます—70個のバインディングをふるいにかける必要はありません。各機能には単一の設定の場所があります。モジュールはコードと同じ境界に従います—UserServiceにはUserModuleがあり、OrderServiceにはOrderModuleがあります。

## Module Designを使用するとき

アプリケーションに明確な機能境界がある場合にModule Designを使用します。これには、ユーザー管理、注文処理、決済、通知などの独立した設定を持つ機能が含まれます。マイクロサービスアーキテクチャ、プラグインシステム、または異なる環境で機能を選択的に有効化する必要があるアプリケーションでは、モジュール設計が必須です。

モジュールは設定が成長し、混沌としている場合に優れています。DIモジュールが50個を超えるバインディングを持つ場合、より小さな機能モジュールに分割します。チームが独立して機能を開発する場合、モジュールはマージコンフリクトを防ぎます—各チームは独自のモジュールに取り組みます。機能がオプションである場合、モジュールはそれらを選択的にインストール可能にします。

## Module Designを避けるとき

バインディングが少ないシンプルなアプリケーションにはModule Designを避けてください。10個未満のバインディングは管理可能です—機能モジュールに分割する必要はありません。すべての設定が密接に関連しており、常に一緒に変更される場合、モジュールは過剰な抽象化です。バインディングが単一の機能に限定されている場合、1つのモジュールで十分です。

## よくある間違い：レイヤー別のモジュール

頻繁に見られるアンチパターンは、機能ではなくレイヤーでモジュールを整理することです：

```php
// ❌ 悪い例 - レイヤー別のモジュール（横の切り口）
class RepositoryModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(PaymentRepositoryInterface::class)->to(MySQLPaymentRepository::class);
        // すべてのリポジトリ、機能を問わず
    }
}

class ServiceModule extends AbstractModule
{
    protected function configure(): void
    {
        // すべてのサービス、機能を問わず
    }
}

// ✅ 良い例 - 機能別のモジュール（縦の切り口）
class OrderModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        $this->bind(ShippingServiceInterface::class)->to(ShippingService::class);
        // 1つの機能のすべてのレイヤー
    }
}
```

レイヤー別のモジュールは機能の凝集性を破壊します。注文機能を理解する際、RepositoryModule、ServiceModule、Controllerモジュールを読む必要があります。注文機能を無効にすることはできません—すべてが3つのモジュールに散らばっています。機能別にモジュールを整理します—各モジュールにはリポジトリ、サービス、コントローラーなど、1つの機能のすべてのレイヤーが含まれます。モジュールはドメイン境界に従います。技術的なレイヤーではありません。

## SOLID原則

Module Designパターンは各モジュールに単一の機能の設定を管理させることで**単一責任原則**を強制します。**開放/閉鎖原則**をサポートします—既存のモジュールを変更せずに、新しいモジュールを作成することで機能を追加できます。モジュールのインターフェースが一貫しているため、**リスコフの置換原則**を支持します—すべてのモジュールはAbstractModuleを拡張し、`configure()`を実装します。DIコンテナがモジュールの具体的な実装に依存しないため、**依存性逆転の原則**を例示します。

## テスト

モジュールはテストを劇的に簡素化します。モジュールがない場合、注文処理のテストには、注文に無関係であってもアプリケーション全体のバインディングをインストールする必要があります。すべてのテストにはすべての依存関係が必要です—選択的な有効化はありません。モジュールを使えば、関連するモジュールだけをインストールします。注文処理のテストにはOrderModuleだけが必要です。テスト対象は50個のバインディングを持つモノリシックな設定から、5個のバインディングを持つ焦点を絞った機能モジュールに縮小されます。

## 重要なポイント

Module Designは機能別にDI構成を整理します。明確な機能境界を持つアプリケーションや、50個を超えるバインディングを持つアプリケーションに使用します。各機能は独自のモジュールを持ちます—UserModule、OrderModule、PaymentModule。アプリケーションモジュールは`install()`を使用してこれらのモジュールを組み合わせます。レイヤー別ではなく機能別にモジュールを整理します—各モジュールには1つの機能のすべてのレイヤー（リポジトリ、サービス、コントローラー）が含まれます。このパターンは設定を発見可能に、機能を独立して開発可能に、テストを焦点を絞ったものにします。

---

**次へ：** [統合](../05-integration/) - すべてをまとめる

**前へ：** [Service Layer](service-layer.html)
