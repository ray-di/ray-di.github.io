---
layout: docs-ja
title: データアクセス層
category: Manual
permalink: /manuals/1.0/ja/tutorial/06-real-world-examples/data-access-layer.html
---

# データアクセス層

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diを使った効率的なデータアクセス層の設計
- リポジトリパターンとDAOパターンの実装
- 複数のデータソースとの統合
- コネクションプーリングとトランザクション管理
- データベースクエリの最適化とキャッシュ戦略

## データアクセス層の設計原則

### 1. レイヤー分離とインターフェース設計

```php
// ドメイン層のインターフェース
interface ProductRepositoryInterface
{
    public function findById(int $id): ?Product;
    public function findByCategory(string $category): array;
    public function findWithFilters(ProductSearchCriteria $criteria): array;
    public function save(Product $product): void;
    public function delete(int $id): void;
    public function findPopular(int $limit = 10): array;
    public function findByPriceRange(float $min, float $max): array;
}

interface UserRepositoryInterface
{
    public function findById(int $id): ?User;
    public function findByEmail(string $email): ?User;
    public function findActiveUsers(): array;
    public function save(User $user): void;
    public function delete(int $id): void;
    public function updateLastLogin(int $userId): void;
}

interface OrderRepositoryInterface
{
    public function findById(int $id): ?Order;
    public function findByCustomerId(int $customerId): array;
    public function findByStatus(OrderStatus $status): array;
    public function save(Order $order): void;
    public function updateStatus(int $orderId, OrderStatus $status): void;
    public function findRecentOrders(int $limit = 50): array;
}
```

### 2. データベース抽象化インターフェース

```php
interface DatabaseInterface
{
    public function query(string $sql, array $params = []): array;
    public function execute(string $sql, array $params = []): int;
    public function beginTransaction(): void;
    public function commit(): void;
    public function rollback(): void;
    public function lastInsertId(): int;
    public function prepare(string $sql): PreparedStatementInterface;
}

interface PreparedStatementInterface
{
    public function bind(string $param, mixed $value, int $type = null): void;
    public function execute(): bool;
    public function fetchAll(): array;
    public function fetchOne(): ?array;
    public function rowCount(): int;
}

interface ConnectionPoolInterface
{
    public function getConnection(): DatabaseInterface;
    public function releaseConnection(DatabaseInterface $connection): void;
    public function getActiveConnections(): int;
    public function getAvailableConnections(): int;
}
```

## 具体的なリポジトリ実装

### 1. 基本的なリポジトリ実装

