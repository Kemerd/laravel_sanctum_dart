import 'package:meta/meta.dart';
import '../constants/sanctum_constants.dart';

/// Configuration class for Laravel Sanctum authentication
///
/// This class holds all the configuration options needed to set up
/// authentication with a Laravel Sanctum backend. It supports both
/// API token authentication and SPA cookie-based authentication.
///
/// Example:
/// ```dart
/// final config = SanctumConfig(
///   baseUrl: 'https://api.example.com',
///   authMode: SanctumAuthMode.api,
///   timeout: Duration(seconds: 30),
/// );
/// ```
@immutable
class SanctumConfig {
  /// The base URL of your Laravel application
  ///
  /// This should be the root URL without any trailing slashes.
  /// Example: 'https://api.example.com' or 'http://localhost:8000'
  final String baseUrl;

  /// The authentication mode to use
  final SanctumAuthMode authMode;

  /// Storage key for the authentication token
  ///
  /// This key is used to store the token in secure storage.
  /// Default: 'sanctum_auth_token'
  final String storageKey;

  /// Custom endpoints for authentication operations
  final SanctumEndpoints endpoints;

  /// Timeout configuration for HTTP requests
  final SanctumTimeouts timeouts;

  /// Cache configuration for performance optimization
  final SanctumCacheConfig cacheConfig;

  /// Retry configuration for failed requests
  final SanctumRetryConfig retryConfig;

  /// Whether to enable debug logging
  ///
  /// When enabled, detailed logs will be printed for debugging purposes.
  /// Should be disabled in production builds.
  final bool debugMode;

  /// Custom headers to include with all requests
  final Map<String, String> defaultHeaders;

  /// Whether to automatically refresh expired tokens
  final bool autoRefreshTokens;

  /// Stateful domains for SPA authentication
  ///
  /// These domains will maintain stateful authentication using cookies.
  /// Only used when [authMode] is [SanctumAuthMode.spa] or [SanctumAuthMode.hybrid].
  final List<String> statefulDomains;

  /// Creates a new [SanctumConfig] instance
  const SanctumConfig({
    required this.baseUrl,
    this.authMode = SanctumAuthMode.api,
    this.storageKey = SanctumConstants.defaultTokenStorageKey,
    this.endpoints = const SanctumEndpoints(),
    this.timeouts = const SanctumTimeouts(),
    this.cacheConfig = const SanctumCacheConfig(),
    this.retryConfig = const SanctumRetryConfig(),
    this.debugMode = false,
    this.defaultHeaders = const {},
    this.autoRefreshTokens = true,
    this.statefulDomains = const [],
  });

  /// Creates a copy of this config with the given fields replaced
  SanctumConfig copyWith({
    String? baseUrl,
    SanctumAuthMode? authMode,
    String? storageKey,
    SanctumEndpoints? endpoints,
    SanctumTimeouts? timeouts,
    SanctumCacheConfig? cacheConfig,
    SanctumRetryConfig? retryConfig,
    bool? debugMode,
    Map<String, String>? defaultHeaders,
    bool? autoRefreshTokens,
    List<String>? statefulDomains,
  }) {
    return SanctumConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      authMode: authMode ?? this.authMode,
      storageKey: storageKey ?? this.storageKey,
      endpoints: endpoints ?? this.endpoints,
      timeouts: timeouts ?? this.timeouts,
      cacheConfig: cacheConfig ?? this.cacheConfig,
      retryConfig: retryConfig ?? this.retryConfig,
      debugMode: debugMode ?? this.debugMode,
      defaultHeaders: defaultHeaders ?? this.defaultHeaders,
      autoRefreshTokens: autoRefreshTokens ?? this.autoRefreshTokens,
      statefulDomains: statefulDomains ?? this.statefulDomains,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumConfig &&
          runtimeType == other.runtimeType &&
          baseUrl == other.baseUrl &&
          authMode == other.authMode &&
          storageKey == other.storageKey &&
          endpoints == other.endpoints &&
          timeouts == other.timeouts &&
          cacheConfig == other.cacheConfig &&
          retryConfig == other.retryConfig &&
          debugMode == other.debugMode &&
          defaultHeaders == other.defaultHeaders &&
          autoRefreshTokens == other.autoRefreshTokens &&
          statefulDomains == other.statefulDomains;

  @override
  int get hashCode => Object.hash(
        baseUrl,
        authMode,
        storageKey,
        endpoints,
        timeouts,
        cacheConfig,
        retryConfig,
        debugMode,
        defaultHeaders,
        autoRefreshTokens,
        statefulDomains,
      );

  @override
  String toString() {
    return 'SanctumConfig{'
        'baseUrl: $baseUrl, '
        'authMode: $authMode, '
        'storageKey: $storageKey, '
        'debugMode: $debugMode'
        '}';
  }
}

/// Authentication modes supported by Laravel Sanctum
enum SanctumAuthMode {
  /// API token authentication using Bearer tokens
  ///
  /// Best for mobile apps and third-party integrations.
  /// Tokens are stored securely and sent with each request.
  api,

