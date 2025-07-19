---
layout: docs-ja
title: DIを使った単体テスト
category: Manual
permalink: /manuals/1.0/ja/tutorial/07-testing-strategies/unit-testing-with-di.html
---

# DIを使った単体テスト

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diを使った効率的な単体テストの書き方
- 依存関係の注入を活用したテストの分離
- テスト用モジュールの作成と設定
- PHPUnitとの統合とベストプラクティス
- テストの実行速度とメンテナンス性の向上

## DIを使った単体テストの基本

### 1. テストの基本構造

```php
use PHPUnit\Framework\TestCase;
use Ray\Di\Injector;

class UserServiceTest extends TestCase
{
    private Injector $injector;
    private UserService $userService;
    private UserRepositoryInterface $userRepository;
    private LoggerInterface $logger;

    protected function setUp(): void
    {
        // テスト用のモジュールを作成
        $this->injector = new Injector(new TestModule());
        
        // 依存関係を取得
        $this->userService = $this->injector->getInstance(UserService::class);
        $this->userRepository = $this->injector->getInstance(UserRepositoryInterface::class);
        $this->logger = $this->injector->getInstance(LoggerInterface::class);
    }

    public function testCreateUser(): void
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
        $this->assertEquals('John Doe', $user->getName());
        $this->assertEquals('john@example.com', $user->getEmail());
        $this->assertTrue($user->verifyPassword('password123'));
    }

    public function testCreateUserWithDuplicateEmail(): void
    {
        // Given
        $this->expectException(DuplicateEmailException::class);
        
        $userData = [
            'name' => 'John Doe',
            'email' => 'existing@example.com',
            'password' => 'password123'
        ];

        // When
        $this->userService->createUser($userData);
    }

    public function testFindUserById(): void
    {
        // Given
        $userId = 1;
        $expectedUser = new User(1, 'John Doe', 'john@example.com');

        // When
        $user = $this->userService->findById($userId);

        // Then
        $this->assertInstanceOf(User::class, $user);
        $this->assertEquals($expectedUser->getId(), $user->getId());
        $this->assertEquals($expectedUser->getName(), $user->getName());
    }

    public function testFindUserByIdNotFound(): void
    {
        // Given
        $this->expectException(UserNotFoundException::class);
        
        $userId = 999;

        // When
        $this->userService->findById($userId);
    }
}
```

### 2. テスト用モジュールの作成

```php
class TestModule extends AbstractModule
{
    protected function configure(): void
    {
        // テスト用のモック実装を束縛
        $this->bind(UserRepositoryInterface::class)
            ->to(InMemoryUserRepository::class)
            ->in(Singleton::class);

        $this->bind(LoggerInterface::class)
            ->to(TestLogger::class)
            ->in(Singleton::class);

        $this->bind(EmailServiceInterface::class)
            ->to(MockEmailService::class)
            ->in(Singleton::class);

        // 設定値をテスト用に設定
        $this->bind('config.database.host')
            ->toInstance('localhost');

        $this->bind('config.email.enabled')
            ->toInstance(false);

        // 実際のクラスはそのまま使用
        $this->bind(UserService::class)
            ->to(UserService::class);

        $this->bind(PasswordHasherInterface::class)
            ->to(PasswordHasher::class);
    }
}
```

### 3. テスト用実装クラス

