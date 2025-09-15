import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../models/auth_config.dart';
import '../exceptions/sanctum_exceptions.dart';
import '../constants/sanctum_constants.dart';
import '../utils/storage.dart';
import '../utils/logger.dart';

/// Interceptor that automatically adds authentication tokens to requests
///
/// This interceptor handles the automatic injection of Bearer tokens
/// for API authentication and manages token-related errors such as
/// expiration and invalid tokens.
///
/// The interceptor:
/// - Automatically adds Authorization headers with Bearer tokens
/// - Handles token expiration by calling an optional callback
/// - Converts authentication errors to appropriate exceptions
/// - Supports both API token and hybrid authentication modes
@immutable
class SanctumAuthInterceptor extends Interceptor {
  /// Secure storage for retrieving tokens
  final SanctumStorage _storage;

  /// Configuration settings
  final SanctumConfig _config;

  /// Logger for debugging
  final SanctumLogger _logger;

  /// Callback function called when token expires
  final Future<void> Function()? _onTokenExpired;

  /// Creates a new [SanctumAuthInterceptor] instance
  const SanctumAuthInterceptor({
    required SanctumStorage storage,
    required SanctumConfig config,
    required SanctumLogger logger,
    Future<void> Function()? onTokenExpired,
  })  : _storage = storage,
        _config = config,
        _logger = logger,
        _onTokenExpired = onTokenExpired;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // Only add tokens for API and hybrid modes
      if (_config.authMode == SanctumAuthMode.api ||
          _config.authMode == SanctumAuthMode.hybrid) {
        await _addAuthenticationToken(options);
      }

      handler.next(options);
    } catch (e, stackTrace) {
      _logger.error('Failed to add authentication token', e, stackTrace);
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Check for token refresh headers or other auth-related response data
    _handleAuthResponse(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    try {
      final response = err.response;
      final statusCode = response?.statusCode;

      // Handle authentication errors
      if (statusCode == 401) {
        await _handleUnauthorizedError(err);
      } else if (statusCode == 403) {
        _handleForbiddenError(err);
      } else if (statusCode == 419) {
        _handleCsrfError(err);
      }

      handler.next(err);
    } catch (e, stackTrace) {
      _logger.error('Error in auth interceptor error handler', e, stackTrace);
      handler.next(err);
    }
  }

  /// Adds authentication token to the request
  Future<void> _addAuthenticationToken(RequestOptions options) async {
    // Skip adding token if Authorization header already exists
    if (options.headers.containsKey(SanctumConstants.authorizationHeader)) {
      _logger.debug('Authorization header already present, skipping token injection');
      return;
    }

    // Get token from storage
    final token = await _storage.getToken(key: _config.storageKey);
    if (token == null || token.isEmpty) {
      _logger.debug('No authentication token found, request will be unauthenticated');
      return;
    }

    // Add Bearer token to request headers
    options.headers[SanctumConstants.authorizationHeader] =
        '${SanctumConstants.bearerPrefix}$token';

    _logger.debug(
      'Authentication token added to request: ${options.method} ${options.path}',
    );
  }

  /// Handles authentication-related response data
  void _handleAuthResponse(Response response) {
    final headers = response.headers;

    // Check for token refresh information in response headers
    final newToken = headers.value('x-new-token');
    if (newToken != null && newToken.isNotEmpty) {
      _logger.info('New token received in response headers');
      // Store the new token asynchronously
      _storage.setToken(newToken, key: _config.storageKey).catchError((e) {
        _logger.error('Failed to store new token from response headers: $e');
      });
    }

    // Check for token expiration warnings
    final expirationWarning = headers.value('x-token-expires-in');
    if (expirationWarning != null) {
      final expiresInSeconds = int.tryParse(expirationWarning);
      if (expiresInSeconds != null && expiresInSeconds < 3600) {
        // Token expires in less than 1 hour
        _logger.warning('Token will expire in $expiresInSeconds seconds');
      }
    }
  }

  /// Handles 401 Unauthorized errors
  Future<void> _handleUnauthorizedError(DioException error) async {
    _logger.warning('Received 401 Unauthorized response');

    final response = error.response;
    final data = response?.data;

    // Check if this is a token expiration error
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString().toLowerCase() ?? '';
      if (message.contains('token') &&
          (message.contains('expired') || message.contains('invalid'))) {
        _logger.info('Token appears to be expired or invalid');

        // Call the token expired callback if provided
        if (_onTokenExpired != null) {
          try {
            await _onTokenExpired!();
            _logger.debug('Token expiration callback executed successfully');
          } catch (e, stackTrace) {
            _logger.error('Token expiration callback failed', e, stackTrace);
          }
        }

        // Clear the invalid token from storage
        try {
          await _storage.removeToken(key: _config.storageKey);
          _logger.debug('Invalid token removed from storage');
        } catch (e, stackTrace) {
          _logger.error('Failed to remove invalid token', e, stackTrace);
        }
      }
    }
  }

  /// Handles 403 Forbidden errors
  void _handleForbiddenError(DioException error) {
    _logger.warning('Received 403 Forbidden response');

    final response = error.response;
    final data = response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString() ?? '';
      if (message.contains('ability') || message.contains('permission')) {
        _logger.info('Request failed due to insufficient token abilities');
      }
    }
  }

  /// Handles 419 CSRF token mismatch errors
  void _handleCsrfError(DioException error) {
    _logger.warning('Received 419 CSRF token mismatch response');

    // This typically happens in SPA mode when CSRF token is invalid
    if (_config.authMode == SanctumAuthMode.spa ||
        _config.authMode == SanctumAuthMode.hybrid) {
      _logger.info('CSRF token may need to be refreshed for SPA authentication');
    }
  }

  /// Checks if a request should be authenticated
  bool _shouldAuthenticate(RequestOptions options) {
    // Skip authentication for certain endpoints
    final path = options.path;
    final skipPaths = {
      _config.endpoints.login,
      _config.endpoints.register,
      _config.endpoints.csrfCookie,
    };

    if (skipPaths.contains(path)) {
      return false;
    }

    // Skip if this is a login or registration request
    if (path.contains('login') || path.contains('register')) {
      return false;
    }

    return true;
  }

  /// Gets the authentication token with validation
  Future<String?> _getValidToken() async {
    try {
      final token = await _storage.getToken(key: _config.storageKey);
      if (token == null || token.isEmpty) {
        return null;
      }

      // Basic token format validation
      if (!_isValidTokenFormat(token)) {
        _logger.warning('Token has invalid format, removing from storage');
        await _storage.removeToken(key: _config.storageKey);
        return null;
      }

      return token;
    } catch (e, stackTrace) {
      _logger.error('Failed to get valid token', e, stackTrace);
      return null;
    }
  }

  /// Validates token format
  bool _isValidTokenFormat(String token) {
    // Laravel Sanctum tokens typically have the format "id|hash"
    if (token.contains('|')) {
      final parts = token.split('|');
      if (parts.length == 2) {
        final id = int.tryParse(parts[0]);
        return id != null && parts[1].isNotEmpty;
      }
    }

    // Also accept simple string tokens
    return token.length >= 10; // Minimum reasonable token length
  }

  /// Creates an authentication header value
  String _createAuthHeader(String token) {
    return '${SanctumConstants.bearerPrefix}$token';
  }

  /// Logs authentication-related information
  void _logAuthInfo(String message, [Map<String, dynamic>? additionalData]) {
    _logger.debug('AuthInterceptor: $message', additionalData);
  }
}

