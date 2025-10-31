---
layout: docs-ja
title: 依存注入の原則
category: Manual
permalink: /manuals/1.0/ja/study/01-foundations/dependency-injection-principles.html
---

# 依存注入の原則

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- 依存注入とは何か、そしてその第一の目的は保守しやすいソフトウェアの構築であること
  - テスト容易性はDIの重要な利点だが、それは保守性向上という本来の目的の副次的な効果
- DIがソフトウェア設計で解決する問題
- 制御の反転（IoC）の中核原則と、DIがIoCを実現する具体的な手法であること
- DIがより良いソフトウェアアーキテクチャを可能にする方法
- DIとSOLID原則の関係、そしてDIが優れたオブジェクト指向プログラミングのスキル向上につながること

## 問題：密結合（Tight Coupling）

ソフトウェア開発でよくある問題から始めます。E-commerceプラットフォームを構築していて、注文確認メールを送信する必要があるとします：

```php
class OrderService
{
    public function processOrder(Order $order): void
    {
        // 注文の検証
        if (!$this->validateOrder($order)) {
            throw new InvalidOrderException();
        }
        
        // データベースに保存
        $database = new MySQLDatabase();
        $database->save($order);
        
        // 確認メールを送信
        $emailService = new SMTPEmailService();
        $emailService->send(
            $order->getCustomerEmail(),
            'Order Confirmation',
            $this->generateOrderEmail($order)
        );
        
        // トランザクションをログに記録
        $logger = new FileLogger('/var/log/orders.log');
        $logger->info("Order {$order->getId()} processed successfully");
    }
}
```

### 問題点

このコードは**密結合**を示しています。コードの保守を困難にするいくつかの問題があります：

1. **ハード依存性**: `OrderService`が`MySQLDatabase`、`SMTPEmailService`、`FileLogger`を直接作成
2. **テストの困難さ**: 具象クラスに直接依存しているため、モックオブジェクトに置き換えることができません。実際にメールを送信したりファイルに書き込んだりせずに単体テストを行う方法がありません
3. **柔軟性の欠如**: MySQLからPostgreSQLに変更したい場合や、SMTPからSendGridに変更したい場合に対応が困難です
4. **SOLID原則の違反**: クラスが変更される理由が複数ある

## 解決策：依存注入（Dependency Injection）

これらの問題を解決する鍵は、オブジェクトの作成責任をどこに置くかを見直すことです。

依存注入は、オブジェクトの作成と管理の制御を反転（Inversion of Control）させることで、これらの問題を解決します。先ほどの`OrderService`の例では、オブジェクトが`new`演算子を使って自ら依存関係を作成していました。これは Control Freak（制御魔）アンチパターンと呼ばれます。

Control Freakとは、オブジェクトが協力者（依存関係）の作成に対して過度な制御を取ろうとする状態です。`OrderService`が「MySQLDatabaseを使う」「SMTPでメールを送る」「ファイルにログを書く」という具体的な実装の詳細まで知り、制御しようとしています。これにより、`OrderService`は本来の責任（注文処理のビジネスロジック）だけでなく、インフラストラクチャの構築責任まで負ってしまいます。

DIは依存関係を外部から提供することで、このアンチパターンを排除します：

```php
interface DatabaseInterface
{
    public function save(Order $order): void;
}

interface EmailServiceInterface
{
    public function send(string $to, string $subject, string $body): void;
}

interface LoggerInterface
{
    public function info(string $message): void;
}

class OrderService
{
    public function __construct(
        private DatabaseInterface $database,
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}
    
    public function processOrder(Order $order): void
    {
        // 注文の検証
        if (!$this->validateOrder($order)) {
            throw new InvalidOrderException();
        }
        
        // データベースに保存
        $this->database->save($order);
        
        // 確認メールを送信
        $this->emailService->send(
            $order->getCustomerEmail(),
            'Order Confirmation',
            $this->generateOrderEmail($order)
        );
        
        // トランザクションをログに記録
        $this->logger->info("Order {$order->getId()} processed successfully");
    }
}
```

### 達成された利点

1. **疎結合（Loose Coupling）**: `OrderService`は抽象化に依存し、具象実装に依存しない
2. **テスト可能性（Testability）**: テスト用にモックオブジェクトを簡単に注入できる
3. **柔軟性（Flexibility）**: `OrderService`を変更せずに実装を切り替えられる
4. **単一責任（Single Responsibility）**: 各クラスが変更される理由は一つ
5. **オープン・クローズド原則（Open/Closed Principle）**: 拡張に対してオープン、変更に対してクローズド
6. **遅延バインディング（Late Binding）**: どの実装を使用するかの決定を、アプリケーション起動時や設定時まで遅延できる
7. **拡張容易性（Extensibility）**: 既存のコードを変更せずに新機能を追加できる

