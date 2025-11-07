---
layout: docs-ja
title: サービス層 - アーキテクチャパターン
category: Manual
permalink: /manuals/1.0/ja/tutorial/04-architecture-patterns/service-layer.html
---

# サービス層 - アーキテクチャパターン

## 学習目標

- Fat Controllerの問題を理解する
- サービス層でビジネスロジックを協調させる方法を学ぶ
- トランザクション境界の管理方法を理解する

## 問題：ビジネスロジックがコントローラーに散在

ビジネスロジックがコントローラーに直接書かれ、再利用できません。

```php
class OrderController
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private UserRepositoryInterface $userRepository,
        private PaymentGatewayInterface $paymentGateway,
        private EmailServiceInterface $emailService,
        private InventoryServiceInterface $inventoryService
    ) {}

    public function createOrder(Request $request): Response
    {
        // ❌ 問題：コントローラーにビジネスロジックが直接書かれている
        try {
            // ユーザー検証
            $user = $this->userRepository->findById($request->get('user_id'));
            if (!$user) {
                return new Response('User not found', 404);
            }

            // 在庫確認
            foreach ($request->get('items') as $item) {
                if (!$this->inventoryService->isAvailable($item['product_id'], $item['quantity'])) {
                    return new Response('Insufficient inventory', 400);
                }
            }

            // 注文作成
            $order = new Order($user->getId(), $request->get('items'), $total);
            $this->orderRepository->save($order);

            // 支払い処理
            $result = $this->paymentGateway->charge($total, $request->get('token'));
            if (!$result->isSuccess()) {
                $this->orderRepository->delete($order);
                return new Response('Payment failed', 400);
            }

            // 在庫更新
            $this->inventoryService->updateInventory($request->get('items'));

            // メール送信
            $this->emailService->sendOrderConfirmation($user, $order);

            return new Response('Order created', 201);
        } catch (Exception $e) {
            return new Response('Internal server error', 500);
        }
    }
}
```

### なぜこれが問題なのか

1. **Fat Controller**
   - コントローラーが100行以上に肥大化
   - HTTPレイヤーとビジネスロジックが混在

2. **再利用不可**
   - 同じビジネスロジックをCLIやバッチで使えない
   - コードの重複

3. **テストの困難さ**
   - ビジネスロジックのテストにHTTPリクエストが必要
   - テストが遅い

4. **トランザクション管理の欠如**
   - 支払い失敗時に注文だけ保存される
   - データの整合性が保証されない

## 解決策：サービス層の導入

**サービス層の役割**：ビジネスロジックを協調させ、トランザクション境界を管理

```php
// 1. サービス層インターフェース
interface OrderServiceInterface
{
    public function createOrder(CreateOrderCommand $command): Order;
}

// コマンドオブジェクト（入力データのカプセル化）
class CreateOrderCommand
{
    public function __construct(
        public readonly int $userId,
        public readonly array $items,
        public readonly string $paymentToken
    ) {}
}

// 2. サービス層実装
class OrderService implements OrderServiceInterface
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private UserRepositoryInterface $userRepository,
        private PaymentGatewayInterface $paymentGateway,
        private InventoryServiceInterface $inventoryService,
        private EmailServiceInterface $emailService
    ) {}

    #[Transactional]  // AOPでトランザクション管理
    public function createOrder(CreateOrderCommand $command): Order
    {
        // ステップ1：検証
        $user = $this->userRepository->findById($command->userId);
        if (!$user) {
            throw new UserNotFoundException();
        }

        $this->validateInventory($command->items);

        // ステップ2：注文作成
        $total = $this->calculateTotal($command->items);
        $order = new Order($command->userId, $command->items, $total);
        $this->orderRepository->save($order);

        // ステップ3：支払い処理
        $result = $this->paymentGateway->charge($total, $command->paymentToken);
        if (!$result->isSuccess()) {
            throw new PaymentFailedException();
        }

        // ステップ4：在庫更新
        $this->inventoryService->updateInventory($command->items);

        // ステップ5：通知
        $this->emailService->sendOrderConfirmation($user, $order);

        return $order;
    }

    private function validateInventory(array $items): void
    {
        foreach ($items as $item) {
            if (!$this->inventoryService->isAvailable($item['product_id'], $item['quantity'])) {
                throw new InsufficientInventoryException();
            }
        }
    }

    private function calculateTotal(array $items): float
    {
        // 計算ロジック
    }
}

// 3. 薄いコントローラー
class OrderController
{
    public function __construct(
        private OrderServiceInterface $orderService
    ) {}

    public function createOrder(Request $request): Response
    {
        // ✅ コントローラーは薄く保つ
        try {
            $command = new CreateOrderCommand(
                $request->get('user_id'),
                $request->get('items'),
                $request->get('payment_token')
            );

            $order = $this->orderService->createOrder($command);

            return new JsonResponse([
                'order_id' => $order->getId(),
                'status' => $order->getStatus()->value
            ], 201);
        } catch (UserNotFoundException $e) {
            return new JsonResponse(['error' => 'User not found'], 404);
        } catch (InsufficientInventoryException $e) {
            return new JsonResponse(['error' => $e->getMessage()], 400);
        } catch (PaymentFailedException $e) {
            return new JsonResponse(['error' => 'Payment failed'], 400);
        }
    }
}
```

## パターンの本質

