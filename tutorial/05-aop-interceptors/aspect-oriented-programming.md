# Aspect-Oriented Programming with Ray.Di

## 🎯 Learning Objectives

By the end of this section, you'll understand:
- What Aspect-Oriented Programming (AOP) is and why it matters
- How AOP solves cross-cutting concerns elegantly
- Ray.Di's interceptor mechanism and how to use it
- Real-world examples: logging, caching, security, transactions
- Best practices for designing maintainable aspects

## 🤔 What is Aspect-Oriented Programming?

Aspect-Oriented Programming (AOP) is a programming paradigm that enables separation of **cross-cutting concerns** from business logic. Cross-cutting concerns are aspects of a program that affect multiple modules - like logging, security, caching, and transactions.

### The Problem: Cross-Cutting Concerns

Without AOP, cross-cutting concerns get scattered throughout your codebase:

```php
class OrderService
{
    public function processOrder(Order $order): void
    {
        // Logging concern
        $this->logger->info("Processing order: " . $order->getId());
        
        // Security concern
        if (!$this->authService->canProcessOrders()) {
            throw new UnauthorizedException();
        }
        
        // Validation concern
        if (!$this->validator->validate($order)) {
            throw new ValidationException();
        }
        
        // Performance monitoring concern
        $startTime = microtime(true);
        
        try {
            // Transaction concern
            $this->database->beginTransaction();
            
            // ACTUAL BUSINESS LOGIC (only 3 lines!)
            $this->calculateTotal($order);
            $this->saveOrder($order);
            $this->sendConfirmation($order);
            
            // Transaction concern
            $this->database->commit();
            
        } catch (Exception $e) {
            // Error handling concern
            $this->database->rollback();
            $this->logger->error("Order processing failed: " . $e->getMessage());
            throw $e;
        }
        
        // Performance monitoring concern
        $duration = microtime(true) - $startTime;
        $this->metrics->record('order_processing_time', $duration);
        
        // Caching concern
        $this->cache->invalidate("user_orders_" . $order->getCustomerId());
        
        // Logging concern
        $this->logger->info("Order processed successfully: " . $order->getId());
    }
}
```

**Problems:**
- Business logic is buried in infrastructure concerns
- Same concerns repeated across many methods
- Hard to modify logging/security/caching behavior globally
- Difficult to test business logic in isolation

## 💡 The AOP Solution

AOP separates concerns into **aspects** that can be applied declaratively:

```php
class OrderService
{
    #[Log("Processing order")]
    #[RequiresPermission("PROCESS_ORDERS")]
    #[Validate]
    #[Transactional]
    #[CacheEvict(pattern: "user_orders_*")]
    #[Monitor(metric: "order_processing_time")]
    public function processOrder(Order $order): void
    {
        // PURE BUSINESS LOGIC!
        $this->calculateTotal($order);
        $this->saveOrder($order);
        $this->sendConfirmation($order);
    }
}
```

**Benefits:**
- Business logic is clean and focused
- Cross-cutting concerns are centralized
- Easy to modify aspect behavior globally
- Better testability and maintainability

## 🏗️ Ray.Di Interceptors

Ray.Di implements AOP through **interceptors** - classes that can wrap method calls and add behavior before, after, or around the method execution.

### Basic Interceptor Structure

```php
use Ray\Aop\MethodInterceptor;
use Ray\Aop\MethodInvocation;

class LoggingInterceptor implements MethodInterceptor
{
    public function __construct(
        private LoggerInterface $logger
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $methodName = $invocation->getMethod()->getName();
        $className = $invocation->getThis()::class;
        
        // Before method execution
        $this->logger->info("Calling {$className}::{$methodName}");
        
        try {
            // Execute the actual method
            $result = $invocation->proceed();
            
            // After successful execution
            $this->logger->info("Successfully completed {$className}::{$methodName}");
            
            return $result;
            
        } catch (Exception $e) {
            // After exception
            $this->logger->error("Exception in {$className}::{$methodName}: " . $e->getMessage());
            throw $e;
        }
    }
}
```

### Binding Interceptors with Attributes

```php
#[Attribute(Attribute::TARGET_METHOD)]
class Log
{
    public function __construct(
        public readonly string $message = '',
        public readonly string $level = 'info'
    ) {}
}

// In your module configuration
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // Bind the interceptor to the attribute
        $this->bindInterceptor(
            $this->matcher->any(),                    // Any class
            $this->matcher->annotatedWith(Log::class), // Methods with #[Log]
            [LoggingInterceptor::class]               // Apply this interceptor
        );
    }
}
```

## 🛡️ Security Aspect Example

Let's create a comprehensive security aspect for our e-commerce platform:

