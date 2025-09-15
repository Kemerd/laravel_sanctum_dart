import 'package:flutter/foundation.dart';
import 'package:laravel_sanctum_dart/laravel_sanctum_dart.dart';

/// Authentication provider that manages app-wide authentication state
class AuthProvider extends ChangeNotifier {
  /// The Sanctum authentication client
  late final SanctumAuth _sanctum;

  /// Current authentication state
  SanctumAuthState _authState = SanctumAuthState.verifying;

  /// Current authenticated user
  SanctumUser? _currentUser;

  /// Error message (if any)
  String? _errorMessage;

  /// Whether an operation is in progress
  bool _isLoading = false;

  /// Performance statistics
  SanctumPerformanceStats? _performanceStats;

  /// Creates a new AuthProvider and initializes Sanctum
  AuthProvider() {
    _initializeSanctum();
  }

  /// Gets the current authentication state
  SanctumAuthState get authState => _authState;

  /// Gets the current user
  SanctumUser? get currentUser => _currentUser;

  /// Gets the error message
  String? get errorMessage => _errorMessage;

  /// Whether an operation is in progress
  bool get isLoading => _isLoading;

  /// Whether the user is authenticated
  bool get isAuthenticated => _authState == SanctumAuthState.authenticated;

  /// Gets performance statistics
  SanctumPerformanceStats? get performanceStats => _performanceStats;

  /// Gets the Sanctum client for advanced operations
  SanctumAuth get sanctum => _sanctum;

  /// Initializes the Sanctum client
  void _initializeSanctum() {
    _sanctum = SanctumAuth(
      baseUrl: 'https://jsonplaceholder.typicode.com', // Demo API
      authMode: SanctumAuthMode.api,
      debugMode: kDebugMode,
      autoRefreshTokens: true,
      cacheConfig: const SanctumCacheConfig(
        enabled: true,
        maxSize: 50,
        timeout: Duration(minutes: 5),
      ),
      retryConfig: const SanctumRetryConfig(
        enabled: true,
        maxRetries: 3,
        initialDelay: Duration(seconds: 1),
      ),
    );

    // Listen to authentication state changes
    _sanctum.authStateStream.listen((state) {
      _authState = state;
      _currentUser = _sanctum.currentUser;
      _performanceStats = _sanctum.performanceStats;
      notifyListeners();
    });
  }

  /// Clears the current error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Sets error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Logs in with email and password
  Future<bool> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // For demo purposes, we'll simulate a login since jsonplaceholder
      // doesn't have actual authentication
      await Future.delayed(const Duration(seconds: 1));

      // Create a mock login response
      final mockUser = SanctumUserBasic(
        id: 1,
        name: email.split('@').first.toUpperCase(),
        email: email,
      );

      // Simulate storing the token
      await _sanctum.dio.options.headers.addAll({
        'Authorization': 'Bearer demo-token-${DateTime.now().millisecondsSinceEpoch}',
      });

