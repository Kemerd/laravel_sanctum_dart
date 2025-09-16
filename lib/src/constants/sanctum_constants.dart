/// Constants used throughout the Laravel Sanctum Dart package
///
/// Contains default values, endpoints, headers, and configuration options
/// that are commonly used when interacting with Laravel Sanctum APIs.
class SanctumConstants {
  /// Default endpoints for Laravel Sanctum authentication
  static const String defaultLoginEndpoint = '/login';
  static const String defaultRegisterEndpoint = '/register';
  static const String defaultLogoutEndpoint = '/logout';
  static const String defaultUserEndpoint = '/api/user';
  static const String defaultTokenEndpoint = '/sanctum/token';
  static const String defaultCsrfCookieEndpoint = '/sanctum/csrf-cookie';
  static const String defaultRevokeTokensEndpoint = '/api/tokens/revoke';
  static const String defaultTokensListEndpoint = '/api/tokens';
  static const String defaultRefreshTokenEndpoint = '/api/refresh';

  /// HTTP headers used in authentication requests
  static const String authorizationHeader = 'Authorization';
  static const String acceptHeader = 'Accept';
  static const String contentTypeHeader = 'Content-Type';
  static const String xsrfTokenHeader = 'X-XSRF-TOKEN';
  static const String refererHeader = 'Referer';
  static const String originHeader = 'Origin';
  static const String userAgentHeader = 'User-Agent';

  /// Header values
  static const String jsonContentType = 'application/json';
  static const String formContentType = 'application/x-www-form-urlencoded';
  static const String bearerPrefix = 'Bearer ';
  static const String acceptJsonValue = 'application/json';

  /// Cookie names
  static const String xsrfTokenCookie = 'XSRF-TOKEN';
  static const String laravelSessionCookie = 'laravel_session';

  /// Storage keys for secure storage
  static const String defaultTokenStorageKey = 'sanctum_auth_token';
  static const String defaultUserStorageKey = 'sanctum_user_data';
  static const String defaultRefreshTokenKey = 'sanctum_refresh_token';
  static const String defaultAbilitiesKey = 'sanctum_token_abilities';

  /// Default configuration values
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration defaultConnectTimeout = Duration(seconds: 15);
  static const Duration defaultReceiveTimeout = Duration(seconds: 30);
  static const Duration defaultCacheTimeout = Duration(minutes: 5);
  static const Duration defaultRetryDelay = Duration(seconds: 1);
  static const int defaultMaxRetries = 3;
  static const int defaultMaxCacheSize = 100;

  /// Authentication modes
  static const String authModeApi = 'api';
  static const String authModeSpa = 'spa';
  static const String authModeHybrid = 'hybrid';

  /// Token abilities (common scopes)
  static const String abilityAll = '*';
  static const String abilityRead = 'read';
  static const String abilityWrite = 'write';
  static const String abilityDelete = 'delete';
  static const String abilityUpdate = 'update';
  static const String abilityCreate = 'create';

  /// Error codes
  static const String errorInvalidCredentials = 'INVALID_CREDENTIALS';
  static const String errorTokenExpired = 'TOKEN_EXPIRED';
  static const String errorTokenInvalid = 'TOKEN_INVALID';
  static const String errorUnauthorized = 'UNAUTHORIZED';
  static const String errorForbidden = 'FORBIDDEN';
  static const String errorNetworkError = 'NETWORK_ERROR';
  static const String errorServerError = 'SERVER_ERROR';
  static const String errorValidationFailed = 'VALIDATION_FAILED';
  static const String errorCsrfMismatch = 'CSRF_MISMATCH';
  static const String errorRateLimited = 'RATE_LIMITED';

  /// HTTP status codes
  static const int statusOk = 200;
  static const int statusCreated = 201;
  static const int statusNoContent = 204;
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusUnprocessableEntity = 422;
  static const int statusTooManyRequests = 429;
  static const int statusInternalServerError = 500;
  static const int statusBadGateway = 502;
  static const int statusServiceUnavailable = 503;

  /// User agent string for the package
  static const String userAgent = 'Laravel-Sanctum-Dart/1.0.0';

  /// Regular expressions for validation
  static const String emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String urlRegex = r'^https?://[^\s/$.?#].[^\s]*$';

  /// Default device names for different platforms
  static const String defaultAndroidDeviceName = 'Android Device';
  static const String defaultIosDeviceName = 'iOS Device';
  static const String defaultWebDeviceName = 'Web Browser';
  static const String defaultDesktopDeviceName = 'Desktop App';

  /// Performance optimization settings
  static const int defaultConnectionPoolSize = 5;
  static const Duration defaultKeepAliveDuration = Duration(seconds: 15);
  static const int defaultConcurrentRequests = 6;

  /// Logging levels
  static const String logLevelOff = 'OFF';
  static const String logLevelError = 'ERROR';
  static const String logLevelWarning = 'WARNING';
  static const String logLevelInfo = 'INFO';
  static const String logLevelDebug = 'DEBUG';
  static const String logLevelVerbose = 'VERBOSE';
}