---
layout: docs-ja
title: 依存関係のモッキング
category: Manual
permalink: /manuals/1.0/ja/tutorial/07-testing-strategies/dependency-mocking.html
---

# 依存関係のモッキング

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diでの効果的なモッキング戦略
- PHPUnitとProphecyを使った高度なモック実装
- テストダブルの種類と使い分け
- 外部依存関係の分離とテスト
- モックの検証とアサーション

## モッキングの基本概念

### 1. テストダブルの種類

```php
// スタブ（Stub）- 定義済みの応答を返す
class StubUserRepository implements UserRepositoryInterface
{
    private array $users = [];

    public function setUsers(array $users): void
    {
        $this->users = $users;
    }

    public function findById(int $id): ?User
    {
        return $this->users[$id] ?? null;
    }

    public function findByEmail(string $email): ?User
    {
        foreach ($this->users as $user) {
            if ($user->getEmail() === $email) {
                return $user;
            }
        }
        return null;
    }

    public function save(User $user): void
    {
        // スタブでは何もしない
    }

    public function delete(int $id): void
    {
        // スタブでは何もしない
    }
}

// モック（Mock）- 呼び出しを記録・検証
class MockEmailService implements EmailServiceInterface
{
    private array $sentEmails = [];
    private array $expectedCalls = [];

    public function expectSend(string $to, string $subject, string $body): void
    {
        $this->expectedCalls[] = compact('to', 'subject', 'body');
    }

    public function send(string $to, string $subject, string $body): void
    {
        $this->sentEmails[] = compact('to', 'subject', 'body');
    }

    public function verify(): void
    {
        if (count($this->sentEmails) !== count($this->expectedCalls)) {
            throw new \Exception('Email send count mismatch');
        }

        foreach ($this->expectedCalls as $index => $expected) {
            $actual = $this->sentEmails[$index];
            if ($actual !== $expected) {
                throw new \Exception('Email content mismatch');
            }
        }
    }

    public function getSentEmails(): array
    {
        return $this->sentEmails;
    }
}

// スパイ（Spy）- 呼び出しを記録
class SpyLogger implements LoggerInterface
{
    private array $logEntries = [];

    public function info(string|\Stringable $message, array $context = []): void
    {
        $this->logEntries[] = [
            'level' => 'info',
            'message' => (string) $message,
            'context' => $context,
            'timestamp' => new DateTime()
        ];
    }

    public function error(string|\Stringable $message, array $context = []): void
    {
        $this->logEntries[] = [
            'level' => 'error',
            'message' => (string) $message,
            'context' => $context,
            'timestamp' => new DateTime()
        ];
    }

    public function getLogEntries(): array
    {
        return $this->logEntries;
    }

    public function wasCalledWith(string $level, string $message): bool
    {
        foreach ($this->logEntries as $entry) {
            if ($entry['level'] === $level && $entry['message'] === $message) {
                return true;
            }
        }
        return false;
    }

    // その他のログメソッドは省略
}
```

### 2. PHPUnitモックの活用

