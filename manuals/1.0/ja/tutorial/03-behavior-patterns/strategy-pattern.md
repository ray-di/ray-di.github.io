---
layout: docs-ja
title: ストラテジーパターン - 振る舞いパターン
category: Manual
permalink: /manuals/1.0/ja/tutorial/03-behavior-patterns/strategy-pattern.html
---

# ストラテジーパターン - 振る舞いパターン

## 学習目標

- 条件分岐による振る舞いの切り替えの問題を理解する
- ストラテジーパターンでアルゴリズムをカプセル化する方法を学ぶ
- Ray.Diの注釈付き束縛（Named）の活用方法を理解する

## 問題：条件分岐の増殖

実行時に異なる処理を選択する必要がある場合、条件分岐が増殖します。

```php
class OrderService
{
    public function processPayment(Order $order, string $method): void
    {
        // ❌ 問題：条件分岐で処理を切り替え
        if ($method === 'credit_card') {
            $stripe = new StripeClient(getenv('STRIPE_KEY'));
            $stripe->charge($order->getTotal(), $order->getToken());
        } elseif ($method === 'paypal') {
            $paypal = new PayPalClient(getenv('PAYPAL_ID'));
            $paypal->createPayment($order->getTotal(), $order->getToken());
        } elseif ($method === 'bank_transfer') {
            $bank = new BankTransferService();
            $bank->initiateTransfer($order->getTotal(), $order->getAccount());
        }
        // 新しい支払い方法の追加 → さらに分岐が増える
    }
}
```

### なぜこれが問題なのか

1. **オープン・クローズド原則違反**
   - 新しい支払い方法の追加 = 既存コードの変更
   - `OrderService`が変更される理由が複数

2. **テストの困難さ**
   - すべての支払いゲートウェイを初期化
   - 条件分岐ごとにテストケースが必要

3. **依存関係の不明確さ**
   - 実行時まで必要な依存関係がわからない
   - すべての外部サービスへの依存

## 解決策：ストラテジーパターン

**ストラテジーの役割**：アルゴリズム（振る舞い）をカプセル化し、実行時に切り替え可能にする

```php
// 1. ストラテジーインターフェース
interface PaymentStrategyInterface
{
    public function processPayment(Order $order): PaymentResult;
}

// 2. 各ストラテジーの実装
class CreditCardPaymentStrategy implements PaymentStrategyInterface
{
    public function __construct(
        private StripeClient $client
    ) {}

    public function processPayment(Order $order): PaymentResult
    {
        $charge = $this->client->charge($order->getTotal(), $order->getToken());
        return new PaymentResult($charge->status === 'succeeded', $charge->id);
    }
}

class PayPalPaymentStrategy implements PaymentStrategyInterface
{
    public function __construct(
        private PayPalClient $client
    ) {}

    public function processPayment(Order $order): PaymentResult
    {
        $payment = $this->client->createPayment($order->getTotal(), $order->getToken());
        return new PaymentResult($payment->state === 'approved', $payment->id);
    }
}

// 3. Ray.Diで注釈付き束縛
class PaymentModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(PaymentStrategyInterface::class)
            ->annotatedWith('credit_card')
            ->to(CreditCardPaymentStrategy::class);

        $this->bind(PaymentStrategyInterface::class)
            ->annotatedWith('paypal')
            ->to(PayPalPaymentStrategy::class);
    }
}

// 4. ストラテジーファクトリー
class PaymentStrategyFactory
{
    public function __construct(
        #[Named('credit_card')] private PaymentStrategyInterface $creditCard,
        #[Named('paypal')] private PaymentStrategyInterface $paypal
    ) {}

    public function getStrategy(string $method): PaymentStrategyInterface
    {
        return match($method) {
            'credit_card' => $this->creditCard,
            'paypal' => $this->paypal,
            default => throw new InvalidPaymentMethodException($method)
        };
    }
}

// 5. 使用側のコード
class OrderService
{
    public function __construct(
        private PaymentStrategyFactory $factory
    ) {}

    public function processPayment(Order $order, string $method): void
    {
        // ✅ ストラテジーパターンで処理を委譲
        $strategy = $this->factory->getStrategy($method);
        $result = $strategy->processPayment($order);

        if ($result->isSuccess()) {
            $order->markAsPaid($result->getTransactionId());
        } else {
            throw new PaymentFailedException();
        }
    }
}
```

## パターンの本質

```
条件分岐アプローチ:
Service → if/else → 具象クラス直接使用

ストラテジーパターン:
Service → Factory → Strategy Interface → 具象実装
         (実行時)    (DI)               (多態性)
```

### ストラテジーが解決すること

1. **オープン・クローズド原則の遵守**
   ```php
   // 新しい支払い方法の追加
   class ApplePayStrategy implements PaymentStrategyInterface { ... }

   // モジュールで束縛を追加するだけ（既存コード変更なし）
   $this->bind(PaymentStrategyInterface::class)
       ->annotatedWith('apple_pay')
       ->to(ApplePayStrategy::class);
   ```