```php
class MySQLProductRepository implements ProductRepositoryInterface
{
    public function __construct(
        private DatabaseInterface $database,
        private CacheInterface $cache,
        private LoggerInterface $logger
    ) {}

    public function findById(int $id): ?Product
    {
        $cacheKey = "product:{$id}";
        $cached = $this->cache->get($cacheKey);
        
        if ($cached !== null) {
            return $this->hydrateProduct($cached);
        }

        $sql = "
            SELECT p.*, c.name as category_name, c.slug as category_slug
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            WHERE p.id = ? AND p.deleted_at IS NULL
        ";

        $result = $this->database->query($sql, [$id]);
        
        if (empty($result)) {
            return null;
        }

        $productData = $result[0];
        $product = $this->hydrateProduct($productData);
        
        // キャッシュに保存（5分間）
        $this->cache->set($cacheKey, $productData, 300);
        
        return $product;
    }

    public function findByCategory(string $category): array
    {
        $sql = "
            SELECT p.*, c.name as category_name, c.slug as category_slug
            FROM products p
            INNER JOIN categories c ON p.category_id = c.id
            WHERE c.slug = ? AND p.deleted_at IS NULL
            ORDER BY p.created_at DESC
        ";

        $results = $this->database->query($sql, [$category]);
        
        return array_map([$this, 'hydrateProduct'], $results);
    }

    public function findWithFilters(ProductSearchCriteria $criteria): array
    {
        $sql = "SELECT p.*, c.name as category_name, c.slug as category_slug
                FROM products p
                LEFT JOIN categories c ON p.category_id = c.id
                WHERE p.deleted_at IS NULL";
        
        $params = [];
        
        if ($criteria->getCategoryId() !== null) {
            $sql .= " AND p.category_id = ?";
            $params[] = $criteria->getCategoryId();
        }
        
        if ($criteria->getMinPrice() !== null) {
            $sql .= " AND p.price >= ?";
            $params[] = $criteria->getMinPrice();
        }
        
        if ($criteria->getMaxPrice() !== null) {
            $sql .= " AND p.price <= ?";
            $params[] = $criteria->getMaxPrice();
        }
        
        if ($criteria->getSearchTerm() !== null) {
            $sql .= " AND (p.name LIKE ? OR p.description LIKE ?)";
            $searchTerm = '%' . $criteria->getSearchTerm() . '%';
            $params[] = $searchTerm;
            $params[] = $searchTerm;
        }
        
        // ソート
        $sortBy = $criteria->getSortBy() ?: 'created_at';
        $sortOrder = $criteria->getSortOrder() ?: 'DESC';
        $sql .= " ORDER BY p.{$sortBy} {$sortOrder}";
        
        // ページネーション
        if ($criteria->getLimit() !== null) {
            $sql .= " LIMIT ?";
            $params[] = $criteria->getLimit();
            
            if ($criteria->getOffset() !== null) {
                $sql .= " OFFSET ?";
                $params[] = $criteria->getOffset();
            }
        }

        $results = $this->database->query($sql, $params);
        
        return array_map([$this, 'hydrateProduct'], $results);
    }

    public function save(Product $product): void
    {
        if ($product->getId() === null) {
            $this->insert($product);
        } else {
            $this->update($product);
        }
        
        // キャッシュの無効化
        $this->cache->delete("product:{$product->getId()}");
        $this->cache->delete("products:category:{$product->getCategory()->getSlug()}");
    }

    private function insert(Product $product): void
    {
        $sql = "
            INSERT INTO products (name, description, price, category_id, stock_quantity, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, NOW(), NOW())
        ";

        $params = [
            $product->getName(),
            $product->getDescription(),
            $product->getPrice(),
            $product->getCategory()->getId(),
            $product->getStockQuantity()
        ];

        $this->database->execute($sql, $params);
        
        $id = $this->database->lastInsertId();
        $product->setId($id);

        $this->logger->info("Product created", [
            'product_id' => $id,
            'name' => $product->getName()
        ]);
    }

    private function update(Product $product): void
    {
        $sql = "
            UPDATE products 
            SET name = ?, description = ?, price = ?, 
                category_id = ?, stock_quantity = ?, updated_at = NOW()
            WHERE id = ?
        ";

        $params = [
            $product->getName(),
            $product->getDescription(),
            $product->getPrice(),
            $product->getCategory()->getId(),
            $product->getStockQuantity(),
            $product->getId()
        ];

        $affected = $this->database->execute($sql, $params);
        
        if ($affected === 0) {
            throw new EntityNotFoundException("Product not found: {$product->getId()}");
        }

        $this->logger->info("Product updated", [
            'product_id' => $product->getId(),
            'name' => $product->getName()
        ]);
    }

    public function delete(int $id): void
    {
        // ソフトデリート
        $sql = "UPDATE products SET deleted_at = NOW() WHERE id = ?";
        $affected = $this->database->execute($sql, [$id]);
        
        if ($affected === 0) {
            throw new EntityNotFoundException("Product not found: {$id}");
        }

        // キャッシュの無効化
        $this->cache->delete("product:{$id}");
        
        $this->logger->info("Product deleted", ['product_id' => $id]);
    }

    public function findPopular(int $limit = 10): array
    {
        $cacheKey = "products:popular:{$limit}";
        $cached = $this->cache->get($cacheKey);
        
        if ($cached !== null) {
            return array_map([$this, 'hydrateProduct'], $cached);
        }

        $sql = "
            SELECT p.*, c.name as category_name, c.slug as category_slug,
                   COUNT(oi.product_id) as order_count
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            LEFT JOIN order_items oi ON p.id = oi.product_id
            INNER JOIN orders o ON oi.order_id = o.id
            WHERE p.deleted_at IS NULL 
            AND o.status = 'completed'
            AND o.created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
            GROUP BY p.id
            ORDER BY order_count DESC
            LIMIT ?
        ";

        $results = $this->database->query($sql, [$limit]);
        
        // キャッシュに保存（1時間）
        $this->cache->set($cacheKey, $results, 3600);
        
        return array_map([$this, 'hydrateProduct'], $results);
    }

    public function findByPriceRange(float $min, float $max): array
    {
        $sql = "
            SELECT p.*, c.name as category_name, c.slug as category_slug
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            WHERE p.price BETWEEN ? AND ? 
            AND p.deleted_at IS NULL
            ORDER BY p.price ASC
        ";

        $results = $this->database->query($sql, [$min, $max]);
        
        return array_map([$this, 'hydrateProduct'], $results);
    }

    private function hydrateProduct(array $data): Product
    {
        $category = new Category(
            $data['category_id'],
            $data['category_name'],
            $data['category_slug']
        );

        return new Product(
            $data['id'],
            $data['name'],
            $data['description'],
            $data['price'],
            $category,
            $data['stock_quantity'],
            new DateTime($data['created_at']),
            new DateTime($data['updated_at'])
        );
    }
}
```

