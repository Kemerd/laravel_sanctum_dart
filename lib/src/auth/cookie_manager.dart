import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:meta/meta.dart';

import '../models/auth_config.dart';
import '../exceptions/sanctum_exceptions.dart';
import '../constants/sanctum_constants.dart';
import '../utils/logger.dart';

/// Manager for Laravel Sanctum SPA cookie-based authentication
///
/// This class handles CSRF token management and cookie-based authentication
/// for Single Page Applications (SPAs) using Laravel Sanctum. It manages
/// the XSRF token workflow required for stateful authentication.
///
/// Example usage:
/// ```dart
/// final cookieManager = SanctumCookieManager(dio: dio, config: config);
///
/// // Get CSRF cookie before making authenticated requests
/// await cookieManager.getCsrfCookie();
///
/// // Extract XSRF token for manual inclusion
/// final xsrfToken = await cookieManager.getXsrfToken();
/// ```
@immutable
class SanctumCookieManager {
  /// HTTP client for making requests
  final Dio _dio;

  /// Configuration settings
  final SanctumConfig _config;

  /// Logger for debugging
  final SanctumLogger _logger;

  /// Cookie jar for managing cookies
  late final CookieJar _cookieJar;

  /// Cookie manager interceptor
  late final CookieManager _cookieManager;

  /// Creates a new [SanctumCookieManager] instance
  SanctumCookieManager({
    required Dio dio,
    required SanctumConfig config,
    required SanctumLogger logger,
    CookieJar? cookieJar,
  })  : _dio = dio,
        _config = config,
        _logger = logger {
    _initializeCookieManagement(cookieJar);
  }

  /// Initializes cookie management for the Dio client
  void _initializeCookieManagement(CookieJar? cookieJar) {
    _cookieJar = cookieJar ?? CookieJar();
    _cookieManager = CookieManager(_cookieJar);

    // Add cookie manager to Dio if not already present
    if (!_dio.interceptors.any((i) => i is CookieManager)) {
      _dio.interceptors.add(_cookieManager);
    }

    _logger.debug('Cookie management initialized for SPA authentication');
  }

  /// Gets the CSRF cookie from the server
  ///
  /// This method makes a request to the CSRF cookie endpoint to initialize
  /// CSRF protection for the SPA. The XSRF-TOKEN cookie will be set and
  /// can be used for subsequent authenticated requests.
  ///
  /// This should be called before making any authenticated requests in SPA mode.
  Future<void> getCsrfCookie() async {
    try {
      _logger.debug('Requesting CSRF cookie from server');

      await _dio.get(_config.endpoints.csrfCookie);

      _logger.debug('CSRF cookie retrieved successfully');
    } on DioException catch (e) {
      _logger.error('Failed to get CSRF cookie: ${e.message}');
      throw _handleDioException(e);
    }
  }

  /// Extracts the XSRF token from cookies
  ///
  /// Returns the current XSRF token value that should be included
  /// in the X-XSRF-TOKEN header for authenticated requests.
  ///
  /// Returns null if the XSRF token cookie is not found.
  Future<String?> getXsrfToken() async {
    try {
      final uri = Uri.parse(_config.baseUrl);
      final cookies = await _cookieJar.loadForRequest(uri);

      for (final cookie in cookies) {
        if (cookie.name == SanctumConstants.xsrfTokenCookie) {
          final token = Uri.decodeComponent(cookie.value);
          _logger.debug('XSRF token extracted from cookies');
          return token;
        }
      }

      _logger.debug('XSRF token not found in cookies');
      return null;
    } catch (e, stackTrace) {
      _logger.error('Failed to extract XSRF token', e, stackTrace);
      return null;
    }
  }

  /// Gets the Laravel session cookie value
  ///
  /// Returns the session cookie value used by Laravel for session management.
  /// This is primarily for debugging and monitoring purposes.
  Future<String?> getSessionCookie() async {
    try {
      final uri = Uri.parse(_config.baseUrl);
      final cookies = await _cookieJar.loadForRequest(uri);

      for (final cookie in cookies) {
        if (cookie.name == SanctumConstants.laravelSessionCookie) {
          _logger.debug('Laravel session cookie found');
          return cookie.value;
        }
      }

      _logger.debug('Laravel session cookie not found');
      return null;
    } catch (e, stackTrace) {
      _logger.error('Failed to get session cookie', e, stackTrace);
      return null;
    }
  }

