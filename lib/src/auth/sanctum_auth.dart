import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import '../models/auth_config.dart';
import '../models/user.dart';
import '../models/token.dart';
import '../models/auth_response.dart';
import '../exceptions/sanctum_exceptions.dart';
import '../constants/sanctum_constants.dart';
import '../utils/storage.dart';
import '../utils/logger.dart';
import '../utils/performance.dart';
import '../interceptors/auth_interceptor.dart';
import '../interceptors/csrf_interceptor.dart';
import '../interceptors/retry_interceptor.dart';
import 'token_manager.dart';
import 'cookie_manager.dart';

/// Main authentication client for Laravel Sanctum
///
/// This is the primary class for interacting with Laravel Sanctum authentication.
/// It provides a comprehensive API for login, registration, token management,
/// and authenticated requests with support for both API tokens and SPA cookies.
///
/// Example usage:
/// ```dart
/// final sanctum = SanctumAuth(
///   baseUrl: 'https://api.example.com',
///   storageKey: 'auth_token',
/// );
///
/// // Login with email/password
/// final loginResponse = await sanctum.login(
///   email: 'user@example.com',
///   password: 'password',
///   deviceName: 'iPhone 12',
/// );
///
/// // Make authenticated requests
/// final user = await sanctum.user();
/// ```
class SanctumAuth {
  /// Configuration for this authentication instance
  final SanctumConfig config;

  /// HTTP client for making requests
  late final Dio _dio;

  /// Secure storage for tokens and user data
  late final SanctumStorage _storage;

  /// Logger for debugging and monitoring
  late final SanctumLogger _logger;

  /// Performance utilities
  late final SanctumPerformance _performance;

  /// Token manager for API token operations
  late final SanctumTokenManager _tokenManager;

  /// Cookie manager for SPA authentication
  late final SanctumCookieManager _cookieManager;

  /// Stream controller for authentication state changes
  final BehaviorSubject<SanctumAuthState> _authStateController =
      BehaviorSubject<SanctumAuthState>.seeded(SanctumAuthState.unauthenticated);

  /// Current authenticated user (cached)
  SanctumUser? _currentUser;

  /// Current authentication token (cached)
  String? _currentToken;

  /// Whether the client has been initialized
  bool _initialized = false;

  /// Completer for initialization
  Completer<void>? _initCompleter;

  /// Creates a new [SanctumAuth] instance
  ///
  /// The [config] parameter contains all configuration options including
  /// the base URL, authentication mode, and various settings.
  SanctumAuth({
    required String baseUrl,
    SanctumAuthMode authMode = SanctumAuthMode.api,
    String storageKey = SanctumConstants.defaultTokenStorageKey,
    SanctumEndpoints endpoints = const SanctumEndpoints(),
    SanctumTimeouts timeouts = const SanctumTimeouts(),
    SanctumCacheConfig cacheConfig = const SanctumCacheConfig(),
    SanctumRetryConfig retryConfig = const SanctumRetryConfig(),
    bool debugMode = false,
    Map<String, String> defaultHeaders = const {},
    bool autoRefreshTokens = true,
    List<String> statefulDomains = const [],
    Map<String, dynamic> Function(String, String, String, List<String>?, bool)? loginRequestTransformer,
    Map<String, dynamic> Function(String, String, String, String, String, List<String>?, Map<String, dynamic>)? registerRequestTransformer,
    SanctumStorage? storage,
    SanctumLogger? logger,
    SanctumPerformance? performance,
  })  : config = SanctumConfig(
          baseUrl: baseUrl,
          authMode: authMode,
          storageKey: storageKey,
          endpoints: endpoints,
          timeouts: timeouts,
          cacheConfig: cacheConfig,
          retryConfig: retryConfig,
          debugMode: debugMode,
          defaultHeaders: defaultHeaders,
          autoRefreshTokens: autoRefreshTokens,
          statefulDomains: statefulDomains,
          loginRequestTransformer: loginRequestTransformer,
          registerRequestTransformer: registerRequestTransformer,
        ) {
    _validateConfig();
    _initializeComponents(storage, logger, performance);
    _setupDio();
    // Initialize asynchronously to avoid blocking the constructor
    // Use scheduleMicrotask to avoid blocking the constructor
    scheduleMicrotask(() => _initialize());
  }

  /// Creates a [SanctumAuth] instance with custom configuration
  SanctumAuth.withConfig(
    this.config, {
    SanctumStorage? storage,
    SanctumLogger? logger,
    SanctumPerformance? performance,
  }) {
    _validateConfig();
    _initializeComponents(storage, logger, performance);
    _setupDio();
    // Initialize asynchronously to avoid blocking the constructor
    scheduleMicrotask(() => _initialize());
  }

