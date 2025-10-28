---
layout: docs-ja
title: Factory Pattern
category: Manual
permalink: /manuals/1.0/ja/study/02-object-creation/factory-pattern.html
---
# Factoryパターン：実行時パラメータと依存性注入の融合

## 問題

DI管理される依存関係と実行時パラメータの両方を必要とするオブジェクトを作成する必要があります。注文処理サービスを考えてみてください。実行時に提供される顧客データでOrderオブジェクトを作成する必要があります。Order自体は、バリデータや計算機などの注入された依存関係も必要とします：

```php
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository
    ) {}

    public function createOrder(Customer $customer, array $items): Order
    {
        // 問題：実行時データとDI依存関係の両方をどう提供する？
        $order = new Order(
            $customer,           // 実行時パラメータ
            $items,              // 実行時パラメータ
            ???                  // OrderValidator（DIが必要）
            ???                  // PriceCalculator（DIが必要）
        );

        $this->orderRepository->save($order);
    }
}
```

## なぜ問題なのか

これは2つのニーズ間に根本的な緊張を生み出します：実行時データの受け渡しと依存関係の注入です。サービス層はOrderの内部依存関係を知るべきではありません。これは関心の分離に違反し、テストを複雑にします。サービスをテストする際、Orderの依存関係をモックできません。Orderのコンストラクタへの変更は、注文を作成するすべてのサービスに波及します。

サービスはビジネスロジックの調整と依存関係の配線という2つの異なる責任を処理しています。この結合により、コードは脆弱で保守が困難になります。

## 解決策：Factoryパターン

Factoryパターンは、オブジェクト作成を専用のFactoryに委譲することでこれを解決し、DIが管理できるようにします：

```php
// Factoryインターフェース
interface OrderFactoryInterface
{
    public function create(Customer $customer, array $items): Order;
}

// Factory実装はDIを通じて依存関係を受け取る
class OrderFactory implements OrderFactoryInterface
{
    public function __construct(
        private OrderValidatorInterface $validator,
        private PriceCalculatorInterface $calculator
    ) {}

    public function create(Customer $customer, array $items): Order
    {
        // 呼び出し元からの実行時データ ↓  コンストラクタからのDI依存関係 ↓
        return new Order($customer, $items, $this->validator, $this->calculator);
    }
}

// サービス層はクリーンに保たれる
class OrderService
{
    public function __construct(
        private OrderFactoryInterface $orderFactory,
        private OrderRepositoryInterface $orderRepository
    ) {}

    public function createOrder(Customer $customer, array $items): Order
    {
        $order = $this->orderFactory->create($customer, $items);
        $this->orderRepository->save($order);
        return $order;
    }
}
```

Factoryバインディングの設定：
```php
$this->bind(OrderFactoryInterface::class)->to(OrderFactory::class);
```

## パターンの本質

Factoryパターンは明確な分離を作り出します：実行時パラメータはメソッド呼び出しを通じて流れ、依存関係はコンストラクタを通じて流れます。Factoryは「何を作成するか」（実行時データ）を受け取り、「どのように作成するか」（依存関係の配線）を知っています。

```
実行時パラメータ ──┐
                  ├──> Factory ──> 依存関係を持つオブジェクト
DI依存関係 ────────┘
```

なぜこれが重要なのでしょうか？実行時のニーズが変わったとき（新しい顧客タイプ、新しい注文フロー）、Factoryの呼び出しだけを修正します。依存関係が変わったとき（新しいバリデータ、異なる計算機）、Factoryのコンストラクタだけを修正します。各変更には単一の明確な場所があります。サービス層は純粋にビジネスロジックに集中し、オブジェクト構築の仕組みをそのために設計されたコンポーネントに委譲します。

## Factoryパターンをいつ使うか

オブジェクトがDI依存関係と実行時パラメータの両方を必要とする場合にFactoryパターンを使用します。この状況は、エンティティが振る舞いの依存関係（サービス、バリデータ）と実行時のみのデータ（ID、値）の両方を必要とするドメイン駆動設計で一般的です。

Factoryはオブジェクト作成に複雑なロジックが含まれる場合にも価値があります。多段階の初期化、検証、条件付き構築など、複雑な生成ロジックを一箇所に集約することで、再利用可能かつテスト可能にします。

## 静的メソッドからDI管理されたFactoryへ

静的Factoryメソッド（`Order::create()`）の利用は珍しくないですが、DI管理されたFactoryへ移行すべきです：

```php
// ❌ 悪い例 - 静的メソッドは依存性注入を使用できない
class Order
{
    public static function create(Customer $customer, array $items): self
    {
        $validator = new OrderValidator(); // ハードコードされた依存関係！
        return new self($customer, $items, $validator);
    }
}

// ✅ 良い例 - FactoryはDIを通じて依存関係を受け取る
class OrderFactory implements OrderFactoryInterface
{
    public function __construct(private OrderValidatorInterface $validator) {}

    public function create(Customer $customer, array $items): Order
    {
        return new Order($customer, $items, $this->validator);
    }
}
```

静的メソッドは便利に見えますが、モックや置換ができない隠れた依存関係を作り出します。これらはテストを極めて困難にし、依存性逆転原則に違反します。

## SOLID原則

FactoryパターンはいくつかのSOLID原則をサポートします。オブジェクト作成をビジネスロジックから分離することで**単一責任原則**を実施します。新しいFactoryを作成し、既存のコードを修正しないことで新しいオブジェクトタイプを追加できるため、**開放/閉鎖原則**を可能にします。最も重要なのは、具体的な実装ではなくFactoryインターフェースに依存することで**依存性逆転原則**を支持することです。

## テスト

Factoryはテストを劇的に簡素化します。Factoryなしでは、OrderServiceをテストするにはOrderValidatorとPriceCalculatorをモックする必要があります。Factoryを使用すれば、OrderFactoryInterfaceだけをモックします。テスト対象が3つのインターフェースから1つに縮小します。

テストは事前に設定されたオブジェクトを返すモックFactoryを作成します。これにより、サービスのビジネスロジックを分離してテストできます。Factory自体は独立してテストでき、依存関係を正しく組み立てることを確認できます。

## 重要なポイント

Factoryパターンは実行時パラメータと依存性注入の間のギャップを埋めます。オブジェクトが両方のタイプの入力を必要とする場合に使用します。Factoryをオブジェクト作成に集中させ、ビジネスロジックは含めません。依存性注入をバイパスする静的Factoryメソッドを避けます。適切に設計されたFactoryは、コードをよりテスト可能で、保守しやすく、SOLID原則に沿ったものにします。

---

**次へ：** [Provider Pattern](provider-pattern.html) - 初期化が複雑な場合

**前へ：** [Ray.Diの基礎](../01-foundations/raydi-fundamentals.html)