### 2. 複雑なクエリを持つリポジトリ

```php
class MySQLOrderRepository implements OrderRepositoryInterface
{
    public function __construct(
        private DatabaseInterface $database,
        private CacheInterface $cache,
        private LoggerInterface $logger
    ) {}

    public function findById(int $id): ?Order
    {
        $sql = "
            SELECT o.*, u.email as customer_email, u.name as customer_name
            FROM orders o
            LEFT JOIN users u ON o.customer_id = u.id
            WHERE o.id = ?
        ";

        $result = $this->database->query($sql, [$id]);
        
        if (empty($result)) {
            return null;
        }

        $orderData = $result[0];
        $order = $this->hydrateOrder($orderData);
        
        // 注文アイテムを取得
        $items = $this->findOrderItems($id);
        foreach ($items as $item) {
            $order->addItem($item);
        }
        
        return $order;
    }

    public function findByCustomerId(int $customerId): array
    {
        $sql = "
            SELECT o.*, u.email as customer_email, u.name as customer_name
            FROM orders o
            LEFT JOIN users u ON o.customer_id = u.id
            WHERE o.customer_id = ?
            ORDER BY o.created_at DESC
        ";

        $results = $this->database->query($sql, [$customerId]);
        $orders = [];
        
        foreach ($results as $orderData) {
            $order = $this->hydrateOrder($orderData);
            $items = $this->findOrderItems($order->getId());
            
            foreach ($items as $item) {
                $order->addItem($item);
            }
            
            $orders[] = $order;
        }
        
        return $orders;
    }

    public function findByStatus(OrderStatus $status): array
    {
        $sql = "
            SELECT o.*, u.email as customer_email, u.name as customer_name
            FROM orders o
            LEFT JOIN users u ON o.customer_id = u.id
            WHERE o.status = ?
            ORDER BY o.created_at DESC
        ";

        $results = $this->database->query($sql, [$status->value]);
        $orders = [];
        
        foreach ($results as $orderData) {
            $order = $this->hydrateOrder($orderData);
            $items = $this->findOrderItems($order->getId());
            
            foreach ($items as $item) {
                $order->addItem($item);
            }
            
            $orders[] = $order;
        }
        
        return $orders;
    }

    public function save(Order $order): void
    {
        $this->database->beginTransaction();
        
        try {
            if ($order->getId() === null) {
                $this->insertOrder($order);
            } else {
                $this->updateOrder($order);
            }
            
            // 注文アイテムの保存
            $this->saveOrderItems($order);
            
            $this->database->commit();
            
            $this->logger->info("Order saved", [
                'order_id' => $order->getId(),
                'customer_id' => $order->getCustomerId(),
                'total' => $order->getTotal()
            ]);
            
        } catch (Exception $e) {
            $this->database->rollback();
            $this->logger->error("Failed to save order", [
                'error' => $e->getMessage(),
                'order_id' => $order->getId()
            ]);
            throw $e;
        }
    }

    public function updateStatus(int $orderId, OrderStatus $status): void
    {
        $sql = "UPDATE orders SET status = ?, updated_at = NOW() WHERE id = ?";
        $affected = $this->database->execute($sql, [$status->value, $orderId]);
        
        if ($affected === 0) {
            throw new EntityNotFoundException("Order not found: {$orderId}");
        }

        $this->logger->info("Order status updated", [
            'order_id' => $orderId,
            'status' => $status->value
        ]);
    }

    public function findRecentOrders(int $limit = 50): array
    {
        $cacheKey = "orders:recent:{$limit}";
        $cached = $this->cache->get($cacheKey);
        
        if ($cached !== null) {
            return array_map([$this, 'hydrateOrder'], $cached);
        }

        $sql = "
            SELECT o.*, u.email as customer_email, u.name as customer_name
            FROM orders o
            LEFT JOIN users u ON o.customer_id = u.id
            ORDER BY o.created_at DESC
            LIMIT ?
        ";

        $results = $this->database->query($sql, [$limit]);
        
        // キャッシュに保存（5分間）
        $this->cache->set($cacheKey, $results, 300);
        
        return array_map([$this, 'hydrateOrder'], $results);
    }

    private function insertOrder(Order $order): void
    {
        $sql = "
            INSERT INTO orders (customer_id, total, status, created_at, updated_at)
            VALUES (?, ?, ?, NOW(), NOW())
        ";

        $params = [
            $order->getCustomerId(),
            $order->getTotal(),
            $order->getStatus()->value
        ];

        $this->database->execute($sql, $params);
        $order->setId($this->database->lastInsertId());
    }

    private function updateOrder(Order $order): void
    {
        $sql = "
            UPDATE orders 
            SET customer_id = ?, total = ?, status = ?, updated_at = NOW()
            WHERE id = ?
        ";

        $params = [
            $order->getCustomerId(),
            $order->getTotal(),
            $order->getStatus()->value,
            $order->getId()
        ];

        $affected = $this->database->execute($sql, $params);
        
        if ($affected === 0) {
            throw new EntityNotFoundException("Order not found: {$order->getId()}");
        }
    }

    private function saveOrderItems(Order $order): void
    {
        // 既存のアイテムを削除
        $sql = "DELETE FROM order_items WHERE order_id = ?";
        $this->database->execute($sql, [$order->getId()]);
        
        // 新しいアイテムを挿入
        foreach ($order->getItems() as $item) {
            $sql = "
                INSERT INTO order_items (order_id, product_id, quantity, price)
                VALUES (?, ?, ?, ?)
            ";
            
            $params = [
                $order->getId(),
                $item->getProductId(),
                $item->getQuantity(),
                $item->getPrice()
            ];
            
            $this->database->execute($sql, $params);
        }
    }

    private function findOrderItems(int $orderId): array
    {
        $sql = "
            SELECT oi.*, p.name as product_name
            FROM order_items oi
            LEFT JOIN products p ON oi.product_id = p.id
            WHERE oi.order_id = ?
            ORDER BY oi.id
        ";

        $results = $this->database->query($sql, [$orderId]);
        $items = [];
        
        foreach ($results as $itemData) {
            $items[] = new OrderItem(
                $itemData['id'],
                $itemData['product_id'],
                $itemData['product_name'],
                $itemData['quantity'],
                $itemData['price']
            );
        }
        
        return $items;
    }

    private function hydrateOrder(array $data): Order
    {
        return new Order(
            $data['id'],
            $data['customer_id'],
            $data['customer_name'],
            $data['customer_email'],
            $data['total'],
            OrderStatus::from($data['status']),
            new DateTime($data['created_at']),
            new DateTime($data['updated_at'])
        );
    }
}
```

