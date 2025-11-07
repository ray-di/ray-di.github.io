---
layout: docs-ja
title: デコレーターパターン/AOP - 横断的関心事
category: Manual
permalink: /manuals/1.0/ja/tutorial/03-behavior-patterns/decorator-pattern-aop.html
---

# デコレーターパターン/AOP - 横断的関心事

## 学習目標

- 横断的関心事（Cross-Cutting Concerns）が散在する問題を理解する
- デコレーターパターンとAOPの違いを学ぶ
- Ray.Diのインターセプターで宣言的に機能を追加する方法を理解する

## 問題：横断的関心事の散在

ビジネスロジックに、ロギング、トランザクション、キャッシュなどの共通処理が混在します。

```php
class OrderService
{
    public function processOrder(Order $order): void
    {
        // ❌ 問題：ビジネスロジックと横断的関心事が混在
        $this->logger->info("Starting order processing");

        $this->db->beginTransaction();
        try {
            // ビジネスロジック（本質）
            $this->orderRepository->save($order);
            $this->paymentService->processPayment($order);

            $this->db->commit();
            $this->logger->info("Order processed successfully");
        } catch (Exception $e) {
            $this->db->rollback();
            $this->logger->error("Order processing failed: " . $e->getMessage());
            throw $e;
        }
    }

    public function cancelOrder(int $orderId): void
    {
        // 同じロギング、トランザクションコードが重複...
        $this->logger->info("Starting order cancellation");
        $this->db->beginTransaction();
        try {
            // ビジネスロジック
            $this->db->commit();
        } catch (Exception $e) {
            $this->db->rollback();
            throw $e;
        }
    }
}
```

### なぜこれが問題なのか

1. **関心事の混在**
   - ビジネスロジックが埋もれて読みにくい
   - ロギング、トランザクションのコードが重複

2. **単一責任原則違反**
   - `OrderService`が複数の責任を持つ
   - 変更される理由が複数ある

3. **保守性の低下**
   - ロギングフォーマット変更 = すべてのメソッドを修正
   - 新しい横断的関心事の追加が困難

## 解決策：AOP（アスペクト指向プログラミング）

**AOPの役割**：横断的関心事をビジネスロジックから分離

```php
// 1. 属性（Attribute）の定義
#[Attribute(Attribute::TARGET_METHOD)]
class Transactional {}

#[Attribute(Attribute::TARGET_METHOD)]
class Loggable {}

// 2. インターセプターの実装
class TransactionalInterceptor implements MethodInterceptor
{
    public function __construct(
        private DatabaseConnection $db
    ) {}

    public function invoke(MethodInvocation $invocation): mixed
    {
        $this->db->beginTransaction();
        try {
            $result = $invocation->proceed();
            $this->db->commit();
            return $result;
        } catch (Exception $e) {
            $this->db->rollback();
            throw $e;
        }
    }
}

class LoggableInterceptor implements MethodInterceptor
{
    public function __construct(
        private LoggerInterface $logger
    ) {}

    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $class = get_class($invocation->getThis());

        $this->logger->info("Method started: {$class}::{$method->getName()}");

        try {
            $result = $invocation->proceed();
            $this->logger->info("Method completed: {$class}::{$method->getName()}");
            return $result;
        } catch (Exception $e) {
            $this->logger->error("Method failed: {$class}::{$method->getName()}", [
                'error' => $e->getMessage()
            ]);
            throw $e;
        }
    }
}

// 3. AOPモジュールの設定
class AopModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Transactional::class),
            [TransactionalInterceptor::class]
        );

        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Loggable::class),
            [LoggableInterceptor::class]
        );
    }
}

// 4. クリーンなビジネスロジック
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private PaymentServiceInterface $paymentService
    ) {}

    #[Transactional]
    #[Loggable]
    public function processOrder(Order $order): void
    {
        // ✅ ビジネスロジックのみ
        $this->orderRepository->save($order);
        $this->paymentService->processPayment($order);
    }

    #[Transactional]
    #[Loggable]
    public function cancelOrder(int $orderId): void
    {
        $order = $this->orderRepository->findById($orderId);
        $order->cancel();
        $this->orderRepository->save($order);
    }
}
```

## パターンの本質

```
通常のメソッド呼び出し:
Client → Service.method() → Business Logic

AOPによるメソッド呼び出し:
Client → Interceptor 1 (Logging)
         → Interceptor 2 (Transaction)
            → Service.method() → Business Logic
         ← Interceptor 2 (Commit/Rollback)
      ← Interceptor 1 (Log Result)
```

### AOPが解決すること

1. **関心事の分離**
   - ビジネスロジック：`OrderService`
   - トランザクション管理：`TransactionalInterceptor`
   - ロギング：`LoggableInterceptor`

2. **DRY原則の遵守**
   ```php
   // ❌ 前：すべてのメソッドに重複コード
   public function processOrder() {
       $this->logger->info(...);
       $this->db->beginTransaction();
       try { ... } catch { ... }
   }

   // ✅ 後：宣言的で重複なし
   #[Transactional]
   #[Loggable]
   public function processOrder() {
       // ビジネスロジックのみ
   }
   ```