/// Enhanced auth interceptor with retry capabilities
class SanctumAuthInterceptorWithRetry extends SanctumAuthInterceptor {
  /// Maximum number of retry attempts for token refresh
  final int maxRetryAttempts;

  /// Current retry attempt count per request
  final Map<String, int> _retryAttempts = {};

  /// Creates a new [SanctumAuthInterceptorWithRetry] instance
  const SanctumAuthInterceptorWithRetry({
    required super.storage,
    required super.config,
    required super.logger,
    super.onTokenExpired,
    this.maxRetryAttempts = 1,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestKey = _getRequestKey(err.requestOptions);
    final attempts = _retryAttempts[requestKey] ?? 0;

    // Only retry 401 errors and if we haven't exceeded max attempts
    if (err.response?.statusCode == 401 && attempts < maxRetryAttempts) {
      _retryAttempts[requestKey] = attempts + 1;

      try {
        // Try to refresh the token
        if (_onTokenExpired != null) {
          await _onTokenExpired!();

          // Get the new token
          final newToken = await _storage.getToken(key: _config.storageKey);
          if (newToken != null) {
            // Retry the request with the new token
            final options = err.requestOptions;
            options.headers[SanctumConstants.authorizationHeader] =
                '${SanctumConstants.bearerPrefix}$newToken';

            _logger.info('Retrying request with refreshed token');

            final dio = Dio();
            try {
              final response = await dio.fetch(options);
              _retryAttempts.remove(requestKey);
              handler.resolve(response);
              return;
            } catch (retryError) {
              _logger.warning('Retry attempt failed: $retryError');
            }
          }
        }
      } catch (e, stackTrace) {
        _logger.error('Token refresh failed during retry', e, stackTrace);
      }

      // Clean up retry count if we've exhausted attempts
      _retryAttempts.remove(requestKey);
    }

    // Continue with normal error handling
    super.onError(err, handler);
  }

  /// Generates a unique key for tracking retry attempts per request
  String _getRequestKey(RequestOptions options) {
    return '${options.method}_${options.path}_${options.hashCode}';
  }
}

/// Interceptor configuration for fine-tuning behavior
@immutable
class SanctumAuthInterceptorConfig {
  /// Whether to automatically add tokens to requests
  final bool autoAddTokens;

  /// Whether to handle token expiration automatically
  final bool handleTokenExpiration;

  /// Whether to retry requests after token refresh
  final bool retryAfterRefresh;

  /// Maximum number of retry attempts
  final int maxRetryAttempts;

  /// Paths that should skip authentication
  final Set<String> skipAuthPaths;

  /// Headers that indicate token refresh
  final Set<String> tokenRefreshHeaders;

  /// Creates interceptor configuration
  const SanctumAuthInterceptorConfig({
    this.autoAddTokens = true,
    this.handleTokenExpiration = true,
    this.retryAfterRefresh = true,
    this.maxRetryAttempts = 1,
    this.skipAuthPaths = const {},
    this.tokenRefreshHeaders = const {'x-new-token'},
  });
}