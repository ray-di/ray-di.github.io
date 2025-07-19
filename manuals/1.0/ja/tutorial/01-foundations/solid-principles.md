---
layout: docs-ja
title: SOLID原則の実践
category: Manual
permalink: /manuals/1.0/ja/tutorial/01-foundations/solid-principles.html
---

# SOLID原則の実践

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- 5つのSOLID原則の定義と意味
- 各原則が依存注入とどのように関連するか
- 実践的なコード例での原則の適用方法
- 違反の兆候と修正方法
- Ray.DiがSOLID原則の実装をどのように支援するか

## SOLID原則の概要

SOLID原則は、保守可能で拡張可能なオブジェクト指向ソフトウェアを設計するための5つの基本原則です：

| 原則 | 名前 | 説明 |
|------|------|------|
| **S** | 単一責任原則 | クラスは変更する理由を一つだけ持つべき |
| **O** | オープン・クローズド原則 | 拡張に対してオープン、変更に対してクローズド |
| **L** | リスコフの置換原則 | 派生クラスは基底クラスと置換可能でなければならない |
| **I** | インターフェース分離原則 | 使用しないインターフェースへの依存を強制しない |
| **D** | 依存性逆転原則 | 抽象に依存し、具象に依存しない |

## S - 単一責任原則（SRP）

**「クラスは変更する理由を一つだけ持つべき」**

### 違反例
```php
class UserManager
{
    public function createUser(string $email, string $password): User
    {
        // ユーザー作成のビジネスロジック
        if (!$this->isValidEmail($email)) {
            throw new InvalidEmailException();
        }
        
        $user = new User($email, $this->hashPassword($password));
        
        // データベースへの保存
        $pdo = new PDO('mysql:host=localhost;dbname=app', 'user', 'pass');
        $stmt = $pdo->prepare('INSERT INTO users (email, password) VALUES (?, ?)');
        $stmt->execute([$user->getEmail(), $user->getPassword()]);
        
        // メール送信
        $mailer = new PHPMailer();
        $mailer->setFrom('noreply@example.com');
        $mailer->addAddress($user->getEmail());
        $mailer->Subject = 'Welcome!';
        $mailer->Body = 'Welcome to our platform!';
        $mailer->send();
        
        // ログ記録
        error_log("User created: " . $user->getEmail());
        
        return $user;
    }
    
    private function isValidEmail(string $email): bool { /* ... */ }
    private function hashPassword(string $password): string { /* ... */ }
}
```

### 修正例（DI使用）
```php
interface UserRepositoryInterface
{
    public function save(User $user): void;
}

interface EmailServiceInterface
{
    public function sendWelcomeEmail(User $user): void;
}

interface LoggerInterface
{
    public function info(string $message): void;
}

class UserService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private EmailServiceInterface $emailService,
        private LoggerInterface $logger
    ) {}
    
    public function createUser(string $email, string $password): User
    {
        // 単一責任：ユーザー作成のビジネスロジックのみ
        if (!$this->isValidEmail($email)) {
            throw new InvalidEmailException();
        }
        
        $user = new User($email, $this->hashPassword($password));
        
        // 依存関係に委譲
        $this->userRepository->save($user);
        $this->emailService->sendWelcomeEmail($user);
        $this->logger->info("User created: " . $user->getEmail());
        
        return $user;
    }
    
    private function isValidEmail(string $email): bool { /* ... */ }
    private function hashPassword(string $password): string { /* ... */ }
}
```

### 利点
- **保守性**: 各クラスが単一の関心事に集中
- **テスト可能性**: 小さく、焦点を絞った単体テスト
- **再利用性**: 専門化されたクラスは他の場所で再利用可能
- **理解しやすさ**: コードの意図が明確

## O - オープン・クローズド原則（OCP）

**「拡張に対してオープン、変更に対してクローズド」**

### 違反例
```php
class OrderCalculator
{
    public function calculateTotal(Order $order): float
    {
        $total = 0;
        
        foreach ($order->getItems() as $item) {
            $total += $item->getPrice() * $item->getQuantity();
        }
        
        // 新しい割引タイプを追加するたびに修正が必要
        switch ($order->getDiscountType()) {
            case 'STUDENT':
                $total *= 0.9; // 10%割引
                break;
            case 'SENIOR':
                $total *= 0.85; // 15%割引
                break;
            case 'EMPLOYEE':
                $total *= 0.8; // 20%割引
                break;
                // 新しい割引タイプのために修正が必要
        }
        
        return $total;
    }
}
```

