# 🚀 Laravel Sanctum Dart

[![pub package](https://img.shields.io/pub/v/laravel_sanctum_dart.svg)](https://pub.dev/packages/laravel_sanctum_dart)
[![pub points](https://img.shields.io/pub/points/laravel_sanctum_dart)](https://pub.dev/packages/laravel_sanctum_dart/score)
[![popularity](https://img.shields.io/pub/popularity/laravel_sanctum_dart)](https://pub.dev/packages/laravel_sanctum_dart/score)
[![likes](https://img.shields.io/pub/likes/laravel_sanctum_dart)](https://pub.dev/packages/laravel_sanctum_dart/score)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Kemerd/laravel_sanctum_dart/blob/main/LICENSE)

A **high-performance**, **feature-rich** Dart package for Laravel Sanctum authentication. Seamlessly integrate your Flutter/Dart applications with Laravel Sanctum APIs with beautiful developer experience and enterprise-grade reliability.

## ✨ Features

### 🔐 **Complete Authentication Support**
- **API Token Authentication** - Perfect for mobile apps and third-party integrations
- **SPA Cookie Authentication** - Ideal for web apps with CSRF protection
- **Hybrid Mode** - Intelligently switches between token and cookie auth

### 🎯 **Advanced Token Management**
- Create, revoke, and refresh tokens
- Token abilities and scopes support
- Multi-device token management
- Automatic token expiration handling

### ⚡ **Performance Optimized**
- Connection pooling for better performance
- Response caching with intelligent TTL
- Retry logic with exponential backoff
- Lazy loading and batch operations

### 🛡️ **Enterprise Security**
- Secure token storage using platform keychain
- CSRF protection for SPA authentication
- Automatic token refresh on expiration
- Rate limiting and error recovery

### 🔧 **Developer Experience**
- **Type-safe** with full null safety
- **Comprehensive logging** for debugging
- **Stream-based** authentication state
- **Beautiful documentation** with examples
- **Zero configuration** for common use cases

### 📱 **Platform Support**
- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Desktop (Windows, macOS, Linux)

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  laravel_sanctum_dart: ^1.0.0
```

Then run:

```bash
dart pub get
```

Or with Flutter:

```bash
flutter pub get
```

## 🚀 Quick Start

### 1. Initialize Sanctum Client

```dart
import 'package:laravel_sanctum_dart/laravel_sanctum_dart.dart';

final sanctum = SanctumAuth(
  baseUrl: 'https://api.yourapp.com',
  storageKey: 'auth_token', // optional
);
```

### 2. Login with Email & Password

```dart
try {
  final response = await sanctum.login(
    email: 'user@example.com',
    password: 'password',
    deviceName: 'iPhone 12',
  );

  print('Welcome ${response.user.name}!');
  print('Token: ${response.token}');
} catch (e) {
  if (e is SanctumAuthenticationException) {
    print('Invalid credentials: ${e.userFriendlyMessage}');
  }
}
```

### 3. Make Authenticated Requests

```dart
// The token is automatically added to requests
final user = await sanctum.user();
print('Current user: ${user.name}');

// Or use the Dio client directly for custom requests
final response = await sanctum.dio.get('/api/posts');
```

### 4. Listen to Authentication State

```dart
sanctum.authStateStream.listen((state) {
  switch (state) {
    case SanctumAuthState.authenticated:
      print('User is logged in');
      break;
    case SanctumAuthState.unauthenticated:
      print('User is logged out');
      break;
    case SanctumAuthState.verifying:
      print('Checking authentication...');
      break;
  }
});
```

## 🎯 Advanced Usage

### 🔑 Token Management

```dart
// Create a token with specific abilities
final tokenResponse = await sanctum.tokens.createToken(
  name: 'Mobile App Token',
  abilities: ['read', 'write', 'delete'],
  expiresAt: DateTime.now().add(Duration(days: 30)),
);

// List all user tokens
final tokens = await sanctum.tokens.listTokens();

// Revoke a specific token
await sanctum.tokens.revokeToken(tokenId: 123);

// Check token abilities
final canDelete = await sanctum.hasAbility('delete');
if (canDelete) {
  // User can delete resources
}
```

### 🍪 SPA Authentication

```dart
final sanctum = SanctumAuth(
  baseUrl: 'https://yourapp.com',
  authMode: SanctumAuthMode.spa, // Enable SPA mode
  statefulDomains: ['yourapp.com'], // Configure stateful domains
);

// CSRF cookie is automatically handled
final response = await sanctum.login(
  email: 'user@example.com',
  password: 'password',
  deviceName: 'Web Browser',
);
```

### ⚡ Performance Configuration

```dart
final sanctum = SanctumAuth(
  baseUrl: 'https://api.yourapp.com',
  cacheConfig: SanctumCacheConfig(
    enabled: true,
    maxSize: 100,
    timeout: Duration(minutes: 5),
  ),
  retryConfig: SanctumRetryConfig(
    enabled: true,
    maxRetries: 3,
    initialDelay: Duration(seconds: 1),
    backoffMultiplier: 2.0,
  ),
);
```

### 🔧 Custom Configuration

```dart
final sanctum = SanctumAuth.withConfig(
  SanctumConfig(
    baseUrl: 'https://api.yourapp.com',
    authMode: SanctumAuthMode.hybrid,
    debugMode: true, // Enable detailed logging
    autoRefreshTokens: true,
    defaultHeaders: {
      'X-Custom-Header': 'value',
    },
    endpoints: SanctumEndpoints(
      login: '/api/auth/login',
      register: '/api/auth/register',
      logout: '/api/auth/logout',
    ),
  ),
);
```

## 📱 Platform-Specific Setup

### Android

No additional setup required! The package uses Android Keystore for secure token storage.

### iOS

No additional setup required! The package uses iOS Keychain for secure token storage.

### Web

For web applications using SPA authentication, ensure your Laravel backend is configured for CORS:

```php
// config/cors.php
'supports_credentials' => true,
```

### Desktop

The package automatically handles secure storage on Windows, macOS, and Linux.

## 🛠️ Error Handling

The package provides comprehensive error handling with specific exception types:

```dart
try {
  await sanctum.login(email: email, password: password, deviceName: 'App');
} on SanctumAuthenticationException catch (e) {
  // Invalid credentials, expired tokens
  print('Auth error: ${e.userFriendlyMessage}');
  print('Recovery: ${e.recoveryAction}');
} on SanctumValidationException catch (e) {
  // Form validation errors
  print('Validation errors: ${e.allErrors}');
} on SanctumNetworkException catch (e) {
  // Network connectivity issues
  print('Network error: ${e.userFriendlyMessage}');
} on SanctumRateLimitException catch (e) {
  // Too many requests
  print('Rate limited. Retry after: ${e.retryAfter}');
} catch (e) {
  // Other errors
  print('Unexpected error: $e');
}
```

## 🔍 Debugging

Enable debug mode for detailed logging:

```dart
final sanctum = SanctumAuth(
  baseUrl: 'https://api.yourapp.com',
  debugMode: true, // This will log all requests/responses
);

// Or configure logging globally
SanctumLog.initialize(
  debugMode: true,
  prefix: '[MyApp]',
);
```

## 🧪 Testing

The package provides mock implementations for easy testing:

```dart
// Create a mock client for testing
final mockSanctum = MockSanctumAuth();

when(mockSanctum.login(
  email: anyNamed('email'),
  password: anyNamed('password'),
  deviceName: anyNamed('deviceName'),
)).thenAnswer((_) async => SanctumLoginResponse(
  user: SanctumUserBasic(id: 1, name: 'Test User', email: 'test@example.com'),
  token: 'test-token',
));
```

## 📊 Performance Monitoring

Monitor performance and cache statistics:

```dart
final stats = sanctum.performanceStats;
print('Cache hit rate: ${stats.cacheStats.hitRate}%');
print('Active connections: ${stats.connectionPoolStats.activeConnections}');

// Get detailed metrics
final metrics = stats.metricsStats.operations;
for (final operation in metrics.values) {
  print('${operation.name}: avg ${operation.averageDuration.inMilliseconds}ms');
}
```

## 🔐 Security Best Practices

1. **Always use HTTPS** in production
2. **Enable secure storage** (enabled by default)
3. **Set appropriate token expiration** times
4. **Use specific abilities** instead of wildcard permissions
5. **Implement proper error handling**
6. **Keep tokens refreshed** automatically

```dart
// Example secure configuration
final sanctum = SanctumAuth(
  baseUrl: 'https://api.yourapp.com', // Always HTTPS
  autoRefreshTokens: true, // Auto-refresh tokens
  debugMode: false, // Disable in production
);

// Create tokens with limited abilities
await sanctum.tokens.createToken(
  name: 'Mobile App',
  abilities: ['read:posts', 'write:posts'], // Specific permissions
  expiresAt: DateTime.now().add(Duration(days: 7)), // Limited lifetime
);
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Laravel Sanctum](https://laravel.com/docs/sanctum) for the amazing authentication system
- [Dio](https://pub.dev/packages/dio) for the powerful HTTP client
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage) for secure token storage

## 📚 Documentation

- [API Documentation](https://pub.dev/documentation/laravel_sanctum_dart/latest/)
- [Example App](example/)
- [Migration Guide](doc/migration.md)
- [Troubleshooting](doc/troubleshooting.md)

---

**Built with ❤️ for the Flutter and Laravel communities**

[![GitHub stars](https://img.shields.io/github/stars/Kemerd/laravel_sanctum_dart?style=social)](https://github.com/Kemerd/laravel_sanctum_dart)
[![GitHub forks](https://img.shields.io/github/forks/Kemerd/laravel_sanctum_dart?style=social)](https://github.com/Kemerd/laravel_sanctum_dart)
