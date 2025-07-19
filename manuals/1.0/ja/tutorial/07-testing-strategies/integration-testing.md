---
layout: docs-ja
title: 統合テスト
category: Manual
permalink: /manuals/1.0/ja/tutorial/07-testing-strategies/integration-testing.html
---

# 統合テスト

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diを使った包括的な統合テストの実装
- データベースとの統合テスト手法
- 外部サービスとの統合テスト戦略
- エンドツーエンドテストの設計
- テスト環境の構築とデータ管理

## 統合テストの基本概念

### 1. 統合テストの種類

```php
// コンポーネント統合テスト
class UserServiceIntegrationTest extends TestCase
{
    private Injector $injector;
    private UserService $userService;
    private DatabaseInterface $database;

    protected function setUp(): void
    {
        // 統合テスト用のモジュール
        $this->injector = new Injector(new IntegrationTestModule());
        $this->userService = $this->injector->getInstance(UserService::class);
        $this->database = $this->injector->getInstance(DatabaseInterface::class);
        
        // データベースの初期化
        $this->database->beginTransaction();
    }

    protected function tearDown(): void
    {
        // データベースのロールバック
        $this->database->rollback();
    }

    public function testUserCreationWithDatabase(): void
    {
        // Given
        $userData = [
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => 'password123'
        ];

        // When
        $user = $this->userService->createUser($userData);

        // Then
        $this->assertInstanceOf(User::class, $user);
        $this->assertNotNull($user->getId());
        
        // データベースに実際に保存されたかを確認
        $this->assertDatabaseHas('users', [
            'id' => $user->getId(),
            'name' => 'John Doe',
            'email' => 'john@example.com'
        ]);
    }

    public function testUserCreationWithEmailNotification(): void
    {
        // Given
        $userData = [
            'name' => 'Jane Doe',
            'email' => 'jane@example.com',
            'password' => 'password123'
        ];

        // When
        $user = $this->userService->createUser($userData);

        // Then - メールが送信されたかを確認
        $emailService = $this->injector->getInstance(EmailServiceInterface::class);
        $sentEmails = $emailService->getSentEmails();
        
        $this->assertCount(1, $sentEmails);
        $this->assertEquals('jane@example.com', $sentEmails[0]['to']);
        $this->assertEquals('Welcome to our service', $sentEmails[0]['subject']);
    }

    private function assertDatabaseHas(string $table, array $data): void
    {
        $conditions = [];
        $params = [];
        
        foreach ($data as $column => $value) {
            $conditions[] = "{$column} = ?";
            $params[] = $value;
        }
        
        $sql = "SELECT COUNT(*) as count FROM {$table} WHERE " . implode(' AND ', $conditions);
        $result = $this->database->query($sql, $params);
        
        $this->assertGreaterThan(0, $result[0]['count']);
    }
}
```

### 2. 統合テスト用モジュール

```php
class IntegrationTestModule extends AbstractModule
{
    protected function configure(): void
    {
        // 実際のサービス実装を使用
        $this->bind(UserService::class)->to(UserService::class);
        $this->bind(ProductService::class)->to(ProductService::class);
        $this->bind(OrderService::class)->to(OrderService::class);

        // テスト用データベース
        $this->bind(DatabaseInterface::class)
            ->to(TestDatabase::class)
            ->in(Singleton::class);

        // テスト用リポジトリ（実際のデータベースを使用）
        $this->bind(UserRepositoryInterface::class)
            ->to(MySQLUserRepository::class);
        
        $this->bind(ProductRepositoryInterface::class)
            ->to(MySQLProductRepository::class);
        
        $this->bind(OrderRepositoryInterface::class)
            ->to(MySQLOrderRepository::class);

        // テスト用外部サービス
        $this->bind(EmailServiceInterface::class)
            ->to(TestEmailService::class)
            ->in(Singleton::class);

        $this->bind(PaymentGatewayInterface::class)
            ->to(TestPaymentGateway::class)
            ->in(Singleton::class);

        // テスト用設定
        $this->bind('database.host')->toInstance('localhost');
        $this->bind('database.port')->toInstance(3306);
        $this->bind('database.name')->toInstance('test_shopsmart');
        $this->bind('database.username')->toInstance('test_user');
        $this->bind('database.password')->toInstance('test_password');
    }
}
```

