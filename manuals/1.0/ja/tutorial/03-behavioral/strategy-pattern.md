---
layout: docs-ja
title: Strategyパターン
category: Manual
permalink: /manuals/1.0/ja/tutorial/03-behavioral/strategy-pattern.html
---
# 依存性注入によるStrategyパターン

## 問題

アルゴリズムを追加するたびに条件分岐が増殖していきます。配送料金を計算するサービスを考えてみましょう。新しい配送方法を追加するたびに、条件分岐が増えていきます。ビジネス要件が増えるたびにメソッドが肥大化します：

```php
class ShippingService
{
    public function calculateCost(Order $order): Money
    {
        $method = $order->getShippingMethod();

        if ($method === 'standard') {
            return Money::of(10.00);
        } elseif ($method === 'express') {
            $cost = Money::of(25.00);
            if ($order->getWeight() > 10) {
                $cost = $cost->add(Money::of(15.00));
            }
            return $cost;
        }
        // 新しい配送方法を追加するたびに条件が増える！
    }
}
```

## なぜ問題なのか

これは機能追加と安定性維持の間に根本的な緊張関係を生み出します。新しい配送方法を追加するたびに既存のコードを変更する必要があり、開放/閉鎖原則に違反します。翌日配送を追加する際に、標準配送や速達配送を処理するコードに触れないわけにはいきません。テストが困難になります—すべてのアルゴリズムをまとめてカバーする巨大なテストが必要になります。

このクラスは複数のアルゴリズムを管理することで単一責任原則に違反しています。コードを理解するには、すべての配送方法を一度に解析する必要があります。変更のたびに既存の機能を壊すリスクがあります。

## 解決策：Strategyパターン

Strategyパターンは、条件分岐をポリモーフィズムに置き換えることで、この問題を解決します。各配送方法は共通のインターフェースを実装する独立したクラスになります。サービスはアルゴリズムの選択をストラテジーに委譲します：

```php
// Strategyインターフェース
interface ShippingStrategyInterface
{
    public function calculateCost(Order $order): Money;
    public function supports(string $method): bool;
}

// 具体的なストラテジー実装
class ExpressShipping implements ShippingStrategyInterface
{
    public function calculateCost(Order $order): Money
    {
        $cost = Money::of(25.00);
        if ($order->getWeight() > 10) {
            $cost = $cost->add(Money::of(15.00));
        }
        return $cost;
    }

    public function supports(string $method): bool
    {
        return $method === 'express';
    }
}

// コンテキスト - ポリモーフィズムでストラテジーを使用
class ShippingService
{
    public function __construct(
        private array $strategies // ShippingStrategyInterface[]
    ) {}

    public function calculateCost(Order $order): Money
    {
        foreach ($this->strategies as $strategy) {
            if ($strategy->supports($order->getShippingMethod())) {
                return $strategy->calculateCost($order);
            }
        }
        throw new InvalidArgumentException('Unknown shipping method');
    }
}
```

## パターンの本質

Strategyパターンは明確な分離を生み出します：1つのクラスがすべてのアルゴリズムを知る代わりに、各アルゴリズムは自分自身だけを知ります。サービスはストラテジーのコレクションを受け取り、マッチが見つかるまで各ストラテジーの`supports()`メソッドを照会します。

```
変更前：1つのクラス、多数の条件分岐（if/else）
変更後：多数のクラス、1つのインターフェース（ポリモーフィズム）
```

なぜこれが重要なのでしょうか？翌日配送を追加する際、既存の配送方法に触れずに新しいクラスを作成します。速達配送のロジックを変更しても、標準配送は影響を受けません。翌日配送をテストする際は、そのクラスだけをテストします。各変更には単一の場所があります。配送方法は自分自身の動作を決定します—ポリモーフィズムが条件分岐チェーンを排除します。

## Strategyパターンを使用するとき

