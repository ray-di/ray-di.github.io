---
layout: docs-ja
title: 認証・認可
category: Manual
permalink: /manuals/1.0/ja/tutorial/06-real-world-examples/authentication-authorization.html
---

# 認証・認可

## 学習目標

このセクションの終わりまでに、以下を理解できるようになります：
- Ray.Diを使った認証・認可システムの設計
- JWTトークンとセッション管理の実装
- ロールベースアクセス制御（RBAC）の実装
- マルチファクタ認証（MFA）の統合
- OAuth 2.0とOpenID Connectの実装
- セキュリティベストプラクティスの適用

## 認証・認可の基本設計

### 1. セキュリティインターフェース設計

```php
// 認証インターフェース
interface AuthenticationServiceInterface
{
    public function authenticate(Credentials $credentials): AuthenticationResult;
    public function validateToken(string $token): ?User;
    public function refreshToken(string $refreshToken): TokenPair;
    public function logout(string $token): void;
    public function isAuthenticated(): bool;
    public function getCurrentUser(): ?User;
}

// 認可インターフェース
interface AuthorizationServiceInterface
{
    public function authorize(User $user, string $permission): bool;
    public function checkRole(User $user, string $role): bool;
    public function checkPermission(User $user, string $permission): bool;
    public function getUserPermissions(User $user): array;
    public function getUserRoles(User $user): array;
}

// セキュリティコンテキスト
interface SecurityContextInterface
{
    public function getUser(): ?User;
    public function isAuthenticated(): bool;
    public function hasPermission(string $permission): bool;
    public function hasRole(string $role): bool;
    public function getToken(): ?string;
}

// トークンサービス
interface TokenServiceInterface
{
    public function createToken(User $user): TokenPair;
    public function validateToken(string $token): ?TokenPayload;
    public function refreshToken(string $refreshToken): TokenPair;
    public function revokeToken(string $token): void;
    public function isTokenRevoked(string $token): bool;
}
```

### 2. 認証モデル設計

```php
// ユーザーエンティティ
class User
{
    public function __construct(
        private ?int $id,
        private string $email,
        private string $hashedPassword,
        private string $name,
        private bool $isActive,
        private bool $isVerified,
        private ?DateTime $lastLoginAt,
        private DateTime $createdAt,
        private DateTime $updatedAt,
        private array $roles = []
    ) {}

    public function getId(): ?int { return $this->id; }
    public function getEmail(): string { return $this->email; }
    public function getName(): string { return $this->name; }
    public function isActive(): bool { return $this->isActive; }
    public function isVerified(): bool { return $this->isVerified; }
    public function getLastLoginAt(): ?DateTime { return $this->lastLoginAt; }
    public function getRoles(): array { return $this->roles; }
    
    public function hasRole(string $role): bool
    {
        return in_array($role, $this->roles, true);
    }
    
    public function verifyPassword(string $password): bool
    {
        return password_verify($password, $this->hashedPassword);
    }
    
    public function updateLastLogin(): void
    {
        $this->lastLoginAt = new DateTime();
    }
}

// 認証資格情報
class Credentials
{
    public function __construct(
        private string $email,
        private string $password,
        private ?string $rememberToken = null,
        private ?string $mfaCode = null
    ) {}

    public function getEmail(): string { return $this->email; }
    public function getPassword(): string { return $this->password; }
    public function getRememberToken(): ?string { return $this->rememberToken; }
    public function getMfaCode(): ?string { return $this->mfaCode; }
}

// 認証結果
class AuthenticationResult
{
    public function __construct(
        private bool $success,
        private ?User $user = null,
        private ?TokenPair $tokens = null,
        private ?string $error = null,
        private bool $requiresMfa = false
    ) {}

    public function isSuccess(): bool { return $this->success; }
    public function getUser(): ?User { return $this->user; }
    public function getTokens(): ?TokenPair { return $this->tokens; }
    public function getError(): ?string { return $this->error; }
    public function requiresMfa(): bool { return $this->requiresMfa; }
}

// トークンペア
class TokenPair
{
    public function __construct(
        private string $accessToken,
        private string $refreshToken,
        private DateTime $expiresAt
    ) {}

    public function getAccessToken(): string { return $this->accessToken; }
    public function getRefreshToken(): string { return $this->refreshToken; }
    public function getExpiresAt(): DateTime { return $this->expiresAt; }
}
```

