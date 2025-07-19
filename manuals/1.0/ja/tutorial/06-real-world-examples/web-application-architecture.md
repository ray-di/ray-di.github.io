---
layout: docs-ja
title: Webアプリケーション アーキテクチャ
category: Manual
permalink: /manuals/1.0/ja/tutorial/06-real-world-examples/web-application-architecture.html
---

# Webアプリケーション アーキテクチャ

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diを使ったWebアプリケーションの全体アーキテクチャ
- 階層化アーキテクチャの実装方法
- MVC、Clean Architecture、Hexagonal Architectureの実装
- 実際のE-commerceプラットフォームの完全な設計
- スケーラビリティとメンテナンス性の確保

## アーキテクチャの概要

### 1. 階層化アーキテクチャ

```php
// アプリケーション全体の階層構造
namespace ShopSmart;

// プレゼンテーション層
namespace ShopSmart\Presentation\Http {
    // コントローラー
    class ProductController {}
    class UserController {}
    class OrderController {}
    
    // ミドルウェア
    class AuthenticationMiddleware {}
    class AuthorizationMiddleware {}
    class LoggingMiddleware {}
    
    // リクエスト/レスポンス
    class CreateOrderRequest {}
    class ProductListResponse {}
}

// アプリケーション層
namespace ShopSmart\Application\UseCase {
    // ユースケース
    class CreateOrderUseCase {}
    class UpdateProductUseCase {}
    class ProcessPaymentUseCase {}
    
    // サービス
    class OrderService {}
    class ProductService {}
    class UserService {}
}

// ドメイン層
namespace ShopSmart\Domain {
    // エンティティ
    class Product {}
    class User {}
    class Order {}
    
    // 値オブジェクト
    class Price {}
    class Email {}
    class OrderId {}
    
    // ドメインサービス
    class PricingService {}
    class InventoryService {}
}

// インフラストラクチャ層
namespace ShopSmart\Infrastructure {
    // リポジトリ実装
    class MySQLProductRepository {}
    class ElasticsearchProductRepository {}
    
    // 外部サービス
    class StripePaymentGateway {}
    class SendGridEmailService {}
}
```

### 2. 依存関係の方向

```php
// 依存関係の逆転を実現するモジュール設計
class ShopSmartAppModule extends AbstractModule
{
    protected function configure(): void
    {
        // プレゼンテーション → アプリケーション
        $this->bind(CreateOrderUseCaseInterface::class)
            ->to(CreateOrderUseCase::class);
        
        // アプリケーション → ドメイン
        $this->bind(ProductServiceInterface::class)
            ->to(ProductService::class);
        
        // ドメイン ← インフラストラクチャ（逆転）
        $this->bind(ProductRepositoryInterface::class)
            ->to(MySQLProductRepository::class);
        
        $this->bind(PaymentGatewayInterface::class)
            ->to(StripePaymentGateway::class);
        
        // 横断的関心事
        $this->installAopModule();
    }
    
    private function installAopModule(): void
    {
        $this->install(new AopModule());
    }
}
```

## MVCアーキテクチャの実装

### 1. コントローラー層