## 制御の反転（Inversion of Control / IoC）

ここまでで、依存注入が「依存関係を外部から注入する」技法であることを見てきました。しかし、なぜこれが有効なのでしょうか？その根底にある原理を理解するために、制御の反転（Inversion of Control、IoC）という概念を見ていきましょう。

制御の反転とは、「誰がオブジェクトの作成と管理を制御するか」という責任の所在を反転させることを意味します。

### 従来のプログラミング：オブジェクトが制御を持つ

通常のオブジェクト指向プログラミングでは、オブジェクト自身が必要な依存関係を作成し、管理します：

```
オブジェクトAが主導権を持つ
  ↓
オブジェクトAが「オブジェクトBが必要だ」と判断
  ↓
オブジェクトAがオブジェクトBを new で作成
  ↓
オブジェクトAがオブジェクトBのライフサイクルを管理
  ↓
オブジェクトAはオブジェクトBの具象型（MySQLDatabaseなど）を知っている
```

これは一見自然に見えますが、オブジェクトAが「どのように作るか」という実装の詳細を知る必要があり、密結合を生み出します。

### IoC：制御をコンテナに移譲

制御の反転では、オブジェクトの作成と管理の責任を、外部のコンテナ（DIコンテナ）に委ねます：

```
DIコンテナが主導権を持つ
  ↓
コンテナがコンストラクタの型宣言から「オブジェクトAにはオブジェクトBが必要だ」と理解
  ↓
コンテナがModule（バインディング設定）から「オブジェクトBの実装」を決定
  ↓
コンテナがオブジェクトBを作成
  ↓
コンテナがオブジェクトBをオブジェクトAに注入
  ↓
オブジェクトAはオブジェクトBのインターフェースのみを知っている（具象型は知らない）
```

この「反転」により、オブジェクトAは「何が必要か」をコンストラクタの型宣言で示し、「どのように作るか」「どの実装を使うか」はコンテナとModule設定に任せられます。これが**制御の反転**の本質です。

### 例：IoC前後の比較

具体的なコードで見てみましょう。

**IoC前（オブジェクトが自ら依存関係を作成）:**
```php
class UserService
{
    private $repository;

    public function __construct()
    {
        // ❌ UserServiceが「MySQLUserRepository」という具体的な実装を知っている
        // ❌ UserServiceが作成のタイミングと方法を制御している
        $this->repository = new MySQLUserRepository();
    }
}
```

この方式では、`UserService`が「MySQLを使う」という実装の詳細まで知る必要があります。PostgreSQLに変更したければ、このクラス自体を修正しなければなりません。

**IoC後（依存関係が外部から注入される）:**
```php
class UserService
{
    public function __construct(
        private UserRepositoryInterface $repository // ✅ インターフェースのみを知る
    ) {
        // ✅ コンストラクタはただ受け取るだけ
        // ✅ コンテナが作成と注入を制御
        // ✅ UserServiceは「何」が必要かだけを宣言し、「どのように」は知らない
    }
}
```

この方式では、`UserService`は「`UserRepositoryInterface`を実装した何か」が必要だと宣言するだけです。実際に`MySQLUserRepository`が注入されるのか、`PostgreSQLUserRepository`が注入されるのかは、外部の設定（DIコンテナ）で決まります。制御が反転しています。

## Pure DIとコンポジションルート

制御の反転という原則を理解したところで、実際にどのように依存関係を組み立てるかを見ていきましょう。

DIの原則は、DIコンテナ（Ray.Diのようなフレームワーク）がなくても実践できます。これを Pure DI（純粋なDI）と呼びます。

### Pure DIの例

```php
// Pure DI: DIコンテナなしで依存関係を手動配線
$database = new MySQLDatabase('localhost', 'myapp', 'user', 'pass');
$emailService = new SMTPEmailService('smtp.example.com', 587);
$logger = new FileLogger('/var/log/app.log');

$orderService = new OrderService($database, $emailService, $logger);
```

この手動配線は小規模なアプリケーションでは十分に機能します。しかし、アプリケーションが成長するにつれて、保守性の問題が顕在化します。

例えば、アプリケーション全体で使われている`LoggerInterface`の実装を`FileLogger`から`CloudLogger`に変更したいとします。Pure DIでは、すべてのコンポジションルートで`new FileLogger()`を探し出し、`new CloudLogger()`に書き換える必要があります。もし100箇所で手動配線していれば、100箇所すべてを修正しなければなりません。1箇所でも見逃せば、本番環境で異なるロガーが混在してしまいます。