## JWT認証サービス実装

### 1. JWTトークンサービス

```php
class JWTTokenService implements TokenServiceInterface
{
    private const ACCESS_TOKEN_EXPIRY = 3600; // 1時間
    private const REFRESH_TOKEN_EXPIRY = 604800; // 7日間

    public function __construct(
        private string $secretKey,
        private string $issuer,
        private CacheInterface $cache,
        private LoggerInterface $logger
    ) {}

    public function createToken(User $user): TokenPair
    {
        $now = new DateTime();
        $accessExpiry = (clone $now)->add(new DateInterval('PT' . self::ACCESS_TOKEN_EXPIRY . 'S'));
        $refreshExpiry = (clone $now)->add(new DateInterval('PT' . self::REFRESH_TOKEN_EXPIRY . 'S'));

        // アクセストークンのペイロード
        $accessPayload = [
            'iss' => $this->issuer,
            'sub' => $user->getId(),
            'email' => $user->getEmail(),
            'name' => $user->getName(),
            'roles' => $user->getRoles(),
            'iat' => $now->getTimestamp(),
            'exp' => $accessExpiry->getTimestamp(),
            'type' => 'access'
        ];

        // リフレッシュトークンのペイロード
        $refreshPayload = [
            'iss' => $this->issuer,
            'sub' => $user->getId(),
            'iat' => $now->getTimestamp(),
            'exp' => $refreshExpiry->getTimestamp(),
            'type' => 'refresh'
        ];

        $accessToken = $this->generateJWT($accessPayload);
        $refreshToken = $this->generateJWT($refreshPayload);

        // リフレッシュトークンをキャッシュに保存
        $this->cache->set(
            "refresh_token:{$user->getId()}:{$refreshToken}",
            true,
            self::REFRESH_TOKEN_EXPIRY
        );

        $this->logger->info("Tokens created for user", [
            'user_id' => $user->getId(),
            'email' => $user->getEmail()
        ]);

        return new TokenPair($accessToken, $refreshToken, $accessExpiry);
    }

    public function validateToken(string $token): ?TokenPayload
    {
        try {
            $payload = $this->decodeJWT($token);
            
            // トークンが取り消されていないかチェック
            if ($this->isTokenRevoked($token)) {
                return null;
            }

            return new TokenPayload(
                $payload['sub'],
                $payload['email'],
                $payload['name'],
                $payload['roles'] ?? [],
                new DateTime('@' . $payload['iat']),
                new DateTime('@' . $payload['exp']),
                $payload['type']
            );

        } catch (Exception $e) {
            $this->logger->warning("Token validation failed", [
                'error' => $e->getMessage(),
                'token' => substr($token, 0, 20) . '...'
            ]);
            return null;
        }
    }

    public function refreshToken(string $refreshToken): TokenPair
    {
        $payload = $this->validateToken($refreshToken);
        
        if (!$payload || $payload->getType() !== 'refresh') {
            throw new InvalidTokenException('Invalid refresh token');
        }

        // リフレッシュトークンがキャッシュに存在するかチェック
        $cacheKey = "refresh_token:{$payload->getUserId()}:{$refreshToken}";
        if (!$this->cache->get($cacheKey)) {
            throw new InvalidTokenException('Refresh token not found or expired');
        }

        // 新しいトークンペアを生成
        $user = $this->userRepository->findById($payload->getUserId());
        if (!$user) {
            throw new UserNotFoundException('User not found');
        }

        // 古いリフレッシュトークンを無効化
        $this->cache->delete($cacheKey);

        return $this->createToken($user);
    }

    public function revokeToken(string $token): void
    {
        $payload = $this->validateToken($token);
        
        if ($payload) {
            $expiry = $payload->getExpiresAt()->getTimestamp() - time();
            
            // トークンを取り消しリストに追加
            $this->cache->set(
                "revoked_token:" . hash('sha256', $token),
                true,
                $expiry
            );

            $this->logger->info("Token revoked", [
                'user_id' => $payload->getUserId(),
                'token_type' => $payload->getType()
            ]);
        }
    }

    public function isTokenRevoked(string $token): bool
    {
        $key = "revoked_token:" . hash('sha256', $token);
        return $this->cache->get($key) !== null;
    }

    private function generateJWT(array $payload): string
    {
        $header = json_encode(['typ' => 'JWT', 'alg' => 'HS256']);
        $payload = json_encode($payload);
        
        $base64Header = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
        $base64Payload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));
        
        $signature = hash_hmac('sha256', $base64Header . "." . $base64Payload, $this->secretKey, true);
        $base64Signature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));
        
        return $base64Header . "." . $base64Payload . "." . $base64Signature;
    }

    private function decodeJWT(string $token): array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            throw new InvalidTokenException('Invalid token format');
        }

        [$base64Header, $base64Payload, $base64Signature] = $parts;
        
        // 署名を検証
        $signature = base64_decode(str_replace(['-', '_'], ['+', '/'], $base64Signature));
        $expectedSignature = hash_hmac('sha256', $base64Header . "." . $base64Payload, $this->secretKey, true);
        
        if (!hash_equals($signature, $expectedSignature)) {
            throw new InvalidTokenException('Invalid token signature');
        }

        $payload = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $base64Payload)), true);
        
        if (!$payload) {
            throw new InvalidTokenException('Invalid token payload');
        }

        // 有効期限チェック
        if (isset($payload['exp']) && $payload['exp'] < time()) {
            throw new ExpiredTokenException('Token expired');
        }

        return $payload;
    }
}
```

