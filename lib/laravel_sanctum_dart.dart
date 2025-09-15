/// A high-performance, feature-rich Dart package for Laravel Sanctum authentication
///
/// Provides seamless integration with Laravel Sanctum, supporting both API token
/// authentication and SPA cookie-based authentication with advanced features like:
///
/// - API token management with abilities/scopes
/// - Cookie-based SPA authentication with CSRF protection
/// - Automatic request interceptors and retry logic
/// - Secure token storage and caching
/// - Type-safe models with null safety
/// - Comprehensive error handling
///
/// Example usage:
/// ```dart
/// import 'package:laravel_sanctum_dart/laravel_sanctum_dart.dart';
///
/// // Initialize the client
/// final sanctum = SanctumAuth(
///   baseUrl: 'https://api.example.com',
///   storageKey: 'auth_token',
/// );
///
/// // Login with email and password
/// final response = await sanctum.login(
///   email: 'user@example.com',
///   password: 'password',
///   deviceName: 'iPhone 12',
/// );
///
/// // Make authenticated requests
/// final user = await sanctum.user();
/// ```
library laravel_sanctum_dart;

// Core authentication
export 'src/auth/sanctum_auth.dart';
export 'src/auth/token_manager.dart';
export 'src/auth/cookie_manager.dart';

// Models
export 'src/models/user.dart';
export 'src/models/token.dart';
export 'src/models/auth_response.dart';
export 'src/models/auth_config.dart';

// Interceptors
export 'src/interceptors/auth_interceptor.dart';
export 'src/interceptors/csrf_interceptor.dart';
export 'src/interceptors/retry_interceptor.dart';

// Exceptions
export 'src/exceptions/sanctum_exceptions.dart';

// Utils
export 'src/utils/storage.dart';
export 'src/utils/performance.dart';
export 'src/utils/logger.dart';

// Constants
export 'src/constants/sanctum_constants.dart';