### 3. テスト用データベース実装

```php
class TestDatabase implements DatabaseInterface
{
    private PDO $pdo;
    private bool $inTransaction = false;

    public function __construct(
        string $host,
        int $port,
        string $database,
        string $username,
        string $password
    ) {
        $dsn = "mysql:host={$host};port={$port};dbname={$database};charset=utf8mb4";
        $this->pdo = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false
        ]);
    }

    public function query(string $sql, array $params = []): array
    {
        $statement = $this->pdo->prepare($sql);
        $statement->execute($params);
        return $statement->fetchAll();
    }

    public function execute(string $sql, array $params = []): int
    {
        $statement = $this->pdo->prepare($sql);
        $statement->execute($params);
        return $statement->rowCount();
    }

    public function beginTransaction(): void
    {
        if (!$this->inTransaction) {
            $this->pdo->beginTransaction();
            $this->inTransaction = true;
        }
    }

    public function commit(): void
    {
        if ($this->inTransaction) {
            $this->pdo->commit();
            $this->inTransaction = false;
        }
    }

    public function rollback(): void
    {
        if ($this->inTransaction) {
            $this->pdo->rollback();
            $this->inTransaction = false;
        }
    }

    public function lastInsertId(): int
    {
        return (int) $this->pdo->lastInsertId();
    }
}
```

## データベース統合テスト

### 1. データベーステストベース

```php
abstract class DatabaseTestCase extends TestCase
{
    protected Injector $injector;
    protected DatabaseInterface $database;

    protected function setUp(): void
    {
        $this->injector = new Injector(new DatabaseTestModule());
        $this->database = $this->injector->getInstance(DatabaseInterface::class);
        
        $this->setupDatabase();
    }

    protected function tearDown(): void
    {
        $this->cleanupDatabase();
    }

    protected function setupDatabase(): void
    {
        // トランザクション開始
        $this->database->beginTransaction();
        
        // テストデータの投入
        $this->seedTestData();
    }

    protected function cleanupDatabase(): void
    {
        // トランザクションのロールバック
        $this->database->rollback();
    }

    protected function seedTestData(): void
    {
        // 基本的なテストデータを投入
        $this->database->execute("
            INSERT INTO users (id, name, email, password, created_at, updated_at) VALUES
            (1, 'Test User 1', 'test1@example.com', 'hashed_password_1', NOW(), NOW()),
            (2, 'Test User 2', 'test2@example.com', 'hashed_password_2', NOW(), NOW()),
            (3, 'Test User 3', 'test3@example.com', 'hashed_password_3', NOW(), NOW())
        ");

        $this->database->execute("
            INSERT INTO categories (id, name, slug, created_at, updated_at) VALUES
            (1, 'Electronics', 'electronics', NOW(), NOW()),
            (2, 'Books', 'books', NOW(), NOW()),
            (3, 'Clothing', 'clothing', NOW(), NOW())
        ");

        $this->database->execute("
            INSERT INTO products (id, name, description, price, category_id, stock_quantity, created_at, updated_at) VALUES
            (1, 'Laptop', 'High-performance laptop', 999.99, 1, 10, NOW(), NOW()),
            (2, 'Programming Book', 'Learn PHP programming', 49.99, 2, 50, NOW(), NOW()),
            (3, 'T-Shirt', 'Comfortable cotton t-shirt', 19.99, 3, 100, NOW(), NOW())
        ");
    }

    protected function getUser(int $id): ?User
    {
        $userRepository = $this->injector->getInstance(UserRepositoryInterface::class);
        return $userRepository->findById($id);
    }

    protected function getProduct(int $id): ?Product
    {
        $productRepository = $this->injector->getInstance(ProductRepositoryInterface::class);
        return $productRepository->findById($id);
    }

    protected function assertDatabaseHas(string $table, array $data): void
    {
        $conditions = [];
        $params = [];
        
        foreach ($data as $column => $value) {
            $conditions[] = "{$column} = ?";
            $params[] = $value;
        }
        
        $sql = "SELECT COUNT(*) as count FROM {$table} WHERE " . implode(' AND ', $conditions);
        $result = $this->database->query($sql, $params);
        
        $this->assertGreaterThan(0, $result[0]['count'], "Database does not contain expected data");
    }

    protected function assertDatabaseMissing(string $table, array $data): void
    {
        $conditions = [];
        $params = [];
        
        foreach ($data as $column => $value) {
            $conditions[] = "{$column} = ?";
            $params[] = $value;
        }
        
        $sql = "SELECT COUNT(*) as count FROM {$table} WHERE " . implode(' AND ', $conditions);
        $result = $this->database->query($sql, $params);
        
        $this->assertEquals(0, $result[0]['count'], "Database contains unexpected data");
    }
}
```