```php
class UserServiceTest extends TestCase
{
    private UserService $userService;
    private UserRepositoryInterface $userRepository;
    private EmailServiceInterface $emailService;
    private LoggerInterface $logger;

    protected function setUp(): void
    {
        // モックを作成
        $this->userRepository = $this->createMock(UserRepositoryInterface::class);
        $this->emailService = $this->createMock(EmailServiceInterface::class);
        $this->logger = $this->createMock(LoggerInterface::class);

        // サービスを手動で作成
        $this->userService = new UserService(
            $this->userRepository,
            $this->emailService,
            $this->logger
        );
    }

    public function testCreateUserSuccess(): void
    {
        // Given
        $userData = [
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => 'password123'
        ];

        // モックの設定
        $this->userRepository
            ->expects($this->once())
            ->method('findByEmail')
            ->with('john@example.com')
            ->willReturn(null);

        $this->userRepository
            ->expects($this->once())
            ->method('save')
            ->with($this->callback(function (User $user) {
                return $user->getEmail() === 'john@example.com' &&
                       $user->getName() === 'John Doe';
            }));

        $this->emailService
            ->expects($this->once())
            ->method('send')
            ->with(
                'john@example.com',
                'Welcome to our service',
                $this->stringContains('John Doe')
            );

        $this->logger
            ->expects($this->once())
            ->method('info')
            ->with('User created successfully', $this->arrayHasKey('user_id'));

        // When
        $user = $this->userService->createUser($userData);

        // Then
        $this->assertInstanceOf(User::class, $user);
        $this->assertEquals('John Doe', $user->getName());
        $this->assertEquals('john@example.com', $user->getEmail());
    }

    public function testCreateUserDuplicateEmail(): void
    {
        // Given
        $userData = [
            'name' => 'John Doe',
            'email' => 'existing@example.com',
            'password' => 'password123'
        ];

        $existingUser = new User(1, 'Existing User', 'existing@example.com');

        // モックの設定
        $this->userRepository
            ->expects($this->once())
            ->method('findByEmail')
            ->with('existing@example.com')
            ->willReturn($existingUser);

        $this->userRepository
            ->expects($this->never())
            ->method('save');

        $this->emailService
            ->expects($this->never())
            ->method('send');

        $this->logger
            ->expects($this->once())
            ->method('warning')
            ->with('Attempted to create user with duplicate email', [
                'email' => 'existing@example.com'
            ]);

        // Then
        $this->expectException(DuplicateEmailException::class);

        // When
        $this->userService->createUser($userData);
    }
}
```

### 3. Prophecyを使った高度なモッキング

```php
use Prophecy\Prophet;
use Prophecy\Argument;

class OrderServiceTest extends TestCase
{
    private Prophet $prophet;
    private OrderService $orderService;

    protected function setUp(): void
    {
        $this->prophet = new Prophet();
        
        // Prophecyでモックを作成
        $userRepository = $this->prophet->prophesize(UserRepositoryInterface::class);
        $productRepository = $this->prophet->prophesize(ProductRepositoryInterface::class);
        $paymentGateway = $this->prophet->prophesize(PaymentGatewayInterface::class);
        $emailService = $this->prophet->prophesize(EmailServiceInterface::class);
        $logger = $this->prophet->prophesize(LoggerInterface::class);

        $this->orderService = new OrderService(
            $userRepository->reveal(),
            $productRepository->reveal(),
            $paymentGateway->reveal(),
            $emailService->reveal(),
            $logger->reveal()
        );
    }

    protected function tearDown(): void
    {
        $this->prophet->checkPredictions();
    }

    public function testCreateOrder(): void
    {
        // Given
        $user = new User(1, 'John Doe', 'john@example.com');
        $product = new Product(1, 'Test Product', 'Description', 19.99, 10);
        
        $orderData = [
            'user_id' => 1,
            'items' => [
                ['product_id' => 1, 'quantity' => 2]
            ]
        ];

        // Prophecyでモックの動作を定義
        $userRepository = $this->prophet->prophesize(UserRepositoryInterface::class);
        $userRepository->findById(1)->willReturn($user);

        $productRepository = $this->prophet->prophesize(ProductRepositoryInterface::class);
        $productRepository->findById(1)->willReturn($product);

        $paymentGateway = $this->prophet->prophesize(PaymentGatewayInterface::class);
        $paymentGateway->charge(39.98, Argument::type('array'))
            ->willReturn(new PaymentResult(true, 'txn_123'));

        $emailService = $this->prophet->prophesize(EmailServiceInterface::class);
        $emailService->send(
            'john@example.com',
            'Order Confirmation',
            Argument::containingString('Order #')
        )->shouldBeCalled();

        $logger = $this->prophet->prophesize(LoggerInterface::class);
        $logger->info('Order created successfully', Argument::that(function ($context) {
            return isset($context['order_id']) && isset($context['total']);
        }))->shouldBeCalled();

        // When
        $order = $this->orderService->createOrder($orderData);

        // Then
        $this->assertInstanceOf(Order::class, $order);
        $this->assertEquals(39.98, $order->getTotal());
        $this->assertEquals('completed', $order->getStatus());
    }

    public function testCreateOrderPaymentFailure(): void
    {
        // Given
        $user = new User(1, 'John Doe', 'john@example.com');
        $product = new Product(1, 'Test Product', 'Description', 19.99, 10);
        
        $orderData = [
            'user_id' => 1,
            'items' => [
                ['product_id' => 1, 'quantity' => 2]
            ]
        ];

        // モックの設定
        $userRepository = $this->prophet->prophesize(UserRepositoryInterface::class);
        $userRepository->findById(1)->willReturn($user);

        $productRepository = $this->prophet->prophesize(ProductRepositoryInterface::class);
        $productRepository->findById(1)->willReturn($product);

        $paymentGateway = $this->prophet->prophesize(PaymentGatewayInterface::class);
        $paymentGateway->charge(39.98, Argument::type('array'))
            ->willReturn(new PaymentResult(false, null, 'Card declined'));

        $emailService = $this->prophet->prophesize(EmailServiceInterface::class);
        $emailService->send(Argument::cetera())->shouldNotBeCalled();

        $logger = $this->prophet->prophesize(LoggerInterface::class);
        $logger->error('Payment failed for order', Argument::that(function ($context) {
            return isset($context['user_id']) && isset($context['error']);
        }))->shouldBeCalled();

        // Then
        $this->expectException(PaymentFailedException::class);
        $this->expectExceptionMessage('Card declined');

        // When
        $this->orderService->createOrder($orderData);
    }
}
```