```php
// インメモリリポジトリ実装
class InMemoryUserRepository implements UserRepositoryInterface
{
    private array $users = [];
    private int $nextId = 1;

    public function __construct()
    {
        // テスト用の初期データ
        $this->users = [
            1 => new User(1, 'John Doe', 'john@example.com', password_hash('password123', PASSWORD_DEFAULT)),
            2 => new User(2, 'Jane Smith', 'jane@example.com', password_hash('password456', PASSWORD_DEFAULT)),
            3 => new User(3, 'Bob Johnson', 'existing@example.com', password_hash('password789', PASSWORD_DEFAULT))
        ];
        $this->nextId = 4;
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
        if ($user->getId() === null) {
            $user->setId($this->nextId++);
        }
        $this->users[$user->getId()] = $user;
    }

    public function delete(int $id): void
    {
        unset($this->users[$id]);
    }

    public function findAll(): array
    {
        return array_values($this->users);
    }

    public function count(): int
    {
        return count($this->users);
    }
}

// テスト用ロガー
class TestLogger implements LoggerInterface
{
    private array $logs = [];

    public function emergency(string|\Stringable $message, array $context = []): void
    {
        $this->log('emergency', $message, $context);
    }

    public function alert(string|\Stringable $message, array $context = []): void
    {
        $this->log('alert', $message, $context);
    }

    public function critical(string|\Stringable $message, array $context = []): void
    {
        $this->log('critical', $message, $context);
    }

    public function error(string|\Stringable $message, array $context = []): void
    {
        $this->log('error', $message, $context);
    }

    public function warning(string|\Stringable $message, array $context = []): void
    {
        $this->log('warning', $message, $context);
    }

    public function notice(string|\Stringable $message, array $context = []): void
    {
        $this->log('notice', $message, $context);
    }

    public function info(string|\Stringable $message, array $context = []): void
    {
        $this->log('info', $message, $context);
    }

    public function debug(string|\Stringable $message, array $context = []): void
    {
        $this->log('debug', $message, $context);
    }

    public function log($level, string|\Stringable $message, array $context = []): void
    {
        $this->logs[] = [
            'level' => $level,
            'message' => (string) $message,
            'context' => $context,
            'timestamp' => new DateTime()
        ];
    }

    public function getLogs(): array
    {
        return $this->logs;
    }

    public function getLogsByLevel(string $level): array
    {
        return array_filter($this->logs, fn($log) => $log['level'] === $level);
    }

    public function hasLog(string $level, string $message): bool
    {
        foreach ($this->logs as $log) {
            if ($log['level'] === $level && $log['message'] === $message) {
                return true;
            }
        }
        return false;
    }

    public function clear(): void
    {
        $this->logs = [];
    }
}

// モックメールサービス
class MockEmailService implements EmailServiceInterface
{
    private array $sentEmails = [];

    public function send(string $to, string $subject, string $body): void
    {
        $this->sentEmails[] = [
            'to' => $to,
            'subject' => $subject,
            'body' => $body,
            'timestamp' => new DateTime()
        ];
    }

    public function getSentEmails(): array
    {
        return $this->sentEmails;
    }

    public function hasSentEmail(string $to, string $subject): bool
    {
        foreach ($this->sentEmails as $email) {
            if ($email['to'] === $to && $email['subject'] === $subject) {
                return true;
            }
        }
        return false;
    }

    public function clear(): void
    {
        $this->sentEmails = [];
    }
}
```

## 高度なテスト技法

### 1. データプロバイダーとパラメータ化テスト

```php
class UserValidationTest extends TestCase
{
    private UserValidator $validator;

    protected function setUp(): void
    {
        $injector = new Injector(new TestModule());
        $this->validator = $injector->getInstance(UserValidator::class);
    }

    /**
     * @dataProvider validUserDataProvider
     */
    public function testValidateValidUserData(array $userData): void
    {
        $result = $this->validator->validate($userData);
        $this->assertTrue($result->isValid());
        $this->assertEmpty($result->getErrors());
    }

    /**
     * @dataProvider invalidUserDataProvider
     */
    public function testValidateInvalidUserData(array $userData, array $expectedErrors): void
    {
        $result = $this->validator->validate($userData);
        $this->assertFalse($result->isValid());
        $this->assertEquals($expectedErrors, $result->getErrors());
    }

    public function validUserDataProvider(): array
    {
        return [
            'standard_user' => [
                [
                    'name' => 'John Doe',
                    'email' => 'john@example.com',
                    'password' => 'password123',
                    'age' => 25
                ]
            ],
            'minimal_user' => [
                [
                    'name' => 'Jane',
                    'email' => 'jane@test.com',
                    'password' => 'secret123'
                ]
            ],
            'user_with_long_name' => [
                [
                    'name' => str_repeat('A', 100),
                    'email' => 'long@example.com',
                    'password' => 'password123'
                ]
            ]
        ];
    }

    public function invalidUserDataProvider(): array
    {
        return [
            'missing_name' => [
                [
                    'email' => 'test@example.com',
                    'password' => 'password123'
                ],
                ['name' => 'Name is required']
            ],
            'invalid_email' => [
                [
                    'name' => 'John Doe',
                    'email' => 'invalid-email',
                    'password' => 'password123'
                ],
                ['email' => 'Invalid email format']
            ],
            'weak_password' => [
                [
                    'name' => 'John Doe',
                    'email' => 'john@example.com',
                    'password' => '123'
                ],
                ['password' => 'Password must be at least 8 characters']
            ],
            'multiple_errors' => [
                [
                    'name' => '',
                    'email' => 'invalid-email',
                    'password' => '123'
                ],
                [
                    'name' => 'Name is required',
                    'email' => 'Invalid email format',
                    'password' => 'Password must be at least 8 characters'
                ]
            ]
        ];
    }
}
```