### 2. 実際のデータベース統合テスト

```php
class OrderIntegrationTest extends DatabaseTestCase
{
    private OrderService $orderService;

    protected function setUp(): void
    {
        parent::setUp();
        $this->orderService = $this->injector->getInstance(OrderService::class);
    }

    public function testCreateOrderWithDatabasePersistence(): void
    {
        // Given
        $orderData = [
            'user_id' => 1,
            'items' => [
                ['product_id' => 1, 'quantity' => 2],
                ['product_id' => 2, 'quantity' => 1]
            ],
            'payment_method' => 'credit_card',
            'payment_data' => [
                'card_number' => '4111111111111111',
                'exp_month' => '12',
                'exp_year' => '2025',
                'cvv' => '123'
            ]
        ];

        // When
        $order = $this->orderService->createOrder($orderData);

        // Then
        $this->assertInstanceOf(Order::class, $order);
        $this->assertNotNull($order->getId());
        
        // データベースに正しく保存されたかを確認
        $this->assertDatabaseHas('orders', [
            'id' => $order->getId(),
            'user_id' => 1,
            'status' => 'pending',
            'total' => 2049.97 // (999.99 * 2) + 49.99
        ]);

        // 注文アイテムも正しく保存されたかを確認
        $this->assertDatabaseHas('order_items', [
            'order_id' => $order->getId(),
            'product_id' => 1,
            'quantity' => 2,
            'price' => 999.99
        ]);

        $this->assertDatabaseHas('order_items', [
            'order_id' => $order->getId(),
            'product_id' => 2,
            'quantity' => 1,
            'price' => 49.99
        ]);
    }

    public function testCreateOrderUpdatesProductStock(): void
    {
        // Given
        $orderData = [
            'user_id' => 1,
            'items' => [
                ['product_id' => 1, 'quantity' => 3] // 在庫は10個
            ]
        ];

        // When
        $order = $this->orderService->createOrder($orderData);

        // Then
        $this->assertInstanceOf(Order::class, $order);
        
        // 在庫が正しく更新されたかを確認
        $this->assertDatabaseHas('products', [
            'id' => 1,
            'stock_quantity' => 7 // 10 - 3 = 7
        ]);
    }

    public function testCreateOrderInsufficientStock(): void
    {
        // Given
        $orderData = [
            'user_id' => 1,
            'items' => [
                ['product_id' => 1, 'quantity' => 15] // 在庫は10個しかない
            ]
        ];

        // Then
        $this->expectException(InsufficientStockException::class);

        // When
        $this->orderService->createOrder($orderData);

        // データベースに注文が保存されていないことを確認
        $this->assertDatabaseMissing('orders', [
            'user_id' => 1,
            'status' => 'pending'
        ]);
    }

    public function testCancelOrderRestoresStock(): void
    {
        // Given - 注文を作成
        $orderData = [
            'user_id' => 1,
            'items' => [
                ['product_id' => 1, 'quantity' => 3]
            ]
        ];
        
        $order = $this->orderService->createOrder($orderData);

        // When - 注文をキャンセル
        $this->orderService->cancelOrder($order->getId());

        // Then
        $this->assertDatabaseHas('orders', [
            'id' => $order->getId(),
            'status' => 'cancelled'
        ]);

        // 在庫が復元されたかを確認
        $this->assertDatabaseHas('products', [
            'id' => 1,
            'stock_quantity' => 10 // 元の在庫に戻る
        ]);
    }
}
```