```php
// 基底コントローラー
abstract class BaseController
{
    protected ResponseFactoryInterface $responseFactory;
    protected ValidatorInterface $validator;
    protected LoggerInterface $logger;
    
    public function __construct(
        ResponseFactoryInterface $responseFactory,
        ValidatorInterface $validator,
        LoggerInterface $logger
    ) {
        $this->responseFactory = $responseFactory;
        $this->validator = $validator;
        $this->logger = $logger;
    }
    
    protected function validateRequest(ServerRequestInterface $request, array $rules): array
    {
        $data = $request->getParsedBody();
        $result = $this->validator->validate($data, $rules);
        
        if (!$result->isValid()) {
            throw new ValidationException($result->getErrors());
        }
        
        return $data;
    }
    
    protected function jsonResponse(mixed $data, int $status = 200): ResponseInterface
    {
        return $this->responseFactory->createResponse($status)
            ->withHeader('Content-Type', 'application/json')
            ->withBody($this->createStream(json_encode($data)));
    }
    
    protected function errorResponse(string $message, int $status = 400): ResponseInterface
    {
        return $this->jsonResponse([
            'error' => $message,
            'status' => $status
        ], $status);
    }
}

// 商品コントローラー
class ProductController extends BaseController
{
    public function __construct(
        ResponseFactoryInterface $responseFactory,
        ValidatorInterface $validator,
        LoggerInterface $logger,
        private ProductServiceInterface $productService
    ) {
        parent::__construct($responseFactory, $validator, $logger);
    }
    
    #[Route('GET', '/products')]
    #[Logged]
    #[Cached(ttl: 300)]
    public function index(ServerRequestInterface $request): ResponseInterface
    {
        $params = $request->getQueryParams();
        
        $page = (int)($params['page'] ?? 1);
        $limit = (int)($params['limit'] ?? 20);
        $category = $params['category'] ?? null;
        
        $products = $this->productService->getProducts($page, $limit, $category);
        
        return $this->jsonResponse([
            'products' => $products,
            'pagination' => [
                'page' => $page,
                'limit' => $limit,
                'total' => $this->productService->getTotalCount($category)
            ]
        ]);
    }
    
    #[Route('POST', '/products')]
    #[Authorized('admin')]
    #[Logged]
    #[Validated]
    public function create(ServerRequestInterface $request): ResponseInterface
    {
        $data = $this->validateRequest($request, [
            'name' => 'required|string|max:255',
            'description' => 'required|string',
            'price' => 'required|numeric|min:0',
            'category_id' => 'required|integer'
        ]);
        
        $product = $this->productService->createProduct($data);
        
        return $this->jsonResponse($product, 201);
    }
    
    #[Route('GET', '/products/{id}')]
    #[Cached(ttl: 600)]
    public function show(ServerRequestInterface $request, array $args): ResponseInterface
    {
        $id = (int)$args['id'];
        $product = $this->productService->getProduct($id);
        
        if (!$product) {
            return $this->errorResponse('Product not found', 404);
        }
        
        return $this->jsonResponse($product);
    }
    
    #[Route('PUT', '/products/{id}')]
    #[Authorized('admin')]
    #[Logged]
    #[CacheEvict(key: 'product:{id}')]
    public function update(ServerRequestInterface $request, array $args): ResponseInterface
    {
        $id = (int)$args['id'];
        $data = $this->validateRequest($request, [
            'name' => 'string|max:255',
            'description' => 'string',
            'price' => 'numeric|min:0',
            'category_id' => 'integer'
        ]);
        
        $product = $this->productService->updateProduct($id, $data);
        
        if (!$product) {
            return $this->errorResponse('Product not found', 404);
        }
        
        return $this->jsonResponse($product);
    }
    
    #[Route('DELETE', '/products/{id}')]
    #[Authorized('admin')]
    #[Logged]
    #[CacheEvict(key: 'product:{id}')]
    public function delete(ServerRequestInterface $request, array $args): ResponseInterface
    {
        $id = (int)$args['id'];
        $result = $this->productService->deleteProduct($id);
        
        if (!$result) {
            return $this->errorResponse('Product not found', 404);
        }
        
        return $this->jsonResponse(['message' => 'Product deleted successfully']);
    }
}
```

### 2. ミドルウェア層