同じ操作に対して複数のアルゴリズムがあり、実行時に選択が必要な場合にStrategyパターンを使用します。これには決済処理（クレジットカード、PayPal、暗号通貨）、割引計算（パーセンテージ、固定額、段階的）、または新しいバリアントごとに条件分岐が増殖するあらゆるシナリオが含まれます。

ストラテジーは、アルゴリズムが関連しているが実装が異なる場合に優れています。各配送方法は異なる方法で料金を計算しますが、すべて同じインターフェースを共有します。このパターンはアルゴリズムロジックをクライアントコードから分離し、両方を独立してテストおよび保守可能にします。

## Strategyを避けるとき

シンプルなケースではストラテジーを避けてください。変更しないアルゴリズムが1つしかない場合、コンストラクタインジェクションで十分です。条件分岐がシンプルで成長しない場合は、条件分岐のままにしておきます。値が空かどうかをチェックするためにストラテジーを作成しないでください—それは抽象化を必要としない1行の条件分岐です。

## よくある間違い：クライアントでのストラテジー選択

頻繁に見られるアンチパターンは、クライアントがストラテジーの選択を担当することです：

```php
// ❌ 悪い例 - クライアントがどのストラテジーを使うか決定
class OrderService
{
    public function processPayment(Order $order)
    {
        if ($order->getPaymentMethod() === 'credit_card') {
            $strategy = $this->creditCardStrategy;
        } else {
            $strategy = $this->paypalStrategy;
        }
        $strategy->process($order);
    }
}

// ✅ 良い例 - ストラテジーがsupports()で決定
class PaymentService
{
    public function __construct(private array $strategies) {}

    public function processPayment(Order $order)
    {
        foreach ($this->strategies as $strategy) {
            if ($strategy->supports($order->getPaymentMethod())) {
                return $strategy->process($order);
            }
        }
    }
}
```

クライアントは具体的なストラテジー実装について知るべきではありません。これは目的を台無しにします—条件分岐をある場所から別の場所に移動しただけです。`supports()`メソッドを使用してサービス内でストラテジー選択をカプセル化します。各ストラテジーに要求を処理できるかどうかを決定させます。ストラテジーはステートレスで再利用可能に保ちます—呼び出しをまたいで蓄積される可変の内部状態を持たせません。

## SOLID原則

Strategyパターンは各ストラテジーに1つのアルゴリズムを管理させることで**単一責任原則**を強制します。**開放/閉鎖原則**をサポートします—配送サービスを変更せずに、新しいストラテジークラスを作成することで新しい配送方法を追加できます。すべてのストラテジーが共通のインターフェースを通じて交換可能であるため、**リスコフの置換原則**を支持します。具体的な実装ではなくストラテジーインターフェースに依存することで**依存性逆転の原則**を例示します。

## テスト

ストラテジーはテストを劇的に簡素化します。ストラテジーがない場合、配送サービスのテストにはすべての配送方法をまとめてカバーする巨大なテストが必要です。変更があればすべてを再テストする必要があります。ストラテジーを使えば、各配送方法を独立してテストできます。標準配送のテストにはStandardShippingクラスだけが必要です。テスト対象は1つの複雑な統合テストから複数のシンプルな単体テストに縮小されます。

## 重要なポイント

Strategyパターンは条件分岐をポリモーフィズムに置き換えます。同じ操作に対して複数のアルゴリズムがあり、実行時に選択が必要な場合に使用します。各ストラテジーは独立していて、テスト可能で、再利用可能です。ストラテジーはステートレスに保ちます—呼び出しをまたいで蓄積される可変の内部状態を持たせません。クライアントにプッシュするのではなく、サービス内でストラテジー選択をカプセル化します。このパターンは開放/閉鎖原則に従います：既存のコードを変更せずに新しいストラテジーを追加できます。

---

**次へ：** [Decoratorパターン & AOP](decorator-aop.html) - 横断的関心事の分離

**前へ：** [Providerパターン](../02-object-creation/provider-pattern.html)