## 外部サービス統合テスト

### 1. 外部APIとの統合テスト

```php
class PaymentGatewayIntegrationTest extends TestCase
{
    private PaymentGatewayService $paymentService;
    private HttpClientInterface $httpClient;

    protected function setUp(): void
    {
        // 実際のHTTPクライアントを使用
        $this->httpClient = new GuzzleHttpClient();
        
        // テスト用のAPIキー（サンドボックス環境）
        $this->paymentService = new PaymentGatewayService(
            $this->httpClient,
            'sk_test_123456789'
        );
    }

    public function testChargeWithRealAPI(): void
    {
        // Given
        $amount = 10.00; // 小額でテスト
        $cardData = [
            'number' => '4242424242424242', // Stripeテスト用カード
            'exp_month' => '12',
            'exp_year' => '2025',
            'cvv' => '123'
        ];

        // When
        $result = $this->paymentService->charge($amount, $cardData);

        // Then
        $this->assertTrue($result->isSuccess());
        $this->assertNotNull($result->getTransactionId());
        $this->assertEquals($amount, $result->getAmount());
        $this->assertNull($result->getErrorMessage());
    }

    public function testChargeWithDeclinedCard(): void
    {
        // Given
        $amount = 10.00;
        $cardData = [
            'number' => '4000000000000002', // Stripe declined test card
            'exp_month' => '12',
            'exp_year' => '2025',
            'cvv' => '123'
        ];

        // When
        $result = $this->paymentService->charge($amount, $cardData);

        // Then
        $this->assertFalse($result->isSuccess());
        $this->assertNull($result->getTransactionId());
        $this->assertNotNull($result->getErrorMessage());
        $this->assertEquals('card_declined', $result->getErrorCode());
    }

    public function testRefundTransaction(): void
    {
        // Given - 成功した取引を作成
        $chargeResult = $this->paymentService->charge(10.00, [
            'number' => '4242424242424242',
            'exp_month' => '12',
            'exp_year' => '2025',
            'cvv' => '123'
        ]);
        
        $this->assertTrue($chargeResult->isSuccess());

        // When - 返金を実行
        $refundResult = $this->paymentService->refund(
            $chargeResult->getTransactionId(),
            5.00 // 部分返金
        );

        // Then
        $this->assertTrue($refundResult->isSuccess());
        $this->assertNotNull($refundResult->getRefundId());
        $this->assertEquals(5.00, $refundResult->getAmount());
    }
}
```

### 2. メール統合テスト

```php
class EmailIntegrationTest extends TestCase
{
    private EmailService $emailService;

    protected function setUp(): void
    {
        // テスト用のメール設定
        $this->emailService = new EmailService(
            new SmtpTransport(
                'smtp.mailtrap.io',
                587,
                'username',
                'password'
            )
        );
    }

    public function testSendWelcomeEmail(): void
    {
        // Given
        $user = new User(1, 'John Doe', 'john@example.com');
        $template = 'welcome';
        $data = [
            'name' => $user->getName(),
            'activation_link' => 'https://example.com/activate/123'
        ];

        // When
        $result = $this->emailService->sendTemplate(
            $user->getEmail(),
            $template,
            $data
        );

        // Then
        $this->assertTrue($result->isSuccess());
        $this->assertNotNull($result->getMessageId());
        
        // メールが実際に送信されたかを確認
        // （テスト環境では実際のメール送信はしない）
    }

    public function testSendOrderConfirmationEmail(): void
    {
        // Given
        $order = new Order(1, 1, 'John Doe', 'john@example.com', 99.99, OrderStatus::COMPLETED);
        $template = 'order_confirmation';
        $data = [
            'order_number' => $order->getId(),
            'total' => $order->getTotal(),
            'items' => $order->getItems()
        ];

        // When
        $result = $this->emailService->sendTemplate(
            $order->getCustomerEmail(),
            $template,
            $data
        );

        // Then
        $this->assertTrue($result->isSuccess());
        $this->assertNotNull($result->getMessageId());
    }

    public function testSendEmailWithInvalidTemplate(): void
    {
        // Given
        $user = new User(1, 'John Doe', 'john@example.com');
        $template = 'nonexistent_template';
        $data = [];

        // Then
        $this->expectException(TemplateNotFoundException::class);

        // When
        $this->emailService->sendTemplate(
            $user->getEmail(),
            $template,
            $data
        );
    }
}
```