### 修正例（DI使用）
```php
interface DiscountStrategyInterface
{
    public function applyDiscount(float $amount): float;
    public function canApply(Order $order): bool;
}

class StudentDiscountStrategy implements DiscountStrategyInterface
{
    public function applyDiscount(float $amount): float
    {
        return $amount * 0.9;
    }
    
    public function canApply(Order $order): bool
    {
        return $order->getCustomer()->isStudent();
    }
}

class SeniorDiscountStrategy implements DiscountStrategyInterface
{
    public function applyDiscount(float $amount): float
    {
        return $amount * 0.85;
    }
    
    public function canApply(Order $order): bool
    {
        return $order->getCustomer()->isSenior();
    }
}

class OrderCalculator
{
    public function __construct(
        private array $discountStrategies // DI で注入
    ) {}
    
    public function calculateTotal(Order $order): float
    {
        $total = 0;
        
        foreach ($order->getItems() as $item) {
            $total += $item->getPrice() * $item->getQuantity();
        }
        
        // 新しい割引戦略を追加してもこのコードは変更不要
        foreach ($this->discountStrategies as $strategy) {
            if ($strategy->canApply($order)) {
                $total = $strategy->applyDiscount($total);
                break;
            }
        }
        
        return $total;
    }
}
```

### 利点
- **拡張性**: 新機能を既存コードを修正せずに追加
- **安定性**: 既存の動作が変更されない
- **リスク軽減**: 回帰バグの可能性を減らす

## L - リスコフの置換原則（LSP）

**「派生クラスは基底クラスと置換可能でなければならない」**

### 違反例
```php
interface BirdInterface
{
    public function fly(): void;
}

class Sparrow implements BirdInterface
{
    public function fly(): void
    {
        echo "Sparrow is flying";
    }
}

class Penguin implements BirdInterface
{
    public function fly(): void
    {
        // ペンギンは飛べません
        throw new Exception("Penguins cannot fly");
    }
}

// 違反：すべてのBirdInterface実装が同じように動作しない
function makeBirdFly(BirdInterface $bird): void
{
    $bird->fly(); // Penguinでは例外が発生
}
```

### 修正例（DI使用）
```php
interface BirdInterface
{
    public function eat(): void;
    public function sleep(): void;
}

interface FlyableBirdInterface extends BirdInterface
{
    public function fly(): void;
}

interface SwimmableBirdInterface extends BirdInterface
{
    public function swim(): void;
}

class Sparrow implements FlyableBirdInterface
{
    public function eat(): void { echo "Sparrow is eating"; }
    public function sleep(): void { echo "Sparrow is sleeping"; }
    public function fly(): void { echo "Sparrow is flying"; }
}

class Penguin implements SwimmableBirdInterface
{
    public function eat(): void { echo "Penguin is eating"; }
    public function sleep(): void { echo "Penguin is sleeping"; }
    public function swim(): void { echo "Penguin is swimming"; }
}

class BirdService
{
    public function __construct(
        private array $flyableBirds,
        private array $swimmableBirds
    ) {}
    
    public function makeFlyableBirdsFly(): void
    {
        foreach ($this->flyableBirds as $bird) {
            $bird->fly(); // 安全に飛行可能
        }
    }
    
    public function makeSwimmableBirdsSwim(): void
    {
        foreach ($this->swimmableBirds as $bird) {
            $bird->swim(); // 安全に泳げる
        }
    }
}
```

### 利点
- **予測可能性**: 実装の置換が期待通りに動作
- **信頼性**: 契約に基づく安全な多態性
- **保守性**: 新しい実装の追加が既存コードを破壊しない

## I - インターフェース分離原則（ISP）

**「使用しないインターフェースへの依存を強制しない」**

### 違反例
```php
interface WorkerInterface
{
    public function work(): void;
    public function eat(): void;
    public function sleep(): void;
}

class HumanWorker implements WorkerInterface
{
    public function work(): void { echo "Human working"; }
    public function eat(): void { echo "Human eating"; }
    public function sleep(): void { echo "Human sleeping"; }
}

class RobotWorker implements WorkerInterface
{
    public function work(): void { echo "Robot working"; }
    
    public function eat(): void 
    {
        // ロボットは食べません
        throw new Exception("Robots don't eat");
    }
    
    public function sleep(): void 
    {
        // ロボットは寝ません
        throw new Exception("Robots don't sleep");
    }
}
```