## 複数データソースの統合

### 1. 複数データベースの管理

```php
class MultiDatabaseModule extends AbstractModule
{
    protected function configure(): void
    {
        // メインデータベース
        $this->bind(DatabaseInterface::class)
            ->annotatedWith(Named::class, 'main')
            ->to(MySQLDatabase::class);
        
        // レポート用データベース
        $this->bind(DatabaseInterface::class)
            ->annotatedWith(Named::class, 'reporting')
            ->to(PostgreSQLDatabase::class);
        
        // キャッシュデータベース
        $this->bind(DatabaseInterface::class)
            ->annotatedWith(Named::class, 'cache')
            ->to(RedisDatabase::class);
        
        // リポジトリの束縛
        $this->bind(ProductRepositoryInterface::class)
            ->to(MySQLProductRepository::class);
        
        $this->bind(ReportRepositoryInterface::class)
            ->to(PostgreSQLReportRepository::class);
        
        $this->bind(CacheRepositoryInterface::class)
            ->to(RedisCacheRepository::class);
    }
}

class HybridProductRepository implements ProductRepositoryInterface
{
    public function __construct(
        #[Named('main')] private DatabaseInterface $mainDb,
        #[Named('reporting')] private DatabaseInterface $reportingDb,
        #[Named('cache')] private DatabaseInterface $cacheDb,
        private LoggerInterface $logger
    ) {}

    public function findById(int $id): ?Product
    {
        // まずキャッシュから検索
        $cached = $this->findFromCache($id);
        if ($cached !== null) {
            return $cached;
        }
        
        // メインデータベースから取得
        $product = $this->findFromMain($id);
        
        if ($product !== null) {
            // キャッシュに保存
            $this->saveToCache($product);
        }
        
        return $product;
    }

    public function findWithFilters(ProductSearchCriteria $criteria): array
    {
        // 複雑な分析クエリはレポートデータベースを使用
        if ($criteria->isComplexAnalytics()) {
            return $this->findFromReporting($criteria);
        }
        
        // 通常のクエリはメインデータベースを使用
        return $this->findFromMain($criteria);
    }

    private function findFromCache(int $id): ?Product
    {
        $sql = "GET product:{$id}";
        $result = $this->cacheDb->query($sql);
        
        if (!empty($result)) {
            return $this->hydrateProduct($result[0]);
        }
        
        return null;
    }

    private function findFromMain(int $id): ?Product
    {
        $sql = "SELECT * FROM products WHERE id = ? AND deleted_at IS NULL";
        $result = $this->mainDb->query($sql, [$id]);
        
        if (!empty($result)) {
            return $this->hydrateProduct($result[0]);
        }
        
        return null;
    }

    private function findFromReporting(ProductSearchCriteria $criteria): array
    {
        // レポートデータベースで複雑な分析クエリを実行
        $sql = "
            SELECT p.*, 
                   AVG(r.rating) as avg_rating,
                   COUNT(o.id) as total_orders,
                   SUM(oi.quantity) as total_sold
            FROM products p
            LEFT JOIN reviews r ON p.id = r.product_id
            LEFT JOIN order_items oi ON p.id = oi.product_id
            LEFT JOIN orders o ON oi.order_id = o.id
            WHERE p.deleted_at IS NULL
            GROUP BY p.id
            HAVING avg_rating >= ? AND total_orders >= ?
            ORDER BY total_sold DESC
        ";
        
        $results = $this->reportingDb->query($sql, [
            $criteria->getMinRating(),
            $criteria->getMinOrderCount()
        ]);
        
        return array_map([$this, 'hydrateProduct'], $results);
    }

    private function saveToCache(Product $product): void
    {
        $sql = "SETEX product:{$product->getId()} 300 ?";
        $this->cacheDb->execute($sql, [json_encode($product->toArray())]);
    }
}
```