さらに、シングルトンとして扱うべきオブジェクト（データベース接続など）を手動で管理するのも困難です。同じインスタンスを再利用すべき場所と、新しいインスタンスを作成すべき場所を、開発者が常に意識して正しく実装する必要があります。これはヒューマンエラーの温床となります。

### コンポジションルート（Composition Root）

**コンポジションルート**は、アプリケーションのエントリーポイントで、すべての依存関係を組み立てる唯一の場所です。これはPure DIでもDIコンテナを使用する場合でも同じ概念です：

```php
// index.php - コンポジションルート
require_once 'vendor/autoload.php';

use Ray\Di\Injector;

// DIコンテナの設定（コンポジションルート）
$injector = new Injector(new AppModule());

// アプリケーションのルートオブジェクトを取得
$app = $injector->getInstance(Application::class);

// アプリケーションを実行
$app->run();
```

**重要な原則**:

コンポジションルートはアプリケーションの最も外側の層、つまりエントリーポイント（`index.php`や`bootstrap.php`など）に配置します。ビジネスロジックやドメイン層のコードが、DIコンテナへの直接の参照を持つことは避けるべきです。また、コンポジションルート以外の場所で`new`演算子を使ってオブジェクトを作成することは推奨されません（ただし、実行時パラメータが必要な場合のFactoryパターンは例外です）。

### DIコンテナの役割

DIコンテナ（Ray.Di）は、この手動配線作業を自動化し、さらに付加価値を提供します。

コンストラクタの型宣言からインターフェースを読み取り、Moduleで設定されたバインディングに基づいて適切な実装を自動的に注入します。この自動配線により、開発者は依存関係の組み立てコードを書く必要がありません。

シングルトンやプロトタイプなどのスコープを管理し、同じインスタンスを再利用すべきか、毎回新しいインスタンスを作成すべきかを制御します。これにより、オブジェクトのライフサイクルを一貫して管理できます。

アプリケーション起動時にバインディングの不整合や循環依存を検出し、実行前にエラーを発見できます。実行時ではなく起動時に問題を検出することで、本番環境での予期しないエラーを防ぎます。

依存関係グラフをキャッシュし、最適化されたPHPコードとして生成することで、実行時のオーバーヘッドを最小化します。Ray.Diは、開発時の柔軟性と本番環境でのパフォーマンスを両立させます。

```php
// Pure DI（手動）- ロガーの実装変更が大変
$validator = new OrderValidator();
$calculator = new PriceCalculator();
$database = new MySQLDatabase('localhost', 'shop', 'user', 'pass');
$repository = new OrderRepository($database);
$emailService = new SMTPEmailService('smtp.example.com', 587);
$logger = new FileLogger('/var/log/orders.log'); // ここを変更すると...
$orderService = new OrderService($validator, $calculator, $repository, $emailService, $logger);
// アプリケーション中の全ての箇所を変更する必要がある

// DIコンテナ使用（自動化）- 1箇所の変更で済む
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // ここを変更するだけで、アプリケーション全体に反映される
        $this->bind(LoggerInterface::class)->to(CloudLogger::class);
    }
}

$injector = new Injector(new AppModule());
$orderService = $injector->getInstance(OrderService::class);
// すべての依存関係が自動的に解決され、一貫したロガーが注入される
```

DIコンテナは、Pure DIの原則を保ちながら、実装の変更を一箇所の設定変更で実現し、複雑性を管理し、保守性を劇的に向上させるツールです。

## 依存注入のタイプ

依存関係を注入する方法にはいくつかのパターンがあります。それぞれの特徴を理解し、適切な場面で使い分けることが重要です。

### 1. コンストラクタ注入（Constructor Injection）- 推奨

```php
class ProductService
{
    public function __construct(
        private ProductRepositoryInterface $repository,
        private CacheInterface $cache
    ) {}
}
```

**メリット:**
- 依存関係が明確で必須
- 構築後は不変（Immutable）
- 依存関係が欠落している場合、高速に失敗（Fail Fast）

### 2. メソッド注入（Method Injection）

```php
class ProductService
{
    public function findProduct(int $id, LoggerInterface $logger): Product
    {
        $logger->info("Finding product: $id");
        return $this->repository->find($id);
    }
}
```

**用途:**
- オプショナルな依存関係
- メソッド呼び出しごとに異なる依存関係

### 3. プロパティ注入（Property Injection）- Ray.Diでは未対応