  /// Stream of authentication state changes
  ///
  /// Listen to this stream to react to authentication state changes
  /// such as login, logout, or token expiration.
  Stream<SanctumAuthState> get authStateStream => _authStateController.stream;

  /// Current authentication state
  SanctumAuthState get authState => _authStateController.value;

  /// Whether the user is currently authenticated
  bool get isAuthenticated => authState == SanctumAuthState.authenticated;

  /// Whether the user is currently unauthenticated
  bool get isUnauthenticated => authState == SanctumAuthState.unauthenticated;

  /// Whether authentication is currently being verified
  bool get isVerifying => authState == SanctumAuthState.verifying;

  /// Current authenticated user (if available)
  SanctumUser? get currentUser => _currentUser;

  /// Current authentication token (if available)
  String? get currentToken => _currentToken;

  /// Gets the configured Dio instance for making custom requests
  Dio get dio => _dio;

  /// Gets the token manager for advanced token operations
  SanctumTokenManager get tokens => _tokenManager;

  /// Gets the cookie manager for SPA operations
  SanctumCookieManager get cookies => _cookieManager;

  /// Gets performance statistics
  SanctumPerformanceStats get performanceStats => _performance.getStats();

  /// Validates the configuration
  void _validateConfig() {
    if (config.baseUrl.isEmpty) {
      throw SanctumConfigurationException.missingBaseUrl();
    }

    final urlRegex = RegExp(SanctumConstants.urlRegex);
    if (!urlRegex.hasMatch(config.baseUrl)) {
      throw SanctumConfigurationException.invalidUrl(config.baseUrl);
    }
  }

  /// Initializes the component dependencies
  void _initializeComponents(
    SanctumStorage? storage,
    SanctumLogger? logger,
    SanctumPerformance? performance,
  ) {
    _logger = logger ?? SanctumLogger(debugMode: config.debugMode);
    _storage = storage ?? SanctumStorage(logger: _logger);
    _performance = performance ?? SanctumPerformance(logger: _logger);

    // Note: _tokenManager and _cookieManager will be initialized after _dio is set up
  }