### 2. 例外とエラーハンドリングのテスト

```php
class OrderServiceTest extends TestCase
{
    private OrderService $orderService;
    private ProductRepositoryInterface $productRepository;
    private PaymentGatewayInterface $paymentGateway;

    protected function setUp(): void
    {
        $injector = new Injector(new TestModule());
        $this->orderService = $injector->getInstance(OrderService::class);
        $this->productRepository = $injector->getInstance(ProductRepositoryInterface::class);
        $this->paymentGateway = $injector->getInstance(PaymentGatewayInterface::class);
    }

    public function testCreateOrderWithInsufficientStock(): void
    {
        // Given
        $this->expectException(InsufficientStockException::class);
        $this->expectExceptionMessage('Insufficient stock for product ID: 1');

        $orderData = [
            'items' => [
                ['product_id' => 1, 'quantity' => 100]
            ],
            'customer_id' => 1
        ];

        // When
        $this->orderService->createOrder($orderData);
    }

    public function testCreateOrderWithPaymentFailure(): void
    {
        // Given
        $this->expectException(PaymentFailedException::class);
        
        $orderData = [
            'items' => [
                ['product_id' => 1, 'quantity' => 1]
            ],
            'customer_id' => 1,
            'payment_method' => 'invalid_card'
        ];

        // When
        $this->orderService->createOrder($orderData);
    }

    public function testCreateOrderRollbackOnFailure(): void
    {
        // Given
        $orderData = [
            'items' => [
                ['product_id' => 1, 'quantity' => 1]
            ],
            'customer_id' => 1,
            'payment_method' => 'failing_card'
        ];

        $initialOrderCount = $this->getOrderCount();

        // When
        try {
            $this->orderService->createOrder($orderData);
        } catch (PaymentFailedException $e) {
            // Expected exception
        }

        // Then
        $this->assertEquals($initialOrderCount, $this->getOrderCount());
    }

    private function getOrderCount(): int
    {
        $orderRepository = $this->injector->getInstance(OrderRepositoryInterface::class);
        return $orderRepository->count();
    }
}
```

### 3. イベントとコールバックのテスト

```php
class EventDrivenServiceTest extends TestCase
{
    private EventDispatcherInterface $eventDispatcher;
    private UserService $userService;
    private array $dispatchedEvents = [];

    protected function setUp(): void
    {
        $injector = new Injector(new TestModule());
        $this->eventDispatcher = $injector->getInstance(EventDispatcherInterface::class);
        $this->userService = $injector->getInstance(UserService::class);
        
        // イベントリスナーを設定
        $this->eventDispatcher->addListener('user.created', [$this, 'onUserCreated']);
        $this->eventDispatcher->addListener('user.updated', [$this, 'onUserUpdated']);
    }

    public function testUserCreationDispatchesEvent(): void
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
        $this->assertCount(1, $this->dispatchedEvents);
        $this->assertEquals('user.created', $this->dispatchedEvents[0]['type']);
        $this->assertEquals($user->getId(), $this->dispatchedEvents[0]['data']['user_id']);
    }

    public function testUserUpdateDispatchesEvent(): void
    {
        // Given
        $user = $this->userService->findById(1);
        $updateData = ['name' => 'Updated Name'];

        // When
        $this->userService->updateUser($user->getId(), $updateData);

        // Then
        $this->assertCount(1, $this->dispatchedEvents);
        $this->assertEquals('user.updated', $this->dispatchedEvents[0]['type']);
        $this->assertEquals($user->getId(), $this->dispatchedEvents[0]['data']['user_id']);
        $this->assertEquals('Updated Name', $this->dispatchedEvents[0]['data']['changes']['name']);
    }

    public function onUserCreated(UserCreatedEvent $event): void
    {
        $this->dispatchedEvents[] = [
            'type' => 'user.created',
            'data' => [
                'user_id' => $event->getUser()->getId(),
                'timestamp' => $event->getTimestamp()
            ]
        ];
    }

    public function onUserUpdated(UserUpdatedEvent $event): void
    {
        $this->dispatchedEvents[] = [
            'type' => 'user.updated',
            'data' => [
                'user_id' => $event->getUser()->getId(),
                'changes' => $event->getChanges(),
                'timestamp' => $event->getTimestamp()
            ]
        ];
    }
}
```

