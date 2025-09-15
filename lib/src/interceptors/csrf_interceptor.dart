import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../auth/cookie_manager.dart';
import '../constants/sanctum_constants.dart';
import '../exceptions/sanctum_exceptions.dart';
import '../utils/logger.dart';

/// Interceptor that automatically handles CSRF protection for SPA requests
///
/// This interceptor manages CSRF tokens for Single Page Application (SPA)
/// authentication by:
/// - Automatically fetching CSRF cookies when needed
/// - Adding X-XSRF-TOKEN headers to state-changing requests
/// - Handling CSRF token mismatch errors
/// - Refreshing CSRF tokens when they expire
@immutable
class SanctumCsrfInterceptor extends Interceptor {
  /// Cookie manager for CSRF operations
  final SanctumCookieManager _cookieManager;

  /// Logger for debugging
  final SanctumLogger _logger;

  /// HTTP methods that require CSRF protection
  final Set<String> _statefulMethods;

  /// Whether to automatically refresh CSRF tokens on mismatch
  final bool _autoRefreshCsrf;

  /// Cache for XSRF token to avoid repeated cookie lookups
  String? _cachedXsrfToken;

  /// Creates a new [SanctumCsrfInterceptor] instance
  SanctumCsrfInterceptor({
    required SanctumCookieManager cookieManager,
    required SanctumLogger logger,
    Set<String>? statefulMethods,
    bool autoRefreshCsrf = true,
  })  : _cookieManager = cookieManager,
        _logger = logger,
        _statefulMethods = statefulMethods ??
            {'POST', 'PUT', 'PATCH', 'DELETE', 'CONNECT', 'OPTIONS', 'TRACE'},
        _autoRefreshCsrf = autoRefreshCsrf;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // Only add CSRF protection for stateful methods
      if (_requiresCsrfProtection(options)) {
        await _addCsrfToken(options);
      }

