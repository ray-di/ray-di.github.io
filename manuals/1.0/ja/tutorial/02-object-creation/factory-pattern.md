---
layout: docs-ja
title: Factoryパターン
category: Manual
permalink: /manuals/1.0/ja/tutorial/factory-pattern.html
---
# 依存性注入におけるFactoryパターン

## 問題

DI管理の依存関係と実行時パラメータの両方を必要とするオブジェクトを作成する必要があります。注文処理サービスを考えてみましょう。このサービスは実行時に提供される顧客データでOrderオブジェクトを作成する必要がありますが、Order自体はバリデーターや計算機などの注入された依存関係を必要とします：

```php
class OrderService
{
    public function __construct(
        private OrderRepositoryInterface $orderRepository
    ) {}

    public function createOrder(Customer $customer, array $items): Order
    {
        // 問題: 実行時データとDI依存関係の両方をどう提供するか？
        $order = new Order(
            $customer,           // 実行時パラメータ
            $items,              // 実行時パラメータ
            ???                  // OrderValidator (DIが必要)
            ???                  // PriceCalculator (DIが必要)
        );

        $this->orderRepository->save($order);
    }
}
```

## なぜ問題なのか

これは根本的な矛盾を生み出します。サービス層はOrderの内部依存関係を知るべきではありません—それは関心の分離に違反し、テストを困難にします。サービスをテストする際、Orderの依存関係をモックすることができません。さらに重要なことに、Orderのコンストラクタを変更すると、注文を作成するすべてのサービスに波及します。

サービスは2つの異なる責任を扱っています：ビジネスロジックの調整と依存関係の配線管理です。この結合によりコードは脆く保守が困難になります。

## 解決策: Factoryパターン

Factoryパターンは、オブジェクト作成をDIが管理できる専用のファクトリーに委譲することでこれを解決します：

```php
// Factoryインターフェース
interface OrderFactoryInterface
{
    public function create(Customer $customer, array $items): Order;
}

// Factory実装はDI経由で依存関係を受け取る
class OrderFactory implements OrderFactoryInterface
{
    public function __construct(
        private OrderValidatorInterface $validator,
        private PriceCalculatorInterface $calculator
    ) {}

    public function create(Customer $customer, array $items): Order
    {
        return new Order($customer, $items, $this->validator, $this->calculator);
    }
}

// サービス層はクリーンなまま
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

ファクトリーのバインディングを設定：
```php
$this->bind(OrderFactoryInterface::class)->to(OrderFactory::class);
```

## パターンの本質

Factoryパターンは明確な分離を作り出します：実行時パラメータはメソッド呼び出しを通じて流れ、依存関係はコンストラクタを通じて流れます。ファクトリーは「何を作成するか」（実行時データ）を受け取り、「どう作成するか」（依存関係の配線）を知っています。

```
実行時パラメータ ──┐
                   ├──> Factory ──> 依存関係を持つオブジェクト
DI依存関係 ────────┘
```

この分離により、サービス層は純粋にビジネスロジックに集中でき、オブジェクト構築の仕組みを、その目的のために特別に設計されたコンポーネントに委譲できます。

## Factoryパターンを使う時

オブジェクトがDI依存関係と実行時パラメータの両方を必要とする場合にFactoryパターンを使用します。この状況は、エンティティが振る舞いの依存関係（サービス、バリデーター）と実行時にのみ存在するデータ（ID、値）の両方を必要とするドメイン駆動設計で頻繁に発生します。

ファクトリーは、オブジェクト作成に複雑なロジック—多段階の初期化、検証、条件付き構築—が含まれる場合にも有用です。このロジックをファクトリーに集約することで、再利用可能でテスト可能になります。

ただし、単純なケースではファクトリーを避けてください。オブジェクトがDI依存関係のみを必要とする場合は、コンストラクタインジェクションを直接使用します。依存関係なしで実行時パラメータのみを必要とする場合は、シンプルなコンストラクタで十分です。1行のオブジェクト構築のためにファクトリーを作成しないでください—それは不要な抽象化です。

## よくある間違い: 静的Factoryメソッド

頻繁に見られるアンチパターンは、DI管理のファクトリーの代わりに静的ファクトリーメソッドを使用することです：

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

// ✅ 良い例 - ファクトリーはDI経由で依存関係を受け取る
class OrderFactory implements OrderFactoryInterface
{
    public function __construct(private OrderValidatorInterface $validator) {}

    public function create(Customer $customer, array $items): Order
    {
        return new Order($customer, $items, $this->validator);
    }
}
```

静的メソッドは便利に見えますが、モックや置き換えができない隠れた依存関係を作成します。テストを不可能にし、依存性逆転の原則に違反します。

## SOLID原則

Factoryパターンは複数のSOLID原則をサポートします。オブジェクト作成とビジネスロジックを分離することで単一責任原則を強制します。開放閉鎖原則を実現します—既存のコードを変更せずに新しいファクトリーを作成することで新しいオブジェクトタイプを追加できます。最も重要なことは、具象実装ではなくファクトリーインターフェースに依存することで依存性逆転の原則を支持します。

## テスト

ファクトリーはテストを劇的に簡素化します。オブジェクトのすべての依存関係をモックする代わりに、ファクトリーだけをモックします。テストでは、事前設定されたオブジェクトを返すモックファクトリーを作成し、サービスのビジネスロジックを分離してテストできます。ファクトリー自体は、依存関係を正しく配線することを確認するために独立してテストできます。

## 重要なポイント

Factoryパターンは実行時パラメータと依存性注入の間のギャップを埋めます。オブジェクトが両方のタイプの入力を必要とする場合に使用します。ファクトリーをオブジェクト作成に集中させてください—ビジネスロジックは含めません。依存性注入をバイパスする静的ファクトリーメソッドを避けてください。適切に設計されたファクトリーは、コードをよりテスト可能で保守しやすく、SOLID原則に沿ったものにします。

---

**次:** [Providerパターン](provider-pattern.html) - 複雑な初期化が必要な場合

**前:** [SOLID原則の実践](../01-foundations/solid-principles.html)