## エンドツーエンドテスト

### 1. 完全なビジネスフロー

```php
class E2EOrderFlowTest extends DatabaseTestCase
{
    private UserService $userService;
    private ProductService $productService;
    private OrderService $orderService;
    private PaymentService $paymentService;
    private EmailService $emailService;

    protected function setUp(): void
    {
        parent::setUp();
        
        // 全てのサービスを実際の実装で取得
        $this->userService = $this->injector->getInstance(UserService::class);
        $this->productService = $this->injector->getInstance(ProductService::class);
        $this->orderService = $this->injector->getInstance(OrderService::class);
        $this->paymentService = $this->injector->getInstance(PaymentService::class);
        $this->emailService = $this->injector->getInstance(EmailService::class);
    }

    public function testCompleteOrderFlow(): void
    {
        // Step 1: ユーザー登録
        $userData = [
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => 'password123'
        ];
        
        $user = $this->userService->createUser($userData);
        $this->assertInstanceOf(User::class, $user);
        $this->assertDatabaseHas('users', ['email' => 'john@example.com']);

        // Step 2: 商品検索
        $products = $this->productService->search('laptop');
        $this->assertNotEmpty($products);
        $laptop = $products[0];

        // Step 3: 注文作成
        $orderData = [
            'user_id' => $user->getId(),
            'items' => [
                ['product_id' => $laptop->getId(), 'quantity' => 1]
            ]
        ];
        
        $order = $this->orderService->createOrder($orderData);
        $this->assertInstanceOf(Order::class, $order);
        $this->assertEquals('pending', $order->getStatus());

        // Step 4: 支払い処理
        $paymentData = [
            'card_number' => '4242424242424242',
            'exp_month' => '12',
            'exp_year' => '2025',
            'cvv' => '123'
        ];
        
        $paymentResult = $this->paymentService->processPayment(
            $order->getId(),
            $paymentData
        );
        
        $this->assertTrue($paymentResult->isSuccess());
        $this->assertNotNull($paymentResult->getTransactionId());

        // Step 5: 注文ステータスの確認
        $updatedOrder = $this->orderService->getOrder($order->getId());
        $this->assertEquals('paid', $updatedOrder->getStatus());
        $this->assertNotNull($updatedOrder->getPaymentTransactionId());

        // Step 6: 確認メール送信の確認
        $emailService = $this->injector->getInstance(EmailServiceInterface::class);
        $sentEmails = $emailService->getSentEmails();
        
        $this->assertGreaterThan(0, count($sentEmails));
        $confirmationEmail = array_filter($sentEmails, function($email) {
            return str_contains($email['subject'], 'Order Confirmation');
        });
        
        $this->assertNotEmpty($confirmationEmail);

        // Step 7: 在庫の確認
        $updatedProduct = $this->productService->getProduct($laptop->getId());
        $this->assertEquals(
            $laptop->getStockQuantity() - 1,
            $updatedProduct->getStockQuantity()
        );

        // Step 8: データベースの整合性確認
        $this->assertDatabaseHas('orders', [
            'id' => $order->getId(),
            'user_id' => $user->getId(),
            'status' => 'paid',
            'total' => $laptop->getPrice()
        ]);

        $this->assertDatabaseHas('order_items', [
            'order_id' => $order->getId(),
            'product_id' => $laptop->getId(),
            'quantity' => 1,
            'price' => $laptop->getPrice()
        ]);
    }

    public function testOrderCancellationFlow(): void
    {
        // Step 1: 注文作成
        $user = $this->getUser(1);
        $product = $this->getProduct(1);
        
        $orderData = [
            'user_id' => $user->getId(),
            'items' => [
                ['product_id' => $product->getId(), 'quantity' => 2]
            ]
        ];
        
        $order = $this->orderService->createOrder($orderData);
        $originalStock = $product->getStockQuantity();

        // Step 2: 支払い処理
        $paymentData = [
            'card_number' => '4242424242424242',
            'exp_month' => '12',
            'exp_year' => '2025',
            'cvv' => '123'
        ];
        
        $paymentResult = $this->paymentService->processPayment(
            $order->getId(),
            $paymentData
        );
        
        $this->assertTrue($paymentResult->isSuccess());

        // Step 3: 注文キャンセル
        $cancelResult = $this->orderService->cancelOrder($order->getId());
        $this->assertTrue($cancelResult->isSuccess());

        // Step 4: 返金処理の確認
        $refundResult = $this->paymentService->getRefundStatus(
            $paymentResult->getTransactionId()
        );
        $this->assertTrue($refundResult->isRefunded());

        // Step 5: 在庫復元の確認
        $updatedProduct = $this->productService->getProduct($product->getId());
        $this->assertEquals($originalStock, $updatedProduct->getStockQuantity());

        // Step 6: 注文ステータスの確認
        $updatedOrder = $this->orderService->getOrder($order->getId());
        $this->assertEquals('cancelled', $updatedOrder->getStatus());

        // Step 7: キャンセル通知メールの確認
        $emailService = $this->injector->getInstance(EmailServiceInterface::class);
        $sentEmails = $emailService->getSentEmails();
        
        $cancellationEmail = array_filter($sentEmails, function($email) {
            return str_contains($email['subject'], 'Order Cancelled');
        });
        
        $this->assertNotEmpty($cancellationEmail);
    }
}
```