## テストヘルパーとユーティリティ

### 1. テストデータファクトリー

```php
class UserFactory
{
    public static function create(array $attributes = []): User
    {
        $defaults = [
            'id' => null,
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => password_hash('password123', PASSWORD_DEFAULT),
            'created_at' => new DateTime(),
            'updated_at' => new DateTime()
        ];

        $merged = array_merge($defaults, $attributes);

        return new User(
            $merged['id'],
            $merged['name'],
            $merged['email'],
            $merged['password'],
            $merged['created_at'],
            $merged['updated_at']
        );
    }

    public static function createMany(int $count, array $attributes = []): array
    {
        $users = [];
        for ($i = 0; $i < $count; $i++) {
            $userAttributes = array_merge($attributes, [
                'id' => $i + 1,
                'name' => "User {$i}",
                'email' => "user{$i}@example.com"
            ]);
            $users[] = self::create($userAttributes);
        }
        return $users;
    }

    public static function withEmail(string $email): User
    {
        return self::create(['email' => $email]);
    }

    public static function withName(string $name): User
    {
        return self::create(['name' => $name]);
    }

    public static function admin(): User
    {
        return self::create([
            'name' => 'Admin User',
            'email' => 'admin@example.com',
            'roles' => ['admin']
        ]);
    }
}

class ProductFactory
{
    public static function create(array $attributes = []): Product
    {
        $defaults = [
            'id' => null,
            'name' => 'Test Product',
            'description' => 'A test product',
            'price' => 19.99,
            'stock_quantity' => 100,
            'category_id' => 1,
            'created_at' => new DateTime(),
            'updated_at' => new DateTime()
        ];

        $merged = array_merge($defaults, $attributes);

        return new Product(
            $merged['id'],
            $merged['name'],
            $merged['description'],
            $merged['price'],
            $merged['stock_quantity'],
            $merged['category_id'],
            $merged['created_at'],
            $merged['updated_at']
        );
    }

    public static function outOfStock(): Product
    {
        return self::create(['stock_quantity' => 0]);
    }

    public static function expensive(): Product
    {
        return self::create(['price' => 999.99]);
    }

    public static function inCategory(int $categoryId): Product
    {
        return self::create(['category_id' => $categoryId]);
    }
}
```

### 2. テストベースクラス

```php
abstract class ServiceTestCase extends TestCase
{
    protected Injector $injector;
    protected TestLogger $logger;

    protected function setUp(): void
    {
        $this->injector = new Injector($this->createTestModule());
        $this->logger = $this->injector->getInstance(LoggerInterface::class);
    }

    protected function createTestModule(): AbstractModule
    {
        return new TestModule();
    }

    protected function getInstance(string $class): object
    {
        return $this->injector->getInstance($class);
    }

    protected function assertLogContains(string $level, string $message): void
    {
        $this->assertTrue(
            $this->logger->hasLog($level, $message),
            "Expected log entry not found: [{$level}] {$message}"
        );
    }

    protected function assertLogCount(int $expectedCount): void
    {
        $this->assertCount($expectedCount, $this->logger->getLogs());
    }

    protected function assertNoLogs(): void
    {
        $this->assertEmpty($this->logger->getLogs());
    }

    protected function clearLogs(): void
    {
        $this->logger->clear();
    }
}

abstract class RepositoryTestCase extends ServiceTestCase
{
    protected function createTestModule(): AbstractModule
    {
        return new DatabaseTestModule();
    }

    protected function setUp(): void
    {
        parent::setUp();
        $this->setupDatabase();
    }

    protected function tearDown(): void
    {
        $this->cleanupDatabase();
        parent::tearDown();
    }

    protected function setupDatabase(): void
    {
        // テスト用データベースの初期化
        $database = $this->getInstance(DatabaseInterface::class);
        $database->beginTransaction();
    }

    protected function cleanupDatabase(): void
    {
        // テスト用データベースのクリーンアップ
        $database = $this->getInstance(DatabaseInterface::class);
        $database->rollback();
    }
}
```