## 外部サービスのモッキング

### 1. HTTP クライアントのモッキング

```php
class PaymentGatewayServiceTest extends TestCase
{
    private PaymentGatewayService $paymentService;
    private HttpClientInterface $httpClient;

    protected function setUp(): void
    {
        $this->httpClient = $this->createMock(HttpClientInterface::class);
        $this->paymentService = new PaymentGatewayService(
            $this->httpClient,
            'test_api_key'
        );
    }

    public function testChargeSuccess(): void
    {
        // Given
        $amount = 100.00;
        $cardData = [
            'number' => '4111111111111111',
            'exp_month' => '12',
            'exp_year' => '2025',
            'cvv' => '123'
        ];

        $mockResponse = new HttpResponse(200, [], json_encode([
            'status' => 'success',
            'transaction_id' => 'txn_123456',
            'amount' => 100.00
        ]));

        // モックの設定
        $this->httpClient
            ->expects($this->once())
            ->method('post')
            ->with(
                'https://api.payment-gateway.com/charges',
                $this->callback(function (array $data) use ($amount) {
                    return $data['amount'] === $amount * 100 && // cents
                           isset($data['card']) &&
                           $data['card']['number'] === '4111111111111111';
                }),
                $this->arrayHasKey('Authorization')
            )
            ->willReturn($mockResponse);

        // When
        $result = $this->paymentService->charge($amount, $cardData);

        // Then
        $this->assertTrue($result->isSuccess());
        $this->assertEquals('txn_123456', $result->getTransactionId());
        $this->assertEquals(100.00, $result->getAmount());
    }

    public function testChargeFailure(): void
    {
        // Given
        $amount = 100.00;
        $cardData = [
            'number' => '4000000000000002', // declined card
            'exp_month' => '12',
            'exp_year' => '2025',
            'cvv' => '123'
        ];

        $mockResponse = new HttpResponse(400, [], json_encode([
            'status' => 'error',
            'error_code' => 'card_declined',
            'message' => 'Your card was declined'
        ]));

        // モックの設定
        $this->httpClient
            ->expects($this->once())
            ->method('post')
            ->willReturn($mockResponse);

        // When
        $result = $this->paymentService->charge($amount, $cardData);

        // Then
        $this->assertFalse($result->isSuccess());
        $this->assertEquals('card_declined', $result->getErrorCode());
        $this->assertEquals('Your card was declined', $result->getErrorMessage());
    }

    public function testChargeHttpException(): void
    {
        // Given
        $amount = 100.00;
        $cardData = ['number' => '4111111111111111'];

        // モックの設定
        $this->httpClient
            ->expects($this->once())
            ->method('post')
            ->willThrowException(new HttpException('Network error'));

        // Then
        $this->expectException(PaymentGatewayException::class);
        $this->expectExceptionMessage('Network error');

        // When
        $this->paymentService->charge($amount, $cardData);
    }
}
```

### 2. データベースのモッキング