```php
// 認証ミドルウェア
class AuthenticationMiddleware implements MiddlewareInterface
{
    public function __construct(
        private AuthServiceInterface $authService,
        private LoggerInterface $logger
    ) {}
    
    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler): ResponseInterface
    {
        $token = $this->extractToken($request);
        
        if (!$token) {
            return $this->createUnauthorizedResponse();
        }
        
        try {
            $user = $this->authService->authenticate($token);
            
            // ユーザー情報をリクエストに追加
            $request = $request->withAttribute('user', $user);
            
            return $handler->handle($request);
            
        } catch (AuthenticationException $e) {
            $this->logger->warning('Authentication failed', [
                'token' => substr($token, 0, 10) . '...',
                'error' => $e->getMessage(),
                'ip' => $request->getServerParams()['REMOTE_ADDR'] ?? 'unknown'
            ]);
            
            return $this->createUnauthorizedResponse();
        }
    }
    
    private function extractToken(ServerRequestInterface $request): ?string
    {
        $header = $request->getHeaderLine('Authorization');
        
        if (preg_match('/Bearer\s+(.*)$/i', $header, $matches)) {
            return $matches[1];
        }
        
        return null;
    }
    
    private function createUnauthorizedResponse(): ResponseInterface
    {
        return new Response(401, [], json_encode([
            'error' => 'Unauthorized',
            'message' => 'Valid authentication token required'
        ]));
    }
}

// 認可ミドルウェア
class AuthorizationMiddleware implements MiddlewareInterface
{
    public function __construct(
        private AuthorizationServiceInterface $authService,
        private LoggerInterface $logger
    ) {}
    
    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $route = $request->getAttribute('route');
        
        if (!$user || !$route) {
            return $handler->handle($request);
        }
        
        $requiredPermissions = $this->extractRequiredPermissions($route);
        
        if (!$requiredPermissions) {
            return $handler->handle($request);
        }
        
        try {
            if ($this->authService->isAuthorized($user, $requiredPermissions)) {
                return $handler->handle($request);
            }
            
            $this->logger->warning('Authorization failed', [
                'user_id' => $user->getId(),
                'required_permissions' => $requiredPermissions,
                'user_permissions' => $user->getPermissions()
            ]);
            
            return $this->createForbiddenResponse();
            
        } catch (AuthorizationException $e) {
            $this->logger->error('Authorization error', [
                'user_id' => $user->getId(),
                'error' => $e->getMessage()
            ]);
            
            return $this->createForbiddenResponse();
        }
    }
    
    private function extractRequiredPermissions(Route $route): ?array
    {
        // ルート情報から必要な権限を抽出
        $permissions = $route->getOption('permissions');
        return $permissions ? (array)$permissions : null;
    }
    
    private function createForbiddenResponse(): ResponseInterface
    {
        return new Response(403, [], json_encode([
            'error' => 'Forbidden',
            'message' => 'Insufficient permissions'
        ]));
    }
}
```

## Clean Architectureの実装

### 1. ユースケース層

```php
// ユースケース基底クラス
abstract class BaseUseCase
{
    protected LoggerInterface $logger;
    protected EventDispatcherInterface $eventDispatcher;
    
    public function __construct(
        LoggerInterface $logger,
        EventDispatcherInterface $eventDispatcher
    ) {
        $this->logger = $logger;
        $this->eventDispatcher = $eventDispatcher;
    }
    
    protected function publishEvent(DomainEventInterface $event): void
    {
        $this->eventDispatcher->dispatch($event);
    }
    
    protected function validateInput(array $input, array $rules): array
    {
        // バリデーションロジック
        return $input;
    }
}

// 注文作成ユースケース
class CreateOrderUseCase extends BaseUseCase
{
    public function __construct(
        LoggerInterface $logger,
        EventDispatcherInterface $eventDispatcher,
        private UserRepositoryInterface $userRepository,
        private ProductRepositoryInterface $productRepository,
        private OrderRepositoryInterface $orderRepository,
        private InventoryServiceInterface $inventoryService,
        private PricingServiceInterface $pricingService
    ) {
        parent::__construct($logger, $eventDispatcher);
    }
    
    #[Logged]
    #[Monitored]
    #[Transactional]
    public function execute(CreateOrderRequest $request): CreateOrderResponse
    {
        // 1. 入力検証
        $this->validateInput($request->toArray(), [
            'user_id' => 'required|integer',
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|integer',
            'items.*.quantity' => 'required|integer|min:1'
        ]);
        
        // 2. ユーザー存在確認
        $user = $this->userRepository->findById($request->getUserId());
        if (!$user) {
            throw new UserNotFoundException("User not found: {$request->getUserId()}");
        }
        
        // 3. 商品とinventory確認
        $orderItems = [];
        foreach ($request->getItems() as $item) {
            $product = $this->productRepository->findById($item['product_id']);
            if (!$product) {
                throw new ProductNotFoundException("Product not found: {$item['product_id']}");
            }
            
            if (!$this->inventoryService->isAvailable($product, $item['quantity'])) {
                throw new InsufficientInventoryException("Insufficient inventory for product: {$product->getName()}");
            }
            
            $orderItems[] = new OrderItem($product, $item['quantity']);
        }
        
        // 4. 価格計算
        $totalAmount = $this->pricingService->calculateTotal($orderItems);
        
        // 5. 注文作成
        $order = new Order($user, $orderItems, $totalAmount);
        
        // 6. 在庫予約
        foreach ($orderItems as $item) {
            $this->inventoryService->reserve($item->getProduct(), $item->getQuantity());
        }
        
        // 7. 注文保存
        $this->orderRepository->save($order);
        
        // 8. ドメインイベント発行
        $this->publishEvent(new OrderCreatedEvent($order));
        
        $this->logger->info('Order created successfully', [
            'order_id' => $order->getId(),
            'user_id' => $user->getId(),
            'total_amount' => $totalAmount
        ]);
        
        return new CreateOrderResponse($order);
    }
}

// リクエスト/レスポンスオブジェクト
class CreateOrderRequest
{
    public function __construct(
        private int $userId,
        private array $items,
        private ?string $couponCode = null
    ) {}
    
    public function getUserId(): int { return $this->userId; }
    public function getItems(): array { return $this->items; }
    public function getCouponCode(): ?string { return $this->couponCode; }
    
    public function toArray(): array
    {
        return [
            'user_id' => $this->userId,
            'items' => $this->items,
            'coupon_code' => $this->couponCode
        ];
    }
}

class CreateOrderResponse
{
    public function __construct(private Order $order) {}
    
    public function getOrder(): Order { return $this->order; }
    
    public function toArray(): array
    {
        return [
            'order_id' => $this->order->getId(),
            'status' => $this->order->getStatus(),
            'total_amount' => $this->order->getTotalAmount(),
            'created_at' => $this->order->getCreatedAt()->format('Y-m-d H:i:s')
        ];
    }
}
```