### 2. 読み取り専用レプリカの活用

```php
class ReadWriteSplitRepository implements ProductRepositoryInterface
{
    public function __construct(
        #[Named('master')] private DatabaseInterface $masterDb,
        #[Named('replica')] private DatabaseInterface $replicaDb,
        private LoggerInterface $logger
    ) {}

    public function findById(int $id): ?Product
    {
        // 読み取り専用操作はレプリカを使用
        try {
            $sql = "SELECT * FROM products WHERE id = ? AND deleted_at IS NULL";
            $result = $this->replicaDb->query($sql, [$id]);
            
            if (!empty($result)) {
                return $this->hydrateProduct($result[0]);
            }
            
            return null;
            
        } catch (Exception $e) {
            $this->logger->warning("Replica query failed, falling back to master", [
                'error' => $e->getMessage(),
                'product_id' => $id
            ]);
            
            // レプリカが利用できない場合はマスターを使用
            $result = $this->masterDb->query($sql, [$id]);
            
            if (!empty($result)) {
                return $this->hydrateProduct($result[0]);
            }
            
            return null;
        }
    }

    public function save(Product $product): void
    {
        // 書き込み操作は常にマスターを使用
        if ($product->getId() === null) {
            $this->insert($product);
        } else {
            $this->update($product);
        }
    }

    private function insert(Product $product): void
    {
        $sql = "
            INSERT INTO products (name, description, price, category_id, stock_quantity, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, NOW(), NOW())
        ";

        $params = [
            $product->getName(),
            $product->getDescription(),
            $product->getPrice(),
            $product->getCategory()->getId(),
            $product->getStockQuantity()
        ];

        $this->masterDb->execute($sql, $params);
        $product->setId($this->masterDb->lastInsertId());
    }

    private function update(Product $product): void
    {
        $sql = "
            UPDATE products 
            SET name = ?, description = ?, price = ?, 
                category_id = ?, stock_quantity = ?, updated_at = NOW()
            WHERE id = ?
        ";

        $params = [
            $product->getName(),
            $product->getDescription(),
            $product->getPrice(),
            $product->getCategory()->getId(),
            $product->getStockQuantity(),
            $product->getId()
        ];

        $affected = $this->masterDb->execute($sql, $params);
        
        if ($affected === 0) {
            throw new EntityNotFoundException("Product not found: {$product->getId()}");
        }
    }
}
```