```php
#[Attribute(Attribute::TARGET_METHOD)]
class RequiresPermission
{
    public function __construct(
        public readonly string $permission,
        public readonly bool $requireOwnership = false
    ) {}
}

class SecurityInterceptor implements MethodInterceptor
{
    public function __construct(
        private SecurityContextInterface $securityContext,
        private PermissionCheckerInterface $permissionChecker
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $attributes = $method->getAttributes(RequiresPermission::class);
        
        foreach ($attributes as $attribute) {
            $permission = $attribute->newInstance();
            $this->checkPermission($permission, $invocation);
        }
        
        return $invocation->proceed();
    }
    
    private function checkPermission(RequiresPermission $permission, MethodInvocation $invocation): void
    {
        $user = $this->securityContext->getCurrentUser();
        
        if (!$user) {
            throw new AuthenticationException('User not authenticated');
        }
        
        if (!$this->permissionChecker->hasPermission($user, $permission->permission)) {
            throw new AuthorizationException("Permission denied: {$permission->permission}");
        }
        
        if ($permission->requireOwnership) {
            $this->checkOwnership($user, $invocation);
        }
    }
    
    private function checkOwnership(User $user, MethodInvocation $invocation): void
    {
        $arguments = $invocation->getArguments();
        
        // Look for entities that implement OwnableInterface
        foreach ($arguments as $argument) {
            if ($argument instanceof OwnableInterface) {
                if ($argument->getOwnerId() !== $user->getId()) {
                    throw new AuthorizationException('Access denied: not the owner');
                }
            }
        }
    }
}

// Usage in services
class OrderService
{
    #[RequiresPermission("ORDER_VIEW")]
    public function getOrder(int $orderId): Order
    {
        return $this->orderRepository->findById($orderId);
    }
    
    #[RequiresPermission("ORDER_EDIT", requireOwnership: true)]
    public function updateOrder(Order $order, array $data): Order
    {
        // Only the order owner (or admin) can update
        return $this->orderRepository->update($order, $data);
    }
    
    #[RequiresPermission("ORDER_DELETE")]
    public function deleteOrder(int $orderId): void
    {
        $this->orderRepository->delete($orderId);
    }
}
```

## 🚀 Performance Monitoring Aspect

```php
#[Attribute(Attribute::TARGET_METHOD)]
class Monitor
{
    public function __construct(
        public readonly string $metric,
        public readonly array $tags = []
    ) {}
}

class PerformanceInterceptor implements MethodInterceptor
{
    public function __construct(
        private MetricsCollectorInterface $metrics
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $attributes = $method->getAttributes(Monitor::class);
        
        if (empty($attributes)) {
            return $invocation->proceed();
        }
        
        $monitor = $attributes[0]->newInstance();
        
        $startTime = microtime(true);
        $startMemory = memory_get_usage(true);
        
        try {
            $result = $invocation->proceed();
            
            $this->recordSuccessMetrics($monitor, $startTime, $startMemory, $invocation);
            
            return $result;
            
        } catch (Exception $e) {
            $this->recordErrorMetrics($monitor, $startTime, $startMemory, $invocation, $e);
            throw $e;
        }
    }
    
    private function recordSuccessMetrics(Monitor $monitor, float $startTime, int $startMemory, MethodInvocation $invocation): void
    {
        $duration = microtime(true) - $startTime;
        $memoryUsed = memory_get_usage(true) - $startMemory;
        
        $tags = array_merge($monitor->tags, [
            'class' => $invocation->getThis()::class,
            'method' => $invocation->getMethod()->getName(),
            'status' => 'success'
        ]);
        
        $this->metrics->timing($monitor->metric . '.duration', $duration, $tags);
        $this->metrics->gauge($monitor->metric . '.memory', $memoryUsed, $tags);
        $this->metrics->increment($monitor->metric . '.calls', $tags);
    }
    
    private function recordErrorMetrics(Monitor $monitor, float $startTime, int $startMemory, MethodInvocation $invocation, Exception $e): void
    {
        $duration = microtime(true) - $startTime;
        
        $tags = array_merge($monitor->tags, [
            'class' => $invocation->getThis()::class,
            'method' => $invocation->getMethod()->getName(),
            'status' => 'error',
            'exception' => $e::class
        ]);
        
        $this->metrics->timing($monitor->metric . '.duration', $duration, $tags);
        $this->metrics->increment($monitor->metric . '.errors', $tags);
    }
}

// Usage
class ProductService
{
    #[Monitor(metric: "product_search", tags: ["type" => "elasticsearch"])]
    public function searchProducts(SearchCriteria $criteria): ProductCollection
    {
        return $this->searchEngine->search($criteria);
    }
    
    #[Monitor(metric: "product_recommendation")]
    public function getRecommendations(User $user, int $limit = 10): array
    {
        return $this->recommendationEngine->getRecommendations($user, $limit);
    }
}
```

## 💾 Caching Aspect