3. **テスト可能性**
   - ビジネスロジックを純粋にテスト
   - インターセプターを個別にテスト

## デコレーターパターンとの違い

| 特徴 | デコレーターパターン | AOP（インターセプター） |
|------|-------------------|---------------------|
| **適用範囲** | 特定のクラス | 多数のクラス/メソッド |
| **追加方法** | 明示的にラップ | 宣言的に属性で指定 |
| **変更箇所** | 一箇所のみ | すべてのメソッドに適用可能 |
| **実装** | プロバイダーで組み立て | モジュールでインターセプター束縛 |

### デコレーターパターンの例

```php
// 特定のクラスにのみ機能を追加したい場合
class LoggingOrderService implements OrderServiceInterface
{
    public function __construct(
        private OrderServiceInterface $inner,
        private LoggerInterface $logger
    ) {}

    public function processOrder(Order $order): void
    {
        $this->logger->info("Processing order");
        $this->inner->processOrder($order);
        $this->logger->info("Order processed");
    }
}

// プロバイダーで組み立て
class OrderServiceProvider implements ProviderInterface
{
    public function get(): OrderServiceInterface
    {
        $service = new OrderService(...);
        return new LoggingOrderService($service, $this->logger);
    }
}
```

## 使い分けの判断基準

```
機能追加が必要
│
├─ 多数のクラス/メソッドに適用？
│  ├─ YES → ビジネスロジックと無関係？
│  │         ├─ YES → ✅ AOP（インターセプター）
│  │         └─ NO  → デコレーターパターン
│  └─ NO  ↓
│
├─ 特定のクラスのみ？
│  ├─ YES → ✅ デコレーターパターン
│  └─ NO  → 通常の実装
```

### AOPを使うべき場合

| 状況 | 例 |
|------|-----|
| **横断的関心事** | ロギング、トランザクション、キャッシュ |
| **宣言的な追加** | 属性でシンプルに機能追加 |
| **多数のメソッド** | すべてのサービス層メソッドなど |

### デコレーターを使うべき場合

| 状況 | 例 |
|------|-----|
| **特定のクラスのみ** | 一部のサービスにのみ機能追加 |
| **複雑な条件分岐** | 実行時の状態に応じた振る舞い |
| **明示的な依存関係** | 追加機能が明確に見える方が良い |

## よくあるアンチパターン

### ビジネスロジックをインターセプターに

```php
// ❌ インターセプターがビジネスロジックを持つ
class OrderProcessingInterceptor implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation): mixed
    {
        $order = $invocation->getArguments()[0];

        // ビジネスロジックをインターセプターに入れない！
        if ($order->getTotal() > 10000) {
            $this->notificationService->sendAlert($order);
        }

        return $invocation->proceed();
    }
}

// ✅ インターセプターは横断的関心事のみ
class LoggableInterceptor implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation): mixed
    {
        $this->logger->info("Method called");
        $result = $invocation->proceed();
        $this->logger->info("Method completed");
        return $result;
    }
}
```

**なぜ問題か**：インターセプターの責任が不明確、ビジネスルールが隠蔽される

### 過度なインターセプター

```php
// ❌ インターセプターを多数付与
#[Logging]
#[Caching]
#[Transactional]
#[Monitoring]
#[RateLimiting]
#[Authentication]
#[Authorization]
#[Validation]
public function processOrder(Order $order): void
{
    // 実行順序が不明確、パフォーマンス問題
}

// ✅ 必要最小限のインターセプター
#[Transactional]
#[Loggable]
public function processOrder(Order $order): void
{
    // 認証・認可はミドルウェア層で
    // バリデーションはドメイン層で
}
```

**なぜ問題か**：実行順序が複雑、パフォーマンスへの影響

## SOLID原則との関係

- **SRP**：ビジネスロジックと横断的関心事を完全に分離
- **OCP**：インターセプターで新機能を追加、既存コード変更不要
- **DIP**：インターセプターは抽象に依存、ビジネスロジックはインターセプターを知らない

## まとめ

### AOPパターンの核心

- **横断的関心事の分離**：ビジネスロジックから完全に分離
- **宣言的な機能追加**：属性で横断的関心事を明示
- **DRY原則の徹底**：重複コードを一箇所で管理

### パターンの効果

- ✅ ビジネスロジックがクリーンで読みやすい
- ✅ 横断的関心事を一箇所で管理
- ✅ テスト可能性が大幅に向上
- ✅ 新しい横断的関心事の追加が容易

### 次のステップ

振る舞いパターンを理解したので、次はアーキテクチャパターンを学びます。

**続きは:** [リポジトリパターン](../04-architecture-patterns/repository-pattern.html)

---

AOPは、Ray.Diの最も強力な機能の一つです。**横断的関心事を宣言的に追加**することで、ビジネスロジックをクリーンに保ちながら、必要な機能をすべて実現できます。
