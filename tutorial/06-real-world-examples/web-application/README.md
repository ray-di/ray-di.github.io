# Building a Real-World E-commerce Web Application

## 🎯 Overview

This section demonstrates how to build a complete e-commerce web application using Ray.Di, showcasing:

- **Clean Architecture**: Layered design with clear separation of concerns
- **SOLID Principles**: Applied throughout the application structure  
- **Design Patterns**: Factory, Repository, Strategy, Observer, and more
- **AOP Integration**: Cross-cutting concerns handled elegantly
- **Testing Strategy**: Comprehensive testing with dependency injection
- **Performance**: Caching, lazy loading, and optimization techniques

## 🏗️ Application Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
├─────────────────────────────────────────────────────────────┤
│  Controllers  │  Middleware  │  Response  │  Request        │
│               │              │  Handlers  │  Validators     │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   Application Layer                          │
├─────────────────────────────────────────────────────────────┤
│  Use Cases    │  Services    │  DTOs      │  Event          │
│               │              │            │  Handlers       │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                     Domain Layer                            │
├─────────────────────────────────────────────────────────────┤
│  Entities     │  Value       │  Domain    │  Repository     │
│               │  Objects     │  Services  │  Interfaces     │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                Infrastructure Layer                         │
├─────────────────────────────────────────────────────────────┤
│  Repositories │  External    │  Database  │  File System   │
│               │  APIs        │  Access    │  Cache          │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
src/
├── App/
│   ├── Controller/           # Presentation Layer
│   │   ├── Api/
│   │   │   ├── ProductController.php
│   │   │   ├── OrderController.php
│   │   │   └── UserController.php
│   │   ├── Web/
│   │   │   ├── HomeController.php
│   │   │   ├── ShopController.php
│   │   │   └── CheckoutController.php
│   │   └── Middleware/
│   │       ├── AuthenticationMiddleware.php
│   │       ├── AuthorizationMiddleware.php
│   │       └── RateLimitMiddleware.php
│   │
│   ├── UseCase/              # Application Layer
│   │   ├── Order/
│   │   │   ├── ProcessOrderUseCase.php
│   │   │   ├── CancelOrderUseCase.php
│   │   │   └── GetOrderHistoryUseCase.php
│   │   ├── Product/
│   │   │   ├── SearchProductsUseCase.php
│   │   │   ├── GetProductDetailsUseCase.php
│   │   │   └── UpdateInventoryUseCase.php
│   │   └── User/
│   │       ├── RegisterUserUseCase.php
│   │       ├── AuthenticateUserUseCase.php
│   │       └── UpdateProfileUseCase.php
│   │
│   ├── Service/              # Application Services
│   │   ├── EmailService.php
│   │   ├── PaymentService.php
│   │   ├── InventoryService.php
│   │   └── RecommendationService.php
│   │
│   └── Infrastructure/       # Infrastructure Layer
│       ├── Repository/
│       │   ├── MySQLProductRepository.php
│       │   ├── MySQLOrderRepository.php
│       │   └── MySQLUserRepository.php
│       ├── External/
│       │   ├── StripePaymentGateway.php
│       │   ├── SendGridEmailService.php
│       │   └── ElasticsearchProductIndex.php
│       └── Cache/
│           ├── RedisCache.php
│           └── FilesystemCache.php
│
├── Domain/                   # Domain Layer
│   ├── Entity/
│   │   ├── User.php
│   │   ├── Product.php
│   │   ├── Order.php
│   │   └── Cart.php
│   ├── ValueObject/
│   │   ├── Money.php
│   │   ├── Email.php
│   │   ├── Address.php
│   │   └── ProductSku.php
│   ├── Repository/
│   │   ├── UserRepositoryInterface.php
│   │   ├── ProductRepositoryInterface.php
│   │   └── OrderRepositoryInterface.php
│   └── Service/
│       ├── PricingService.php
│       ├── InventoryService.php
│       └── OrderValidationService.php
│
└── Module/                   # DI Configuration
    ├── AppModule.php
    ├── DatabaseModule.php
    ├── CacheModule.php
    └── ExternalServicesModule.php