```php
class ProductRepositoryTest extends TestCase
{
    private ProductRepository $repository;
    private DatabaseInterface $database;

    protected function setUp(): void
    {
        $this->database = $this->createMock(DatabaseInterface::class);
        $this->repository = new ProductRepository($this->database);
    }

    public function testFindById(): void
    {
        // Given
        $productId = 1;
        $expectedData = [
            'id' => 1,
            'name' => 'Test Product',
            'description' => 'A test product',
            'price' => 19.99,
            'stock_quantity' => 10
        ];

        // モックの設定
        $this->database
            ->expects($this->once())
            ->method('query')
            ->with(
                'SELECT * FROM products WHERE id = ? AND deleted_at IS NULL',
                [$productId]
            )
            ->willReturn([$expectedData]);

        // When
        $product = $this->repository->findById($productId);

        // Then
        $this->assertInstanceOf(Product::class, $product);
        $this->assertEquals(1, $product->getId());
        $this->assertEquals('Test Product', $product->getName());
        $this->assertEquals(19.99, $product->getPrice());
    }

    public function testFindByIdNotFound(): void
    {
        // Given
        $productId = 999;

        // モックの設定
        $this->database
            ->expects($this->once())
            ->method('query')
            ->with(
                'SELECT * FROM products WHERE id = ? AND deleted_at IS NULL',
                [$productId]
            )
            ->willReturn([]);

        // When
        $product = $this->repository->findById($productId);

        // Then
        $this->assertNull($product);
    }

    public function testSaveNew(): void
    {
        // Given
        $product = new Product(null, 'New Product', 'Description', 29.99, 5);

        // モックの設定
        $this->database
            ->expects($this->once())
            ->method('execute')
            ->with(
                $this->stringContains('INSERT INTO products'),
                $this->callback(function (array $params) {
                    return $params[0] === 'New Product' &&
                           $params[1] === 'Description' &&
                           $params[2] === 29.99 &&
                           $params[3] === 5;
                })
            )
            ->willReturn(1);

        $this->database
            ->expects($this->once())
            ->method('lastInsertId')
            ->willReturn(123);

        // When
        $this->repository->save($product);

        // Then
        $this->assertEquals(123, $product->getId());
    }

    public function testSaveExisting(): void
    {
        // Given
        $product = new Product(1, 'Updated Product', 'Updated Description', 39.99, 15);

        // モックの設定
        $this->database
            ->expects($this->once())
            ->method('execute')
            ->with(
                $this->stringContains('UPDATE products SET'),
                $this->callback(function (array $params) {
                    return $params[0] === 'Updated Product' &&
                           $params[1] === 'Updated Description' &&
                           $params[2] === 39.99 &&
                           $params[3] === 15 &&
                           $params[4] === 1;
                })
            )
            ->willReturn(1);

        $this->database
            ->expects($this->never())
            ->method('lastInsertId');

        // When
        $this->repository->save($product);

        // Then
        $this->assertEquals(1, $product->getId());
    }
}
```

### 3. キャッシュのモッキング

```php
class CachedProductServiceTest extends TestCase
{
    private CachedProductService $service;
    private ProductRepositoryInterface $repository;
    private CacheInterface $cache;

    protected function setUp(): void
    {
        $this->repository = $this->createMock(ProductRepositoryInterface::class);
        $this->cache = $this->createMock(CacheInterface::class);
        $this->service = new CachedProductService($this->repository, $this->cache);
    }

    public function testGetProductCacheHit(): void
    {
        // Given
        $productId = 1;
        $cachedProduct = new Product(1, 'Cached Product', 'Description', 19.99, 10);

        // モックの設定
        $this->cache
            ->expects($this->once())
            ->method('get')
            ->with("product:{$productId}")
            ->willReturn($cachedProduct);

        $this->repository
            ->expects($this->never())
            ->method('findById');

        $this->cache
            ->expects($this->never())
            ->method('set');

        // When
        $product = $this->service->getProduct($productId);

        // Then
        $this->assertSame($cachedProduct, $product);
    }

    public function testGetProductCacheMiss(): void
    {
        // Given
        $productId = 1;
        $product = new Product(1, 'Product', 'Description', 19.99, 10);

        // モックの設定
        $this->cache
            ->expects($this->once())
            ->method('get')
            ->with("product:{$productId}")
            ->willReturn(null);

        $this->repository
            ->expects($this->once())
            ->method('findById')
            ->with($productId)
            ->willReturn($product);

        $this->cache
            ->expects($this->once())
            ->method('set')
            ->with("product:{$productId}", $product, 3600);

        // When
        $result = $this->service->getProduct($productId);

        // Then
        $this->assertSame($product, $result);
    }

    public function testUpdateProductInvalidatesCache(): void
    {
        // Given
        $productId = 1;
        $product = new Product(1, 'Updated Product', 'Description', 29.99, 5);

        // モックの設定
        $this->repository
            ->expects($this->once())
            ->method('save')
            ->with($product);

        $this->cache
            ->expects($this->once())
            ->method('delete')
            ->with("product:{$productId}");

        // When
        $this->service->updateProduct($product);
    }
}
```