### 3. アサーションヘルパー

```php
trait CustomAssertions
{
    protected function assertUser(User $expected, User $actual): void
    {
        $this->assertEquals($expected->getId(), $actual->getId());
        $this->assertEquals($expected->getName(), $actual->getName());
        $this->assertEquals($expected->getEmail(), $actual->getEmail());
    }

    protected function assertProduct(Product $expected, Product $actual): void
    {
        $this->assertEquals($expected->getId(), $actual->getId());
        $this->assertEquals($expected->getName(), $actual->getName());
        $this->assertEquals($expected->getPrice(), $actual->getPrice());
        $this->assertEquals($expected->getStockQuantity(), $actual->getStockQuantity());
    }

    protected function assertOrder(Order $expected, Order $actual): void
    {
        $this->assertEquals($expected->getId(), $actual->getId());
        $this->assertEquals($expected->getCustomerId(), $actual->getCustomerId());
        $this->assertEquals($expected->getTotal(), $actual->getTotal());
        $this->assertEquals($expected->getStatus(), $actual->getStatus());
    }

    protected function assertEmailSent(string $to, string $subject, MockEmailService $emailService): void
    {
        $this->assertTrue(
            $emailService->hasSentEmail($to, $subject),
            "Expected email not sent to {$to} with subject '{$subject}'"
        );
    }

    protected function assertEventDispatched(string $eventType, array $expectedData, TestEventDispatcher $dispatcher): void
    {
        $events = $dispatcher->getDispatchedEvents();
        $found = false;
        
        foreach ($events as $event) {
            if ($event['type'] === $eventType) {
                $this->assertEquals($expectedData, $event['data']);
                $found = true;
                break;
            }
        }
        
        $this->assertTrue($found, "Event {$eventType} was not dispatched");
    }

    protected function assertDatabaseHas(string $table, array $data, DatabaseInterface $database): void
    {
        $conditions = [];
        $params = [];
        
        foreach ($data as $column => $value) {
            $conditions[] = "{$column} = ?";
            $params[] = $value;
        }
        
        $sql = "SELECT COUNT(*) as count FROM {$table} WHERE " . implode(' AND ', $conditions);
        $result = $database->query($sql, $params);
        
        $this->assertGreaterThan(0, $result[0]['count'], "Database does not contain expected data");
    }
}
```

## パフォーマンステスト

### 1. 実行時間測定

```php
class PerformanceTest extends ServiceTestCase
{
    use CustomAssertions;

    public function testUserServicePerformance(): void
    {
        // Given
        $userService = $this->getInstance(UserService::class);
        $userData = [
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => 'password123'
        ];

        // When
        $startTime = microtime(true);
        
        for ($i = 0; $i < 1000; $i++) {
            $userData['email'] = "user{$i}@example.com";
            $userService->createUser($userData);
        }
        
        $endTime = microtime(true);
        $duration = $endTime - $startTime;

        // Then
        $this->assertLessThan(1.0, $duration, 'User creation took too long');
        $this->assertGreaterThan(0.0, $duration, 'User creation was too fast (suspicious)');
    }

    public function testRepositoryQueryPerformance(): void
    {
        // Given
        $repository = $this->getInstance(UserRepositoryInterface::class);
        
        // Setup test data
        for ($i = 0; $i < 100; $i++) {
            $user = UserFactory::create(['email' => "user{$i}@example.com"]);
            $repository->save($user);
        }

        // When
        $startTime = microtime(true);
        
        for ($i = 0; $i < 100; $i++) {
            $repository->findByEmail("user{$i}@example.com");
        }
        
        $endTime = microtime(true);
        $duration = $endTime - $startTime;

        // Then
        $this->assertLessThan(0.1, $duration, 'Repository queries took too long');
    }

    public function testMemoryUsage(): void
    {
        // Given
        $userService = $this->getInstance(UserService::class);
        $initialMemory = memory_get_usage(true);

        // When
        for ($i = 0; $i < 1000; $i++) {
            $userData = [
                'name' => "User {$i}",
                'email' => "user{$i}@example.com",
                'password' => 'password123'
            ];
            $userService->createUser($userData);
        }

        $finalMemory = memory_get_usage(true);
        $memoryUsed = $finalMemory - $initialMemory;

        // Then
        $this->assertLessThan(10 * 1024 * 1024, $memoryUsed, 'Memory usage too high'); // 10MB limit
    }
}
```