```php
class ProductService
{
    public LoggerInterface $logger; // ここに直接インジェクトされる
}
```

**重要：Ray.Diではプロパティ注入をサポートしていません。**

これはRay.Diの設計哲学に基づく意図的な制限です。プロパティ注入には以下の問題があります：

1. **オブジェクトの不完全な状態を許容してしまう**：コンストラクタ注入では、依存関係がすべて満たされるまでオブジェクトが構築されません。しかしプロパティ注入では、依存関係が注入される前にオブジェクトが存在してしまい、不完全な状態のオブジェクトが使用されるリスクがあります。

2. **依存関係の必須性が不明確**：コンストラクタのシグネチャを見れば必須の依存関係が明確ですが、プロパティ注入ではオプショナルなのか必須なのかが不明瞭です。

3. **不変性（Immutability）を破る**：プロパティ注入では依存関係が後から変更可能になり、オブジェクトの予測可能性が低下します。コンストラクタ注入は、オブジェクト構築後の依存関係の不変性を保証します。

Google Guiceにおいても、プロパティ注入（Field Injection）を避けるべきだという[議論](https://github.com/google/guice/wiki/InjectionPoints#field-injection)があり、「Field injectionを避け、constructor injectionを優先すべき」と明記されています。

Ray.Diでは代わりにコンストラクタ注入の使用を強く推奨しています。これにより、オブジェクトは常に完全な状態で構築され、依存関係が明示的で、不変性が保たれます。

## DIの設計哲学：変更を前提とした構造設計

ここまで、依存注入の技術的な側面—制御の反転、Pure DI、注入のタイプ—を見てきました。しかし、DIの真の価値は技術的なメカニズムだけにあるのではありません。DIは、ソフトウェア開発に対する根本的な考え方の転換をもたらします。

依存注入は単なるテスト技法ではありません。それは複雑さと変化を制御するための設計哲学です。

### プログラムを「オブジェクトグラフ」として捉える

従来のプログラミングでは、コードを「命令の集まり」として見てきました。しかしDIでは、プログラムをオブジェクトグラフ（Object Graph）—オブジェクト間の依存関係のネットワーク—として捉えます。クラスAがクラスBに依存し、クラスBがクラスCに依存する。この依存関係のグラフこそが、ソフトウェアの真の構造です。

```php
// 命令の集まりとしての視点
$database = new MySQLDatabase();
$repository = new OrderRepository($database);
$service = new OrderService($repository);

// オブジェクトグラフとしての視点
OrderService → OrderRepositoryInterface → DatabaseInterface
    ↓              ↓                        ↓
  実装詳細      実装詳細                  実装詳細
```

重要なのは、このオブジェクトグラフが非循環（ADP: Acyclic Dependencies Principle）を維持しながら、疎結合（Loose Coupling）な構造を持つことです。ソフトウェアとは、この性質を満たすオブジェクトグラフの設計そのものと言えます。循環依存のない有向非巡回グラフ（DAG）により、変更の影響が一方向にのみ伝播し、制御可能になります。

### 依存関係を「制御可能な設計要素」として扱う

DIは、依存関係を暗黙的なハードコーディングから、明示的で制御可能な設計要素へと変えます。

```php
// 暗黙的（制御不可能）
class OrderService
{
    public function __construct()
    {
        $this->repository = new MySQLOrderRepository(); // 変更不可能
    }
}

// 明示的（制御可能）
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $repository // 設計要素として制御可能
    ) {}
}
```

この明示化により、チームは依存制御の思考の枠組みを共有できます。レビュー時に「なぜこのクラスはこれに依存するのか」「この依存関係は適切か」という議論が可能になります。

### コーディングに秩序をもたらす構造

DIは、ソフトウェアの書き方に一定の秩序をもたらします。従来のプログラミングでは、どこからでも、どの道具（オブジェクト）でも自由に呼び出せました。この自由度は柔軟性に見えますが、実際には無秩序を生み出していました。

DIは明確なパターンを確立します。必要な依存関係はコンストラクタで宣言し、各メソッドではそれらを使用するというスタイルです。

```php
class OrderService
{
    // 構造的規律：必要なものはすべてコンストラクタで宣言
    public function __construct(
        private OrderRepositoryInterface $repository,
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}

    // 各メソッドは準備された依存関係だけを使う
    public function processOrder(Order $order): void
    {
        $this->repository->save($order);      // コンストラクタで準備済み
        $this->emailService->send(...);       // コンストラクタで準備済み
        $this->logger->info(...);             // コンストラクタで準備済み
    }
}
```

この構造的規律がもたらす具体的な恩恵は明確です。コンストラクタを見れば、そのクラスがどの依存関係を必要とするかが一目でわかります。依存関係が揃わなければ、コンストラクタで早期にエラーが発生し、実行時の予期しない失敗を防げます。メソッド内で突然新しいオブジェクトが作られることもなく、コードの動作が予測可能になります。

この秩序は、チーム開発において特に価値があります。コードレビューの際、コンストラクタを見るだけで、そのクラスの責任範囲と依存関係の妥当性を判断できます。新しいメンバーがコードを読む際も、コンストラクタという明確な「入り口」から理解を始められます。

### オブジェクト合成（Object Composition）による柔軟性

DIは、継承ではなくオブジェクト合成による設計を促進します。オブジェクトを小さな部品に分割し、それらを組み合わせることで複雑な振る舞いを実現します：

```php
// 継承による拡張（硬直的）
class OrderService extends BaseService { }
class PremiumOrderService extends OrderService { }
class ExpressOrderService extends PremiumOrderService { } // 継承階層が深くなる

// 合成による拡張（柔軟）
class OrderService
{
    public function __construct(
        private OrderValidatorInterface $validator,     // 部品1
        private PricingStrategyInterface $pricing,      // 部品2
        private NotificationInterface $notification     // 部品3
    ) {}
}

// 部品を差し替えるだけで異なる振る舞いを実現
new OrderService(
    new PremiumValidator(),
    new DynamicPricing(),
    new CompositeNotification([new Email(), new SMS()])
);
```

合成により、実行時に振る舞いを変更でき、テストも容易になります。何より、変更の影響範囲が局所化されます。

### 非循環依存関係の原則（ADP: Acyclic Dependencies Principle）

依存制御のもう一つの重要な側面は、循環依存を排除することです：

```php
// ❌ 循環依存（悪い設計）
class OrderService
{
    public function __construct(private InvoiceService $invoice) {}
}

class InvoiceService
{
    public function __construct(private OrderService $order) {} // 循環！
}

// ✅ 依存の方向を一方向に
interface InvoiceEventInterface { }

class OrderService
{
    public function __construct(
        private InvoiceEventInterface $invoiceEvent // インターフェースに依存
    ) {}
}

class InvoiceService implements InvoiceEventInterface
{
    // OrderServiceには依存しない
}
```

ADPにより、依存関係グラフが有向非巡回グラフ（DAG: Directed Acyclic Graph）となり、変更の影響が一方向にのみ伝播します。これは複雑さの制御において極めて重要です。

### ソフトウェア開発 = 変更を前提とした構造設計

DIの本質は、「変更が起こる」という避けられない現実を受け入れ、その変更を構造レベルでコントロールすることにあります。

依存関係が暗黙的にハードコーディングされているコードでは、「この一行を変えたら、どこに影響が及ぶのか」を把握するのが困難です。実装の詳細が複数の箇所に散在し、変更が予期しない場所に波及する可能性があります。しかし依存関係を明示的に制御すると、変更の影響範囲が可視化されます。ある実装を変更しても、それが依存するインターフェースを変えなければ、依存する側には影響しません。逆に、インターフェースを変更すれば、影響を受ける箇所がコンパイラやIDEによって即座に判明します。

さらに重要なのは、新しい要件への対応方法の変化です。従来の設計では、新機能を追加する際に既存のコードを修正する必要がありました。しかしDIでは、新しい実装クラスを追加し、それをバインディング設定で指定するだけで済みます。既存のビジネスロジックには一切手を触れず、新機能を導入できるのです。これは、Open/Closed Principle（開放/閉鎖原則）の実践そのものです。

そして、依存関係が明示的になることで、チームメンバー全員が同じ構造を理解できるようになります。コードレビューで「なぜこのクラスは、このインターフェースに依存するのか」「この依存関係は適切か、それとも設計の臭いか」という建設的な議論が可能になります。依存関係という共通言語を通じて、設計の意図を伝え、改善の方向性を共有できるのです。

テスト容易性は、この設計哲学がもたらす副次的な恩恵にすぎません。変更の影響範囲が制御され、部品が差し替え可能な構造を持つコードは、必然的にテストしやすくなります。テストとは「本番の実装をテスト用の実装に差し替える」行為です。DIで設計されたコードは、差し替え可能性を中核に持つため、テストは特別な努力を要する作業ではなく、設計が自然にもたらす帰結となります。

---

**次へ：** [SOLID原則の実践](solid-principles.html) - DIがより良い設計を可能にする方法

**関連：** [Ray.Diの基礎](raydi-fundamentals.html) - フレームワークの具体的なアプローチ