### 2. 認証サービス実装

```php
class AuthenticationService implements AuthenticationServiceInterface
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private TokenServiceInterface $tokenService,
        private SecurityContextInterface $securityContext,
        private MfaServiceInterface $mfaService,
        private LoggerInterface $logger,
        private CacheInterface $cache,
        private int $maxFailedAttempts = 5,
        private int $lockoutDuration = 1800 // 30分
    ) {}

    public function authenticate(Credentials $credentials): AuthenticationResult
    {
        $email = $credentials->getEmail();
        
        // レート制限チェック
        if ($this->isRateLimited($email)) {
            $this->logger->warning("Authentication rate limited", ['email' => $email]);
            return new AuthenticationResult(false, null, null, 'Too many failed attempts');
        }

        // ユーザー検索
        $user = $this->userRepository->findByEmail($email);
        if (!$user) {
            $this->recordFailedAttempt($email);
            $this->logger->warning("Authentication failed - user not found", ['email' => $email]);
            return new AuthenticationResult(false, null, null, 'Invalid credentials');
        }

        // アクティブユーザーチェック
        if (!$user->isActive()) {
            $this->logger->warning("Authentication failed - user inactive", ['email' => $email]);
            return new AuthenticationResult(false, null, null, 'Account is inactive');
        }

        // パスワード検証
        if (!$user->verifyPassword($credentials->getPassword())) {
            $this->recordFailedAttempt($email);
            $this->logger->warning("Authentication failed - invalid password", ['email' => $email]);
            return new AuthenticationResult(false, null, null, 'Invalid credentials');
        }

        // MFA チェック
        if ($this->mfaService->isEnabled($user)) {
            if (!$credentials->getMfaCode()) {
                return new AuthenticationResult(false, null, null, 'MFA code required', true);
            }

            if (!$this->mfaService->verifyCode($user, $credentials->getMfaCode())) {
                $this->recordFailedAttempt($email);
                $this->logger->warning("Authentication failed - invalid MFA code", ['email' => $email]);
                return new AuthenticationResult(false, null, null, 'Invalid MFA code');
            }
        }

        // 認証成功
        $this->clearFailedAttempts($email);
        $user->updateLastLogin();
        $this->userRepository->save($user);

        $tokens = $this->tokenService->createToken($user);

        $this->logger->info("User authenticated successfully", [
            'user_id' => $user->getId(),
            'email' => $user->getEmail()
        ]);

        return new AuthenticationResult(true, $user, $tokens);
    }

    public function validateToken(string $token): ?User
    {
        $payload = $this->tokenService->validateToken($token);
        
        if (!$payload) {
            return null;
        }

        $user = $this->userRepository->findById($payload->getUserId());
        
        if (!$user || !$user->isActive()) {
            return null;
        }

        return $user;
    }

    public function refreshToken(string $refreshToken): TokenPair
    {
        return $this->tokenService->refreshToken($refreshToken);
    }

    public function logout(string $token): void
    {
        $this->tokenService->revokeToken($token);
        
        $this->logger->info("User logged out", [
            'token' => substr($token, 0, 20) . '...'
        ]);
    }

    public function isAuthenticated(): bool
    {
        return $this->securityContext->isAuthenticated();
    }

    public function getCurrentUser(): ?User
    {
        return $this->securityContext->getUser();
    }

    private function isRateLimited(string $email): bool
    {
        $key = "auth_attempts:{$email}";
        $attempts = $this->cache->get($key, 0);
        
        return $attempts >= $this->maxFailedAttempts;
    }

    private function recordFailedAttempt(string $email): void
    {
        $key = "auth_attempts:{$email}";
        $attempts = $this->cache->get($key, 0) + 1;
        
        $this->cache->set($key, $attempts, $this->lockoutDuration);
    }

    private function clearFailedAttempts(string $email): void
    {
        $key = "auth_attempts:{$email}";
        $this->cache->delete($key);
    }
}
```