### 2. ドメイン層

```php
// ドメインエンティティ
class Order
{
    private ?int $id = null;
    private string $status = 'pending';
    private DateTime $createdAt;
    private DateTime $updatedAt;
    private array $items = [];
    private float $totalAmount;
    
    public function __construct(
        private User $user,
        array $items,
        float $totalAmount
    ) {
        $this->items = $items;
        $this->totalAmount = $totalAmount;
        $this->createdAt = new DateTime();
        $this->updatedAt = new DateTime();
    }
    
    public function getId(): ?int { return $this->id; }
    public function getUser(): User { return $this->user; }
    public function getItems(): array { return $this->items; }
    public function getTotalAmount(): float { return $this->totalAmount; }
    public function getStatus(): string { return $this->status; }
    public function getCreatedAt(): DateTime { return $this->createdAt; }
    
    public function markAsPaid(): void
    {
        if ($this->status !== 'pending') {
            throw new InvalidOrderStatusException("Cannot mark order as paid. Current status: {$this->status}");
        }
        
        $this->status = 'paid';
        $this->updatedAt = new DateTime();
    }
    
    public function cancel(): void
    {
        if (!in_array($this->status, ['pending', 'paid'])) {
            throw new InvalidOrderStatusException("Cannot cancel order. Current status: {$this->status}");
        }
        
        $this->status = 'cancelled';
        $this->updatedAt = new DateTime();
    }
    
    public function fulfill(): void
    {
        if ($this->status !== 'paid') {
            throw new InvalidOrderStatusException("Cannot fulfill order. Current status: {$this->status}");
        }
        
        $this->status = 'fulfilled';
        $this->updatedAt = new DateTime();
    }
}

// 値オブジェクト
class Price
{
    private float $amount;
    private string $currency;
    
    public function __construct(float $amount, string $currency = 'USD')
    {
        if ($amount < 0) {
            throw new InvalidArgumentException('Price cannot be negative');
        }
        
        $this->amount = $amount;
        $this->currency = $currency;
    }
    
    public function getAmount(): float { return $this->amount; }
    public function getCurrency(): string { return $this->currency; }
    
    public function add(Price $other): Price
    {
        if ($this->currency !== $other->currency) {
            throw new InvalidArgumentException('Cannot add prices with different currencies');
        }
        
        return new Price($this->amount + $other->amount, $this->currency);
    }
    
    public function multiply(float $multiplier): Price
    {
        return new Price($this->amount * $multiplier, $this->currency);
    }
    
    public function equals(Price $other): bool
    {
        return $this->amount === $other->amount && $this->currency === $other->currency;
    }
}

// ドメインサービス
class PricingService implements PricingServiceInterface
{
    public function __construct(
        private TaxCalculatorInterface $taxCalculator,
        private DiscountServiceInterface $discountService
    ) {}
    
    public function calculateTotal(array $orderItems): float
    {
        $subtotal = 0;
        
        foreach ($orderItems as $item) {
            $subtotal += $item->getProduct()->getPrice() * $item->getQuantity();
        }
        
        $discount = $this->discountService->calculateDiscount($orderItems);
        $tax = $this->taxCalculator->calculateTax($subtotal - $discount);
        
        return $subtotal - $discount + $tax;
    }
    
    public function calculateItemPrice(Product $product, int $quantity): float
    {
        $basePrice = $product->getPrice() * $quantity;
        
        // 数量割引
        if ($quantity >= 10) {
            $basePrice *= 0.9; // 10%割引
        }
        
        return $basePrice;
    }
}
```

