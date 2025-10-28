---
layout: docs-ja
title: SOLID原則の実践
category: Manual
permalink: /manuals/1.0/ja/tutorial/01-foundations/solid-principles.html
---

# SOLID原則の実践：保守可能なコードへの道

## 問題：変更が連鎖する脆弱なコード

新機能を追加するたびに、予期しない場所でバグが発生していませんか？「支払い方法にPayPalを追加したら、なぜかメール送信が壊れた」という経験はありませんか？これは、コードが密結合し、責任が混在し、抽象化が不適切なときに起こる典型的な症状です。

SOLID原則は、これらの根本的な設計問題を解決するための5つの指針です。抽象的な理論ではなく、日々の開発で直面する具体的な問題への実践的な解答です。依存性注入と組み合わせることで、変更に強く、拡張しやすく、テスト可能なコードを実現します。

## 単一責任原則（SRP）- 変更理由を1つに

ユーザー登録を処理するクラスを考えてみましょう。このクラスがデータベース保存、メール送信、ログ記録をすべて直接処理していたらどうなるでしょうか？

```php
// ❌ 問題：すべてを自分でやろうとするクラス
class UserManager
{
    public function createUser(string $email, string $password): User
    {
        $user = new User($email, $this->hashPassword($password));

        // データベース処理、メール送信、ログ記録が混在
        $pdo = new PDO('mysql:host=localhost;dbname=app', 'user', 'pass');
        $stmt = $pdo->prepare('INSERT INTO users...');
        $stmt->execute([...]);

        $mailer = new PHPMailer();
        $mailer->send();

        error_log("User created: " . $email);

        return $user;
    }
}
```

これは保守性に関する根本的な問題を生み出します。メールサービスをSendGridに変更する際、なぜユーザー作成ロジックに触れる必要があるのでしょうか？データベースをPostgreSQLに変更する際、ビジネスロジックのテストが壊れるべきでしょうか？

単一責任原則は、各クラスに1つの明確な責任を与えることで、この問題を解決します：

```php
// ✅ 解決：責任を分離し、依存性を注入
class UserService
{
    public function __construct(
        private UserRepositoryInterface $repository,
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}

    public function createUser(string $email, string $password): User
    {
        $user = new User($email, $this->hashPassword($password));

        $this->repository->save($user);
        $this->emailService->sendWelcome($user);
        $this->logger->info("User created: {$email}");

        return $user;
    }
}
```

なぜこれが重要なのでしょうか？メール送信の実装を変更しても、UserServiceには一切触れません。データベースを変更しても、ビジネスロジックは影響を受けません。各クラスが1つの責任に集中することで、変更の影響範囲が明確になり、予期しないバグを防げます。

### Constructor Over-Injection（コンストラクタ過剰注入）- 設計の臭い

**重要な警告**: コンストラクタが多くの依存関係（一般的に4つ以上）を受け取る場合、それは**Constructor Over-Injection**という**設計の臭い（Code Smell）**です。これは単一責任原則（SRP）に違反している兆候です：

```php
// ⚠️ 警告：コンストラクタが多すぎる依存関係を受け取っている
class OrderService
{
    public function __construct(
        private OrderValidatorInterface $validator,
        private PriceCalculatorInterface $calculator,
        private OrderRepositoryInterface $repository,
        private EmailServiceInterface $emailService,
        private SMSServiceInterface $smsService,
        private LoggerInterface $logger,
        private MetricsCollectorInterface $metrics,
        private AuditLogInterface $auditLog,
        private InventoryServiceInterface $inventory
    ) {} // 9つの依存関係 - これは多すぎる！
}
```

**この問題が示唆すること**:
1. クラスが複数の責任を持っている（SRP違反）
2. クラスが大きすぎる（リファクタリングが必要）
3. 抽象化レベルが適切でない

**解決策**:
1. **責任を分離**: クラスをより小さな、単一責任のクラスに分割する
2. **ファサードパターン**: 関連する依存関係をファサードとしてグループ化する
3. **抽象化レベルの見直し**: より高レベルの抽象化を導入する