```php
#[Attribute(Attribute::TARGET_METHOD)]
class Cacheable
{
    public function __construct(
        public readonly string $key = '',
        public readonly int $ttl = 3600,
        public readonly array $tags = []
    ) {}
}

#[Attribute(Attribute::TARGET_METHOD)]
class CacheEvict
{
    public function __construct(
        public readonly string $pattern = '',
        public readonly array $tags = []
    ) {}
}

class CachingInterceptor implements MethodInterceptor
{
    public function __construct(
        private CacheInterface $cache,
        private CacheKeyGeneratorInterface $keyGenerator
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        
        // Handle cache eviction first
        $evictAttributes = $method->getAttributes(CacheEvict::class);
        foreach ($evictAttributes as $attribute) {
            $this->handleCacheEviction($attribute->newInstance(), $invocation);
        }
        
        // Handle caching
        $cacheableAttributes = $method->getAttributes(Cacheable::class);
        if (!empty($cacheableAttributes)) {
            return $this->handleCaching($cacheableAttributes[0]->newInstance(), $invocation);
        }
        
        return $invocation->proceed();
    }
    
    private function handleCaching(Cacheable $cacheable, MethodInvocation $invocation): mixed
    {
        $cacheKey = $this->generateCacheKey($cacheable, $invocation);
        
        // Try to get from cache
        $cached = $this->cache->get($cacheKey);
        if ($cached !== null) {
            return $cached;
        }
        
        // Execute method and cache result
        $result = $invocation->proceed();
        
        $this->cache->set($cacheKey, $result, $cacheable->ttl, $cacheable->tags);
        
        return $result;
    }
    
    private function handleCacheEviction(CacheEvict $evict, MethodInvocation $invocation): void
    {
        if ($evict->pattern) {
            $this->cache->deleteByPattern($evict->pattern);
        }
        
        if (!empty($evict->tags)) {
            $this->cache->deleteByTags($evict->tags);
        }
    }
    
    private function generateCacheKey(Cacheable $cacheable, MethodInvocation $invocation): string
    {
        if ($cacheable->key) {
            return $this->keyGenerator->generate($cacheable->key, $invocation->getArguments());
        }
        
        $class = $invocation->getThis()::class;
        $method = $invocation->getMethod()->getName();
        $args = $invocation->getArguments();
        
        return $this->keyGenerator->generate("{$class}::{$method}", $args);
    }
}

// Usage
class ProductService
{
    #[Cacheable(key: "product_{id}", ttl: 1800, tags: ["products"])]
    public function getProduct(int $id): Product
    {
        return $this->productRepository->findById($id);
    }
    
    #[Cacheable(key: "featured_products", ttl: 3600, tags: ["products", "featured"])]
    public function getFeaturedProducts(): array
    {
        return $this->productRepository->findFeatured();
    }
    
    #[CacheEvict(tags: ["products"])]
    public function updateProduct(Product $product): Product
    {
        $result = $this->productRepository->save($product);
        
        // All product-related cache entries will be evicted
        return $result;
    }
    
    #[CacheEvict(pattern: "user_cart_*")]
    public function updateProductPrice(int $productId, Money $newPrice): void
    {
        $this->productRepository->updatePrice($productId, $newPrice);
        
        // Evict all user cart caches since prices changed
    }
}
```

## 📊 Transaction Management Aspect

```php
#[Attribute(Attribute::TARGET_METHOD)]
class Transactional
{
    public function __construct(
        public readonly string $propagation = 'REQUIRED',
        public readonly array $rollbackFor = [Exception::class]
    ) {}
}

class TransactionalInterceptor implements MethodInterceptor
{
    public function __construct(
        private DatabaseManagerInterface $databaseManager
    ) {}
    
    public function invoke(MethodInvocation $invocation): mixed
    {
        $method = $invocation->getMethod();
        $attributes = $method->getAttributes(Transactional::class);
        
        if (empty($attributes)) {
            return $invocation->proceed();
        }
        
        $transactional = $attributes[0]->newInstance();
        
        if ($this->databaseManager->inTransaction() && $transactional->propagation === 'REQUIRED') {
            // Join existing transaction
            return $invocation->proceed();
        }
        
        // Start new transaction
        $this->databaseManager->beginTransaction();
        
        try {
            $result = $invocation->proceed();
            $this->databaseManager->commit();
            return $result;
            
        } catch (Exception $e) {
            $this->databaseManager->rollback();
            
            if ($this->shouldRollback($e, $transactional->rollbackFor)) {
                throw $e;
            }
            
            // Re-throw without rollback for specified exceptions
            throw $e;
        }
    }
    
    private function shouldRollback(Exception $e, array $rollbackFor): bool
    {
        foreach ($rollbackFor as $exceptionClass) {
            if ($e instanceof $exceptionClass) {
                return true;
            }
        }
        return false;
    }
}

// Usage
class OrderService
{
    #[Transactional]
    public function processOrder(Order $order): void
    {
        // All operations in this method will be in a transaction
        $this->validateOrder($order);
        $this->reserveInventory($order);
        $this->chargePayment($order);
        $this->saveOrder($order);
        $this->sendConfirmation($order);
        
        // If any step fails, entire transaction rolls back
    }
    
    #[Transactional(rollbackFor: [PaymentException::class, InventoryException::class])]
    public function processPayment(Order $order): PaymentResult
    {
        // Only roll back for specific exceptions
        return $this->paymentProcessor->process($order);
    }
}
```

