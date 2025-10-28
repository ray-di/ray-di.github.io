---
layout: docs-ja
title: Service Layer
category: Manual
permalink: /manuals/1.0/ja/study/04-architecture/service-layer.html
---
# Service Layer：ビジネスロジックの調整

## 問題

ビジネスロジックがコントローラーに直接埋め込まれています。注文を処理するエンドポイントを考えてみましょう。HTTPリクエストを処理するコードの中にビジネスルール、検証、在庫チェックが混在しています。コントローラーはドメインロジックで肥大化し、再利用が不可能になっています：

```php
class OrderController
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private InventoryServiceInterface $inventoryService,
        private PaymentGatewayInterface $paymentGateway
    ) {}

    public function createOrder(Request $request): Response
    {
        // 検証がHTTPレイヤーと混在
        if (!$request->has('items') || empty($request->get('items'))) {
            return new Response('Items required', 400);
        }

        // ビジネスロジックがコントローラーに埋め込まれている！
        $order = new Order($request->get('customer_id'));
        foreach ($request->get('items') as $itemData) {
            if (!$this->inventoryService->isAvailable($itemData['product_id'], $itemData['quantity'])) {
                return new Response('Insufficient inventory', 400);
            }
            $order->addItem($itemData['product_id'], $itemData['quantity']);
        }

        $this->paymentGateway->charge($order->getTotal());
        $this->orderRepository->save($order);

        return new Response('Order created', 201);
    }
}
```

## なぜ問題なのか

これはプレゼンテーション層とビジネスロジックの間に根本的な結合を生み出します。注文処理をCLIコマンド、APIエンドポイント、バックグラウンドジョブから使用したくても、ビジネスロジックがHTTPコントローラーに閉じ込められているため不可能です。検証、在庫チェック、決済処理を単独でテストできません—完全なHTTPリクエストが必要です。

コントローラーはHTTP関連のタスクとビジネスルールの両方を処理することで単一責任原則に違反しています。HTTPリクエストのマッピングをJSON APIからGraphQLに変更しても、ビジネスロジックは影響を受けるべきではありません。しかし、ここではそれらが不可分に結合しています。複数のエンドポイントが注文処理を必要とする場合、ロジックを重複させるかコントローラー間で共有するしかありません—どちらもアンチパターンです。

## 解決策：Service Layer

Service Layerパターンは、ビジネスロジックをプレゼンテーション層から分離することで、この問題を解決します。コントローラーはシンプルなままでリクエストのマッピングのみを処理し、サービスはビジネスルールを調整し、リポジトリはデータアクセスを処理します：

```php
// Service Layer - ビジネスロジックを調整
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository,
        private InventoryServiceInterface $inventoryService,
        private PaymentGatewayInterface $paymentGateway
    ) {}

    public function createOrder(int $customerId, array $items): Order
    {
        $this->validateItems($items);

        $order = new Order($customerId);
        foreach ($items as $item) {
            $this->validateInventory($item['product_id'], $item['quantity']);
            $order->addItem($item['product_id'], $item['quantity']);
        }

        $this->paymentGateway->charge($order->getTotal());
        $this->orderRepository->save($order);

        return $order;
    }

    private function validateItems(array $items): void
    {
        if (empty($items)) {
            throw new InvalidArgumentException('Items required');
        }
    }

    private function validateInventory(int $productId, int $quantity): void;
}

// Thin Controller - HTTPマッピングのみ
class OrderController
{
    public function __construct(private OrderService $orderService) {}

    public function createOrder(Request $request): Response
    {
        try {
            $order = $this->orderService->createOrder(
                $request->get('customer_id'),
                $request->get('items')
            );
            return new Response('Order created', 201);
        } catch (InvalidArgumentException $e) {
            return new Response($e->getMessage(), 400);
        }
    }
}
```

## パターンの本質