## ロールベースアクセス制御（RBAC）

### 1. RBAC設計

```php
// 権限エンティティ
class Permission
{
    public function __construct(
        private int $id,
        private string $name,
        private string $resource,
        private string $action,
        private string $description
    ) {}

    public function getId(): int { return $this->id; }
    public function getName(): string { return $this->name; }
    public function getResource(): string { return $this->resource; }
    public function getAction(): string { return $this->action; }
    public function getDescription(): string { return $this->description; }
}

// ロールエンティティ
class Role
{
    public function __construct(
        private int $id,
        private string $name,
        private string $description,
        private array $permissions = []
    ) {}

    public function getId(): int { return $this->id; }
    public function getName(): string { return $this->name; }
    public function getDescription(): string { return $this->description; }
    public function getPermissions(): array { return $this->permissions; }
    
    public function hasPermission(string $permission): bool
    {
        return in_array($permission, array_column($this->permissions, 'name'), true);
    }
    
    public function addPermission(Permission $permission): void
    {
        $this->permissions[] = $permission;
    }
}

// 認可サービス実装
class AuthorizationService implements AuthorizationServiceInterface
{
    public function __construct(
        private RoleRepositoryInterface $roleRepository,
        private PermissionRepositoryInterface $permissionRepository,
        private CacheInterface $cache,
        private LoggerInterface $logger
    ) {}

    public function authorize(User $user, string $permission): bool
    {
        // スーパーユーザーは全ての権限を持つ
        if ($user->hasRole('super_admin')) {
            return true;
        }

        // ユーザーの権限をキャッシュから取得
        $cacheKey = "user_permissions:{$user->getId()}";
        $permissions = $this->cache->get($cacheKey);
        
        if ($permissions === null) {
            $permissions = $this->getUserPermissions($user);
            $this->cache->set($cacheKey, $permissions, 3600); // 1時間キャッシュ
        }

        $hasPermission = in_array($permission, $permissions, true);

        $this->logger->debug("Authorization check", [
            'user_id' => $user->getId(),
            'permission' => $permission,
            'authorized' => $hasPermission
        ]);

        return $hasPermission;
    }

    public function checkRole(User $user, string $role): bool
    {
        return $user->hasRole($role);
    }

    public function checkPermission(User $user, string $permission): bool
    {
        return $this->authorize($user, $permission);
    }

    public function getUserPermissions(User $user): array
    {
        $permissions = [];
        
        foreach ($user->getRoles() as $roleName) {
            $role = $this->roleRepository->findByName($roleName);
            if ($role) {
                foreach ($role->getPermissions() as $permission) {
                    $permissions[] = $permission->getName();
                }
            }
        }

        return array_unique($permissions);
    }

    public function getUserRoles(User $user): array
    {
        return $user->getRoles();
    }
}
```

### 2. 権限管理システム

