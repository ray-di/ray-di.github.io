---
layout: docs-ja
title: Ray.Diの基礎
category: Manual
permalink: /manuals/1.0/ja/tutorial/01-foundations/raydi-fundamentals.html
---

# Ray.Diの基礎：Google Guiceの思想をPHPへ

## なぜRay.Diなのか

「DIコンテナは設定が複雑で学習コストが高い」という声をよく聞きます。確かに、多くのPHP DIフレームワークは、配列やYAMLでの設定、文字列ベースのサービス定義、実行時まで分からないエラーなど、開発者を悩ませる要素があります。

Ray.DiはGoogle Guiceの設計哲学をPHPに持ち込み、これらの問題を根本から解決します。型安全性、明示的な設定、コンパイル時の最適化により、大規模アプリケーションでも安心して使えるDIフレームワークを実現しています。

## 他のDIフレームワークとの根本的な違い

### サービスロケーターパターンの問題

多くのPHP DIコンテナは、実はサービスロケーターパターンの実装です。設定を配列やクロージャで記述し、文字列キーでサービスを取得します：

```php
// 従来のDIコンテナ（Pimpleなど）
$container['database'] = function($c) {
    return new PDO($c['db.dsn'], $c['db.user'], $c['db.pass']);
};

$container['user.repository'] = function($c) {
    return new UserRepository($c['database']); // 文字列でのアクセス
};

// 問題：'database'のタイポは実行時まで検出されない
// 問題：IDEの支援が受けられない
// 問題：リファクタリングが困難
```

このアプローチには根本的な問題があります。依存関係が文字列で表現されるため、IDEの自動補完が効きません。タイプミスは実行時エラーになります。クラス名を変更してもDI設定は自動で更新されません。

### Ray.Diの宣言的アプローチ

Ray.Diは、Javaの世界で実績のあるGoogle Guiceの思想を採用しています。依存関係をルールとして宣言し、フレームワークが自動的に依存グラフを構築します：

```php
// Ray.Diの宣言的な設定
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // インターフェースと実装の関係を宣言
        $this->bind(DatabaseInterface::class)
             ->to(MySQLDatabase::class)
             ->in(Singleton::class);

        $this->bind(UserRepositoryInterface::class)
             ->to(UserRepository::class);
    }
}

// 型安全：IDEが完全サポート、リファクタリング対応
// 明示的：何がどう結合されるか一目瞭然
// 検証可能：設定ミスは即座に検出
```

この違いは単なる記法の違いではありません。Ray.Diでは、依存関係が型として表現されるため、PHPの型システムとIDEの機能をフルに活用できます。設定ミスはコンパイル時（より正確には、DIコンテナ構築時）に検出されます。

### 実行時の最適化

さらに重要な違いは、Ray.Diが設定を最適化されたPHPコードにコンパイルすることです。他のDIコンテナが実行時に依存解決を行うのに対し、Ray.Diは事前にすべての依存関係を解決し、最適なインスタンス生成コードを生成します：

```php
// Ray.Diが生成する最適化されたコード（概念的な例）
class UserService_RayAop
{
    public function __construct()
    {
        $this->db = new MySQLDatabase('localhost', 'user', 'pass');
        $this->repository = new UserRepository($this->db);
        $this->logger = new FileLogger('/var/log/app.log');
    }
}
```

これにより、実行時のオーバーヘッドが実質ゼロになります。アプリケーションは、手動で依存関係を配線した場合と同等の速度で動作します。

## 基本概念：最初の一歩

Ray.Diを理解するには、まず簡単な例から始めましょう。インストールは他のComposerパッケージと同様です：

```bash
composer require ray/di
```

### 依存性注入の基本パターン

挨拶メッセージを生成する簡単なアプリケーションを考えてみましょう。言語によって異なる挨拶を返す必要があります：

```php
<?php
use Ray\Di\Injector;
use Ray\Di\AbstractModule;

interface GreetingServiceInterface
{
    public function greet(string $name): string;
}

class EnglishGreetingService implements GreetingServiceInterface
{
    public function greet(string $name): string
    {
        return "Hello, {$name}!";
    }
}

class HelloWorld
{
    public function __construct(
        private GreetingServiceInterface $greetingService
    ) {}

    public function sayHello(string $name): string
    {
        return $this->greetingService->greet($name);
    }
}
```

ここで重要なのは、`HelloWorld`クラスが`EnglishGreetingService`に直接依存していないことです。インターフェースに依存することで、実装を自由に差し替えられます。