```php
// ✅ 改善例：責任を分離
class OrderValidator
{
    public function __construct(
        private ValidationRulesInterface $rules,
        private LoggerInterface $logger
    ) {}
}

class OrderNotifier
{
    public function __construct(
        private EmailServiceInterface $emailService,
        private SMSServiceInterface $smsService
    ) {}
}

class OrderProcessor
{
    public function __construct(
        private OrderRepositoryInterface $repository,
        private InventoryServiceInterface $inventory,
        private MetricsCollectorInterface $metrics
    ) {}
}

// OrderServiceは高レベルの調整のみを行う
class OrderService
{
    public function __construct(
        private OrderValidator $validator,      // 3つのファサード
        private OrderNotifier $notifier,        // より明確で保守しやすい
        private OrderProcessor $processor
    ) {}
}
```

依存関係の数が増えたら、それは設計を見直すシグナルです。DIはコードの設計問題を可視化し、より良い設計へと導く道しるべとなります。

## オープン・クローズド原則（OCP）- 拡張に開き、変更に閉じる

ECサイトの割引計算を考えてみましょう。新しい割引タイプを追加するたびに、既存のコードを修正していませんか？

```php
// ❌ 問題：新機能のたびに既存コードを修正
class OrderCalculator
{
    public function calculateDiscount(Order $order): float
    {
        switch ($order->getCustomerType()) {
            case 'student': return $order->getTotal() * 0.1;
            case 'senior': return $order->getTotal() * 0.15;
            case 'employee': return $order->getTotal() * 0.2;
            // 新しい割引タイプのたびにここを修正...
        }
    }
}
```

これは機能追加と既存機能の安定性の間に根本的な緊張関係を生み出します。ブラックフライデー割引を追加したら、なぜか学生割引が壊れた—こんな経験はありませんか？

オープン・クローズド原則は、既存コードを変更せずに新機能を追加できるようにします：

```php
// ✅ 解決：Strategyパターンで拡張可能に
interface DiscountStrategy {
    public function calculate(Order $order): float;
    public function supports(string $customerType): bool;
}

class OrderCalculator {
    public function __construct(private array $strategies) {}

    public function calculateDiscount(Order $order): float {
        foreach ($this->strategies as $strategy) {
            if ($strategy->supports($order->getCustomerType())) {
                return $strategy->calculate($order);
            }
        }
        return 0;
    }
}
```

新しい割引タイプ？新しいStrategyクラスを追加するだけです。既存のコードには一切触れません。これにより、既存機能の安定性を保ちながら、新機能を安全に追加できます。

## リスコフの置換原則（LSP）- 期待通りに動く置換可能性

基底クラスを期待するコードに派生クラスを渡したとき、プログラムが正しく動作しなくなったことはありませんか？「ShapeインターフェースにはgetArea()があるはずなのに、なぜエラーになるんだ」という経験はありませんか？これは派生クラスが基底クラスの契約を守っていないときに起こる典型的な症状です。

```php
// ✅ 正しいLSP：すべての派生クラスが基底クラスの契約を守る
abstract class Shape
{
    abstract public function getArea(): float;
}

class Circle extends Shape
{
    public function __construct(private float $radius) {}

    public function getArea(): float
    {
        return pi() * $this->radius ** 2;
    }
}

class Rectangle extends Shape
{
    public function __construct(
        private float $width,
        private float $height
    ) {}

    public function getArea(): float
    {
        return $this->width * $this->height;
    }
}

// Shapeを期待するコードはどの派生クラスでも動作する
function calculateTotalArea(array $shapes): float
{
    $total = 0;
    foreach ($shapes as $shape) {
        $total += $shape->getArea(); // CircleでもRectangleでも動作
    }
    return $total;
}
```

この例では、`Circle`も`Rectangle`も`Shape`の契約（getArea()メソッドを持つ）を完全に守っています。どちらのクラスも`Shape`として扱えます。

リスコフの置換原則は、派生クラスが基底クラスの契約を完全に守ることを要求します。契約には、メソッドシグネチャだけでなく、事前条件（メソッドが呼ばれる前提）、事後条件（メソッドが保証する結果）、不変条件（クラスが常に満たす条件）が含まれます。派生クラスは、事前条件を強めてはいけません。事後条件を弱めてはいけません。基底クラスで確立された振る舞いを維持しなければなりません。