### 修正例（DI使用）
```php
interface WorkableInterface
{
    public function work(): void;
}

interface EatableInterface
{
    public function eat(): void;
}

interface SleepableInterface
{
    public function sleep(): void;
}

class HumanWorker implements WorkableInterface, EatableInterface, SleepableInterface
{
    public function work(): void { echo "Human working"; }
    public function eat(): void { echo "Human eating"; }
    public function sleep(): void { echo "Human sleeping"; }
}

class RobotWorker implements WorkableInterface
{
    public function work(): void { echo "Robot working"; }
}

class WorkManager
{
    public function __construct(
        private array $workers,
        private array $eaters,
        private array $sleepers
    ) {}
    
    public function makeWorkersWork(): void
    {
        foreach ($this->workers as $worker) {
            $worker->work();
        }
    }
    
    public function makeEatersEat(): void
    {
        foreach ($this->eaters as $eater) {
            $eater->eat();
        }
    }
    
    public function makeSleepersRest(): void
    {
        foreach ($this->sleepers as $sleeper) {
            $sleeper->sleep();
        }
    }
}
```

### 利点
- **柔軟性**: 実装は必要なインターフェースのみに依存
- **可読性**: インターフェースの意図が明確
- **実装の簡素化**: 不要なメソッドの実装不要

## D - 依存性逆転原則（DIP）

**「抽象に依存し、具象に依存しない」**

### 違反例
```php
class EmailService
{
    public function sendEmail(string $to, string $subject, string $body): void
    {
        // 具象実装に直接依存
        $mailer = new PHPMailer();
        $mailer->setFrom('noreply@example.com');
        $mailer->addAddress($to);
        $mailer->Subject = $subject;
        $mailer->Body = $body;
        $mailer->send();
    }
}

class UserService
{
    public function __construct()
    {
        // 高レベルモジュールが低レベルモジュールに依存
        $this->emailService = new EmailService();
    }
    
    public function registerUser(string $email, string $password): void
    {
        // ユーザー作成...
        $this->emailService->sendEmail($email, 'Welcome!', 'Welcome to our platform!');
    }
}
```

### 修正例（DI使用）
```php
// 抽象化の定義
interface EmailServiceInterface
{
    public function sendEmail(string $to, string $subject, string $body): void;
}

interface UserRepositoryInterface
{
    public function save(User $user): void;
}

// 低レベルモジュール（抽象化に依存）
class PHPMailerEmailService implements EmailServiceInterface
{
    public function sendEmail(string $to, string $subject, string $body): void
    {
        $mailer = new PHPMailer();
        $mailer->setFrom('noreply@example.com');
        $mailer->addAddress($to);
        $mailer->Subject = $subject;
        $mailer->Body = $body;
        $mailer->send();
    }
}

class SendGridEmailService implements EmailServiceInterface
{
    public function sendEmail(string $to, string $subject, string $body): void
    {
        // SendGrid API を使用
        $email = new \SendGrid\Mail\Mail();
        $email->setFrom('noreply@example.com');
        $email->addTo($to);
        $email->setSubject($subject);
        $email->addContent('text/plain', $body);
        
        $sendgrid = new \SendGrid('API_KEY');
        $sendgrid->send($email);
    }
}

class MySQLUserRepository implements UserRepositoryInterface
{
    public function save(User $user): void
    {
        // MySQL実装
    }
}

// 高レベルモジュール（抽象化に依存）
class UserService
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private EmailServiceInterface $emailService
    ) {}
    
    public function registerUser(string $email, string $password): void
    {
        $user = new User($email, $password);
        $this->userRepository->save($user);
        $this->emailService->sendEmail($email, 'Welcome!', 'Welcome to our platform!');
    }
}
```

### 利点
- **柔軟性**: 実装を簡単に変更可能
- **テスト可能性**: モック実装を注入可能
- **拡張性**: 新しい実装を追加しやすい
- **保守性**: 依存関係の変更が局所化

## Ray.DiでのSOLID原則実装

### バインディング設定
```php
use Ray\Di\AbstractModule;

class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // 依存性逆転原則の実装
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        $this->bind(EmailServiceInterface::class)->to(PHPMailerEmailService::class);
        $this->bind(LoggerInterface::class)->to(FileLogger::class);
        
        // インターフェース分離の実装
        $this->bind(WorkableInterface::class)->to(HumanWorker::class);
        $this->bind(EatableInterface::class)->to(HumanWorker::class);
        $this->bind(SleepableInterface::class)->to(HumanWorker::class);
        
        // オープン・クローズド原則の実装
        $this->bind()->annotatedWith('discount_strategies')->toInstance([
            new StudentDiscountStrategy(),
            new SeniorDiscountStrategy(),
            new EmployeeDiscountStrategy()
        ]);
    }
}
```