### モジュールによる設定

Ray.Diの設定は「モジュール」という単位で行います。モジュールは、インターフェースと実装の関係を定義する場所です：

```php
$injector = new Injector(new class extends AbstractModule {
    protected function configure(): void
    {
        $this->bind(GreetingServiceInterface::class)->to(EnglishGreetingService::class);
    }
});

$helloWorld = $injector->getInstance(HelloWorld::class);
echo $helloWorld->sayHello('World'); // "Hello, World!"
```

この設定により、「`GreetingServiceInterface`を要求されたら`EnglishGreetingService`を提供する」というルールが確立されます。日本語の挨拶に変更したければ、モジュールの設定を変更するだけです。ビジネスロジックには一切触れません。

## モジュール設計の実践

実際のアプリケーションでは、設定が増えてきます。Ray.Diのモジュールシステムは、この複雑性を管理するための強力な仕組みを提供します。

モジュールは関心事ごとに分割できます。データベース関連の設定、メール送信の設定、ビジネスロジックの設定を別々のモジュールに分けることで、各モジュールが単一の責任を持つようになります：

```php
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(DatabaseConnectionInterface::class)
             ->to(MySQLConnection::class)
             ->in(Singleton::class);

        $this->bind(UserRepositoryInterface::class)
             ->to(MySQLUserRepository::class);
    }
}

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->install(new DatabaseModule());
        $this->install(new EmailModule());
        $this->bind(OrderServiceInterface::class)->to(OrderService::class);
    }
}
```

`install()`メソッドにより、モジュールを組み合わせて使用できます。これは単なる設定の分割ではありません。各モジュールが独立してテスト可能になり、異なるプロジェクト間で再利用できるようになります。

## バインディングパターンの活用

Ray.Diは様々なバインディングパターンを提供し、それぞれが特定の問題を解決します。

最も基本的なパターンは、インターフェースを実装にバインドすることです。しかし、実際のアプリケーションでは、より複雑なニーズが発生します。設定値を注入したい場合はインスタンスバインディングを使用します。オブジェクトの生成に複雑なロジックが必要な場合はプロバイダーを使用します。

```php
// 設定値のインスタンスバインディング
$config = new AppConfig(['database' => 'mysql://localhost/myapp']);
$this->bind(AppConfig::class)->toInstance($config);

// 複雑な初期化が必要な場合のプロバイダー
$this->bind(DatabaseConnectionInterface::class)
     ->toProvider(DatabaseConnectionProvider::class);
```

特に強力なのが注釈付きバインディングです。同じインターフェースに対して複数の実装が必要な場合、`@Named`アトリビュートで区別できます：

```php
class OrderService
{
    public function __construct(
        #[Named('file')] private LoggerInterface $fileLogger,
        #[Named('email')] private LoggerInterface $emailLogger
    ) {}
}
```

この機能により、「ファイルログ」と「メールログ」という異なる目的のロガーを明確に区別できます。文字列ベースのサービスロケーターとは異なり、型安全性は維持されます。

## インジェクション方式の選択

Ray.Diは主にコンストラクタインジェクションを推奨しています。これには明確な理由があります。コンストラクタインジェクションは、オブジェクトが生成された時点ですべての依存関係が満たされることを保証します。不完全な状態のオブジェクトが存在することがありません。

```php
class OrderService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private PaymentServiceInterface $paymentService
    ) {}
}
```

メソッドインジェクションは、オプショナルな依存関係や循環依存を解決する場合に使用できます。しかし、Ray.Diではプロパティインジェクションを意図的にサポートしていません。これは、プロパティインジェクションがカプセル化を破壊し、オブジェクトの不完全な状態を許容してしまうためです。

## オブジェクトのライフサイクル管理

オブジェクトをいつ作成し、どのくらいの期間保持するかは、アプリケーションのパフォーマンスとメモリ使用量に大きく影響します。Ray.Diは2つのスコープを提供します。

デフォルトのプロトタイプスコープでは、依存関係が要求されるたびに新しいインスタンスが作成されます。これは状態を持たないサービスやリクエストごとに異なる状態を持つ必要があるオブジェクトに適しています。

一方、シングルトンスコープは、アプリケーション全体で1つのインスタンスを共有します：

```php
$this->bind(DatabaseConnectionInterface::class)
    ->to(MySQLConnection::class)
    ->in(Singleton::class);
```