  /// Checks if the current domain is configured as stateful
  ///
  /// Stateful domains are allowed to use cookie-based authentication
  /// and maintain session state with the Laravel backend.
  bool isDomainStateful(String domain) {
    // If no stateful domains are configured, assume current domain is stateful
    if (_config.statefulDomains.isEmpty) {
      return true;
    }

    // Check if domain matches any configured stateful domain
    for (final statefulDomain in _config.statefulDomains) {
      if (_domainMatches(domain, statefulDomain)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if a domain matches a pattern
  ///
  /// Supports wildcards (e.g., "*.example.com" matches "api.example.com")
  bool _domainMatches(String domain, String pattern) {
    if (pattern == domain) return true;

    // Handle wildcard patterns
    if (pattern.startsWith('*.')) {
      final baseDomain = pattern.substring(2);
      return domain.endsWith('.$baseDomain') || domain == baseDomain;
    }

    return false;
  }

  /// Validates that CSRF protection is properly configured
  ///
  /// Checks that the XSRF token is available and can be used for
  /// authenticated requests. Throws an exception if CSRF protection
  /// is not properly set up.
  Future<void> validateCsrfProtection() async {
    final xsrfToken = await getXsrfToken();
    if (xsrfToken == null || xsrfToken.isEmpty) {
      throw SanctumCsrfException.tokenMismatch(
        customMessage: 'CSRF token not found. Call getCsrfCookie() first.',
      );
    }

    _logger.debug('CSRF protection validated successfully');
  }

  /// Gets all cookies for the current domain
  ///
  /// Returns a map of cookie names to values for debugging purposes.
  /// Sensitive cookies are masked in the returned map.
  Future<Map<String, String>> getAllCookies({bool maskSensitive = true}) async {
    try {
      final uri = Uri.parse(_config.baseUrl);
      final cookies = await _cookieJar.loadForRequest(uri);
      final cookieMap = <String, String>{};

      for (final cookie in cookies) {
        if (maskSensitive && _isSensitiveCookie(cookie.name)) {
          cookieMap[cookie.name] = _maskCookieValue(cookie.value);
        } else {
          cookieMap[cookie.name] = cookie.value;
        }
      }

      return cookieMap;
    } catch (e, stackTrace) {
      _logger.error('Failed to get all cookies', e, stackTrace);
      return {};
    }
  }

  /// Clears all cookies for the current domain
  ///
  /// This effectively logs out the user from the SPA session
  /// by removing all authentication-related cookies.
  Future<void> clearCookies() async {
    try {
      final uri = Uri.parse(_config.baseUrl);
      await _cookieJar.delete(uri);

      _logger.debug('All cookies cleared for SPA logout');
    } catch (e, stackTrace) {
      _logger.error('Failed to clear cookies', e, stackTrace);
      rethrow;
    }
  }

  /// Clears only authentication-related cookies
  ///
  /// This removes XSRF and session cookies while preserving
  /// other cookies that might be needed by the application.
  Future<void> clearAuthCookies() async {
    try {
      final uri = Uri.parse(_config.baseUrl);
      final cookies = await _cookieJar.loadForRequest(uri);

      final authCookieNames = {
        SanctumConstants.xsrfTokenCookie,
        SanctumConstants.laravelSessionCookie,
      };

      for (final cookie in cookies) {
        if (authCookieNames.contains(cookie.name)) {
          // Create an expired cookie to delete it
          final expiredCookie = Cookie(cookie.name, '')
            ..domain = cookie.domain
            ..path = cookie.path
            ..expires = DateTime.now().subtract(const Duration(days: 1));

          await _cookieJar.saveFromResponse(uri, [expiredCookie]);
        }
      }

      _logger.debug('Authentication cookies cleared');
    } catch (e, stackTrace) {
      _logger.error('Failed to clear auth cookies', e, stackTrace);
      rethrow;
    }
  }

  /// Gets cookie statistics for monitoring
  ///
  /// Returns information about the current cookie state including
  /// counts and expiration data.
  Future<SanctumCookieStats> getCookieStats() async {
    try {
      final uri = Uri.parse(_config.baseUrl);
      final cookies = await _cookieJar.loadForRequest(uri);

      int totalCount = cookies.length;
      int expiredCount = 0;
      int sessionCount = 0; // Cookies without explicit expiration
      int secureCount = 0;
      int httpOnlyCount = 0;

      final now = DateTime.now();

      for (final cookie in cookies) {
        if (cookie.expires != null && cookie.expires!.isBefore(now)) {
          expiredCount++;
        }

        if (cookie.expires == null) {
          sessionCount++;
        }

        if (cookie.secure) {
          secureCount++;
        }

        if (cookie.httpOnly) {
          httpOnlyCount++;
        }
      }

      return SanctumCookieStats(
        totalCount: totalCount,
        expiredCount: expiredCount,
        sessionCount: sessionCount,
        secureCount: secureCount,
        httpOnlyCount: httpOnlyCount,
        hasXsrfToken: await getXsrfToken() != null,
        hasSessionCookie: await getSessionCookie() != null,
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to get cookie stats', e, stackTrace);
      return const SanctumCookieStats(
        totalCount: 0,
        expiredCount: 0,
        sessionCount: 0,
        secureCount: 0,
        httpOnlyCount: 0,
        hasXsrfToken: false,
        hasSessionCookie: false,
      );
    }
  }

  /// Checks if a cookie name contains sensitive information
  bool _isSensitiveCookie(String cookieName) {
    const sensitiveCookies = {
      SanctumConstants.xsrfTokenCookie,
      SanctumConstants.laravelSessionCookie,
      'remember_token',
      'auth_token',
    };

    return sensitiveCookies.contains(cookieName.toLowerCase());
  }

  /// Masks a cookie value for logging
  String _maskCookieValue(String value) {
    if (value.length <= 8) {
      return '*' * value.length;
    }
    return '${value.substring(0, 4)}${'*' * (value.length - 8)}${value.substring(value.length - 4)}';
  }

  /// Converts Dio exceptions to Sanctum exceptions
  SanctumException _handleDioException(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;

    if (statusCode == 419) {
      // Laravel CSRF token mismatch
      return SanctumCsrfException.tokenMismatch();
    } else if (statusCode == 401) {
      return SanctumAuthenticationException(
        'Authentication failed in SPA mode',
        statusCode: statusCode,
      );
    } else if (statusCode == 403) {
      return SanctumAuthorizationException(
        'Access forbidden in SPA mode',
        statusCode: statusCode,
      );
    }

    // Default to network exception for other errors
    return SanctumNetworkException(
      error.message ?? 'SPA cookie operation failed',
      statusCode: statusCode,
      originalException: error,
    );
  }
}

/// Statistics about cookie state for monitoring
@immutable
class SanctumCookieStats {
  /// Total number of cookies
  final int totalCount;

  /// Number of expired cookies
  final int expiredCount;

  /// Number of session cookies (no explicit expiration)
  final int sessionCount;

  /// Number of secure cookies
  final int secureCount;

  /// Number of HTTP-only cookies
  final int httpOnlyCount;

  /// Whether XSRF token is present
  final bool hasXsrfToken;

  /// Whether Laravel session cookie is present
  final bool hasSessionCookie;

  /// Creates new cookie statistics
  const SanctumCookieStats({
    required this.totalCount,
    required this.expiredCount,
    required this.sessionCount,
    required this.secureCount,
    required this.httpOnlyCount,
    required this.hasXsrfToken,
    required this.hasSessionCookie,
  });

  /// Whether SPA authentication appears to be properly configured
  bool get isProperlyConfigured => hasXsrfToken && hasSessionCookie;

  /// Percentage of secure cookies
  double get securePercentage =>
      totalCount > 0 ? (secureCount / totalCount) * 100 : 0;

  /// Percentage of HTTP-only cookies
  double get httpOnlyPercentage =>
      totalCount > 0 ? (httpOnlyCount / totalCount) * 100 : 0;

  @override
  String toString() {
    return 'SanctumCookieStats{'
        'total: $totalCount, '
        'expired: $expiredCount, '
        'session: $sessionCount, '
        'secure: $secureCount, '
        'httpOnly: $httpOnlyCount, '
        'hasXsrf: $hasXsrfToken, '
        'hasSession: $hasSessionCookie'
        '}';
  }
}