## 複雑なシナリオのモッキング

### 1. 条件分岐のモッキング

```php
class NotificationServiceTest extends TestCase
{
    private NotificationService $service;
    private EmailServiceInterface $emailService;
    private SmsServiceInterface $smsService;
    private UserRepositoryInterface $userRepository;

    protected function setUp(): void
    {
        $this->emailService = $this->createMock(EmailServiceInterface::class);
        $this->smsService = $this->createMock(SmsServiceInterface::class);
        $this->userRepository = $this->createMock(UserRepositoryInterface::class);
        
        $this->service = new NotificationService(
            $this->emailService,
            $this->smsService,
            $this->userRepository
        );
    }

    public function testSendNotificationEmailPreferred(): void
    {
        // Given
        $userId = 1;
        $message = 'Test notification';
        $user = new User(1, 'John Doe', 'john@example.com');
        $user->setPreferredNotificationMethod('email');

        // モックの設定
        $this->userRepository
            ->expects($this->once())
            ->method('findById')
            ->with($userId)
            ->willReturn($user);

        $this->emailService
            ->expects($this->once())
            ->method('send')
            ->with('john@example.com', 'Notification', $message);

        $this->smsService
            ->expects($this->never())
            ->method('send');

        // When
        $this->service->sendNotification($userId, $message);
    }

    public function testSendNotificationSmsPreferred(): void
    {
        // Given
        $userId = 1;
        $message = 'Test notification';
        $user = new User(1, 'John Doe', 'john@example.com');
        $user->setPreferredNotificationMethod('sms');
        $user->setPhoneNumber('+1234567890');

        // モックの設定
        $this->userRepository
            ->expects($this->once())
            ->method('findById')
            ->with($userId)
            ->willReturn($user);

        $this->smsService
            ->expects($this->once())
            ->method('send')
            ->with('+1234567890', $message);

        $this->emailService
            ->expects($this->never())
            ->method('send');

        // When
        $this->service->sendNotification($userId, $message);
    }

    public function testSendNotificationBothMethods(): void
    {
        // Given
        $userId = 1;
        $message = 'Urgent notification';
        $user = new User(1, 'John Doe', 'john@example.com');
        $user->setPhoneNumber('+1234567890');

        // モックの設定
        $this->userRepository
            ->expects($this->once())
            ->method('findById')
            ->with($userId)
            ->willReturn($user);

        $this->emailService
            ->expects($this->once())
            ->method('send')
            ->with('john@example.com', 'Urgent Notification', $message);

        $this->smsService
            ->expects($this->once())
            ->method('send')
            ->with('+1234567890', $message);

        // When
        $this->service->sendUrgentNotification($userId, $message);
    }
}
```

### 2. 連続的な呼び出しのモッキング