なぜこれが重要なのでしょうか？型で約束された振る舞いが確実に守られます。置換してもコードが壊れません。予期しない副作用のない、信頼できるシステムを構築できます。

## インターフェース分離原則（ISP）- 必要なものだけに依存

CRUDインターフェースを実装するとき、読み取り専用のレポートサービスに削除メソッドの実装を強制されたことはありませんか？使わないメソッドに「throw new Exception("読み取り専用です")」を書く—これは不必要な複雑性という根本的な設計問題を生み出します。

```php
// ❌ 問題：巨大なインターフェース
interface UserRepositoryInterface {
    public function find(int $id): User;
    public function findAll(): array;
    public function save(User $user): void;
    public function delete(int $id): void;  // レポートには不要
    public function update(User $user): void; // 監査ログには不要
}

// ✅ 解決：目的別に分離
interface UserReaderInterface {
    public function find(int $id): User;
    public function findAll(): array;
}

interface UserWriterInterface {
    public function save(User $user): void;
    public function update(User $user): void;
    public function delete(int $id): void;
}

// レポートは読み取りだけ
class ReportService {
    public function __construct(private UserReaderInterface $reader) {}
}
```

この原則は、巨大なインターフェースを目的別の小さなインターフェースに分割します。レポートサービスは`UserReaderInterface`だけを実装し、フルアクセスが必要なサービスは両方のインターフェースを実装できます。

なぜこれが重要なのでしょうか？各サービスは本当に必要な機能だけに依存します。レポートサービスが誤って削除を呼び出すことはありません。監査ログが間違って更新することもありません。インターフェースが小さいほど、実装も使用も簡単になり、テストも書きやすくなります。

## 依存性逆転原則（DIP）- 抽象に依存する

高レベルのビジネスロジックが低レベルの実装詳細に依存するとき、変更の波及が起こります：

```php
// ❌ 問題：具象クラスへの直接依存
class UserService {
    public function __construct() {
        $this->mailer = new PHPMailer(); // 具象に依存
    }
}

// ✅ 解決：インターフェースへの依存
class UserService {
    public function __construct(
        private EmailServiceInterface $emailService // 抽象に依存
    ) {}
}
```

なぜこれが重要なのでしょうか？PHPMailerからSendGridに変更する際、UserServiceのコードは変更不要です。テスト時にはモック実装を注入できます。環境ごとに異なる実装を使い分けられます。

## Ray.DiでSOLID原則を実現

Ray.Diは、これらの原則を自然に実現するための強力なツールです：

```php
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // DIP: インターフェースと実装のバインディング
        $this->bind(EmailServiceInterface::class)
             ->to(SendGridEmailService::class);

        // OCP: Strategyパターンの設定
        $this->bind('discount_strategies')->toInstance([
            new StudentDiscount(),
            new SeniorDiscount(),
            // 新しい割引戦略を追加してもコード変更なし
        ]);
    }
}
```

## なぜSOLID原則が重要なのか

SOLID原則に従ったコードは、変更に対して予測可能に振る舞います。新機能を追加しても既存機能が壊れません。バグ修正が新たなバグを生みません。テストが書きやすく、保守が容易になります。

これは理想論ではありません。実際のプロジェクトで、リリース前夜に「この変更が他に影響しないか」と不安になった経験はありませんか？SOLID原則は、その不安を設計レベルで解消します。各部品が明確な責任を持ち、適切に分離され、安全に置換可能なとき、変更は局所的で予測可能になります。

## 実践のポイント

SOLID原則は教条的なルールではなく、より良い設計への指針です。すべてを完璧に適用する必要はありません。プロジェクトの規模、チームのスキル、納期を考慮して、適切なバランスを見つけることが重要です。

小さく始めましょう。まず依存性逆転原則から始めて、具象クラスへの直接依存を減らします。次に単一責任原則を適用して、肥大化したクラスを分割します。段階的に改善することで、無理なくSOLID原則を実践できます。

---

**次へ：** [Ray.Diの基礎](raydi-fundamentals.html) - フレームワークの実践的な使用

**前へ：** [依存性注入の原則](dependency-injection-principles.html)