## Hexagonal Architectureの実装

### 1. ポートとアダプターの定義

```php
// 入力ポート（プライマリポート）
interface OrderManagementPortInterface
{
    public function createOrder(CreateOrderCommand $command): OrderId;
    public function getOrder(OrderId $orderId): Order;
    public function updateOrderStatus(OrderId $orderId, string $status): void;
    public function cancelOrder(OrderId $orderId): void;
}

// 出力ポート（セカンダリポート）
interface OrderRepositoryPortInterface
{
    public function save(Order $order): void;
    public function findById(OrderId $orderId): ?Order;
    public function findByUserId(UserId $userId): array;
    public function findByStatus(string $status): array;
}

interface PaymentGatewayPortInterface
{
    public function processPayment(PaymentRequest $request): PaymentResult;
    public function refundPayment(string $transactionId): RefundResult;
    public function getPaymentStatus(string $transactionId): string;
}

interface NotificationPortInterface
{
    public function sendOrderConfirmation(Order $order): void;
    public function sendShippingNotification(Order $order, string $trackingNumber): void;
    public function sendCancellationNotification(Order $order): void;
}

// アプリケーションサービス（ヘキサゴンの中心）
class OrderManagementService implements OrderManagementPortInterface
{
    public function __construct(
        private OrderRepositoryPortInterface $orderRepository,
        private PaymentGatewayPortInterface $paymentGateway,
        private NotificationPortInterface $notificationService,
        private InventoryServiceInterface $inventoryService,
        private LoggerInterface $logger
    ) {}
    
    #[Logged]
    #[Monitored]
    #[Transactional]
    public function createOrder(CreateOrderCommand $command): OrderId
    {
        // ドメインロジック
        $order = new Order($command->getUserId(), $command->getItems());
        
        // 在庫チェック
        foreach ($order->getItems() as $item) {
            if (!$this->inventoryService->isAvailable($item->getProductId(), $item->getQuantity())) {
                throw new InsufficientInventoryException();
            }
        }
        
        // 注文保存
        $this->orderRepository->save($order);
        
        // 在庫確保
        foreach ($order->getItems() as $item) {
            $this->inventoryService->reserve($item->getProductId(), $item->getQuantity());
        }
        
        // 通知送信
        $this->notificationService->sendOrderConfirmation($order);
        
        $this->logger->info('Order created', ['order_id' => $order->getId()]);
        
        return $order->getId();
    }
    
    public function getOrder(OrderId $orderId): Order
    {
        $order = $this->orderRepository->findById($orderId);
        
        if (!$order) {
            throw new OrderNotFoundException("Order not found: {$orderId}");
        }
        
        return $order;
    }
    
    public function updateOrderStatus(OrderId $orderId, string $status): void
    {
        $order = $this->getOrder($orderId);
        $order->updateStatus($status);
        $this->orderRepository->save($order);
    }
    
    public function cancelOrder(OrderId $orderId): void
    {
        $order = $this->getOrder($orderId);
        $order->cancel();
        
        // 在庫を戻す
        foreach ($order->getItems() as $item) {
            $this->inventoryService->release($item->getProductId(), $item->getQuantity());
        }
        
        $this->orderRepository->save($order);
        $this->notificationService->sendCancellationNotification($order);
    }
}
```

### 2. アダプターの実装