```php
class BatchProcessorTest extends TestCase
{
    private BatchProcessor $processor;
    private JobRepositoryInterface $jobRepository;
    private JobExecutorInterface $jobExecutor;

    protected function setUp(): void
    {
        $this->jobRepository = $this->createMock(JobRepositoryInterface::class);
        $this->jobExecutor = $this->createMock(JobExecutorInterface::class);
        $this->processor = new BatchProcessor($this->jobRepository, $this->jobExecutor);
    }

    public function testProcessBatch(): void
    {
        // Given
        $jobs = [
            new Job(1, 'Job 1', 'pending'),
            new Job(2, 'Job 2', 'pending'),
            new Job(3, 'Job 3', 'pending')
        ];

        // モックの設定 - 連続的な呼び出し
        $this->jobRepository
            ->expects($this->exactly(3))
            ->method('findPendingJobs')
            ->withConsecutive([10], [10], [10])
            ->willReturnOnConsecutiveCalls(
                [$jobs[0], $jobs[1]],  // 最初の呼び出し
                [$jobs[2]],            // 2回目の呼び出し
                []                     // 3回目の呼び出し（空）
            );

        $this->jobExecutor
            ->expects($this->exactly(3))
            ->method('execute')
            ->withConsecutive(
                [$jobs[0]],
                [$jobs[1]],
                [$jobs[2]]
            )
            ->willReturnOnConsecutiveCalls(
                new JobResult(true, 'Job 1 completed'),
                new JobResult(true, 'Job 2 completed'),
                new JobResult(false, 'Job 3 failed')
            );

        $this->jobRepository
            ->expects($this->exactly(3))
            ->method('updateStatus')
            ->withConsecutive(
                [1, 'completed'],
                [2, 'completed'],
                [3, 'failed']
            );

        // When
        $result = $this->processor->processBatch();

        // Then
        $this->assertEquals(3, $result->getProcessedCount());
        $this->assertEquals(2, $result->getSuccessCount());
        $this->assertEquals(1, $result->getFailureCount());
    }
}
```

### 3. 例外処理のモッキング

```php
class ResilientServiceTest extends TestCase
{
    private ResilientService $service;
    private ExternalApiInterface $externalApi;
    private LoggerInterface $logger;

    protected function setUp(): void
    {
        $this->externalApi = $this->createMock(ExternalApiInterface::class);
        $this->logger = $this->createMock(LoggerInterface::class);
        $this->service = new ResilientService($this->externalApi, $this->logger);
    }

    public function testCallWithRetrySuccess(): void
    {
        // Given
        $data = ['key' => 'value'];
        $expectedResult = ['result' => 'success'];

        // モックの設定 - 最初の呼び出しで成功
        $this->externalApi
            ->expects($this->once())
            ->method('call')
            ->with($data)
            ->willReturn($expectedResult);

        $this->logger
            ->expects($this->never())
            ->method('warning');

        // When
        $result = $this->service->callWithRetry($data);

        // Then
        $this->assertEquals($expectedResult, $result);
    }

    public function testCallWithRetrySuccessAfterRetry(): void
    {
        // Given
        $data = ['key' => 'value'];
        $expectedResult = ['result' => 'success'];

        // モックの設定 - 最初は失敗、2回目で成功
        $this->externalApi
            ->expects($this->exactly(2))
            ->method('call')
            ->with($data)
            ->willReturnOnConsecutiveCalls(
                $this->throwException(new TemporaryException('Network error')),
                $expectedResult
            );

        $this->logger
            ->expects($this->once())
            ->method('warning')
            ->with('API call failed, retrying', $this->arrayHasKey('attempt'));

        // When
        $result = $this->service->callWithRetry($data);

        // Then
        $this->assertEquals($expectedResult, $result);
    }

    public function testCallWithRetryMaxRetriesExceeded(): void
    {
        // Given
        $data = ['key' => 'value'];

        // モックの設定 - 全ての試行で失敗
        $this->externalApi
            ->expects($this->exactly(3)) // 最初の試行 + 2回のリトライ
            ->method('call')
            ->with($data)
            ->willThrowException(new TemporaryException('Persistent error'));

        $this->logger
            ->expects($this->exactly(2))
            ->method('warning')
            ->with('API call failed, retrying', $this->arrayHasKey('attempt'));

        $this->logger
            ->expects($this->once())
            ->method('error')
            ->with('API call failed after all retries', $this->arrayHasKey('max_retries'));

        // Then
        $this->expectException(ApiException::class);
        $this->expectExceptionMessage('Max retries exceeded');

        // When
        $this->service->callWithRetry($data);
    }
}
```

## DIコンテナとモッキングの統合

### 1. テスト用モジュールでのモック束縛