```

## 🎮 Complete Example: Product Management

Let's walk through a complete feature implementation:

### Domain Layer

```php
// Domain/Entity/Product.php
class Product
{
    public function __construct(
        private ProductId $id,
        private string $name,
        private string $description,
        private Money $price,
        private ProductSku $sku,
        private CategoryId $categoryId,
        private int $stockQuantity,
        private bool $isActive = true,
        private DateTimeImmutable $createdAt = new DateTimeImmutable(),
        private ?DateTimeImmutable $updatedAt = null
    ) {}
    
    public function updatePrice(Money $newPrice): void
    {
        if ($newPrice->isNegative()) {
            throw new InvalidArgumentException('Price cannot be negative');
        }
        
        $this->price = $newPrice;
        $this->updatedAt = new DateTimeImmutable();
    }
    
    public function reserveStock(int $quantity): void
    {
        if ($quantity <= 0) {
            throw new InvalidArgumentException('Quantity must be positive');
        }
        
        if ($this->stockQuantity < $quantity) {
            throw new InsufficientStockException("Not enough stock available");
        }
        
        $this->stockQuantity -= $quantity;
        $this->updatedAt = new DateTimeImmutable();
    }
    
    public function isAvailable(): bool
    {
        return $this->isActive && $this->stockQuantity > 0;
    }
    
    // Getters...
    public function getId(): ProductId { return $this->id; }
    public function getName(): string { return $this->name; }
    public function getPrice(): Money { return $this->price; }
    public function getSku(): ProductSku { return $this->sku; }
    public function getStockQuantity(): int { return $this->stockQuantity; }
}

// Domain/ValueObject/ProductSku.php
class ProductSku
{
    private string $value;
    
    public function __construct(string $value)
    {
        if (!preg_match('/^[A-Z0-9]{8,12}$/', $value)) {
            throw new InvalidArgumentException('Invalid SKU format');
        }
        
        $this->value = $value;
    }
    
    public function getValue(): string
    {
        return $this->value;
    }
    
    public function equals(ProductSku $other): bool
    {
        return $this->value === $other->value;
    }
}

// Domain/Repository/ProductRepositoryInterface.php
interface ProductRepositoryInterface
{
    public function findById(ProductId $id): ?Product;
    public function findBySku(ProductSku $sku): ?Product;
    public function findByCategory(CategoryId $categoryId): ProductCollection;
    public function search(ProductSearchCriteria $criteria): ProductCollection;
    public function save(Product $product): void;
    public function delete(ProductId $id): void;
}
```

### Application Layer

```php
// App/UseCase/Product/GetProductDetailsUseCase.php
class GetProductDetailsUseCase
{
    public function __construct(
        private ProductRepositoryInterface $productRepository,
        private CategoryRepositoryInterface $categoryRepository,
        private ReviewRepositoryInterface $reviewRepository,
        private RecommendationServiceInterface $recommendationService
    ) {}
    
    #[Log("Getting product details")]
    #[Cacheable(key: "product_details_{id}", ttl: 1800)]
    #[Monitor(metric: "product_details_fetch")]
    public function execute(GetProductDetailsRequest $request): GetProductDetailsResponse
    {
        $product = $this->productRepository->findById($request->getProductId());
        
        if (!$product) {
            throw new ProductNotFoundException("Product not found: " . $request->getProductId());
        }
        
        // Get additional data
        $category = $this->categoryRepository->findById($product->getCategoryId());
        $reviews = $this->reviewRepository->findByProductId($product->getId());
        $recommendations = $this->recommendationService->getRelatedProducts($product->getId());
        
        return new GetProductDetailsResponse(
            product: $product,
            category: $category,
            reviews: $reviews,
            recommendations: $recommendations,
            averageRating: $reviews->getAverageRating(),
            totalReviews: $reviews->count()
        );
    }
}

// App/UseCase/Product/SearchProductsUseCase.php
class SearchProductsUseCase
{
    public function __construct(
        private ProductRepositoryInterface $productRepository,
        private ProductSearchServiceInterface $searchService
    ) {}
    