```php
class PermissionManager
{
    public function __construct(
        private RoleRepositoryInterface $roleRepository,
        private PermissionRepositoryInterface $permissionRepository,
        private UserRepositoryInterface $userRepository,
        private CacheInterface $cache,
        private LoggerInterface $logger
    ) {}

    public function createPermission(string $name, string $resource, string $action, string $description = ''): Permission
    {
        $permission = new Permission(null, $name, $resource, $action, $description);
        $this->permissionRepository->save($permission);
        
        $this->logger->info("Permission created", [
            'name' => $name,
            'resource' => $resource,
            'action' => $action
        ]);

        return $permission;
    }

    public function createRole(string $name, string $description = ''): Role
    {
        $role = new Role(null, $name, $description);
        $this->roleRepository->save($role);
        
        $this->logger->info("Role created", [
            'name' => $name,
            'description' => $description
        ]);

        return $role;
    }

    public function assignPermissionToRole(Role $role, Permission $permission): void
    {
        $role->addPermission($permission);
        $this->roleRepository->save($role);
        
        // キャッシュクリア
        $this->clearRolePermissionCache($role);
        
        $this->logger->info("Permission assigned to role", [
            'role' => $role->getName(),
            'permission' => $permission->getName()
        ]);
    }

    public function assignRoleToUser(User $user, Role $role): void
    {
        $user->addRole($role->getName());
        $this->userRepository->save($user);
        
        // キャッシュクリア
        $this->clearUserPermissionCache($user);
        
        $this->logger->info("Role assigned to user", [
            'user_id' => $user->getId(),
            'role' => $role->getName()
        ]);
    }

    public function revokePermissionFromRole(Role $role, Permission $permission): void
    {
        $role->removePermission($permission);
        $this->roleRepository->save($role);
        
        // キャッシュクリア
        $this->clearRolePermissionCache($role);
        
        $this->logger->info("Permission revoked from role", [
            'role' => $role->getName(),
            'permission' => $permission->getName()
        ]);
    }

    public function revokeRoleFromUser(User $user, Role $role): void
    {
        $user->removeRole($role->getName());
        $this->userRepository->save($user);
        
        // キャッシュクリア
        $this->clearUserPermissionCache($user);
        
        $this->logger->info("Role revoked from user", [
            'user_id' => $user->getId(),
            'role' => $role->getName()
        ]);
    }

    private function clearRolePermissionCache(Role $role): void
    {
        // このロールを持つすべてのユーザーのキャッシュをクリア
        $pattern = "user_permissions:*";
        $keys = $this->cache->keys($pattern);
        
        foreach ($keys as $key) {
            $this->cache->delete($key);
        }
    }

    private function clearUserPermissionCache(User $user): void
    {
        $cacheKey = "user_permissions:{$user->getId()}";
        $this->cache->delete($cacheKey);
    }
}
```

## マルチファクタ認証（MFA）

### 1. MFA実装