      handler.next(options);
    } catch (e, stackTrace) {
      _logger.error('Failed to add CSRF token to request', e, stackTrace);
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
    // Update cached XSRF token if response contains a new one
    _updateCachedXsrfToken(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    try {
      // Handle CSRF token mismatch errors
      if (_isCsrfError(err)) {
        await _handleCsrfError(err, handler);
        return;
      }

      handler.next(err);
    } catch (e, stackTrace) {
      _logger.error('Error in CSRF interceptor error handler', e, stackTrace);
      handler.next(err);
    }
  }

  /// Checks if a request requires CSRF protection
  bool _requiresCsrfProtection(RequestOptions options) {
    // Skip CSRF for GET and HEAD requests
    if (!_statefulMethods.contains(options.method.toUpperCase())) {
      return false;
    }

    // Skip CSRF for CSRF cookie endpoint itself
    if (options.path.endsWith('/sanctum/csrf-cookie')) {
      return false;
    }

    // Skip if XSRF header already exists
    if (options.headers.containsKey(SanctumConstants.xsrfTokenHeader)) {
      _logger.debug('XSRF token header already present, skipping injection');
      return false;
    }

    return true;
  }

  /// Adds CSRF token to the request headers
  Future<void> _addCsrfToken(RequestOptions options) async {
    // Get XSRF token from cache or cookies
    String? xsrfToken = _cachedXsrfToken;

    if (xsrfToken == null || xsrfToken.isEmpty) {
      xsrfToken = await _cookieManager.getXsrfToken();

      // If no token is available, try to get CSRF cookie
      if (xsrfToken == null || xsrfToken.isEmpty) {
        _logger.debug('No XSRF token found, fetching CSRF cookie');
        await _cookieManager.getCsrfCookie();
        xsrfToken = await _cookieManager.getXsrfToken();
      }
    }

    if (xsrfToken != null && xsrfToken.isNotEmpty) {
      options.headers[SanctumConstants.xsrfTokenHeader] = xsrfToken;
      _cachedXsrfToken = xsrfToken;

      _logger.debug(
        'CSRF token added to request: ${options.method} ${options.path}',
      );
    } else {
      _logger.warning(
        'No CSRF token available for protected request: ${options.method} ${options.path}',
      );
    }
  }

  /// Updates the cached XSRF token from response headers or cookies
  void _updateCachedXsrfToken(Response response) {
    // Check if response contains new XSRF token in headers
    final newXsrfToken = response.headers.value('x-xsrf-token');
    if (newXsrfToken != null && newXsrfToken.isNotEmpty) {
      _cachedXsrfToken = newXsrfToken;
      _logger.debug('XSRF token updated from response headers');
    }
  }

  /// Checks if an error is a CSRF-related error
  bool _isCsrfError(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;

    // Laravel returns 419 for CSRF token mismatch
    if (statusCode == 419) {
      return true;
    }

    // Check error message for CSRF-related content
    if (response?.data is Map<String, dynamic>) {
      final data = response!.data as Map<String, dynamic>;
      final message = data['message']?.toString().toLowerCase() ?? '';

      if (message.contains('csrf') ||
          message.contains('token mismatch') ||
          message.contains('page expired')) {
        return true;
      }
    }

    return false;
  }

  /// Handles CSRF token mismatch errors
  Future<void> _handleCsrfError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    _logger.warning('CSRF token mismatch detected');

    if (_autoRefreshCsrf) {
      try {
        // Clear cached token
        _cachedXsrfToken = null;

        // Get fresh CSRF cookie
        await _cookieManager.getCsrfCookie();
        final newXsrfToken = await _cookieManager.getXsrfToken();

        if (newXsrfToken != null && newXsrfToken.isNotEmpty) {
          _cachedXsrfToken = newXsrfToken;

          // Retry the original request with new CSRF token
          final options = error.requestOptions;
          options.headers[SanctumConstants.xsrfTokenHeader] = newXsrfToken;

          _logger.info('Retrying request with fresh CSRF token');

          final dio = Dio();
          try {
            final response = await dio.fetch(options);
            handler.resolve(response);
            return;
          } catch (retryError) {
            _logger.warning('CSRF retry failed: $retryError');
          }
        }
      } catch (e, stackTrace) {
        _logger.error('Failed to refresh CSRF token', e, stackTrace);
      }
    }

    // If auto-refresh is disabled or failed, continue with the original error
    handler.next(error);
  }

  /// Validates CSRF configuration
  Future<bool> validateCsrfConfig() async {
    try {
      // Check if we can get CSRF cookie
      await _cookieManager.getCsrfCookie();

      // Check if XSRF token is available
      final xsrfToken = await _cookieManager.getXsrfToken();

      if (xsrfToken == null || xsrfToken.isEmpty) {
        _logger.warning('CSRF validation failed: No XSRF token available');
        return false;
      }

      _cachedXsrfToken = xsrfToken;
      _logger.debug('CSRF configuration validated successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.error('CSRF validation failed', e, stackTrace);
      return false;
    }
  }

  /// Clears the cached XSRF token
  void clearCachedToken() {
    _cachedXsrfToken = null;
    _logger.debug('Cached XSRF token cleared');
  }

  /// Gets the current cached XSRF token
  String? get cachedXsrfToken => _cachedXsrfToken;

  /// Checks if CSRF protection is properly configured
  Future<bool> isCsrfProtected() async {
    try {
      final xsrfToken = await _cookieManager.getXsrfToken();
      return xsrfToken != null && xsrfToken.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Gets CSRF protection statistics
  Future<SanctumCsrfStats> getStats() async {
    try {
      final hasXsrfToken = await _cookieManager.getXsrfToken() != null;
      final hasSessionCookie = await _cookieManager.getSessionCookie() != null;
      final hasCachedToken = _cachedXsrfToken != null;

      return SanctumCsrfStats(
        hasXsrfToken: hasXsrfToken,
        hasSessionCookie: hasSessionCookie,
        hasCachedToken: hasCachedToken,
        autoRefreshEnabled: _autoRefreshCsrf,
        protectedMethods: _statefulMethods.toList(),
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to get CSRF stats', e, stackTrace);
      return SanctumCsrfStats(
        hasXsrfToken: false,
        hasSessionCookie: false,
        hasCachedToken: false,
        autoRefreshEnabled: _autoRefreshCsrf,
        protectedMethods: _statefulMethods.toList(),
      );
    }
  }

  /// Manually refreshes the CSRF token
  Future<bool> refreshCsrfToken() async {
    try {
      _logger.debug('Manually refreshing CSRF token');

      // Clear cached token
      _cachedXsrfToken = null;

      // Get fresh CSRF cookie
      await _cookieManager.getCsrfCookie();

      // Update cached token
      final newToken = await _cookieManager.getXsrfToken();
      if (newToken != null && newToken.isNotEmpty) {
        _cachedXsrfToken = newToken;
        _logger.debug('CSRF token refreshed successfully');
        return true;
      }

      _logger.warning('Failed to get new CSRF token after refresh');
      return false;
    } catch (e, stackTrace) {
      _logger.error('Failed to refresh CSRF token', e, stackTrace);
      return false;
    }
  }

  /// Preloads CSRF protection for better performance
  Future<void> preloadCsrfProtection() async {
    try {
      _logger.debug('Preloading CSRF protection');

      await _cookieManager.getCsrfCookie();
      final xsrfToken = await _cookieManager.getXsrfToken();

      if (xsrfToken != null && xsrfToken.isNotEmpty) {
        _cachedXsrfToken = xsrfToken;
        _logger.debug('CSRF protection preloaded successfully');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to preload CSRF protection', e, stackTrace);
    }
  }
}

/// Statistics about CSRF protection state
@immutable
class SanctumCsrfStats {
  /// Whether XSRF token is available
  final bool hasXsrfToken;

  /// Whether session cookie is available
  final bool hasSessionCookie;

  /// Whether token is cached in memory
  final bool hasCachedToken;

  /// Whether auto-refresh is enabled
  final bool autoRefreshEnabled;

  /// HTTP methods that are protected
  final List<String> protectedMethods;

  /// Creates CSRF statistics
  const SanctumCsrfStats({
    required this.hasXsrfToken,
    required this.hasSessionCookie,
    required this.hasCachedToken,
    required this.autoRefreshEnabled,
    required this.protectedMethods,
  });

  /// Whether CSRF protection is fully operational
  bool get isFullyProtected => hasXsrfToken && hasSessionCookie;

  /// Number of protected HTTP methods
  int get protectedMethodCount => protectedMethods.length;

  @override
  String toString() {
    return 'SanctumCsrfStats{'
        'hasXsrfToken: $hasXsrfToken, '
        'hasSessionCookie: $hasSessionCookie, '
        'hasCachedToken: $hasCachedToken, '
        'autoRefreshEnabled: $autoRefreshEnabled, '
        'protectedMethods: $protectedMethodCount'
        '}';
  }
}

/// Configuration for CSRF interceptor behavior
@immutable
class SanctumCsrfInterceptorConfig {
  /// HTTP methods that require CSRF protection
  final Set<String> statefulMethods;

  /// Whether to automatically refresh CSRF tokens on mismatch
  final bool autoRefreshCsrf;

  /// Whether to cache XSRF tokens in memory
  final bool cacheXsrfToken;

  /// Whether to preload CSRF protection on initialization
  final bool preloadCsrfProtection;

  /// Custom header name for XSRF token
  final String xsrfHeaderName;

  /// Creates CSRF interceptor configuration
  const SanctumCsrfInterceptorConfig({
    this.statefulMethods = const {'POST', 'PUT', 'PATCH', 'DELETE'},
    this.autoRefreshCsrf = true,
    this.cacheXsrfToken = true,
    this.preloadCsrfProtection = false,
    this.xsrfHeaderName = SanctumConstants.xsrfTokenHeader,
  });
}