```php
// プライマリアダプター（入力）
class OrderRestController
{
    public function __construct(
        private OrderManagementPortInterface $orderManagement,
        private ResponseFactoryInterface $responseFactory
    ) {}
    
    #[Route('POST', '/orders')]
    public function createOrder(ServerRequestInterface $request): ResponseInterface
    {
        $data = json_decode($request->getBody()->getContents(), true);
        
        $command = new CreateOrderCommand(
            $data['user_id'],
            $data['items']
        );
        
        $orderId = $this->orderManagement->createOrder($command);
        
        return $this->responseFactory->createResponse(201)
            ->withBody($this->createStream(json_encode([
                'order_id' => $orderId->toString(),
                'status' => 'created'
            ])));
    }
    
    #[Route('GET', '/orders/{id}')]
    public function getOrder(ServerRequestInterface $request, array $args): ResponseInterface
    {
        $orderId = new OrderId($args['id']);
        $order = $this->orderManagement->getOrder($orderId);
        
        return $this->responseFactory->createResponse(200)
            ->withBody($this->createStream(json_encode($order->toArray())));
    }
}

// セカンダリアダプター（出力）
class MySQLOrderRepository implements OrderRepositoryPortInterface
{
    public function __construct(
        private PDO $pdo,
        private OrderMapperInterface $mapper
    ) {}
    
    public function save(Order $order): void
    {
        $data = $this->mapper->toArray($order);
        
        if ($order->getId()) {
            $this->update($data);
        } else {
            $this->insert($data);
        }
    }
    
    public function findById(OrderId $orderId): ?Order
    {
        $stmt = $this->pdo->prepare('SELECT * FROM orders WHERE id = ?');
        $stmt->execute([$orderId->toString()]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $data ? $this->mapper->fromArray($data) : null;
    }
    
    public function findByUserId(UserId $userId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC');
        $stmt->execute([$userId->toString()]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        return array_map([$this->mapper, 'fromArray'], $results);
    }
    
    public function findByStatus(string $status): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM orders WHERE status = ?');
        $stmt->execute([$status]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        return array_map([$this->mapper, 'fromArray'], $results);
    }
    
    private function insert(array $data): void
    {
        $sql = 'INSERT INTO orders (id, user_id, status, total_amount, created_at) VALUES (?, ?, ?, ?, ?)';
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([
            $data['id'],
            $data['user_id'],
            $data['status'],
            $data['total_amount'],
            $data['created_at']
        ]);
    }
    
    private function update(array $data): void
    {
        $sql = 'UPDATE orders SET status = ?, total_amount = ?, updated_at = ? WHERE id = ?';
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([
            $data['status'],
            $data['total_amount'],
            $data['updated_at'],
            $data['id']
        ]);
    }
}

class StripePaymentGatewayAdapter implements PaymentGatewayPortInterface
{
    public function __construct(
        private StripeClient $stripe,
        private LoggerInterface $logger
    ) {}
    
    public function processPayment(PaymentRequest $request): PaymentResult
    {
        try {
            $charge = $this->stripe->charges->create([
                'amount' => $request->getAmount() * 100, // cents
                'currency' => $request->getCurrency(),
                'source' => $request->getToken(),
                'description' => $request->getDescription()
            ]);
            
            $this->logger->info('Payment processed successfully', [
                'charge_id' => $charge->id,
                'amount' => $request->getAmount()
            ]);
            
            return new PaymentResult(true, $charge->id);
            
        } catch (StripeException $e) {
            $this->logger->error('Payment processing failed', [
                'error' => $e->getMessage(),
                'amount' => $request->getAmount()
            ]);
            
            return new PaymentResult(false, null, $e->getMessage());
        }
    }
    
    public function refundPayment(string $transactionId): RefundResult
    {
        try {
            $refund = $this->stripe->refunds->create([
                'charge' => $transactionId
            ]);
            
            return new RefundResult(true, $refund->id);
            
        } catch (StripeException $e) {
            return new RefundResult(false, null, $e->getMessage());
        }
    }
    
    public function getPaymentStatus(string $transactionId): string
    {
        try {
            $charge = $this->stripe->charges->retrieve($transactionId);
            return $charge->status;
            
        } catch (StripeException $e) {
            return 'unknown';
        }
    }
}
```

## アプリケーション構成

### 1. 統合DIモジュール