データベース接続やログ記録器など、作成コストが高く、状態を共有しても安全なオブジェクトにはシングルトンスコープが適しています。ただし、シングルトンは慎重に使用する必要があります。グローバル状態を作り出し、テストを困難にする可能性があるためです。

## 環境に応じた設定の切り替え

実際のアプリケーションでは、開発環境と本番環境で異なる設定が必要です。開発環境ではメモリキャッシュを使い、本番環境ではRedisを使う。開発環境ではメールを実際に送信せず、本番環境では実際に送信する。Ray.Diはこれらの要求をエレガントに解決します。

環境ごとに異なるモジュールを作成し、起動時に適切なモジュールを選択するだけです：

```php
$module = getenv('APP_ENV') === 'production'
    ? new ProductionModule()
    : new DevelopmentModule();
$injector = new Injector($module);
```

この方法により、環境固有の設定がコード全体に散らばることを防げます。すべての環境差異が明確にモジュールとして表現されます。

## テスト戦略

依存性注入の最大の利点の一つは、テストの容易さです。Ray.Diを使えば、本番用の複雑な依存関係を、テスト用の軽量な実装に簡単に置き換えられます。

```php
class TestModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)->to(InMemoryUserRepository::class);
        $this->bind(EmailServiceInterface::class)->to(MockEmailService::class);
    }
}
```

テストでは、このTestModuleを使用してインジェクターを構築します。データベース接続なし、外部APIなし、副作用なし。純粋にビジネスロジックのテストに集中できます。


## 実践例：すべてを統合する

ここまでの概念を統合した実践的な例を見てみましょう。注文処理サービスを構築します：

```php
class OrderService
{
    public function __construct(
        private PaymentServiceInterface $paymentService,
        private EmailServiceInterface $emailService,
        #[Named('audit')] private LoggerInterface $logger
    ) {}

    public function processOrder(Order $order): void
    {
        $this->logger->info("Processing order: {$order->id}");
        $this->paymentService->charge($order->total);
        $this->emailService->sendConfirmation($order);
    }
}

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // 環境に応じた支払いサービス
        $paymentImpl = $_ENV['APP_ENV'] === 'production'
            ? StripePaymentService::class
            : MockPaymentService::class;

        $this->bind(PaymentServiceInterface::class)->to($paymentImpl);
        $this->bind(EmailServiceInterface::class)->to(SendGridEmailService::class);
        $this->bind(LoggerInterface::class)
             ->annotatedWith('audit')
             ->to(FileLogger::class)
             ->in(Singleton::class);
    }
}
```

この例は、Ray.Diの主要な機能を示しています。インターフェースへの依存により、支払いサービスを環境に応じて切り替えています。名前付きバインディングで監査用ログを区別しています。シングルトンスコープでログインスタンスを共有しています。

## 設計のベストプラクティス

Ray.Diを効果的に使うには、いくつかの重要な原則があります。

まず、常にインターフェースに対してプログラムすることです。具象クラスを直接バインドすると、テストが困難になり、実装の切り替えができなくなります。インターフェースを使うことで、実装の詳細から使用側を解放できます。

次に、モジュールを適切な粒度で分割することです。すべてを1つの巨大なモジュールに入れるのではなく、関心事ごとにモジュールを分けます。データベース設定、メール設定、ビジネスロジックの設定を別々のモジュールにすることで、各モジュールが単一の責任を持つようになります。

最後に、依存関係を最小限に保つことです。クラスが必要とする依存関係だけを注入します。「念のため」という理由で不要な依存関係を追加すると、テストが複雑になり、コードの理解が困難になります。

## まとめ

Ray.DiはGoogle Guiceの設計哲学をPHPに持ち込み、型安全で明示的な依存性注入を実現します。文字列ベースのサービスロケーターとは異なり、IDEの完全なサポートを受けられ、設定ミスは実行前に検出されます。

設定を最適化されたPHPコードにコンパイルすることで、実行時のオーバーヘッドを実質ゼロにします。環境ごとの設定切り替え、テスト用のモック注入、複雑な初期化ロジックの管理など、実際のアプリケーション開発に必要な機能をすべて備えています。

この明示性と型安全性こそが、大規模なアプリケーションでも保守性とテスト可能性を保証する鍵となります。

---

**次へ：** [基本的なバインディング](../02-basic-bindings/linked-binding.html)

**前へ：** [SOLID原則の実践](solid-principles.html)