### 2. 並行実行テスト

```php
class ConcurrencyTest extends ServiceTestCase
{
    public function testConcurrentUserCreation(): void
    {
        // Given
        $userService = $this->getInstance(UserService::class);
        $processes = [];
        $results = [];

        // When - 複数プロセスで同時実行をシミュレート
        for ($i = 0; $i < 5; $i++) {
            $pid = pcntl_fork();
            
            if ($pid == -1) {
                $this->fail('Could not fork process');
            } elseif ($pid) {
                $processes[] = $pid;
            } else {
                // 子プロセス
                $userData = [
                    'name' => "User {$i}",
                    'email' => "concurrent{$i}@example.com",
                    'password' => 'password123'
                ];
                
                try {
                    $user = $userService->createUser($userData);
                    exit(0); // 成功
                } catch (Exception $e) {
                    exit(1); // 失敗
                }
            }
        }

        // 全プロセスの完了を待つ
        foreach ($processes as $pid) {
            $status = null;
            pcntl_waitpid($pid, $status);
            $results[] = pcntl_wexitstatus($status);
        }

        // Then
        $this->assertEquals([0, 0, 0, 0, 0], $results, 'Some concurrent operations failed');
    }
}
```

## 統合テストモジュール

### 1. 包括的テストモジュール

```php
class ComprehensiveTestModule extends AbstractModule
{
    protected function configure(): void
    {
        // コアサービス
        $this->install(new ServiceTestModule());
        
        // データアクセス
        $this->install(new RepositoryTestModule());
        
        // 外部サービス
        $this->install(new ExternalServiceTestModule());
        
        // イベント処理
        $this->install(new EventTestModule());
        
        // セキュリティ
        $this->install(new SecurityTestModule());
    }
}

class ServiceTestModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserService::class)->to(UserService::class);
        $this->bind(ProductService::class)->to(ProductService::class);
        $this->bind(OrderService::class)->to(OrderService::class);
        $this->bind(PaymentService::class)->to(PaymentService::class);
    }
}

class RepositoryTestModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(UserRepositoryInterface::class)
            ->to(InMemoryUserRepository::class)
            ->in(Singleton::class);
        
        $this->bind(ProductRepositoryInterface::class)
            ->to(InMemoryProductRepository::class)
            ->in(Singleton::class);
        
        $this->bind(OrderRepositoryInterface::class)
            ->to(InMemoryOrderRepository::class)
            ->in(Singleton::class);
    }
}

class ExternalServiceTestModule extends AbstractModule
{
    protected function configure(): void
    {
        $this->bind(EmailServiceInterface::class)
            ->to(MockEmailService::class)
            ->in(Singleton::class);
        
        $this->bind(PaymentGatewayInterface::class)
            ->to(MockPaymentGateway::class)
            ->in(Singleton::class);
        
        $this->bind(NotificationServiceInterface::class)
            ->to(MockNotificationService::class)
            ->in(Singleton::class);
    }
}
```

## 次のステップ

単体テストの基盤を構築したので、次に進む準備が整いました。

1. **依存関係のモッキング**: より高度なモックとスタブの活用
2. **統合テスト**: システム全体のテスト戦略
3. **テストの自動化**: CI/CDパイプラインでのテスト実行

**続きは:** [依存関係のモッキング](dependency-mocking.html)

## 重要なポイント

- **DI**によりテストの分離と独立性を実現
- **テスト用モジュール**で依存関係を制御
- **ファクトリーパターン**でテストデータを効率的に生成
- **インメモリ実装**で高速なテスト実行
- **カスタムアサーション**でテストの可読性を向上
- **パフォーマンステスト**で品質を保証

---

Ray.Diを活用することで、保守しやすく実行速度の速い単体テストを構築できます。適切な抽象化により、ビジネスロジックのテストに集中できます。