Service Layerパターンは明確な責任の分離を生み出します：コントローラーはHTTPリクエストとレスポンスを処理します。サービスはビジネスロジックを調整します。リポジトリはデータアクセスを処理します。各レイヤーは単一の関心事を知っています。

```
変更前：Controller → ビジネスロジック + データアクセス
変更後：Controller → Service → Repository
```

なぜこれが重要なのでしょうか？RESTからGraphQLに切り替える際、サービスには触れません—新しいコントローラーを書くだけです。CLIコマンドを追加する際、サービスを再利用します—ビジネスロジックの重複はありません。注文処理をテストする際、HTTPなしでサービスをテストします—HTTPコンテキスト全体をモックする必要はありません。ビジネスロジックは一度書いて、どこからでも使用できます。各レイヤーは独立してテスト可能で、交換可能です。

## Service Layerを使用するとき

複数のエントリーポイントから同じビジネスロジックにアクセスする必要がある場合にService Layerを使用します。これにはREST API、GraphQL、CLIコマンド、バックグラウンドジョブからアクセスされる注文処理、ユーザー登録、支払い処理が含まれます。ビジネスロジックが複雑で、複数のリポジトリやサービスを調整する必要がある場合、サービスレイヤーはこの調整をカプセル化します。

サービスはビジネスロジックをプレゼンテーション層から分離したり、ビジネスルールを独立してテストしたりする必要がある場合に優れています。コントローラーがビジネスロジックで肥大化している場合、サービスレイヤーはコントローラーをシンプルに保ちます。ビジネスロジックが複数のドメインオブジェクトにまたがる場合、サービスはトランザクション境界とワークフロー調整を提供します。

## サービスとオブジェクト指向

Service Layerは、オブジェクト指向と手続き型プログラミングのハイブリッドです。ドメインオブジェクトは振る舞いを持つ（オブジェクト指向）一方、サービスは基本的に対象を操作する手続き型のプログラミングです。

### ドメインオブジェクトに振る舞いを持たせる

```php
// ✅ ドメインオブジェクトが自律的に振る舞う（オブジェクト指向）
class Order
{
    public function validate(): void
    {
        if (empty($this->items)) {
            throw new InvalidOrderException();
        }
    }

    public function markAsConfirmed(): void
    {
        if ($this->status !== 'pending') {
            throw new InvalidStateException();
        }
        $this->status = 'confirmed';
    }
}
```

ドメインの概念（検証、状態遷移、計算）はドメインオブジェクトのメソッドとして実装します。`Order`は単なるデータの入れ物ではなく、自分自身の状態を管理する責任を持ちます。

### サービスは調整に徹する

```php
// サービスはドメインオブジェクト同士を調整する
class OrderService
{
    public function processOrder(Order $order): void
    {
        // ドメインロジックはOrderに委譲
        $order->validate();

        // 在庫サービスとの調整
        if (!$this->inventoryService->reserve($order->getItems())) {
            throw new InsufficientInventoryException();
        }

        // ドメインロジックはOrderに委譲
        $order->markAsConfirmed();

        // リポジトリとの調整
        $this->orderRepository->save($order);
    }
}
```

サービスはビジネスロジックを持たず、ドメインオブジェクト同士やインフラストラクチャとの調整に徹します。検証ロジックは`Order.validate()`に、状態遷移ロジックは`Order.markAsConfirmed()`に委譲されています。サービスは「どう検証するか」「どう状態遷移するか」を知りません。ただ「いつ検証するか」「いつ状態遷移するか」という手順だけを知っています。

### 貧血ドメインモデルを避ける

```php
// ❌ 悪い例 - ビジネスロジックがサービスに
class Order
{
    public function setStatus(string $status): void { }  // 単なるデータ
}

class OrderService
{
    public function confirmOrder(Order $order): void
    {
        // ビジネスロジック（状態遷移のルール）がサービスに
        if ($order->getStatus() !== 'pending') {
            throw new InvalidStateException();
        }
        $order->setStatus('confirmed');
    }
}
```