    #[Log("Searching products")]
    #[Cacheable(key: "product_search_{query}_{filters}_{page}", ttl: 900)]
    #[Monitor(metric: "product_search")]
    public function execute(SearchProductsRequest $request): SearchProductsResponse
    {
        $criteria = ProductSearchCriteria::create(
            query: $request->getQuery(),
            category: $request->getCategoryId(),
            priceRange: $request->getPriceRange(),
            filters: $request->getFilters(),
            sortBy: $request->getSortBy(),
            page: $request->getPage(),
            limit: $request->getLimit()
        );
        
        // Use search service for complex queries
        if ($request->hasComplexFilters()) {
            $results = $this->searchService->search($criteria);
        } else {
            // Use repository for simple queries
            $results = $this->productRepository->search($criteria);
        }
        
        return new SearchProductsResponse(
            products: $results->getProducts(),
            totalCount: $results->getTotalCount(),
            facets: $results->getFacets(),
            pagination: $results->getPagination()
        );
    }
}
```

### Infrastructure Layer

```php
// App/Infrastructure/Repository/MySQLProductRepository.php
class MySQLProductRepository implements ProductRepositoryInterface
{
    public function __construct(
        private PDO $database,
        private ProductMapper $mapper
    ) {}
    
    public function findById(ProductId $id): ?Product
    {
        $stmt = $this->database->prepare('
            SELECT p.*, c.name as category_name 
            FROM products p 
            JOIN categories c ON p.category_id = c.id 
            WHERE p.id = ?
        ');
        
        $stmt->execute([$id->getValue()]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        
        return $data ? $this->mapper->mapFromArray($data) : null;
    }
    
    public function search(ProductSearchCriteria $criteria): ProductCollection
    {
        $query = $this->buildSearchQuery($criteria);
        $stmt = $this->database->prepare($query->getSql());
        $stmt->execute($query->getParameters());
        
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $products = array_map([$this->mapper, 'mapFromArray'], $results);
        
        return new ProductCollection($products);
    }
    
    #[CacheEvict(tags: ["products"])]
    public function save(Product $product): void
    {
        $data = $this->mapper->mapToArray($product);
        
        if ($this->exists($product->getId())) {
            $this->update($data);
        } else {
            $this->insert($data);
        }
    }
    
    private function buildSearchQuery(ProductSearchCriteria $criteria): SearchQuery
    {
        $builder = new SearchQueryBuilder();
        
        $builder->select('p.*, c.name as category_name')
                ->from('products p')
                ->join('categories c', 'p.category_id = c.id')
                ->where('p.is_active = 1');
        
        if ($criteria->hasQuery()) {
            $builder->where('(p.name LIKE ? OR p.description LIKE ?)')
                   ->addParameter('%' . $criteria->getQuery() . '%')
                   ->addParameter('%' . $criteria->getQuery() . '%');
        }
        
        if ($criteria->hasCategoryFilter()) {
            $builder->where('p.category_id = ?')
                   ->addParameter($criteria->getCategoryId()->getValue());
        }
        
        if ($criteria->hasPriceRange()) {
            $range = $criteria->getPriceRange();
            $builder->where('p.price BETWEEN ? AND ?')
                   ->addParameter($range->getMin()->getAmount())
                   ->addParameter($range->getMax()->getAmount());
        }
        
        $builder->orderBy($criteria->getSortBy())
               ->limit($criteria->getLimit())
               ->offset($criteria->getOffset());
        
        return $builder->build();
    }
}

// App/Infrastructure/External/ElasticsearchProductSearchService.php
class ElasticsearchProductSearchService implements ProductSearchServiceInterface
{
    public function __construct(
        private ElasticsearchClient $client,
        private ProductMapper $mapper
    ) {}
    
    #[Monitor(metric: "elasticsearch_search")]
    public function search(ProductSearchCriteria $criteria): ProductSearchResult
    {
        $query = $this->buildElasticsearchQuery($criteria);
        
        $response = $this->client->search([
            'index' => 'products',
            'body' => $query
        ]);
        
        $products = $this->mapSearchResults($response['hits']['hits']);
        $facets = $this->mapAggregations($response['aggregations'] ?? []);
        
        return new ProductSearchResult(
            products: $products,
            totalCount: $response['hits']['total']['value'],
            facets: $facets
        );
    }
    
    private function buildElasticsearchQuery(ProductSearchCriteria $criteria): array
    {
        $query = [
            'query' => [
                'bool' => [
                    'must' => [],
                    'filter' => []
                ]
            ],
            'aggs' => [
                'categories' => [
                    'terms' => ['field' => 'category_id']
                ],
                'price_ranges' => [
                    'range' => [
                        'field' => 'price',
                        'ranges' => [
                            ['to' => 50],
                            ['from' => 50, 'to' => 100],
                            ['from' => 100, 'to' => 200],
                            ['from' => 200]
                        ]
                    ]
                ]
            ]
        ];
        
        if ($criteria->hasQuery()) {
            $query['query']['bool']['must'][] = [
                'multi_match' => [
                    'query' => $criteria->getQuery(),
                    'fields' => ['name^2', 'description', 'tags']
                ]
            ];
        }
        
        if ($criteria->hasCategoryFilter()) {
            $query['query']['bool']['filter'][] = [
                'term' => ['category_id' => $criteria->getCategoryId()->getValue()]
            ];
        }
        
        return $query;
    }
}
```

### Presentation Layer

```php
// App/Controller/Api/ProductController.php
class ProductController
{
    public function __construct(
        private GetProductDetailsUseCase $getProductDetailsUseCase,
        private SearchProductsUseCase $searchProductsUseCase,
        private UpdateProductUseCase $updateProductUseCase
    ) {}
    
    #[Route('/api/products/{id}', methods: ['GET'])]
    #[RequiresPermission('PRODUCT_VIEW')]
    public function show(int $id): JsonResponse
    {
        try {
            $request = new GetProductDetailsRequest(new ProductId($id));
            $response = $this->getProductDetailsUseCase->execute($request);
            
            return new JsonResponse([
                'success' => true,
                'data' => [
                    'product' => $this->serializeProduct($response->getProduct()),
                    'category' => $this->serializeCategory($response->getCategory()),
                    'reviews' => $this->serializeReviews($response->getReviews()),
                    'recommendations' => $this->serializeProducts($response->getRecommendations()),
                    'rating' => $response->getAverageRating(),
                    'review_count' => $response->getTotalReviews()
                ]
            ]);
            
        } catch (ProductNotFoundException $e) {
            return new JsonResponse([
                'success' => false,
                'error' => 'Product not found'
            ], 404);
        }
    }
    
    #[Route('/api/products/search', methods: ['GET'])]
    public function search(Request $request): JsonResponse
    {
        $searchRequest = new SearchProductsRequest(
            query: $request->query->get('q', ''),
            categoryId: $request->query->get('category') ? new CategoryId($request->query->get('category')) : null,
            priceRange: $this->parsePriceRange($request->query->get('price')),
            filters: $request->query->all('filters'),
            sortBy: $request->query->get('sort', 'relevance'),
            page: (int) $request->query->get('page', 1),
            limit: min((int) $request->query->get('limit', 20), 100)
        );
        
        $response = $this->searchProductsUseCase->execute($searchRequest);
        
        return new JsonResponse([
            'success' => true,
            'data' => [
                'products' => $this->serializeProducts($response->getProducts()),
                'total' => $response->getTotalCount(),
                'facets' => $response->getFacets(),
                'pagination' => $response->getPagination()
            ]
        ]);
    }
    
    #[Route('/api/products/{id}', methods: ['PUT'])]
    #[RequiresPermission('PRODUCT_EDIT')]
    #[Transactional]
    public function update(int $id, Request $request): JsonResponse
    {
        try {
            $updateRequest = new UpdateProductRequest(
                productId: new ProductId($id),
                name: $request->json->get('name'),
                description: $request->json->get('description'),
                price: $request->json->get('price') ? Money::fromString($request->json->get('price')) : null,
                categoryId: $request->json->get('category_id') ? new CategoryId($request->json->get('category_id')) : null
            );
            
            $response = $this->updateProductUseCase->execute($updateRequest);
            
            return new JsonResponse([
                'success' => true,
                'data' => $this->serializeProduct($response->getProduct())
            ]);
            
        } catch (ProductNotFoundException $e) {
            return new JsonResponse([
                'success' => false,
                'error' => 'Product not found'
            ], 404);
        } catch (ValidationException $e) {
            return new JsonResponse([
                'success' => false,
                'error' => 'Validation failed',
                'details' => $e->getErrors()
            ], 400);
        }
    }
}
```

### Module Configuration

```php
// Module/AppModule.php
class AppModule extends AbstractModule
{
    protected function configure(): void
    {
        // Install other modules
        $this->install(new DatabaseModule());
        $this->install(new CacheModule());
        $this->install(new ExternalServicesModule());
        $this->install(new AopModule());
        
        // Bind repositories
        $this->bind(ProductRepositoryInterface::class)->to(MySQLProductRepository::class);
        $this->bind(OrderRepositoryInterface::class)->to(MySQLOrderRepository::class);
        $this->bind(UserRepositoryInterface::class)->to(MySQLUserRepository::class);
        
        // Bind services
        $this->bind(ProductSearchServiceInterface::class)->to(ElasticsearchProductSearchService::class);
        $this->bind(PaymentServiceInterface::class)->to(StripePaymentService::class);
        $this->bind(EmailServiceInterface::class)->to(SendGridEmailService::class);
        
        // Bind use cases
        $this->bind(GetProductDetailsUseCase::class);
        $this->bind(SearchProductsUseCase::class);
        $this->bind(ProcessOrderUseCase::class);
        
        // Configure scopes
        $this->bind(SecurityContextInterface::class)->in(RequestScoped::class);
        $this->bind(CartInterface::class)->in(SessionScoped::class);
    }
}

// Module/DatabaseModule.php
class DatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        // Database configuration
        $this->bind(PDO::class)->toProvider(DatabaseProvider::class)->in(Singleton::class);
        
        // Mappers
        $this->bind(ProductMapper::class)->in(Singleton::class);
        $this->bind(OrderMapper::class)->in(Singleton::class);
        $this->bind(UserMapper::class)->in(Singleton::class);
    }
}