```php
class WebApplicationModule extends AbstractModule
{
    protected function configure(): void
    {
        // 基盤モジュールのインストール
        $this->installInfrastructureModules();
        
        // ドメインモジュールのインストール
        $this->installDomainModules();
        
        // アプリケーションモジュールのインストール
        $this->installApplicationModules();
        
        // プレゼンテーションモジュールのインストール
        $this->installPresentationModules();
        
        // AOPモジュールのインストール
        $this->installAopModules();
    }
    
    private function installInfrastructureModules(): void
    {
        $this->install(new DatabaseModule());
        $this->install(new CacheModule());
        $this->install(new LoggingModule());
        $this->install(new EventModule());
    }
    
    private function installDomainModules(): void
    {
        // ドメインサービス
        $this->bind(PricingServiceInterface::class)
            ->to(PricingService::class);
        
        $this->bind(InventoryServiceInterface::class)
            ->to(InventoryService::class);
        
        // リポジトリ（ポート）
        $this->bind(OrderRepositoryPortInterface::class)
            ->to(MySQLOrderRepository::class);
        
        $this->bind(ProductRepositoryInterface::class)
            ->to(MySQLProductRepository::class);
        
        $this->bind(UserRepositoryInterface::class)
            ->to(MySQLUserRepository::class);
    }
    
    private function installApplicationModules(): void
    {
        // ユースケース
        $this->bind(CreateOrderUseCaseInterface::class)
            ->to(CreateOrderUseCase::class);
        
        $this->bind(UpdateProductUseCaseInterface::class)
            ->to(UpdateProductUseCase::class);
        
        // アプリケーションサービス
        $this->bind(OrderManagementPortInterface::class)
            ->to(OrderManagementService::class);
        
        $this->bind(ProductManagementPortInterface::class)
            ->to(ProductManagementService::class);
        
        // 外部サービス（アダプター）
        $this->bind(PaymentGatewayPortInterface::class)
            ->to(StripePaymentGatewayAdapter::class);
        
        $this->bind(NotificationPortInterface::class)
            ->to(EmailNotificationAdapter::class);
    }
    
    private function installPresentationModules(): void
    {
        // コントローラー
        $this->bind(ProductController::class);
        $this->bind(OrderController::class);
        $this->bind(UserController::class);
        
        // ミドルウェア
        $this->bind(AuthenticationMiddleware::class);
        $this->bind(AuthorizationMiddleware::class);
        $this->bind(LoggingMiddleware::class);
        $this->bind(ValidationMiddleware::class);
        
        // レスポンス
        $this->bind(ResponseFactoryInterface::class)
            ->to(ResponseFactory::class)
            ->in(Singleton::class);
    }
    
    private function installAopModules(): void
    {
        $this->install(new LoggingAopModule());
        $this->install(new SecurityAopModule());
        $this->install(new CacheAopModule());
        $this->install(new TransactionAopModule());
        $this->install(new MonitoringAopModule());
    }
}
```

### 2. アプリケーションブートストラップ