ドメインオブジェクトが単なるgetter/setterだけを持つ状態を「貧血ドメインモデル」と呼びます。状態遷移のルール（pending状態でなければ確定できない）というビジネスロジックがサービスに漏れ出しています。このルールは`Order`クラスの`markAsConfirmed()`メソッドに属するべきです。

**原則**: ドメインのロジックはドメインオブジェクトに書きます。サービスにはビジネスロジックを持たせず、ドメインオブジェクト同士の調整に徹します。

## よくある間違い：太ったサービス

頻繁に見られるアンチパターンは、すべてのビジネスロジックを1つの巨大なサービスに詰め込むことです：

```php
// ❌ 悪い例 - 単一の巨大なサービスがすべてを処理
class OrderService
{
    public function createOrder(...) { }
    public function cancelOrder(...) { }
    public function refundOrder(...) { }
    public function shipOrder(...) { }
    public function trackShipment(...) { }
    public function calculateShipping(...) { }
    public function validateAddress(...) { }
    public function sendOrderEmail(...) { }
    // 12個のメソッド、500行...
}

// ✅ 良い例 - 機能別にサービスを分割
class OrderService
{
    public function createOrder(...) { }
    public function cancelOrder(...) { }
}

class ShippingService
{
    public function shipOrder(...) { }
    public function trackShipment(...) { }
    public function calculateCost(...) { }
}

class OrderNotificationService
{
    public function sendOrderConfirmation(...) { }
    public function sendShipmentNotification(...) { }
}
```

サービスは関連するビジネスロジックをグループ化しますが、すべてを含むべきではありません。配送計算は注文作成とは異なる関心事です—ShippingServiceに属します。通知は注文ワークフローとは異なる関心事です—NotificationServiceに属します。サービスは1つのドメインエンティティまたは密接に関連する操作に焦点を当てます。サービスが10個以上のメソッドを持つ場合、または500行を超える場合、より小さなサービスに分割します。

## SOLID原則

Service Layerパターンは各サービスに単一の凝集性のある責任を与えることで**単一責任原則**を強制します。コントローラーはHTTPを処理し、サービスはビジネスロジックを処理し、リポジトリはデータアクセスを処理します。**開放/閉鎖原則**をサポートします—ビジネスロジックを変更せずに新しいコントローラー（REST、GraphQL、CLI）を追加できます。すべてのサービスがインターフェースを通じて交換可能であるため、**リスコフの置換原則**を支持します。具体的な実装ではなくサービスインターフェースに依存することで**依存性逆転の原則**を例示します。

## テスト

Service Layerはテストを劇的に簡素化します。サービスがない場合、注文処理のテストには完全なHTTPリクエスト、ルーティング、リクエストパラメータのマッピング、レスポンス解析が必要です—すべてのテストがフレームワーク統合テストになります。サービスを使えば、ビジネスロジックを直接テストします。注文処理のテストにはOrderServiceとモックされた依存関係だけが必要です。テスト対象はHTTPインフラストラクチャを含む統合テストから、ビジネスロジックに焦点を当てた単体テストに縮小されます。

## 重要なポイント

Service Layerはビジネスロジックをプレゼンテーション層から分離します。複数のエントリーポイント（REST、GraphQL、CLI）が同じビジネスロジックを必要とする場合や、ビジネスルールが複雑で独立したテストが必要な場合に使用します。コントローラーはシンプルに保ちます—リクエストをマップし、サービスを呼び出し、レスポンスを返します。サービスはビジネスロジックを調整します—検証、ワークフロー、トランザクション境界を処理します。リポジトリはデータアクセスを処理します。すべてのビジネスロジックを1つの巨大なサービスに詰め込まないでください—関連する操作ごとに焦点を絞ったサービスを作成します。

---

**次へ：** [Module Design](module-design.html) - DI設定の整理

**前へ：** [Repositoryパターン](repository-pattern.html)