// Module/AopModule.php
class AopModule extends AbstractModule
{
    protected function configure(): void
    {
        // Logging
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Log::class),
            [LoggingInterceptor::class]
        );
        
        // Security
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(RequiresPermission::class),
            [SecurityInterceptor::class]
        );
        
        // Caching
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->logicalOr(
                $this->matcher->annotatedWith(Cacheable::class),
                $this->matcher->annotatedWith(CacheEvict::class)
            ),
            [CachingInterceptor::class]
        );
        
        // Transactions
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Transactional::class),
            [TransactionalInterceptor::class]
        );
        
        // Monitoring
        $this->bindInterceptor(
            $this->matcher->any(),
            $this->matcher->annotatedWith(Monitor::class),
            [PerformanceInterceptor::class]
        );
    }
}
```

## 🧪 Testing Strategy

```php
// tests/Unit/UseCase/Product/GetProductDetailsUseCaseTest.php
class GetProductDetailsUseCaseTest extends TestCase
{
    private ProductRepositoryInterface $productRepository;
    private CategoryRepositoryInterface $categoryRepository;
    private ReviewRepositoryInterface $reviewRepository;
    private RecommendationServiceInterface $recommendationService;
    private GetProductDetailsUseCase $useCase;
    
    protected function setUp(): void
    {
        $this->productRepository = $this->createMock(ProductRepositoryInterface::class);
        $this->categoryRepository = $this->createMock(CategoryRepositoryInterface::class);
        $this->reviewRepository = $this->createMock(ReviewRepositoryInterface::class);
        $this->recommendationService = $this->createMock(RecommendationServiceInterface::class);
        
        $this->useCase = new GetProductDetailsUseCase(
            $this->productRepository,
            $this->categoryRepository,
            $this->reviewRepository,
            $this->recommendationService
        );
    }
    