```php
interface MfaServiceInterface
{
    public function isEnabled(User $user): bool;
    public function enable(User $user): string; // Returns secret key
    public function disable(User $user): void;
    public function verifyCode(User $user, string $code): bool;
    public function generateBackupCodes(User $user): array;
    public function verifyBackupCode(User $user, string $code): bool;
}

class TOTPMfaService implements MfaServiceInterface
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private CacheInterface $cache,
        private LoggerInterface $logger
    ) {}

    public function isEnabled(User $user): bool
    {
        $mfaData = $this->getUserMfaData($user);
        return $mfaData['enabled'] ?? false;
    }

    public function enable(User $user): string
    {
        $secretKey = $this->generateSecretKey();
        
        $mfaData = [
            'enabled' => true,
            'secret_key' => $secretKey,
            'backup_codes' => $this->generateBackupCodes(),
            'enabled_at' => new DateTime()
        ];
        
        $this->saveMfaData($user, $mfaData);
        
        $this->logger->info("MFA enabled for user", [
            'user_id' => $user->getId(),
            'email' => $user->getEmail()
        ]);

        return $secretKey;
    }

    public function disable(User $user): void
    {
        $mfaData = [
            'enabled' => false,
            'secret_key' => null,
            'backup_codes' => [],
            'disabled_at' => new DateTime()
        ];
        
        $this->saveMfaData($user, $mfaData);
        
        $this->logger->info("MFA disabled for user", [
            'user_id' => $user->getId(),
            'email' => $user->getEmail()
        ]);
    }

    public function verifyCode(User $user, string $code): bool
    {
        $mfaData = $this->getUserMfaData($user);
        
        if (!$mfaData['enabled'] || !$mfaData['secret_key']) {
            return false;
        }

        // リプレイ攻撃防止
        $cacheKey = "mfa_used_code:{$user->getId()}:{$code}";
        if ($this->cache->get($cacheKey)) {
            return false;
        }

        $isValid = $this->verifyTOTP($mfaData['secret_key'], $code);
        
        if ($isValid) {
            // 使用済みコードをキャッシュに保存（30秒間）
            $this->cache->set($cacheKey, true, 30);
        }

        $this->logger->info("MFA code verification", [
            'user_id' => $user->getId(),
            'valid' => $isValid
        ]);

        return $isValid;
    }

    public function generateBackupCodes(User $user): array
    {
        $codes = [];
        for ($i = 0; $i < 10; $i++) {
            $codes[] = $this->generateRandomCode();
        }
        
        $mfaData = $this->getUserMfaData($user);
        $mfaData['backup_codes'] = $codes;
        $this->saveMfaData($user, $mfaData);
        
        return $codes;
    }

    public function verifyBackupCode(User $user, string $code): bool
    {
        $mfaData = $this->getUserMfaData($user);
        $backupCodes = $mfaData['backup_codes'] ?? [];
        
        $codeIndex = array_search($code, $backupCodes, true);
        
        if ($codeIndex === false) {
            return false;
        }

        // バックアップコードを使用済みにする
        unset($backupCodes[$codeIndex]);
        $mfaData['backup_codes'] = array_values($backupCodes);
        $this->saveMfaData($user, $mfaData);
        
        $this->logger->info("Backup code used", [
            'user_id' => $user->getId(),
            'remaining_codes' => count($backupCodes)
        ]);

        return true;
    }

    private function generateSecretKey(): string
    {
        return base32_encode(random_bytes(20));
    }

    private function generateRandomCode(): string
    {
        return str_pad(random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }

    private function verifyTOTP(string $secretKey, string $code): bool
    {
        $timeStep = floor(time() / 30);
        
        // 前後の時間窓も考慮（クロックスキューの許容）
        for ($i = -1; $i <= 1; $i++) {
            $calculatedCode = $this->generateTOTP($secretKey, $timeStep + $i);
            if (hash_equals($calculatedCode, $code)) {
                return true;
            }
        }
        
        return false;
    }

    private function generateTOTP(string $secretKey, int $timeStep): string
    {
        $key = base32_decode($secretKey);
        $time = pack('N*', 0, $timeStep);
        $hash = hash_hmac('sha1', $time, $key, true);
        $offset = ord($hash[19]) & 0xf;
        $code = (
            ((ord($hash[$offset + 0]) & 0x7f) << 24) |
            ((ord($hash[$offset + 1]) & 0xff) << 16) |
            ((ord($hash[$offset + 2]) & 0xff) << 8) |
            (ord($hash[$offset + 3]) & 0xff)
        ) % 1000000;
        
        return str_pad($code, 6, '0', STR_PAD_LEFT);
    }

    private function getUserMfaData(User $user): array
    {
        // この実装では簡単のため、ユーザーのメタデータから取得
        // 実際の実装では専用のテーブルやストレージを使用
        return json_decode($user->getMfaData() ?? '{}', true);
    }

    private function saveMfaData(User $user, array $data): void
    {
        $user->setMfaData(json_encode($data));
        $this->userRepository->save($user);
    }
}
```

## セキュリティミドルウェア

### 1. 認証ミドルウェア