## パフォーマンス最適化

### 1. クエリビルダーとプリペアドステートメント

```php
class OptimizedProductRepository implements ProductRepositoryInterface
{
    public function __construct(
        private DatabaseInterface $database,
        private QueryBuilderInterface $queryBuilder,
        private CacheInterface $cache
    ) {}

    public function findWithFilters(ProductSearchCriteria $criteria): array
    {
        $query = $this->queryBuilder
            ->select([
                'p.id', 'p.name', 'p.description', 'p.price', 'p.stock_quantity',
                'c.name as category_name', 'c.slug as category_slug'
            ])
            ->from('products p')
            ->leftJoin('categories c', 'p.category_id = c.id')
            ->where('p.deleted_at IS NULL');

        // 動的フィルタリング
        if ($criteria->getCategoryId() !== null) {
            $query->andWhere('p.category_id = :category_id')
                  ->setParameter('category_id', $criteria->getCategoryId());
        }

        if ($criteria->getMinPrice() !== null) {
            $query->andWhere('p.price >= :min_price')
                  ->setParameter('min_price', $criteria->getMinPrice());
        }

        if ($criteria->getMaxPrice() !== null) {
            $query->andWhere('p.price <= :max_price')
                  ->setParameter('max_price', $criteria->getMaxPrice());
        }

        if ($criteria->getSearchTerm() !== null) {
            $query->andWhere('(p.name LIKE :search OR p.description LIKE :search)')
                  ->setParameter('search', '%' . $criteria->getSearchTerm() . '%');
        }

        // ソート
        $sortBy = $criteria->getSortBy() ?: 'created_at';
        $sortOrder = $criteria->getSortOrder() ?: 'DESC';
        $query->orderBy("p.{$sortBy}", $sortOrder);

        // ページネーション
        if ($criteria->getLimit() !== null) {
            $query->setMaxResults($criteria->getLimit());
            
            if ($criteria->getOffset() !== null) {
                $query->setFirstResult($criteria->getOffset());
            }
        }

        $results = $query->execute()->fetchAll();
        
        return array_map([$this, 'hydrateProduct'], $results);
    }

    public function findBatchById(array $ids): array
    {
        if (empty($ids)) {
            return [];
        }

        // バッチ処理でN+1問題を回避
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $sql = "
            SELECT p.*, c.name as category_name, c.slug as category_slug
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            WHERE p.id IN ({$placeholders}) AND p.deleted_at IS NULL
        ";

        $results = $this->database->query($sql, $ids);
        $products = [];
        
        foreach ($results as $row) {
            $products[$row['id']] = $this->hydrateProduct($row);
        }
        
        return $products;
    }

    public function findPopularWithCache(int $limit = 10): array
    {
        $cacheKey = "products:popular:{$limit}";
        $cached = $this->cache->get($cacheKey);
        
        if ($cached !== null) {
            return $cached;
        }

        // 複雑な集計クエリを実行
        $sql = "
            SELECT p.*, c.name as category_name, c.slug as category_slug,
                   COALESCE(sales.total_sales, 0) as total_sales,
                   COALESCE(reviews.avg_rating, 0) as avg_rating,
                   COALESCE(reviews.review_count, 0) as review_count
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            LEFT JOIN (
                SELECT oi.product_id, 
                       SUM(oi.quantity) as total_sales
                FROM order_items oi
                INNER JOIN orders o ON oi.order_id = o.id
                WHERE o.status = 'completed' 
                AND o.created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
                GROUP BY oi.product_id
            ) sales ON p.id = sales.product_id
            LEFT JOIN (
                SELECT r.product_id,
                       AVG(r.rating) as avg_rating,
                       COUNT(r.id) as review_count
                FROM reviews r
                WHERE r.created_at > DATE_SUB(NOW(), INTERVAL 90 DAY)
                GROUP BY r.product_id
            ) reviews ON p.id = reviews.product_id
            WHERE p.deleted_at IS NULL
            ORDER BY (
                COALESCE(sales.total_sales, 0) * 0.4 +
                COALESCE(reviews.avg_rating, 0) * 0.3 +
                COALESCE(reviews.review_count, 0) * 0.3
            ) DESC
            LIMIT ?
        ";

        $results = $this->database->query($sql, [$limit]);
        $products = array_map([$this, 'hydrateProduct'], $results);
        
        // キャッシュに保存（30分間）
        $this->cache->set($cacheKey, $products, 1800);
        
        return $products;
    }
}
```