      _currentUser = mockUser.toFullUser();
      _authState = SanctumAuthState.authenticated;

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _setError(_getErrorMessage(e));
      return false;
    }
  }

  /// Registers a new user
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? deviceName,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Validate passwords match
      if (password != passwordConfirmation) {
        throw Exception('Passwords do not match');
      }

      // For demo purposes, simulate registration
      await Future.delayed(const Duration(seconds: 1));

      final mockUser = SanctumUserBasic(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        email: email,
      );

      _currentUser = mockUser.toFullUser();
      _authState = SanctumAuthState.authenticated;

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _setError(_getErrorMessage(e));
      return false;
    }
  }

  /// Logs out the current user
  Future<void> logout() async {
    try {
      _setLoading(true);
      _setError(null);

      // For demo purposes, simulate logout
      await Future.delayed(const Duration(milliseconds: 500));

      _currentUser = null;
      _authState = SanctumAuthState.unauthenticated;
      _sanctum.dio.options.headers.remove('Authorization');

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      _setError(_getErrorMessage(e));
    }
  }

  /// Refreshes the current user data
  Future<void> refreshUser() async {
    if (!isAuthenticated) return;

    try {
      _setLoading(true);
      _setError(null);

      // For demo purposes, simulate user refresh
      await Future.delayed(const Duration(milliseconds: 800));

      // In a real app, you would call: _currentUser = await _sanctum.user(forceRefresh: true);
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          updatedAt: DateTime.now(),
        );
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      _setError(_getErrorMessage(e));
    }
  }

  /// Checks if the user has a specific ability
  Future<bool> hasAbility(String ability) async {
    if (!isAuthenticated) return false;

    try {
      // For demo purposes, simulate ability check
      await Future.delayed(const Duration(milliseconds: 100));

      // In a real app: return await _sanctum.hasAbility(ability);
      // For demo, return true for common abilities
      return ['read', 'write', 'delete', '*'].contains(ability);
    } catch (e) {
      return false;
    }
  }

  /// Gets demo API data (simulates authenticated requests)
  Future<List<Map<String, dynamic>>> getDemoData() async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _sanctum.dio.get('/posts?_limit=10');
      final data = List<Map<String, dynamic>>.from(response.data);

      _setLoading(false);
      return data;
    } catch (e) {
      _setLoading(false);
      _setError(_getErrorMessage(e));
      return [];
    }
  }

  /// Creates a demo post
  Future<Map<String, dynamic>?> createDemoPost({
    required String title,
    required String body,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _sanctum.dio.post('/posts', data: {
        'title': title,
        'body': body,
        'userId': _currentUser?.id ?? 1,
      });

      _setLoading(false);
      return response.data;
    } catch (e) {
      _setLoading(false);
      _setError(_getErrorMessage(e));
      return null;
    }
  }

  /// Gets user-friendly error message from exception
  String _getErrorMessage(dynamic error) {
    if (error is SanctumAuthenticationException) {
      return error.userFriendlyMessage;
    } else if (error is SanctumValidationException) {
      return error.userFriendlyMessage;
    } else if (error is SanctumNetworkException) {
      return error.userFriendlyMessage;
    } else if (error is SanctumRateLimitException) {
      return error.userFriendlyMessage;
    } else if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    } else {
      return error.toString();
    }
  }

  /// Simulates token operations for demo
  Future<List<DemoToken>> getTokens() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      DemoToken(
        id: 1,
        name: 'iPhone 12',
        abilities: ['*'],
        lastUsed: DateTime.now().subtract(const Duration(hours: 2)),
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      DemoToken(
        id: 2,
        name: 'Web Browser',
        abilities: ['read', 'write'],
        lastUsed: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      DemoToken(
        id: 3,
        name: 'API Client',
        abilities: ['read'],
        lastUsed: DateTime.now().subtract(const Duration(days: 3)),
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];
  }

  /// Simulates token creation
  Future<DemoToken?> createToken({
    required String name,
    required List<String> abilities,
  }) async {
    try {
      _setLoading(true);
      await Future.delayed(const Duration(seconds: 1));

      final token = DemoToken(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        abilities: abilities,
        lastUsed: null,
        createdAt: DateTime.now(),
      );

      _setLoading(false);
      return token;
    } catch (e) {
      _setLoading(false);
      _setError(_getErrorMessage(e));
      return null;
    }
  }

  /// Simulates token revocation
  Future<bool> revokeToken(int tokenId) async {
    try {
      _setLoading(true);
      await Future.delayed(const Duration(milliseconds: 800));
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError(_getErrorMessage(e));
      return false;
    }
  }

  @override
  void dispose() {
    _sanctum.dispose();
    super.dispose();
  }
}

/// Demo token class for example app
class DemoToken {
  final int id;
  final String name;
  final List<String> abilities;
  final DateTime? lastUsed;
  final DateTime createdAt;

  const DemoToken({
    required this.id,
    required this.name,
    required this.abilities,
    required this.lastUsed,
    required this.createdAt,
  });

  String get lastUsedDescription {
    if (lastUsed == null) return 'Never used';

    final now = DateTime.now();
    final difference = now.difference(lastUsed!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}