```php
class AuthenticationMiddleware
{
    public function __construct(
        private AuthenticationServiceInterface $authService,
        private SecurityContextInterface $securityContext,
        private LoggerInterface $logger
    ) {}

    public function handle(Request $request, callable $next): Response
    {
        $token = $this->extractToken($request);
        
        if (!$token) {
            return $this->unauthorizedResponse('Token required');
        }

        $user = $this->authService->validateToken($token);
        
        if (!$user) {
            return $this->unauthorizedResponse('Invalid token');
        }

        // セキュリティコンテキストにユーザー情報を設定
        $this->securityContext->setUser($user);
        $this->securityContext->setToken($token);

        return $next($request);
    }

    private function extractToken(Request $request): ?string
    {
        $authHeader = $request->getHeader('Authorization');
        
        if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
            return null;
        }

        return substr($authHeader, 7);
    }

    private function unauthorizedResponse(string $message): Response
    {
        return new Response(401, ['Content-Type' => 'application/json'], json_encode([
            'error' => 'Unauthorized',
            'message' => $message
        ]));
    }
}
```

### 2. 認可ミドルウェア

```php
class AuthorizationMiddleware
{
    public function __construct(
        private AuthorizationServiceInterface $authService,
        private SecurityContextInterface $securityContext,
        private LoggerInterface $logger
    ) {}

    public function handle(Request $request, callable $next, string $permission): Response
    {
        $user = $this->securityContext->getUser();
        
        if (!$user) {
            return $this->forbiddenResponse('User not authenticated');
        }

        if (!$this->authService->authorize($user, $permission)) {
            $this->logger->warning("Authorization denied", [
                'user_id' => $user->getId(),
                'permission' => $permission,
                'ip' => $request->getClientIp()
            ]);
            
            return $this->forbiddenResponse('Insufficient permissions');
        }

        return $next($request);
    }

    private function forbiddenResponse(string $message): Response
    {
        return new Response(403, ['Content-Type' => 'application/json'], json_encode([
            'error' => 'Forbidden',
            'message' => $message
        ]));
    }
}
```

## セキュリティ設定モジュール

### 1. 認証・認可モジュール

```php
class SecurityModule extends AbstractModule
{
    protected function configure(): void
    {
        // トークンサービス
        $this->bind(TokenServiceInterface::class)
            ->to(JWTTokenService::class)
            ->in(Singleton::class);

        // 認証サービス
        $this->bind(AuthenticationServiceInterface::class)
            ->to(AuthenticationService::class)
            ->in(Singleton::class);

        // 認可サービス
        $this->bind(AuthorizationServiceInterface::class)
            ->to(AuthorizationService::class)
            ->in(Singleton::class);

        // MFAサービス
        $this->bind(MfaServiceInterface::class)
            ->to(TOTPMfaService::class)
            ->in(Singleton::class);

        // セキュリティコンテキスト
        $this->bind(SecurityContextInterface::class)
            ->to(SecurityContext::class)
            ->in(Singleton::class);

        // リポジトリ
        $this->bind(UserRepositoryInterface::class)
            ->to(MySQLUserRepository::class);

        $this->bind(RoleRepositoryInterface::class)
            ->to(MySQLRoleRepository::class);

        $this->bind(PermissionRepositoryInterface::class)
            ->to(MySQLPermissionRepository::class);

        // セキュリティ設定
        $this->bind('security.jwt.secret')
            ->toInstance($_ENV['JWT_SECRET'] ?? 'your-secret-key');

        $this->bind('security.jwt.issuer')
            ->toInstance($_ENV['JWT_ISSUER'] ?? 'ShopSmart');

        $this->bind('security.max_failed_attempts')
            ->toInstance(5);

        $this->bind('security.lockout_duration')
            ->toInstance(1800);
    }
}
```

## 次のステップ

認証・認可システムの実装を理解したので、次に進む準備が整いました。

1. **ロギング・監査システム**: セキュリティイベントの記録と監視
2. **テスト戦略**: 認証・認可システムのテスト手法
3. **セキュリティ強化**: 追加のセキュリティ機能の実装

**続きは:** [ロギング・監査システム](logging-audit-system.html)

## 重要なポイント

- **JWTトークン**による状態なし認証
- **ロールベースアクセス制御**（RBAC）で権限管理
- **マルチファクタ認証**でセキュリティ強化
- **レート制限**でブルートフォース攻撃を防止
- **監査ログ**でセキュリティイベントを記録
- **セキュリティコンテキスト**で認証情報を管理

---

堅牢な認証・認可システムは、Webアプリケーションのセキュリティの基盤です。Ray.Diの依存性注入により、拡張可能で保守しやすいセキュリティシステムを構築できます。