### 2. コネクションプーリング実装

```php
class ConnectionPool implements ConnectionPoolInterface
{
    private array $connections = [];
    private array $usedConnections = [];
    private int $maxConnections;
    private int $minConnections;

    public function __construct(
        private DatabaseConfigInterface $config,
        private LoggerInterface $logger,
        int $maxConnections = 20,
        int $minConnections = 5
    ) {
        $this->maxConnections = $maxConnections;
        $this->minConnections = $minConnections;
        $this->initializePool();
    }

    public function getConnection(): DatabaseInterface
    {
        if (empty($this->connections)) {
            if (count($this->usedConnections) >= $this->maxConnections) {
                throw new ConnectionPoolException('Connection pool exhausted');
            }
            
            $connection = $this->createConnection();
        } else {
            $connection = array_pop($this->connections);
        }

        $connectionId = spl_object_hash($connection);
        $this->usedConnections[$connectionId] = $connection;

        $this->logger->debug("Connection acquired", [
            'connection_id' => $connectionId,
            'active_connections' => count($this->usedConnections),
            'available_connections' => count($this->connections)
        ]);

        return $connection;
    }

    public function releaseConnection(DatabaseInterface $connection): void
    {
        $connectionId = spl_object_hash($connection);
        
        if (!isset($this->usedConnections[$connectionId])) {
            throw new ConnectionPoolException('Connection not found in pool');
        }

        unset($this->usedConnections[$connectionId]);
        
        // コネクションの健全性チェック
        if ($this->isConnectionHealthy($connection)) {
            $this->connections[] = $connection;
        } else {
            $this->logger->warning("Unhealthy connection discarded", [
                'connection_id' => $connectionId
            ]);
        }

        $this->logger->debug("Connection released", [
            'connection_id' => $connectionId,
            'active_connections' => count($this->usedConnections),
            'available_connections' => count($this->connections)
        ]);
    }

    public function getActiveConnections(): int
    {
        return count($this->usedConnections);
    }

    public function getAvailableConnections(): int
    {
        return count($this->connections);
    }

    private function initializePool(): void
    {
        for ($i = 0; $i < $this->minConnections; $i++) {
            $this->connections[] = $this->createConnection();
        }
    }

    private function createConnection(): DatabaseInterface
    {
        return new MySQLDatabase($this->config);
    }

    private function isConnectionHealthy(DatabaseInterface $connection): bool
    {
        try {
            $connection->query('SELECT 1');
            return true;
        } catch (Exception $e) {
            return false;
        }
    }
}

class PooledRepositoryModule extends AbstractModule
{
    protected function configure(): void
    {
        // コネクションプールの設定
        $this->bind(ConnectionPoolInterface::class)
            ->to(ConnectionPool::class)
            ->in(Singleton::class);

        // プールを使用するデータベース実装
        $this->bind(DatabaseInterface::class)
            ->to(PooledDatabase::class);

        // リポジトリの束縛
        $this->bind(ProductRepositoryInterface::class)
            ->to(OptimizedProductRepository::class);
    }
}
```