  /// SPA cookie-based authentication
  ///
  /// Best for single-page applications that share the same domain.
  /// Uses Laravel's session authentication with CSRF protection.
  spa,

  /// Hybrid mode supporting both API tokens and SPA authentication
  ///
  /// Automatically detects the best authentication method based on
  /// the request context and available credentials.
  hybrid,
}

/// Configuration for Laravel Sanctum API endpoints
@immutable
class SanctumEndpoints {
  /// Login endpoint for email/password authentication
  final String login;

  /// Registration endpoint for new user signup
  final String register;

  /// Logout endpoint to revoke the current session/token
  final String logout;

  /// User profile endpoint to get authenticated user data
  final String user;

  /// Token creation endpoint for API authentication
  final String createToken;

  /// CSRF cookie endpoint for SPA authentication
  final String csrfCookie;

  /// Token revocation endpoint
  final String revokeTokens;

  /// Token listing endpoint
  final String listTokens;

  /// Creates a new [SanctumEndpoints] instance with default values
  const SanctumEndpoints({
    this.login = SanctumConstants.defaultLoginEndpoint,
    this.register = SanctumConstants.defaultRegisterEndpoint,
    this.logout = SanctumConstants.defaultLogoutEndpoint,
    this.user = SanctumConstants.defaultUserEndpoint,
    this.createToken = SanctumConstants.defaultTokenEndpoint,
    this.csrfCookie = SanctumConstants.defaultCsrfCookieEndpoint,
    this.revokeTokens = SanctumConstants.defaultRevokeTokensEndpoint,
    this.listTokens = SanctumConstants.defaultTokensListEndpoint,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumEndpoints &&
          runtimeType == other.runtimeType &&
          login == other.login &&
          register == other.register &&
          logout == other.logout &&
          user == other.user &&
          createToken == other.createToken &&
          csrfCookie == other.csrfCookie &&
          revokeTokens == other.revokeTokens &&
          listTokens == other.listTokens;

  @override
  int get hashCode => Object.hash(
        login,
        register,
        logout,
        user,
        createToken,
        csrfCookie,
        revokeTokens,
        listTokens,
      );
}

/// Configuration for HTTP request timeouts
@immutable
class SanctumTimeouts {
  /// Connection timeout for establishing HTTP connections
  final Duration connect;

  /// Receive timeout for reading response data
  final Duration receive;

  /// Send timeout for sending request data
  final Duration send;

  /// Creates a new [SanctumTimeouts] instance
  const SanctumTimeouts({
    this.connect = SanctumConstants.defaultConnectTimeout,
    this.receive = SanctumConstants.defaultReceiveTimeout,
    this.send = SanctumConstants.defaultTimeout,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumTimeouts &&
          runtimeType == other.runtimeType &&
          connect == other.connect &&
          receive == other.receive &&
          send == other.send;

  @override
  int get hashCode => Object.hash(connect, receive, send);
}

/// Configuration for caching responses and user data
@immutable
class SanctumCacheConfig {
  /// Whether to enable response caching
  final bool enabled;

  /// Maximum cache size in number of entries
  final int maxSize;

  /// Default cache timeout for responses
  final Duration timeout;

  /// Whether to cache user data
  final bool cacheUserData;

  /// Creates a new [SanctumCacheConfig] instance
  const SanctumCacheConfig({
    this.enabled = true,
    this.maxSize = SanctumConstants.defaultMaxCacheSize,
    this.timeout = SanctumConstants.defaultCacheTimeout,
    this.cacheUserData = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumCacheConfig &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          maxSize == other.maxSize &&
          timeout == other.timeout &&
          cacheUserData == other.cacheUserData;

  @override
  int get hashCode => Object.hash(enabled, maxSize, timeout, cacheUserData);
}

/// Configuration for automatic retry of failed requests
@immutable
class SanctumRetryConfig {
  /// Whether to enable automatic retries
  final bool enabled;

  /// Maximum number of retry attempts
  final int maxRetries;

  /// Initial delay between retries
  final Duration initialDelay;

  /// Multiplier for exponential backoff
  final double backoffMultiplier;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// HTTP status codes that should trigger a retry
  final List<int> retryableStatusCodes;

  /// Creates a new [SanctumRetryConfig] instance
  const SanctumRetryConfig({
    this.enabled = true,
    this.maxRetries = SanctumConstants.defaultMaxRetries,
    this.initialDelay = SanctumConstants.defaultRetryDelay,
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.retryableStatusCodes = const [500, 502, 503, 504, 408, 429],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumRetryConfig &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          maxRetries == other.maxRetries &&
          initialDelay == other.initialDelay &&
          backoffMultiplier == other.backoffMultiplier &&
          maxDelay == other.maxDelay &&
          retryableStatusCodes == other.retryableStatusCodes;

  @override
  int get hashCode => Object.hash(
        enabled,
        maxRetries,
        initialDelay,
        backoffMultiplier,
        maxDelay,
        retryableStatusCodes,
      );
}