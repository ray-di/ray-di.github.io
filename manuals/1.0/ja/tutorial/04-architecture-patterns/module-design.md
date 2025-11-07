---
layout: docs-ja
title: モジュール設計 - アーキテクチャパターン
category: Manual
permalink: /manuals/1.0/ja/tutorial/04-architecture-patterns/module-design.html
---

# モジュール設計 - アーキテクチャパターン

## 学習目標

- DI設定の肥大化問題を理解する
- モジュールで関心事ごとに設定を分割する方法を学ぶ
- 環境ごとのモジュール構成を理解する

## 問題：肥大化したDI設定

すべての束縛を一つのモジュールに記述すると管理が困難になります。

```php
class ApplicationModule extends AbstractModule
{
    protected function configure(): void
    {
        // ❌ 問題：データベース、サービス、外部API、環境分岐がすべて混在

        // データベース関連
        $this->bind(PDO::class)->toProvider(PDOProvider::class)->in(Singleton::class);
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);

        // サービス層
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);

        // 外部サービス
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
        $this->bind(PaymentGatewayInterface::class)->to(StripePaymentGateway::class);

        // 環境による分岐
        if (getenv('APP_ENV') === 'production') {
            $this->bind(CacheInterface::class)->to(RedisCache::class);
        } else {
            $this->bind(CacheInterface::class)->to(ArrayCache::class);
        }

        // さらに100行続く...
    }
}
```

### なぜこれが問題なのか

1. **責任の不明確さ**
   - データベース、外部サービス、環境設定が混在
   - 300行以上の巨大なモジュール

2. **保守性の低下**
   - 関連する束縛を見つけるのが困難
   - 変更の影響範囲が不明確

3. **再利用の困難さ**
   - 一部の機能だけを別プロジェクトで使えない
   - テスト用設定が本番設定と混在

## 解決策：モジュールの分割

**モジュールの役割**：関心事ごとにDI設定を分割し、組み合わせて使用

### アプローチ1：層ごとの分割

```php
// 1. データベース層モジュール
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(PDO::class)->toProvider(PDOProvider::class)->in(Singleton::class);
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
    }
}

// 2. サービス層モジュール
class ServiceModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
        $this->bind(UserServiceInterface::class)->to(UserService::class);
    }
}

// 3. AOP層モジュール
class AopModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Transactional::class),
            [TransactionalInterceptor::class]
        );
    }
}

// 4. 組み合わせ
class ApplicationModule extends AbstractModule
{
    protected function configure(): void
    {
        // ✅ モジュールを組み合わせる
        $this->install(new DatabaseModule());
        $this->install(new ServiceModule());
        $this->install(new AopModule());
    }
}
```

### アプローチ2：環境ごとの分割

```php
// 1. 共通モジュール
class CommonModule extends AbstractModule
{
    protected function configure(): void
    {
        // すべての環境で共通の束縛
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);

        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Transactional::class),
            [TransactionalInterceptor::class]
        );
    }
}

// 2. 開発環境モジュール
class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new CommonModule());

        // 開発環境固有の束縛
        $this->bind(PDO::class)->toProvider(SQLitePDOProvider::class);
        $this->bind(CacheInterface::class)->to(ArrayCache::class);
        $this->bind(EmailServiceInterface::class)->to(LogEmailService::class);
    }
}

// 3. 本番環境モジュール
class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new CommonModule());

        // 本番環境固有の束縛
        $this->bind(PDO::class)->toProvider(MySQLPDOProvider::class)->in(Singleton::class);
        $this->bind(CacheInterface::class)->to(RedisCache::class)->in(Singleton::class);
        $this->bind(EmailServiceInterface::class)->to(SMTPEmailService::class);
    }
}

// 4. 環境に応じたモジュール選択
class Application
{
    public function __construct()
    {
        $module = match(getenv('APP_ENV')) {
            'production' => new ProductionModule(),
            'development' => new DevelopmentModule(),
            default => throw new InvalidEnvironmentException()
        };

        $this->injector = new Injector($module);
    }
}
```

## パターンの本質