## 統合モジュールの設定

### 1. 包括的なデータアクセスモジュール

```php
class DataAccessModule extends AbstractModule
{
    protected function configure(): void
    {
        // データベース設定
        $this->bind(DatabaseConfigInterface::class)
            ->toInstance(new DatabaseConfig([
                'host' => $_ENV['DB_HOST'] ?? 'localhost',
                'port' => $_ENV['DB_PORT'] ?? 3306,
                'database' => $_ENV['DB_NAME'] ?? 'shopsmart',
                'username' => $_ENV['DB_USERNAME'] ?? 'root',
                'password' => $_ENV['DB_PASSWORD'] ?? '',
                'charset' => 'utf8mb4',
                'options' => [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false,
                    PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4"
                ]
            ]));

        // コネクションプール
        $this->bind(ConnectionPoolInterface::class)
            ->to(ConnectionPool::class)
            ->in(Singleton::class);

        // データベース接続
        $this->bind(DatabaseInterface::class)
            ->to(PooledDatabase::class);

        // クエリビルダー
        $this->bind(QueryBuilderInterface::class)
            ->to(QueryBuilder::class);

        // リポジトリ実装
        $this->bind(ProductRepositoryInterface::class)
            ->to(OptimizedProductRepository::class);

        $this->bind(UserRepositoryInterface::class)
            ->to(MySQLUserRepository::class);

        $this->bind(OrderRepositoryInterface::class)
            ->to(MySQLOrderRepository::class);

        $this->bind(CategoryRepositoryInterface::class)
            ->to(MySQLCategoryRepository::class);

        // キャッシュ設定
        $this->bind(CacheInterface::class)
            ->to(RedisCache::class)
            ->in(Singleton::class);

        // ログ設定
        $this->bind(LoggerInterface::class)
            ->to(Logger::class)
            ->in(Singleton::class);
    }
}
```

### 2. 環境別設定モジュール

```php
class ProductionDataAccessModule extends AbstractModule
{
    protected function configure(): void
    {
        // 本番環境用の設定
        $this->bind(DatabaseInterface::class)
            ->annotatedWith(Named::class, 'master')
            ->to(MySQLDatabase::class);

        $this->bind(DatabaseInterface::class)
            ->annotatedWith(Named::class, 'replica')
            ->to(MySQLReplicaDatabase::class);

        // 読み書き分離リポジトリ
        $this->bind(ProductRepositoryInterface::class)
            ->to(ReadWriteSplitRepository::class);

        // 高度なキャッシュ設定
        $this->bind(CacheInterface::class)
            ->to(RedisClusterCache::class)
            ->in(Singleton::class);

        // パフォーマンス監視
        $this->bind(MetricsCollectorInterface::class)
            ->to(DatadogMetricsCollector::class);
    }
}

class DevelopmentDataAccessModule extends AbstractModule
{
    protected function configure(): void
    {
        // 開発環境用の設定
        $this->bind(DatabaseInterface::class)
            ->to(MySQLDatabase::class);

        // 標準リポジトリ
        $this->bind(ProductRepositoryInterface::class)
            ->to(MySQLProductRepository::class);

        // ファイルキャッシュ
        $this->bind(CacheInterface::class)
            ->to(FileCache::class);

        // デバッグ用メトリクス
        $this->bind(MetricsCollectorInterface::class)
            ->to(LogMetricsCollector::class);
    }
}
```

## 次のステップ

データアクセス層の実装を理解したので、次に進む準備が整いました。

1. **認証・認可システム**: セキュリティ実装の詳細学習
2. **ロギング・監査システム**: 運用監視の実装
3. **テスト戦略**: データアクセス層のテスト手法

**続きは:** [認証・認可](authentication-authorization.html)

## 重要なポイント

- **リポジトリパターン**でデータアクセス層を抽象化
- **複数データソース**の統合と最適化
- **コネクションプーリング**によるパフォーマンス向上
- **読み書き分離**でスケーラビリティを確保
- **キャッシュ戦略**による高速化
- **バッチ処理**でN+1問題を回避

---

効率的なデータアクセス層は、アプリケーションのパフォーマンスと保守性の基盤となります。Ray.Diの依存性注入により、柔軟で テスト可能なデータアクセス層を構築できます。