### 2. API統合テスト

```php
class APIIntegrationTest extends TestCase
{
    private Application $app;
    private TestClient $client;

    protected function setUp(): void
    {
        // テスト用のアプリケーションインスタンス
        $this->app = new Application(new IntegrationTestModule());
        $this->client = new TestClient($this->app);
    }

    public function testCreateUserAPI(): void
    {
        // Given
        $userData = [
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => 'password123'
        ];

        // When
        $response = $this->client->post('/api/users', $userData);

        // Then
        $this->assertEquals(201, $response->getStatusCode());
        
        $responseData = json_decode($response->getContent(), true);
        $this->assertArrayHasKey('id', $responseData);
        $this->assertEquals('John Doe', $responseData['name']);
        $this->assertEquals('john@example.com', $responseData['email']);
        $this->assertArrayNotHasKey('password', $responseData);
    }

    public function testCreateOrderAPI(): void
    {
        // Given - ユーザーを作成してトークンを取得
        $user = $this->createTestUser();
        $token = $this->authenticateUser($user);

        $orderData = [
            'items' => [
                ['product_id' => 1, 'quantity' => 2]
            ]
        ];

        // When
        $response = $this->client->post('/api/orders', $orderData, [
            'Authorization' => "Bearer {$token}"
        ]);

        // Then
        $this->assertEquals(201, $response->getStatusCode());
        
        $responseData = json_decode($response->getContent(), true);
        $this->assertArrayHasKey('id', $responseData);
        $this->assertEquals('pending', $responseData['status']);
        $this->assertArrayHasKey('total', $responseData);
        $this->assertArrayHasKey('items', $responseData);
    }

    public function testUnauthorizedAccess(): void
    {
        // Given
        $orderData = [
            'items' => [
                ['product_id' => 1, 'quantity' => 1]
            ]
        ];

        // When
        $response = $this->client->post('/api/orders', $orderData);

        // Then
        $this->assertEquals(401, $response->getStatusCode());
        
        $responseData = json_decode($response->getContent(), true);
        $this->assertEquals('Unauthorized', $responseData['error']);
    }

    private function createTestUser(): User
    {
        $userData = [
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => 'password123'
        ];

        $response = $this->client->post('/api/users', $userData);
        $responseData = json_decode($response->getContent(), true);
        
        return new User($responseData['id'], $responseData['name'], $responseData['email']);
    }

    private function authenticateUser(User $user): string
    {
        $credentials = [
            'email' => $user->getEmail(),
            'password' => 'password123'
        ];

        $response = $this->client->post('/api/auth/login', $credentials);
        $responseData = json_decode($response->getContent(), true);
        
        return $responseData['access_token'];
    }
}
```