```
階層化アーキテクチャ:
┌─────────────────────┐
│  Presentation Layer │ ← OrderController（薄い）
├─────────────────────┤
│  Application Layer  │ ← OrderService（ビジネスロジック協調）
├─────────────────────┤
│     Domain Layer    │ ← Order, User（ビジネスルール）
├─────────────────────┤
│ Infrastructure      │ ← Repositories, Email, Payment
└─────────────────────┘

責任の分離:
- Controller: HTTP処理、例外ハンドリング
- Service: ビジネスロジック協調、トランザクション境界
- Domain: ビジネスルール
- Infrastructure: 外部システムとの連携
```

### サービス層が解決すること

1. **責任の明確化**
   - Controller：HTTPリクエスト/レスポンス
   - Service：ビジネスロジック協調
   - Repository：データアクセス

2. **再利用性の向上**
   ```php
   // HTTPエンドポイント
   class OrderController
   {
       public function createOrder(Request $request): Response
       {
           $order = $this->orderService->createOrder($command);
       }
   }

   // CLIコマンド
   class CreateOrderCommand extends Command
   {
       protected function execute(InputInterface $input, OutputInterface $output): int
       {
           $order = $this->orderService->createOrder($command);  // 再利用
       }
   }
   ```

3. **トランザクション境界の明確化**
   - `#[Transactional]`属性でトランザクション境界を宣言
   - 支払い失敗時は自動的にロールバック

## 使い分けの判断基準

```
処理が必要
│
├─ 複数のリポジトリ/サービスが必要？
│  ├─ YES → ✅ Application層（サービス）
│  └─ NO  ↓
│
├─ ビジネスルールの検証？
│  ├─ YES → Domain層（エンティティ）
│  └─ NO  ↓
│
├─ データアクセス？
│  ├─ YES → Infrastructure層（リポジトリ）
│  └─ NO  → Presentation層（コントローラー）
```

### サービス層に含めるべきもの

| 内容 | 理由 |
|------|------|
| **ユースケースの実装** | ビジネスフロー全体の協調 |
| **トランザクション境界** | データ整合性の保証 |
| **複数エンティティの協調** | リポジトリやドメインサービスの組み合わせ |
| **外部サービスとの統合** | 支払い、メール、通知など |

### サービス層に含めないもの

| 内容 | 代わりの場所 |
|------|-------------|
| **HTTPリクエスト処理** | コントローラー（Presentation層） |
| **ビジネスルール** | エンティティ（Domain層） |
| **データアクセス詳細** | リポジトリ（Infrastructure層） |

## よくあるアンチパターン

### Anemic Domain Model

```php
// ❌ ドメインモデルがデータのみ
class Order
{
    public int $id;
    public int $userId;
    public string $status;
    // ビジネスロジックがない
}

// すべてのロジックがサービスに
class OrderService
{
    public function cancelOrder(int $orderId): void
    {
        $order = $this->repository->findById($orderId);
        if ($order->status === 'completed') {  // ビジネスルールがサービスに漏れている
            throw new InvalidOperationException();
        }
        $order->status = 'cancelled';
        $this->repository->save($order);
    }
}

// ✅ Rich Domain Model
class Order
{
    public function cancel(): void
    {
        // ビジネスルールはドメインに
        if ($this->status === OrderStatus::Completed) {
            throw new InvalidOperationException();
        }
        $this->status = OrderStatus::Cancelled;
    }
}

class OrderService
{
    public function cancelOrder(int $orderId): void
    {
        $order = $this->repository->findById($orderId);
        $order->cancel();  // ビジネスルールはドメインに委譲
        $this->repository->save($order);
    }
}
```

**なぜ問題か**：ビジネスルールがサービス層に散在、ドメインモデルの意味がない

### God Service

```php
// ❌ すべてを処理する巨大サービス
class OrderService
{
    public function createOrder() {}
    public function cancelOrder() {}
    public function updateShipping() {}
    public function processRefund() {}
    public function generateInvoice() {}
    public function sendReminder() {}
    // 100個のメソッド...
}

// ✅ 責任ごとにサービスを分離
class OrderService
{
    public function createOrder() {}
    public function cancelOrder() {}
}

class OrderShippingService
{
    public function updateShipping() {}
}

class OrderBillingService
{
    public function processRefund() {}
    public function generateInvoice() {}
}
```

**なぜ問題か**：単一責任原則違反、変更の影響範囲が大きい

## SOLID原則との関係

- **SRP**：サービスは一つのユースケースまたは関連するユースケースのみを担当
- **DIP**：サービスはインターフェースに依存、具象実装への依存を排除

## まとめ

### サービス層の核心

- **ビジネスロジックの協調**：複数のリポジトリ/サービスを組み合わせる
- **トランザクション境界**：データ整合性を保証
- **薄いコントローラー**：HTTPレイヤーとビジネスロジックを分離

### パターンの効果

- ✅ ビジネスロジックを複数のインターフェース（HTTP、CLI）で再利用
- ✅ テストが容易（HTTPレイヤー不要）
- ✅ トランザクション管理が明確
- ✅ 保守性が向上

### 次のステップ

アーキテクチャパターンの最後として、モジュール設計を学びます。

**続きは:** [モジュール設計](module-design.html)

---

サービス層は、**アプリケーションの中核**を構成します。ビジネスロジックを適切に配置し、各層の責任を明確にすることで、保守性とテスト可能性の高いアーキテクチャを実現できます。