```php
class MockModule extends AbstractModule
{
    private array $mocks = [];

    public function addMock(string $interface, object $mock): void
    {
        $this->mocks[$interface] = $mock;
    }

    protected function configure(): void
    {
        foreach ($this->mocks as $interface => $mock) {
            $this->bind($interface)->toInstance($mock);
        }
    }
}

class IntegratedMockTest extends TestCase
{
    private Injector $injector;
    private MockModule $mockModule;

    protected function setUp(): void
    {
        $this->mockModule = new MockModule();
        $this->injector = new Injector($this->mockModule);
    }

    public function testServiceWithMockedDependencies(): void
    {
        // Given
        $mockRepository = $this->createMock(UserRepositoryInterface::class);
        $mockEmailService = $this->createMock(EmailServiceInterface::class);

        // モックをモジュールに追加
        $this->mockModule->addMock(UserRepositoryInterface::class, $mockRepository);
        $this->mockModule->addMock(EmailServiceInterface::class, $mockEmailService);

        // DIコンテナからサービスを取得
        $userService = $this->injector->getInstance(UserService::class);

        // モックの設定
        $userData = ['name' => 'John Doe', 'email' => 'john@example.com'];
        $user = new User(1, 'John Doe', 'john@example.com');

        $mockRepository
            ->expects($this->once())
            ->method('findByEmail')
            ->with('john@example.com')
            ->willReturn(null);

        $mockRepository
            ->expects($this->once())
            ->method('save')
            ->with($this->isInstanceOf(User::class));

        $mockEmailService
            ->expects($this->once())
            ->method('send')
            ->with('john@example.com', 'Welcome', $this->anything());

        // When
        $result = $userService->createUser($userData);

        // Then
        $this->assertInstanceOf(User::class, $result);
    }
}
```

### 2. 部分的モッキング

```php
class PartialMockTest extends TestCase
{
    public function testPartialMockingWithDI(): void
    {
        // Given
        $mockRepository = $this->createMock(UserRepositoryInterface::class);
        $realEmailService = new EmailService(new SmtpTransport());
        $mockLogger = $this->createMock(LoggerInterface::class);

        // 部分的にモックを使用したモジュール
        $module = new class($mockRepository, $realEmailService, $mockLogger) extends AbstractModule {
            public function __construct(
                private UserRepositoryInterface $repository,
                private EmailServiceInterface $emailService,
                private LoggerInterface $logger
            ) {}

            protected function configure(): void
            {
                $this->bind(UserRepositoryInterface::class)->toInstance($this->repository);
                $this->bind(EmailServiceInterface::class)->toInstance($this->emailService);
                $this->bind(LoggerInterface::class)->toInstance($this->logger);
                $this->bind(UserService::class)->to(UserService::class);
            }
        };

        $injector = new Injector($module);
        $userService = $injector->getInstance(UserService::class);

        // モックの設定
        $userData = ['name' => 'John Doe', 'email' => 'john@example.com'];
        
        $mockRepository
            ->expects($this->once())
            ->method('findByEmail')
            ->willReturn(null);

        $mockRepository
            ->expects($this->once())
            ->method('save');

        $mockLogger
            ->expects($this->once())
            ->method('info');

        // When
        $user = $userService->createUser($userData);

        // Then
        $this->assertInstanceOf(User::class, $user);
        // 実際のメールサービスが使用されるため、実際にメールが送信される
    }
}
```

## 次のステップ

依存関係のモッキングを習得したので、次に進む準備が整いました。

1. **統合テスト**: システム全体のテスト戦略
2. **デザインパターン**: DIを使ったベストプラクティス
3. **トラブルシューティング**: 実際の問題解決

**続きは:** [統合テスト](integration-testing.html)

## 重要なポイント

- **テストダブル**の種類を理解して適切に使い分け
- **PHPUnit**と**Prophecy**の特徴を活用
- **外部サービス**を効果的に分離
- **複雑なシナリオ**も体系的にテスト
- **DIコンテナ**とモッキングの統合
- **部分的モッキング**で現実的なテスト環境を構築

---

効果的なモッキングにより、依存関係を分離した高品質なテストを実現できます。Ray.Diの依存性注入と組み合わせることで、保守しやすいテストスイートを構築できます。