  /// Sets up the Dio HTTP client with interceptors
  void _setupDio() {
    _dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.timeouts.connect,
      receiveTimeout: config.timeouts.receive,
      sendTimeout: config.timeouts.send,
      headers: {
        SanctumConstants.acceptHeader: SanctumConstants.acceptJsonValue,
        SanctumConstants.contentTypeHeader: SanctumConstants.jsonContentType,
        SanctumConstants.userAgentHeader: SanctumConstants.userAgent,
        ...config.defaultHeaders,
      },
    ));

    // Initialize managers now that Dio is available
    _tokenManager = SanctumTokenManager(
      dio: _dio,
      config: config,
      storage: _storage,
      logger: _logger,
    );

    _cookieManager = SanctumCookieManager(
      dio: _dio,
      config: config,
      logger: _logger,
    );

    // Add interceptors in the correct order
    _dio.interceptors.addAll([
      // Retry interceptor (should be first to retry all failures)
      SanctumRetryInterceptor(config: config.retryConfig, logger: _logger),

      // CSRF interceptor (for SPA mode)
      if (config.authMode == SanctumAuthMode.spa ||
          config.authMode == SanctumAuthMode.hybrid)
        SanctumCsrfInterceptor(
          cookieManager: _cookieManager,
          logger: _logger,
        ),

      // Auth interceptor (adds tokens to requests)
      SanctumAuthInterceptor(
        storage: _storage,
        config: config,
        logger: _logger,
        onTokenExpired: _handleTokenExpired,
      ),

      // Logging interceptor (should be last to log everything)
      if (config.debugMode) _createLoggingInterceptor(),
    ]);
  }

  /// Creates a logging interceptor for debugging
  Interceptor _createLoggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        _logger.logRequest(
          method: options.method,
          url: '${options.baseUrl}${options.path}',
          headers: options.headers.cast<String, dynamic>(),
          body: options.data,
        );
        handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.logResponse(
          statusCode: response.statusCode ?? 0,
          url: response.requestOptions.uri.toString(),
          headers: response.headers.map.cast<String, dynamic>(),
          body: response.data,
        );
        handler.next(response);
      },
      onError: (error, handler) {
        _logger.error(
          'HTTP Error: ${error.message}',
          error,
          error.stackTrace,
        );
        handler.next(error);
      },
    );
  }

  /// Initializes the authentication state from stored data
  Future<void> _initialize() async {
    if (_initialized) return;

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      _authStateController.add(SanctumAuthState.verifying);

      // Load stored token and user data
      final storedToken = await _storage.getToken(key: config.storageKey);
      final storedUser = await _storage.getUser();

      if (storedToken != null) {
        _currentToken = storedToken;

        // Verify token is still valid by attempting to fetch user
        if (storedUser != null) {
          _currentUser = storedUser;
          _authStateController.add(SanctumAuthState.authenticated);
          _logger.logAuthEvent(
            event: 'SESSION_RESTORED',
            userId: storedUser.id.toString(),
          );
        } else {
          // Try to fetch user with stored token
          try {
            final user = await _fetchUser();
            _currentUser = user;
            await _storage.setUser(user);
            _authStateController.add(SanctumAuthState.authenticated);
            _logger.logAuthEvent(
              event: 'SESSION_VALIDATED',
              userId: user.id.toString(),
            );
          } catch (e) {
            // Token is invalid, clear it
            await _clearAuthData();
            _authStateController.add(SanctumAuthState.unauthenticated);
            _logger.logAuthEvent(event: 'SESSION_INVALID');
          }
        }
      } else {
        _authStateController.add(SanctumAuthState.unauthenticated);
      }

      _initialized = true;
      _initCompleter!.complete();
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize auth state', e, stackTrace);
      _authStateController.add(SanctumAuthState.unauthenticated);
      _initCompleter!.completeError(e);
    } finally {
      _initCompleter = null;
    }
  }

  /// Ensures the client is initialized before operations
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _initialize();
    }
  }

  /// Authenticates a user with email and password
  ///
  /// Returns the login response containing user data and token information.
  /// The token is automatically stored and future requests will be authenticated.
  ///
  /// [email] - User's email address
  /// [password] - User's password
  /// [deviceName] - Human-readable device name for the token
  /// [abilities] - List of abilities to grant to the token (defaults to all)
  /// [remember] - Whether to set longer token expiration
  Future<SanctumLoginResponse> login({
    required String email,
    required String password,
    required String deviceName,
    List<String> abilities = const ['*'],
    bool remember = false,
  }) async {
    await _ensureInitialized();

    return await _performance.measureOperation('login', () async {
      try {
        _logger.logAuthEvent(
          event: 'LOGIN_ATTEMPT',
          additionalData: {'email': email, 'device_name': deviceName},
        );

        // For SPA mode, get CSRF token first
        if (config.authMode == SanctumAuthMode.spa ||
            config.authMode == SanctumAuthMode.hybrid) {
          await _cookieManager.getCsrfCookie();
        }

        // Use custom request transformer if provided, otherwise use default format
        final requestData = config.loginRequestTransformer?.call(
          email,
          password,
          deviceName,
          abilities,
          remember,
        ) ?? {
          'email': email,
          'password': password,
          'device_name': deviceName,
          if (abilities.isNotEmpty) 'abilities': abilities,
          if (remember) 'remember': true,
        };

        // Debug logging for development
        if (config.debugMode) {
          _logger.debug('Login request data: $requestData');
        }

        final response = await _dio.post(
          config.endpoints.login,
          data: requestData,
        );

        final loginResponse = SanctumLoginResponse.fromJson(
          response.data as Map<String, dynamic>,
        );

        // Store authentication data
        await _storeAuthData(
          token: loginResponse.token,
          user: loginResponse.user.toFullUser(),
          abilities: loginResponse.abilities,
        );

        _authStateController.add(SanctumAuthState.authenticated);

        _logger.logAuthEvent(
          event: 'LOGIN_SUCCESS',
          userId: loginResponse.user.id.toString(),
          tokenName: deviceName,
          abilities: loginResponse.abilities,
        );

        return loginResponse;
      } on DioException catch (e) {
        _logger.logAuthEvent(
          event: 'LOGIN_FAILED',
          additionalData: {'error': e.message},
        );
        throw _handleDioException(e);
      }
    });
  }

  /// Registers a new user account
  ///
  /// Returns the registration response containing user data and token information.
  /// The user is automatically logged in after successful registration.
  Future<SanctumRegisterResponse> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String deviceName,
    List<String> abilities = const ['*'],
    Map<String, dynamic> additionalFields = const {},
  }) async {
    await _ensureInitialized();

    return await _performance.measureOperation('register', () async {
      try {
        _logger.logAuthEvent(
          event: 'REGISTER_ATTEMPT',
          additionalData: {
            'name': name,
            'email': email,
            'device_name': deviceName,
          },
        );

        // For SPA mode, get CSRF token first
        if (config.authMode == SanctumAuthMode.spa ||
            config.authMode == SanctumAuthMode.hybrid) {
          await _cookieManager.getCsrfCookie();
        }

        // Use custom request transformer if provided, otherwise use default format
        final requestData = config.registerRequestTransformer?.call(
          name,
          email,
          password,
          passwordConfirmation,
          deviceName,
          abilities,
          additionalFields,
        ) ?? {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'device_name': deviceName,
          if (abilities.isNotEmpty) 'abilities': abilities,
          ...additionalFields,
        };

        final response = await _dio.post(
          config.endpoints.register,
          data: requestData,
        );

        final registerResponse = SanctumRegisterResponse.fromJson(
          response.data as Map<String, dynamic>,
        );

        // Store authentication data
        await _storeAuthData(
          token: registerResponse.token,
          user: registerResponse.user.toFullUser(),
          abilities: registerResponse.abilities,
        );

        _authStateController.add(SanctumAuthState.authenticated);

        _logger.logAuthEvent(
          event: 'REGISTER_SUCCESS',
          userId: registerResponse.user.id.toString(),
          tokenName: deviceName,
          abilities: registerResponse.abilities,
        );

        return registerResponse;
      } on DioException catch (e) {
        _logger.logAuthEvent(
          event: 'REGISTER_FAILED',
          additionalData: {'error': e.message},
        );
        throw _handleDioException(e);
      }
    });
  }

  /// Logs out the current user
  ///
  /// Revokes the current authentication token and clears stored data.
  /// In SPA mode, this also invalidates the session on the server.
  Future<SanctumLogoutResponse> logout() async {
    await _ensureInitialized();

    if (!isAuthenticated) {
      throw SanctumAuthenticationException(
        'No authenticated user to log out',
        statusCode: 401,
      );
    }

    return await _performance.measureOperation('logout', () async {
      try {
        _logger.logAuthEvent(
          event: 'LOGOUT_ATTEMPT',
          userId: _currentUser?.id.toString(),
        );

        final response = await _dio.post(config.endpoints.logout);

        final logoutResponse = SanctumLogoutResponse.fromJson(
          response.data as Map<String, dynamic>,
        );

        await _clearAuthData();
        _authStateController.add(SanctumAuthState.unauthenticated);

        _logger.logAuthEvent(event: 'LOGOUT_SUCCESS');

        return logoutResponse;
      } on DioException catch (e) {
        // Even if the server request fails, clear local data
        await _clearAuthData();
        _authStateController.add(SanctumAuthState.unauthenticated);

        _logger.logAuthEvent(
          event: 'LOGOUT_FAILED',
          additionalData: {'error': e.message},
        );

        throw _handleDioException(e);
      }
    });
  }

  /// Gets the currently authenticated user
  ///
  /// If [forceRefresh] is true, fetches fresh user data from the server.
  /// Otherwise, returns cached user data if available.
  Future<SanctumUser> user({bool forceRefresh = false}) async {
    await _ensureInitialized();

    if (!isAuthenticated) {
      throw SanctumAuthenticationException(
        'User is not authenticated',
        statusCode: 401,
      );
    }

    if (!forceRefresh && _currentUser != null) {
      return _currentUser!;
    }

    return await _performance.measureOperation('fetch_user', () async {
      final user = await _fetchUser();
      _currentUser = user;
      await _storage.setUser(user);
      return user;
    });
  }

  /// Fetches user data from the server
  Future<SanctumUser> _fetchUser() async {
    try {
      final response = await _dio.get(config.endpoints.user);
      return SanctumUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Refreshes the authentication token (if supported)
  ///
  /// Some Laravel setups support token refresh. This method attempts
  /// to get a new token using the current refresh token.
  Future<String> refreshToken() async {
    await _ensureInitialized();

    if (!isAuthenticated) {
      throw SanctumAuthenticationException(
        'No authenticated user to refresh token for',
        statusCode: 401,
      );
    }

    return await _performance.measureOperation('refresh_token', () async {
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null) {
          throw SanctumTokenException(
            'No refresh token available',
            statusCode: 401,
          );
        }

        final response = await _dio.post(
          config.endpoints.refreshToken,
          data: {'refresh_token': refreshToken},
        );

        final newToken = response.data['token'] as String;
        await _storage.setToken(newToken, key: config.storageKey);
        _currentToken = newToken;

        _logger.logTokenOperation(
          operation: 'REFRESH',
          tokenName: 'Authentication Token',
        );

        return newToken;
      } on DioException catch (e) {
        throw _handleDioException(e);
      }
    });
  }

  /// Checks if the current token has a specific ability
  Future<bool> hasAbility(String ability) async {
    await _ensureInitialized();

    if (!isAuthenticated) return false;

    final abilities = await _storage.getTokenAbilities();
    if (abilities == null) return true; // Assume all abilities if not stored

    return abilities.contains('*') || abilities.contains(ability);
  }

  /// Checks if the current token has any of the specified abilities
  Future<bool> hasAnyAbility(List<String> requiredAbilities) async {
    await _ensureInitialized();

    if (!isAuthenticated) return false;

    final abilities = await _storage.getTokenAbilities();
    if (abilities == null) return true; // Assume all abilities if not stored

    if (abilities.contains('*')) return true;

    return requiredAbilities.any((ability) => abilities.contains(ability));
  }

  /// Checks if the current token has all of the specified abilities
  Future<bool> hasAllAbilities(List<String> requiredAbilities) async {
    await _ensureInitialized();

    if (!isAuthenticated) return false;

    final abilities = await _storage.getTokenAbilities();
    if (abilities == null) return true; // Assume all abilities if not stored

    if (abilities.contains('*')) return true;

    return requiredAbilities.every((ability) => abilities.contains(ability));
  }

  /// Stores authentication data securely
  Future<void> _storeAuthData({
    required String token,
    required SanctumUser user,
    List<String>? abilities,
  }) async {
    await Future.wait([
      _storage.setToken(token, key: config.storageKey),
      _storage.setUser(user),
      if (abilities != null) _storage.setTokenAbilities(abilities),
    ]);

    _currentToken = token;
    _currentUser = user;
  }

  /// Clears all authentication data
  Future<void> _clearAuthData() async {
    await _storage.clearAll();
    _currentToken = null;
    _currentUser = null;
  }

  /// Handles token expiration
  Future<void> _handleTokenExpired() async {
    _logger.logAuthEvent(event: 'TOKEN_EXPIRED');

    if (config.autoRefreshTokens) {
      try {
        await refreshToken();
        _logger.logAuthEvent(event: 'TOKEN_AUTO_REFRESHED');
        return;
      } catch (e) {
        _logger.warning('Failed to auto-refresh token: $e');
      }
    }

    // If refresh failed or not enabled, clear auth data
    await _clearAuthData();
    _authStateController.add(SanctumAuthState.unauthenticated);
  }

  /// Converts Dio exceptions to Sanctum exceptions
  SanctumException _handleDioException(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final data = response?.data;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return SanctumNetworkException.timeout(
          timeout: Duration(
            milliseconds: (error.requestOptions.connectTimeout as int?) ?? 30000,
          ),
        );

      case DioExceptionType.connectionError:
        return SanctumNetworkException.connectionFailed(
          originalException: error,
        );

      case DioExceptionType.badResponse:
        if (statusCode != null) {
          if (statusCode == 401) {
            return SanctumAuthenticationException.invalidCredentials();
          } else if (statusCode == 403) {
            return SanctumAuthorizationException(
              'Access forbidden',
              statusCode: statusCode,
            );
          } else if (statusCode == 422 && data is Map<String, dynamic>) {
            final errors = <String, List<String>>{};
            if (data['errors'] != null) {
              final errorData = data['errors'] as Map<String, dynamic>;
              for (final entry in errorData.entries) {
                errors[entry.key] = List<String>.from(entry.value);
              }
            }
            return SanctumValidationException.fromResponse(errors: errors);
          } else if (statusCode == 429) {
            return SanctumRateLimitException.fromHeaders(
              headers: response?.headers.map,
            );
          } else if (statusCode >= 500) {
            return SanctumNetworkException.serverError(
              statusCode: statusCode,
              details: data is Map<String, dynamic> ? data : null,
            );
          }
        }
        break;

      case DioExceptionType.cancel:
        return SanctumNetworkException(
          'Request was cancelled',
          originalException: error,
        );

      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return SanctumNetworkException.connectionFailed(
            originalException: error.error,
          );
        }
        break;

      default:
        break;
    }

    return SanctumNetworkException(
      error.message ?? 'An unknown network error occurred',
      originalException: error,
      statusCode: statusCode,
    );
  }

  /// Disposes of resources and closes streams
  void dispose() {
    _authStateController.close();
    _performance.dispose();
    _dio.close();
  }
}

/// Represents the current authentication state
enum SanctumAuthState {
  /// User is not authenticated
  unauthenticated,

  /// Authentication state is being verified
  verifying,

  /// User is authenticated
  authenticated,
}