```php
class Application
{
    private Injector $injector;
    private RouterInterface $router;
    private MiddlewareStackInterface $middlewareStack;
    
    public function __construct()
    {
        $this->injector = new Injector(new WebApplicationModule());
        $this->router = $this->injector->getInstance(RouterInterface::class);
        $this->middlewareStack = $this->injector->getInstance(MiddlewareStackInterface::class);
        
        $this->configureRoutes();
        $this->configureMiddleware();
    }
    
    public function run(): void
    {
        $request = $this->createServerRequest();
        $response = $this->processRequest($request);
        $this->sendResponse($response);
    }
    
    private function configureRoutes(): void
    {
        $productController = $this->injector->getInstance(ProductController::class);
        $orderController = $this->injector->getInstance(OrderController::class);
        $userController = $this->injector->getInstance(UserController::class);
        
        // 商品関連ルート
        $this->router->get('/products', [$productController, 'index']);
        $this->router->post('/products', [$productController, 'create']);
        $this->router->get('/products/{id}', [$productController, 'show']);
        $this->router->put('/products/{id}', [$productController, 'update']);
        $this->router->delete('/products/{id}', [$productController, 'delete']);
        
        // 注文関連ルート
        $this->router->get('/orders', [$orderController, 'index']);
        $this->router->post('/orders', [$orderController, 'create']);
        $this->router->get('/orders/{id}', [$orderController, 'show']);
        $this->router->put('/orders/{id}', [$orderController, 'update']);
        
        // ユーザー関連ルート
        $this->router->post('/users/register', [$userController, 'register']);
        $this->router->post('/users/login', [$userController, 'login']);
        $this->router->get('/users/profile', [$userController, 'profile']);
    }
    
    private function configureMiddleware(): void
    {
        $this->middlewareStack->push($this->injector->getInstance(LoggingMiddleware::class));
        $this->middlewareStack->push($this->injector->getInstance(AuthenticationMiddleware::class));
        $this->middlewareStack->push($this->injector->getInstance(AuthorizationMiddleware::class));
        $this->middlewareStack->push($this->injector->getInstance(ValidationMiddleware::class));
    }
    
    private function processRequest(ServerRequestInterface $request): ResponseInterface
    {
        try {
            return $this->middlewareStack->process($request, new RequestHandler($this->router));
            
        } catch (Exception $e) {
            $logger = $this->injector->getInstance(LoggerInterface::class);
            $logger->error('Request processing failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            
            return $this->createErrorResponse($e);
        }
    }
    
    private function createServerRequest(): ServerRequestInterface
    {
        return ServerRequestFactory::fromGlobals();
    }
    
    private function sendResponse(ResponseInterface $response): void
    {
        http_response_code($response->getStatusCode());
        
        foreach ($response->getHeaders() as $name => $values) {
            foreach ($values as $value) {
                header("{$name}: {$value}", false);
            }
        }
        
        echo $response->getBody()->getContents();
    }
    
    private function createErrorResponse(Exception $e): ResponseInterface
    {
        $statusCode = $e instanceof HttpException ? $e->getStatusCode() : 500;
        
        return new Response($statusCode, ['Content-Type' => 'application/json'], json_encode([
            'error' => 'Internal Server Error',
            'message' => $e->getMessage(),
            'status' => $statusCode
        ]));
    }
}

// アプリケーションエントリーポイント
try {
    $app = new Application();
    $app->run();
} catch (Exception $e) {
    error_log("Application startup failed: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Application startup failed']);
}
```

## パフォーマンスとスケーラビリティ

### 1. キャッシュ戦略

```php
class CacheStrategyModule extends AbstractModule
{
    protected function configure(): void
    {
        // 階層キャッシュ
        $this->bind(CacheInterface::class)
            ->annotatedWith('L1')
            ->to(APCuCache::class)
            ->in(Singleton::class);
        
        $this->bind(CacheInterface::class)
            ->annotatedWith('L2')
            ->to(RedisCache::class)
            ->in(Singleton::class);
        
        $this->bind(CacheInterface::class)
            ->to(HierarchicalCache::class)
            ->in(Singleton::class);
        
        // 読み取り専用レプリカ
        $this->bind(ProductRepositoryInterface::class)
            ->annotatedWith('read')
            ->to(ReadOnlyProductRepository::class);
        
        // CDNキャッシュ
        $this->bind(AssetCacheInterface::class)
            ->to(CloudFrontCache::class)
            ->in(Singleton::class);
    }
}
```

### 2. 非同期処理

```php
class AsyncProcessingModule extends AbstractModule
{
    protected function configure(): void
    {
        // メッセージキュー
        $this->bind(MessageQueueInterface::class)
            ->to(RedisMessageQueue::class)
            ->in(Singleton::class);
        
        // 非同期ジョブ
        $this->bind(JobProcessorInterface::class)
            ->to(AsyncJobProcessor::class);
        
        // イベントハンドラー
        $this->bind(EventHandlerInterface::class)
            ->to(AsyncEventHandler::class);
    }
}
```

## 次のステップ

Webアプリケーションアーキテクチャの実装を理解したので、次に進む準備が整いました。

1. **データアクセス層の学習**: 効率的なデータ処理の実装
2. **認証・認可の実装**: セキュリティ機能の詳細
3. **ログ・監査システム**: 運用監視の実装

**続きは:** [データアクセス層](data-access-layer.html)

## 重要なポイント

- **階層化アーキテクチャ**で関心事を分離
- **Clean Architecture**でビジネスロジックを保護
- **Hexagonal Architecture**で外部依存を抽象化
- **DIコンテナ**でアーキテクチャを強制
- **AOP**で横断的関心事を管理
- **パフォーマンス**とスケーラビリティを考慮した設計

---

適切なアーキテクチャにより、保守性、テスト可能性、拡張性を兼ね備えたWebアプリケーションを構築できます。Ray.Diはこれらのアーキテクチャパターンを効果的に実装するための強力なツールです。