2. **単一責任原則の遵守**
   - `CreditCardStrategy`：クレジットカード決済のみ
   - `OrderService`：注文処理の協調のみ

3. **テスト可能性の向上**
   - 各ストラテジーを独立してテスト
   - テスト用ストラテジーへの差し替え

## Ray.Diの注釈付き束縛

**課題**：同じインターフェースの複数実装をどう管理するか？

```php
// ❌ これでは区別できない
$this->bind(PaymentStrategyInterface::class)->to(CreditCardStrategy::class);
$this->bind(PaymentStrategyInterface::class)->to(PayPalStrategy::class);  // 上書き

// ✅ 注釈付き束縛で区別
$this->bind(PaymentStrategyInterface::class)
    ->annotatedWith('credit_card')  // 名前で区別
    ->to(CreditCardStrategy::class);

$this->bind(PaymentStrategyInterface::class)
    ->annotatedWith('paypal')
    ->to(PayPalStrategy::class);

// 注入時に名前を指定
public function __construct(
    #[Named('credit_card')] private PaymentStrategyInterface $creditCard,
    #[Named('paypal')] private PaymentStrategyInterface $paypal
) {}
```

## 使い分けの判断基準

### ストラテジーパターンを使うべき場合

| 状況 | 理由 |
|------|------|
| **同じ操作の複数の方法** | 支払い方法、配送方法、計算アルゴリズム |
| **条件分岐の増加** | if/elseやswitchが複数箇所で重複 |
| **実行時の切り替え** | ユーザー選択や設定による振る舞い変更 |

### 他のパターンを検討すべき場合

| 状況 | 代替パターン |
|------|------------|
| **振る舞いが1つのみ** | シンプルな実装で十分 |
| **静的な振る舞い** | プロバイダー束縛 |
| **横断的関心事** | AOP/インターセプター |

### 判断フロー

```
同じ操作の複数の方法が存在？
│
├─ YES → 実行時に切り替えが必要？
│         ├─ YES → ✅ ストラテジーパターン
│         └─ NO  → プロバイダー束縛
│
└─ NO  → ストラテジーパターン不要
```

## よくあるアンチパターン

### ストラテジーでの状態保持

```php
// ❌ ストラテジーが状態を持つ
class CreditCardStrategy implements PaymentStrategyInterface
{
    private array $processedOrders = [];  // 状態保持

    public function processPayment(Order $order): PaymentResult
    {
        $this->processedOrders[] = $order;  // NG
        // ...
    }
}

// ✅ ステートレスなストラテジー
class CreditCardStrategy implements PaymentStrategyInterface
{
    public function processPayment(Order $order): PaymentResult
    {
        // 引数で受け取り、結果を返すのみ
        return new PaymentResult(...);
    }
}
```

**なぜ問題か**：ストラテジーは純粋な振る舞いのみを持つべき

### 選択ロジックの分散

```php
// ❌ 選択ロジックが複数箇所に分散
class OrderService
{
    public function processPayment(Order $order, string $method): void
    {
        $strategy = match($method) {  // 選択ロジック
            'credit_card' => $this->creditCard,
            // ...
        };
    }
}

class InvoiceService
{
    public function generateInvoice(Order $order, string $method): void
    {
        $strategy = match($method) {  // 同じ選択ロジックが重複
            'credit_card' => $this->creditCard,
            // ...
        };
    }
}

// ✅ ファクトリーで選択ロジックを一元化
class PaymentStrategyFactory
{
    public function getStrategy(string $method): PaymentStrategyInterface
    {
        // 選択ロジックを一箇所に集約
    }
}
```

**なぜ問題か**：選択ロジックの変更が多数の箇所に影響

## SOLID原則との関係

- **OCP**：新しいストラテジーの追加時、既存コードを変更しない
- **SRP**：各ストラテジーは一つのアルゴリズムのみを担当
- **LSP**：すべてのストラテジーが同じインターフェースを実装
- **DIP**：使用側は抽象（インターフェース）に依存

## まとめ

### ストラテジーパターンの核心

- **アルゴリズムのカプセル化**：振る舞いを切り替え可能にする
- **注釈付き束縛**：同じインターフェースの複数実装を管理
- **ファクトリー**：ストラテジー選択ロジックを一元化

### パターンの効果

- ✅ 新機能追加時の既存コード変更不要（OCP）
- ✅ 各ストラテジーを独立してテスト可能
- ✅ 条件分岐を排除、可読性向上
- ✅ 依存関係が明確

### 次のステップ

振る舞いの切り替えを学んだので、次は横断的関心事（ロギング、トランザクション）を処理する方法を学びます。

**続きは:** [デコレーターパターン/AOP](decorator-pattern-aop.html)

---

ストラテジーパターンは、**条件分岐をポリモーフィズムに置き換える**ことで、拡張可能で保守しやすいコードを実現します。