    public function testExecuteReturnsProductDetails(): void
    {
        // Arrange
        $productId = new ProductId(1);
        $product = $this->createProduct($productId);
        $category = $this->createCategory();
        $reviews = new ReviewCollection([]);
        $recommendations = new ProductCollection([]);
        
        $this->productRepository
            ->expects($this->once())
            ->method('findById')
            ->with($productId)
            ->willReturn($product);
        
        $this->categoryRepository
            ->expects($this->once())
            ->method('findById')
            ->with($product->getCategoryId())
            ->willReturn($category);
        
        $this->reviewRepository
            ->expects($this->once())
            ->method('findByProductId')
            ->with($productId)
            ->willReturn($reviews);
        
        $this->recommendationService
            ->expects($this->once())
            ->method('getRelatedProducts')
            ->with($productId)
            ->willReturn($recommendations);
        
        $request = new GetProductDetailsRequest($productId);
        
        // Act
        $response = $this->useCase->execute($request);
        
        // Assert
        $this->assertSame($product, $response->getProduct());
        $this->assertSame($category, $response->getCategory());
        $this->assertSame($reviews, $response->getReviews());
        $this->assertSame($recommendations, $response->getRecommendations());
    }
    
    public function testExecuteThrowsExceptionWhenProductNotFound(): void
    {
        // Arrange
        $productId = new ProductId(999);
        
        $this->productRepository
            ->expects($this->once())
            ->method('findById')
            ->with($productId)
            ->willReturn(null);
        
        $request = new GetProductDetailsRequest($productId);
        
        // Act & Assert
        $this->expectException(ProductNotFoundException::class);
        $this->useCase->execute($request);
    }
}