### 環境固有のモジュール
```php
// 開発環境用モジュール
class DevelopmentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(EmailServiceInterface::class)->to(MockEmailService::class);
    }
}

// 本番環境用モジュール
class ProductionModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(EmailServiceInterface::class)->to(SendGridEmailService::class);
    }
}

// アプリケーションの起動時に適切なモジュールを選択
$module = getenv('APP_ENV') === 'production' 
    ? new ProductionModule() 
    : new DevelopmentModule();
$injector = new Injector($module);
```

## SOLID原則のテスト

### 単体テスト例
```php
class UserServiceTest extends PHPUnit\Framework\TestCase
{
    public function testRegisterUser(): void
    {
        // 依存性逆転原則により、モックを簡単に注入
        $userRepository = $this->createMock(UserRepositoryInterface::class);
        $emailService = $this->createMock(EmailServiceInterface::class);
        
        $userRepository->expects($this->once())->method('save');
        $emailService->expects($this->once())->method('sendEmail');
        
        $userService = new UserService($userRepository, $emailService);
        $userService->registerUser('test@example.com', 'password');
    }
}
```

## 違反の兆候と修正

### SRP違反の兆候
- クラスが長すぎる（>200行）
- 多くのimport文
- 複数のpublic メソッド群
- 「and」や「or」で説明されるクラス

### OCP違反の兆候
- 新機能のたびにswitch文を修正
- 既存のメソッドを頻繁に変更
- 条件文が複雑で長い

### LSP違反の兆候
- 派生クラスで例外を投げる
- 事前条件の強化
- 事後条件の緩和

### ISP違反の兆候
- 実装で例外を投げる空のメソッド
- 使用しないメソッドの実装
- 巨大なインターフェース

### DIP違反の兆候
- new演算子の直接使用
- 具象クラスのtype hint
- 設定の硬直化

## 実践的な修正ガイド

### 1. 段階的リファクタリング
```php
// ステップ1: インターフェースを抽出
interface PaymentProcessorInterface
{
    public function processPayment(float $amount): bool;
}

// ステップ2: 既存クラスがインターフェースを実装
class StripePaymentProcessor implements PaymentProcessorInterface
{
    // 既存のコード
}

// ステップ3: 依存注入を導入
class OrderService
{
    public function __construct(
        private PaymentProcessorInterface $paymentProcessor
    ) {}
}

// ステップ4: DIコンテナで設定
$this->bind(PaymentProcessorInterface::class)->to(StripePaymentProcessor::class);
```

### 2. レガシーコードの改善
```php
// 既存のレガシーコード
class LegacyOrderService
{
    public function processOrder(Order $order): void
    {
        // 複雑な処理...
    }
}

// SOLID原則を適用したリファクタリング
class OrderService
{
    public function __construct(
        private OrderValidatorInterface $validator,
        private PaymentProcessorInterface $paymentProcessor,
        private InventoryServiceInterface $inventoryService,
        private NotificationServiceInterface $notificationService
    ) {}
    
    public function processOrder(Order $order): void
    {
        $this->validator->validate($order);
        $this->paymentProcessor->processPayment($order->getTotal());
        $this->inventoryService->updateInventory($order->getItems());
        $this->notificationService->sendOrderConfirmation($order);
    }
}
```

## 次のステップ

SOLID原則を理解したので、次に進む準備が整いました。

1. **Ray.Diの基礎の学習**: フレームワークの具体的な使用方法を学ぶ
2. **実践的な例の探索**: 原則を実際のコードで適用する方法を見る
3. **デザインパターンの習得**: SOLID原則を使ったパターンの実装

**続きは:** [Ray.Diの基礎](raydi-fundamentals.html)

## 重要なポイント

- **SOLID原則**は保守可能なコードの基盤
- **依存注入**はSOLID原則を実装するための強力な手段
- **Ray.Di**は原則の実装を簡素化し、自動化する
- **段階的リファクタリング**により既存コードを改善できる
- **テスト可能性**はSOLID原則の自然な結果
- **設計の判断**は原則を柔軟に適用することが重要

---

SOLID原則は厳格なルールではなく、より良い設計を導くガイドラインです。コンテキストに応じて適切に適用する必要があります。