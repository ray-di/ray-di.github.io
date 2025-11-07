---
layout: docs-ja
title: ファクトリーパターン - オブジェクト生成パターン
category: Manual
permalink: /manuals/1.0/ja/tutorial/02-object-creation-patterns/factory-pattern.html
---

# ファクトリーパターン - オブジェクト生成パターン

## 学習目標

- 実行時パラメータが必要なオブジェクト生成の課題を理解する
- ファクトリーパターンがDIの限界をどう補完するかを学ぶ
- プロバイダーパターンとの使い分けを判断できるようになる

## 問題：実行時パラメータと設定時依存関係の混在

DIコンテナは設定時に依存関係グラフを構築します。しかし、実行時にしかわからないパラメータが必要な場合、どうすればよいでしょうか？

```php
class OrderProcessor
{
    public function __construct(
        private int $orderId,              // ← 実行時パラメータ（ユーザー入力）
        private PaymentServiceInterface $paymentService,  // ← 設定時依存関係（DI）
        private InventoryServiceInterface $inventoryService
    ) {}
}

// ❌ 問題：DIコンテナはorderIdを知らない
$processor = $injector->getInstance(OrderProcessor::class);  // orderIdをどう渡す？
```

### なぜこれが問題なのか

1. **依存関係の性質が異なる**
   - `PaymentService`：アプリケーション起動時に決定（設定）
   - `orderId`：ユーザーリクエストで決定（実行時）

2. **DIの限界**
   - DIコンテナは「何を注入するか」を知っている
   - しかし「どの値を注入するか」は実行時まで不明

3. **アンチパターンへの誘惑**
   ```php
   // セッターで渡す？ → 可変状態、依存関係が不明確
   $processor->setOrderId($orderId);

   // サービスロケーター？ → DIの利点を失う
   $processor = new OrderProcessor($orderId, $container->get(...), ...);
   ```

## 解決策：ファクトリーパターン

**ファクトリーの役割**：実行時パラメータと設定時依存関係の架け橋

```php
// 1. ファクトリーインターフェース
interface OrderProcessorFactoryInterface
{
    public function create(int $orderId): OrderProcessor;
}

// 2. ファクトリー実装（設定時依存関係を注入）
class OrderProcessorFactory implements OrderProcessorFactoryInterface
{
    public function __construct(
        private PaymentServiceInterface $paymentService,
        private InventoryServiceInterface $inventoryService
    ) {}

    public function create(int $orderId): OrderProcessor
    {
        return new OrderProcessor(
            $orderId,                  // 実行時パラメータ
            $this->paymentService,     // 設定時依存関係
            $this->inventoryService
        );
    }
}

// 3. 使用側
class OrderController
{
    public function __construct(
        private OrderProcessorFactoryInterface $factory  // ファクトリーを注入
    ) {}

    public function processOrder(Request $request): void
    {
        $orderId = $request->get('order_id');
        $processor = $this->factory->create($orderId);  // ✅ 実行時に生成
        $processor->process();
    }
}
```

## パターンの本質

```
実行時パラメータの流れ:
Request → Controller → Factory.create(param) → New Object

設定時依存関係の流れ:
DI Container → Factory.__construct(deps) → Factory.create() → New Object
```

### ファクトリーが解決すること

1. **責任の分離**
   - Controller：実行時パラメータの取得
   - Factory：オブジェクト生成
   - DI Container：設定時依存関係の解決

2. **テスト可能性**
   - ファクトリーをテスト用実装に差し替え可能
   - 実際のサービスを起動せずにテスト

3. **依存関係の明確化**
   - コンストラクタで全依存関係を受け取る
   - 構築後は不変

## 使い分けの判断基準

### ファクトリーパターンを使うべき場合

| 状況 | 理由 |
|------|------|
| **実行時パラメータが必要** | ユーザー入力、リクエストデータ |
| **同じタイプを複数回生成** | ループ内で異なるパラメータ |
| **条件付き生成** | 実行時条件で異なるタイプ |

### 他のパターンを検討すべき場合

| 状況 | 代替パターン |
|------|------------|
| **実行時パラメータ不要** | 直接DI |
| **複雑な初期化のみ** | プロバイダー束縛 |
| **シングルトン** | スコープ設定 |

### 判断フロー

```
オブジェクト生成が必要
│
├─ 実行時パラメータが必要？
│  ├─ YES → ✅ ファクトリーパターン
│  └─ NO  → 次の質問へ
│
├─ 初期化が複雑？
│  ├─ YES → プロバイダーパターン（次のセクション）
│  └─ NO  → 通常のDI束縛で十分
```

## よくあるアンチパターン

### 神ファクトリー

```php
// ❌ 何でも生成できる汎用ファクトリー
interface GenericFactoryInterface
{
    public function create(string $class, array $params): object;
}

// ✅ 型安全な専用ファクトリー
interface OrderProcessorFactoryInterface
{
    public function create(int $orderId): OrderProcessor;
}
```

**なぜ問題か**：型安全性の喪失、インターフェースの契約が不明確

### ファクトリーでのビジネスロジック

```php
// ❌ ファクトリーがビジネスロジックを持つ
public function create(int $orderId): OrderProcessor
{
    $order = $this->repository->find($orderId);
    if ($order->getTotal() > 10000) {  // ビジネスルール
        $this->notify($order);
    }
    return new OrderProcessor(...);
}

// ✅ ファクトリーは生成のみ
public function create(int $orderId): OrderProcessor
{
    return new OrderProcessor($orderId, $this->service, ...);
}
```

**なぜ問題か**：単一責任原則違反、ファクトリーの責任が不明確

## SOLID原則との関係

- **SRP**：ファクトリーは「オブジェクト生成」のみを担当
- **OCP**：新しいタイプの追加時、既存コードを変更しない
- **DIP**：インターフェースに依存、具象クラスへの依存を排除

## まとめ

### ファクトリーパターンの核心

- **DIコンテナの限界を補完**：実行時パラメータを扱えるようにする
- **責任の明確化**：生成ロジックを分離
- **テスト可能性**：ファクトリーを差し替え可能

### 次のステップ

実行時パラメータではなく、**複雑な初期化ロジック**が課題の場合は、プロバイダーパターンが適しています。

**続きは:** [プロバイダーパターン](provider-pattern.html)

---

ファクトリーパターンは、**設定時**と**実行時**の境界を明確にします。この理解がDIを使いこなす鍵です。