// tests/Integration/Repository/MySQLProductRepositoryTest.php
class MySQLProductRepositoryTest extends DatabaseTestCase
{
    private MySQLProductRepository $repository;
    
    protected function setUp(): void
    {
        parent::setUp();
        
        $this->repository = new MySQLProductRepository(
            $this->getDatabase(),
            new ProductMapper()
        );
    }
    
    public function testFindByIdReturnsProduct(): void
    {
        // Arrange
        $productData = $this->insertTestProduct();
        $productId = new ProductId($productData['id']);
        
        // Act
        $product = $this->repository->findById($productId);
        
        // Assert
        $this->assertNotNull($product);
        $this->assertEquals($productId, $product->getId());
        $this->assertEquals($productData['name'], $product->getName());
    }
}
```

## 🚀 Performance Optimizations

### 1. Lazy Loading
```php
class Product
{
    private ?ReviewCollection $reviews = null;
    
    public function getReviews(): ReviewCollection
    {
        if ($this->reviews === null) {
            $this->reviews = $this->reviewRepository->findByProductId($this->id);
        }
        return $this->reviews;
    }
}
```

### 2. Query Optimization
```php
class ProductRepository
{
    #[Cacheable(key: "featured_products", ttl: 3600)]
    public function findFeaturedProducts(): ProductCollection
    {
        // Optimized query with proper indexing
        $query = "
            SELECT p.*, c.name as category_name,
                   AVG(r.rating) as avg_rating,
                   COUNT(r.id) as review_count
            FROM products p
            JOIN categories c ON p.category_id = c.id
            LEFT JOIN reviews r ON p.id = r.product_id
            WHERE p.is_featured = 1 AND p.is_active = 1
            GROUP BY p.id
            ORDER BY p.featured_order ASC
            LIMIT 20
        ";
        
        return $this->executeQuery($query);
    }
}
```

### 3. Cache Strategy
```php
class ProductService
{
    #[Cacheable(key: "product_details_{id}", ttl: 1800, tags: ["products"])]
    public function getProductDetails(ProductId $id): ProductDetails
    {
        // Cache product details for 30 minutes
    }
    
    #[CacheEvict(tags: ["products"])]
    public function updateProduct(Product $product): void
    {
        // Invalidate all product-related cache
    }
}
```

## 🎯 Key Benefits Achieved

1. **Maintainability**: Clear separation of concerns makes code easy to modify
2. **Testability**: Dependency injection enables comprehensive testing
3. **Scalability**: Layered architecture supports growth
4. **Performance**: Caching and optimization strategies
5. **Security**: AOP-based authentication and authorization
6. **Monitoring**: Built-in performance and error tracking
7. **Flexibility**: Easy to swap implementations

## 📚 Next Steps

Explore other real-world examples:
- **[Data Access Layer](../data-access/)**: Advanced repository patterns
- **[Authentication System](../authentication/)**: Security implementation
- **[Logging & Audit](../logging-audit/)**: Comprehensive logging strategy

## 💡 Key Takeaways

- **Clean Architecture** with Ray.Di creates maintainable applications
- **Dependency Injection** enables flexible, testable code
- **AOP** handles cross-cutting concerns elegantly
- **Proper layering** separates technical and business concerns
- **Testing strategy** ensures reliability and confidence

---

This example demonstrates how Ray.Di enables building robust, maintainable web applications following best practices and design principles!