## 🎯 Combining Multiple Aspects

You can apply multiple aspects to the same method:

```php
class OrderService
{
    #[Log("Processing order")]
    #[RequiresPermission("ORDER_PROCESS")]
    #[Monitor(metric: "order_processing")]
    #[Transactional]
    #[CacheEvict(pattern: "user_orders_*")]
    public function processOrder(Order $order): void
    {
        // Pure business logic - all concerns handled by aspects
        $this->calculateOrderTotal($order);
        $this->applyDiscounts($order);
        $this->reserveInventory($order);
        $this->processPayment($order);
        $this->saveOrder($order);
        $this->sendConfirmation($order);
    }
}
```

**Execution order:**
1. Security check (authentication/authorization)
2. Transaction begins
3. Logging starts
4. Performance monitoring starts
5. **Business logic executes**
6. Performance monitoring records metrics
7. Logging completes
8. Transaction commits
9. Cache eviction occurs

## 🔧 Module Configuration

```php
class AopModule extends AbstractModule
{
    protected function configure(): void
    {
        // Bind all interceptors
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Log::class),
            [LoggingInterceptor::class]
        );
        
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(RequiresPermission::class),
            [SecurityInterceptor::class]
        );
        
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Monitor::class),
            [PerformanceInterceptor::class]
        );
        
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->logicalOr(
                $this->matcher->annotatedWith(Cacheable::class),
                $this->matcher->annotatedWith(CacheEvict::class)
            ),
            [CachingInterceptor::class]
        );
        
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Transactional::class),
            [TransactionalInterceptor::class]
        );
    }
}
```

## 📋 Best Practices

### 1. Keep Aspects Focused
Each aspect should handle one concern:

```php
// Good: Focused on logging
class LoggingInterceptor implements MethodInterceptor { /* ... */ }

// Bad: Handles multiple concerns
class LoggingAndCachingInterceptor implements MethodInterceptor { /* ... */ }
```

### 2. Make Aspects Configurable
```php
#[Log(level: "debug", includeArguments: true)]
#[Cacheable(ttl: 300, condition: "result.size() > 0")]
#[Monitor(metric: "api_calls", sampleRate: 0.1)]
public function expensiveOperation(): Result { /* ... */ }
```

### 3. Order Matters
```php
// Security should be first
// Transactions should wrap business logic
// Logging can be anywhere
// Caching should be outermost for reads
```

### 4. Handle Exceptions Properly
```php
class RobustInterceptor implements MethodInterceptor
{
    public function invoke(MethodInvocation $invocation): mixed
    {
        try {
            // Pre-processing
            $this->beforeExecution($invocation);
            
            $result = $invocation->proceed();
            
            // Post-processing
            $this->afterExecution($invocation, $result);
            
            return $result;
            
        } catch (Exception $e) {
            // Error handling
            $this->onException($invocation, $e);
            throw $e; // Re-throw unless you want to suppress
        }
    }
}
```

## 🎓 Benefits of AOP with Ray.Di

1. **Separation of Concerns**: Business logic is pure and focused
2. **Reusability**: Aspects can be applied to any method
3. **Maintainability**: Change aspect behavior in one place
4. **Testability**: Test business logic without infrastructure concerns
5. **Consistency**: Ensure consistent behavior across the application
6. **Non-invasive**: Add aspects without changing business code

## 🚀 Next Steps

Now that you understand AOP, explore:

1. **[Method Interceptors](method-interceptors.md)**: Deep dive into interceptor patterns
2. **[Common Cross-cutting Concerns](common-crosscutting-concerns.md)**: More real-world examples
3. **[Real-World Examples](../06-real-world-examples/)**: See AOP in complete applications

## 💡 Key Takeaways

- **AOP separates** cross-cutting concerns from business logic
- **Ray.Di interceptors** provide powerful AOP capabilities
- **Attributes** make aspect application declarative and clean
- **Multiple aspects** can be combined on the same method
- **Proper design** makes applications more maintainable and testable

---

**Remember:** AOP is a powerful tool, but use it judiciously. Not every piece of code needs to be an aspect - focus on true cross-cutting concerns that appear throughout your application!