## テスト環境管理

### 1. テスト設定管理

```php
class TestConfiguration
{
    public static function getDatabaseConfig(): array
    {
        return [
            'host' => $_ENV['TEST_DB_HOST'] ?? 'localhost',
            'port' => $_ENV['TEST_DB_PORT'] ?? 3306,
            'database' => $_ENV['TEST_DB_NAME'] ?? 'test_shopsmart',
            'username' => $_ENV['TEST_DB_USERNAME'] ?? 'test_user',
            'password' => $_ENV['TEST_DB_PASSWORD'] ?? 'test_password'
        ];
    }

    public static function getEmailConfig(): array
    {
        return [
            'host' => $_ENV['TEST_EMAIL_HOST'] ?? 'smtp.mailtrap.io',
            'port' => $_ENV['TEST_EMAIL_PORT'] ?? 587,
            'username' => $_ENV['TEST_EMAIL_USERNAME'] ?? 'test_user',
            'password' => $_ENV['TEST_EMAIL_PASSWORD'] ?? 'test_password'
        ];
    }

    public static function getPaymentConfig(): array
    {
        return [
            'api_key' => $_ENV['TEST_PAYMENT_API_KEY'] ?? 'sk_test_123456789',
            'webhook_secret' => $_ENV['TEST_PAYMENT_WEBHOOK_SECRET'] ?? 'whsec_test_123'
        ];
    }
}
```

### 2. テストデータファクトリー

```php
class TestDataFactory
{
    public static function createUsers(int $count = 5): array
    {
        $users = [];
        for ($i = 1; $i <= $count; $i++) {
            $users[] = [
                'id' => $i,
                'name' => "Test User {$i}",
                'email' => "user{$i}@example.com",
                'password' => password_hash('password123', PASSWORD_DEFAULT),
                'created_at' => date('Y-m-d H:i:s'),
                'updated_at' => date('Y-m-d H:i:s')
            ];
        }
        return $users;
    }

    public static function createProducts(int $count = 10): array
    {
        $products = [];
        for ($i = 1; $i <= $count; $i++) {
            $products[] = [
                'id' => $i,
                'name' => "Product {$i}",
                'description' => "Description for product {$i}",
                'price' => round(random_int(10, 1000) + (random_int(0, 99) / 100), 2),
                'category_id' => random_int(1, 3),
                'stock_quantity' => random_int(0, 100),
                'created_at' => date('Y-m-d H:i:s'),
                'updated_at' => date('Y-m-d H:i:s')
            ];
        }
        return $products;
    }

    public static function createOrders(int $count = 3): array
    {
        $orders = [];
        for ($i = 1; $i <= $count; $i++) {
            $orders[] = [
                'id' => $i,
                'user_id' => random_int(1, 3),
                'total' => round(random_int(10, 500) + (random_int(0, 99) / 100), 2),
                'status' => ['pending', 'paid', 'completed', 'cancelled'][random_int(0, 3)],
                'created_at' => date('Y-m-d H:i:s'),
                'updated_at' => date('Y-m-d H:i:s')
            ];
        }
        return $orders;
    }
}
```

## 次のステップ

統合テストを習得したので、次はベストプラクティスを学ぶ準備が整いました。

1. **DIを使ったデザインパターン**: 効果的な設計手法
2. **トラブルシューティング**: 実際の問題解決
3. **パフォーマンス最適化**: 本番環境での考慮事項

**続きは:** [DIを使ったデザインパターン](../08-best-practices/design-patterns-with-di.html)

## 重要なポイント

- **実際のコンポーネント**を使用して統合をテスト
- **データベーストランザクション**でテストを分離
- **外部サービス**との統合も実際の環境でテスト
- **エンドツーエンドテスト**で完全なビジネスフローを検証
- **テスト環境管理**で一貫性のあるテスト実行
- **テストデータファクトリー**で効率的なデータ準備

---

統合テストにより、システム全体の品質と信頼性を確保できます。Ray.Diの依存性注入により、テストしやすいアーキテクチャを実現し、包括的なテストカバレッジを提供します。