```
肥大化したモジュール:
ApplicationModule
├─ データベース設定
├─ サービス設定
├─ 外部API設定
├─ 環境分岐
└─ 300行...

モジュール分割後:
層ごとの分割                 環境ごとの分割
├── DatabaseModule          ├── CommonModule
├── ServiceModule           ├── DevelopmentModule
├── PaymentModule           ├── ProductionModule
└── AopModule               └── TestModule

ApplicationModule
└── install() で組み合わせ
```

### モジュール分割が解決すること

1. **関心事の分離**
   - データベース：DatabaseModule
   - ビジネスロジック：ServiceModule
   - 横断的関心事：AopModule

2. **環境ごとの設定管理**
   - 開発環境：SQLite、メモリキャッシュ、ログメール
   - 本番環境：MySQL、Redis、SMTP

3. **再利用性の向上**
   ```php
   // プロジェクトAではすべて使用
   $this->install(new DatabaseModule());
   $this->install(new PaymentModule());

   // プロジェクトBでは一部のみ使用
   $this->install(new DatabaseModule());
   // PaymentModuleは不要
   ```

## 使い分けの判断基準

```
モジュールが肥大化
│
├─ 100行を超える？
│  ├─ YES → 関心事が複数？
│  │         ├─ YES → ✅ 層ごとに分割
│  │         └─ NO  → 環境ごとに異なる？
│  │                   ├─ YES → ✅ 環境ごとに分割
│  │                   └─ NO  → このまま
│  └─ NO  ↓
│
├─ 再利用したい？
│  ├─ YES → ✅ 再利用単位で分割
│  └─ NO  → このまま
```

### モジュールを分割すべき場合

| 状況 | 理由 |
|------|------|
| **関心事が明確に異なる** | データベース、メール、支払いなど |
| **環境ごとに異なる実装** | 本番、開発、テスト |
| **100行を超える束縛** | 保守性のため分割 |

### モジュール分割が過剰な場合

| 状況 | 代替手段 |
|------|---------|
| **束縛が5個以下** | 一つのモジュールで十分 |
| **密接に関連する束縛** | 分割せず一つのモジュールに |
| **再利用しない** | 分割不要 |

## よくあるアンチパターン

### 過度な分割

```php
// ❌ 束縛が1つのモジュールが大量
class UserRepositoryModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
    }
}

class OrderRepositoryModule extends AbstractModule  // 50個のモジュール...
{
    protected function configure(): void
    {
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
    }
}

// ✅ 関連する束縛をグループ化
class RepositoryModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
    }
}
```

**なぜ問題か**：モジュール数が多すぎて管理が困難、過剰なファイル数

### 環境判定のハードコード

```php
// ❌ モジュール内で環境判定
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        if (getenv('APP_ENV') === 'production') {
            $this->bind(PDO::class)->toProvider(MySQLPDOProvider::class);
        } else {
            $this->bind(PDO::class)->toProvider(SQLitePDOProvider::class);
        }
    }
}

// ✅ 環境ごとに別モジュール
class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new CommonModule());
        $this->bind(PDO::class)->toProvider(MySQLPDOProvider::class);
    }
}

class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new CommonModule());
        $this->bind(PDO::class)->toProvider(SQLitePDOProvider::class);
    }
}
```

**なぜ問題か**：モジュールの責任が不明確、環境ごとの違いが分散

## SOLID原則との関係

- **SRP**：モジュールは一つの関心事のみを担当
- **OCP**：新しいモジュール追加時、既存モジュールを変更しない
- **DIP**：モジュールはインターフェースに依存、具象実装への依存を排除

## まとめ

### モジュール設計の核心

- **関心事ごとの分割**：データベース、サービス、AOPなど
- **環境ごとの分割**：本番、開発、テスト
- **install()で組み合わせ**：柔軟な構成

### パターンの効果

- ✅ DI設定が整理され、見つけやすい
- ✅ 環境ごとの違いが明確
- ✅ 再利用可能なコンポーネント
- ✅ テスト用設定を簡単に作成

### 次のステップ

これでRay.Diの主要なパターンを学びました。Part 5以降で、AOPの詳細、実世界の例、テスト戦略、ベストプラクティスを学びます。

**続きは:** [アスペクト指向プログラミング](/manuals/1.0/ja/tutorial/05-aop-interceptors/aspect-oriented-programming.html)

---

モジュール設計は、**DIコンテナ設定の保守性を左右**します。適切に分割し、組み合わせることで、柔軟で再利用可能な設定を実現できます。
