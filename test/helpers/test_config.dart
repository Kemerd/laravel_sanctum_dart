import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:laravel_sanctum_dart/laravel_sanctum_dart.dart';

/// Configuration helper for integration tests with Laravel Sanctum APIs
/// Loads environment variables from .env file for secure test credentials
class TestConfig {
  static late DotEnv _env;
  static bool _initialized = false;

  /// Initialize test configuration by loading environment variables
  static void initialize() {
    if (_initialized) return;

    _env = DotEnv();

    // Try to load .env file from project root
    final envFile = File('.env');
    if (envFile.existsSync()) {
      _env.load(['.env']);
    } else {
      throw Exception('Missing .env file. Please create one with test credentials.');
    }

    _initialized = true;
  }

  /// Base API URL for your Laravel Sanctum API
  static String get apiBaseUrl => _getRequired('API_BASE_URL');

  /// Primary test user email credential
  static String get testUserEmail => _getRequired('TEST_USER_EMAIL');

  /// Primary test user password credential
  static String get testUserPassword => _getRequired('TEST_USER_PASSWORD');

  /// Secondary test user email credential
  static String get testUser2Email => _getRequired('TEST_USER_2_EMAIL');

  /// Secondary test user password credential
  static String get testUser2Password => _getRequired('TEST_USER_2_PASSWORD');

  /// Optional API token for pre-authenticated tests
  static String? get apiToken => _getOptional('API_TOKEN');

  /// Test timeout in milliseconds
  static int get testTimeoutMs => int.tryParse(_getOptional('TEST_TIMEOUT_MS') ?? '30000') ?? 30000;

  /// Number of retry attempts for failed tests
  static int get testRetryAttempts => int.tryParse(_getOptional('TEST_RETRY_ATTEMPTS') ?? '3') ?? 3;

  /// Creates a SanctumAuth instance configured for testing
  static SanctumAuth createTestSanctumAuth({
    bool debugMode = true,
    SanctumAuthMode authMode = SanctumAuthMode.api,
  }) {
    initialize();

    return SanctumAuth(
      baseUrl: apiBaseUrl,
      debugMode: debugMode,
      authMode: authMode,
    );
  }

  /// Get required environment variable, throw if missing
  static String _getRequired(String key) {
    final value = _env[key];
    if (value == null || value.isEmpty) {
      throw Exception('Missing required environment variable: $key');
    }
    return value;
  }

  /// Get optional environment variable, return null if missing
  static String? _getOptional(String key) {
    return _env[key];
  }

  /// Primary test user credentials
  static Map<String, String> get primaryUserCredentials => {
    'email': testUserEmail,
    'password': testUserPassword,
  };

  /// Secondary test user credentials
  static Map<String, String> get secondaryUserCredentials => {
    'email': testUser2Email,
    'password': testUser2Password,
  };

  /// Check if environment is properly configured for testing
  static bool get isConfigured {
    try {
      initialize();
      // Try accessing all required variables
      apiBaseUrl;
      testUserEmail;
      testUserPassword;
      testUser2Email;
      testUser2Password;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get timeout duration for tests
  static Duration get testTimeout => Duration(milliseconds: testTimeoutMs);
}