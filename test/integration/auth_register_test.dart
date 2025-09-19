import 'package:flutter_test/flutter_test.dart';
import 'package:laravel_sanctum_dart/laravel_sanctum_dart.dart';

import '../helpers/test_config.dart';

/// Integration tests for Laravel Sanctum user registration endpoint
///
/// These tests use real API calls against a Laravel Sanctum API
/// to ensure user registration works properly with the Laravel Sanctum Dart package.
///
/// To run these tests:
/// 1. Copy .env.example to .env
/// 2. Fill in your Laravel API URL and test user credentials
/// 3. Ensure your Laravel app has registration enabled
///
/// Standard Laravel Sanctum registration endpoint: POST /register
/// Expected request format:
/// {
///   "name": "string",
///   "email": "user@example.com",
///   "password": "string",
///   "password_confirmation": "string",
///   "device_name": "string"
/// }
void main() {
  group('Laravel Sanctum User Registration Integration Tests', () {
    late SanctumAuth sanctumAuth;

    setUpAll(() {
      // Ensure test configuration is loaded from .env file
      TestConfig.initialize();

      // Verify that the environment is properly configured
      if (!TestConfig.isConfigured) {
        throw Exception('Test environment not properly configured. Check .env file.');
      }
    });

    setUp(() {
      // Create a fresh SanctumAuth instance for each test
      // This ensures clean state and prevents test interference
      sanctumAuth = TestConfig.createTestSanctumAuth(
        debugMode: true, // Enable debug mode for detailed logging during tests
      );
    });

    tearDown(() async {
      // Clean up after each test to prevent state pollution
      try {
        // Attempt to logout if authenticated
        if (sanctumAuth.isAuthenticated) {
          await sanctumAuth.logout();
        }
      } catch (e) {
        // Ignore logout errors during teardown
        print('Warning: Failed to logout during teardown: $e');
      } finally {
        // Always dispose of the auth instance
        sanctumAuth.dispose();
      }
    });

    group('User Registration Tests', () {
      test('should successfully register a new user', () async {
        // Generate unique email to avoid conflicts with existing test data
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final testEmail = 'test.user.$timestamp@example.com';
        final testPassword = 'TestPassword123!';
        final testName = 'Test User $timestamp';

        // Attempt to register a new user
        final registerResponse = await sanctumAuth.register(
          name: testName,
          email: testEmail,
          password: testPassword,
          passwordConfirmation: testPassword,
          deviceName: 'Test Registration Device',
        );

        // Verify the response structure
        expect(registerResponse, isA<SanctumRegisterResponse>());
        expect(registerResponse.token, isNotEmpty);
        expect(registerResponse.tokenType, equals('Bearer'));
        expect(registerResponse.user, isA<SanctumUserBasic>());
        expect(registerResponse.user.email, equals(testEmail));
        expect(registerResponse.user.name, equals(testName));

        // Verify authentication state is updated correctly after registration
        expect(sanctumAuth.isAuthenticated, isTrue);
        expect(sanctumAuth.authState, equals(SanctumAuthState.authenticated));

        // Verify token can be used for authorization headers
        expect(registerResponse.authorizationHeaderValue, startsWith('Bearer '));

        // Verify we can get current user info after registration
        final currentUser = await sanctumAuth.user();
        expect(currentUser, isA<SanctumUser>());
        expect(currentUser.email, equals(testEmail));
        expect(currentUser.name, equals(testName));
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should handle registration with specific abilities', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final testEmail = 'test.abilities.$timestamp@example.com';

        final registerResponse = await sanctumAuth.register(
          name: 'Test Abilities User',
          email: testEmail,
          password: 'TestPassword123!',
          passwordConfirmation: 'TestPassword123!',
          deviceName: 'Abilities Test Device',
          abilities: ['read', 'write'], // Specific abilities instead of all
        );

        expect(registerResponse, isA<SanctumRegisterResponse>());
        expect(registerResponse.token, isNotEmpty);

        // Check if abilities are properly set (if returned by API)
        if (registerResponse.abilities != null) {
          expect(registerResponse.abilities, isNotEmpty);
        }

        expect(sanctumAuth.isAuthenticated, isTrue);
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should handle registration with additional custom fields', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final testEmail = 'test.custom.$timestamp@example.com';

        final registerResponse = await sanctumAuth.register(
          name: 'Test Custom Fields User',
          email: testEmail,
          password: 'TestPassword123!',
          passwordConfirmation: 'TestPassword123!',
          deviceName: 'Custom Fields Test Device',
          additionalFields: {
            'phone': '+1234567890', // Additional field if your API supports it
            'preferences': {
              'notifications': true,
              'theme': 'dark',
            },
          },
        );

        expect(registerResponse, isA<SanctumRegisterResponse>());
        expect(registerResponse.token, isNotEmpty);
        expect(sanctumAuth.isAuthenticated, isTrue);
      }, timeout: Timeout(TestConfig.testTimeout));
    });

    group('Registration with Different Data Tests', () {
      test('should handle registration with minimum required fields', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final testEmail = 'test.minimal.$timestamp@example.com';

        final registerResponse = await sanctumAuth.register(
          name: 'Minimal User',
          email: testEmail,
          password: 'TestPassword123!',
          passwordConfirmation: 'TestPassword123!',
          deviceName: 'Minimal Test Device',
        );

        expect(registerResponse, isA<SanctumRegisterResponse>());
        expect(registerResponse.token, isNotEmpty);
        expect(sanctumAuth.isAuthenticated, isTrue);
      }, timeout: Timeout(TestConfig.testTimeout));
    });

    group('Registration Validation Tests', () {
      test('should reject registration with existing email', () async {
        // Try to register with an email that already exists (primary test user email)
        expect(
          () async => await sanctumAuth.register(
            name: 'Duplicate Email User',
            email: TestConfig.testUserEmail, // Existing email
            password: 'TestPassword123!',
            passwordConfirmation: 'TestPassword123!',
            deviceName: 'Duplicate Test Device',
          ),
          throwsA(isA<SanctumValidationException>()),
        );

        // Verify state remains unauthenticated
        expect(sanctumAuth.isAuthenticated, isFalse);
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should reject registration with mismatched passwords', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        expect(
          () async => await sanctumAuth.register(
            name: 'Password Mismatch User',
            email: 'mismatch.$timestamp@example.com',
            password: 'TestPassword123!',
            passwordConfirmation: 'DifferentPassword456!', // Different password
            deviceName: 'Mismatch Test Device',
            additionalFields: {
              'type': 'customer',
            },
          ),
          throwsA(isA<SanctumValidationException>()),
        );
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should reject registration with invalid email format', () async {
        expect(
          () async => await sanctumAuth.register(
            name: 'Invalid Email User',
            email: 'not-an-email-address', // Invalid email format
            password: 'TestPassword123!',
            passwordConfirmation: 'TestPassword123!',
            deviceName: 'Invalid Email Test Device',
            additionalFields: {
              'type': 'customer',
            },
          ),
          throwsA(isA<SanctumValidationException>()),
        );
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should reject registration with empty required fields', () async {
        // Test empty name
        expect(
          () async => await sanctumAuth.register(
            name: '', // Empty name
            email: 'empty.name@example.com',
            password: 'TestPassword123!',
            passwordConfirmation: 'TestPassword123!',
            deviceName: 'Empty Name Test',
          ),
          throwsA(isA<SanctumValidationException>()),
        );

        // Test empty email
        expect(
          () async => await sanctumAuth.register(
            name: 'Test User',
            email: '', // Empty email
            password: 'TestPassword123!',
            passwordConfirmation: 'TestPassword123!',
            deviceName: 'Empty Email Test',
            additionalFields: {'type': 'customer'},
          ),
          throwsA(isA<SanctumValidationException>()),
        );

        // Test empty password
        expect(
          () async => await sanctumAuth.register(
            name: 'Test User',
            email: 'empty.password@example.com',
            password: '', // Empty password
            passwordConfirmation: '',
            deviceName: 'Empty Password Test',
          ),
          throwsA(isA<SanctumValidationException>()),
        );

        // Test empty device name
        expect(
          () async => await sanctumAuth.register(
            name: 'Test User',
            email: 'empty.device@example.com',
            password: 'TestPassword123!',
            passwordConfirmation: 'TestPassword123!',
            deviceName: '', // Empty device name
          ),
          throwsA(isA<SanctumValidationException>()),
        );
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should reject registration with weak password', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        expect(
          () async => await sanctumAuth.register(
            name: 'Weak Password User',
            email: 'weak.password.$timestamp@example.com',
            password: '123', // Weak password
            passwordConfirmation: '123',
            deviceName: 'Weak Password Test',
          ),
          throwsA(isA<SanctumValidationException>()),
        );
      }, timeout: Timeout(TestConfig.testTimeout));
    });

    group('Registration and Login Flow Tests', () {
      test('should register user and then allow login with same credentials', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final testEmail = 'test.flow.$timestamp@example.com';
        final testPassword = 'TestPassword123!';
        final testName = 'Flow Test User';

        // Step 1: Register a new user
        final registerResponse = await sanctumAuth.register(
          name: testName,
          email: testEmail,
          password: testPassword,
          passwordConfirmation: testPassword,
          deviceName: 'Registration Flow Test',
        );

        expect(registerResponse, isA<SanctumRegisterResponse>());
        expect(sanctumAuth.isAuthenticated, isTrue);

        final registerToken = registerResponse.token;

        // Step 2: Logout
        await sanctumAuth.logout();
        expect(sanctumAuth.isAuthenticated, isFalse);

        // Step 3: Login with the same credentials
        final loginResponse = await sanctumAuth.login(
          email: testEmail,
          password: testPassword,
          deviceName: 'Login Flow Test',
        );

        expect(loginResponse, isA<SanctumLoginResponse>());
        expect(loginResponse.user.email, equals(testEmail));
        expect(loginResponse.user.name, equals(testName));
        expect(sanctumAuth.isAuthenticated, isTrue);

        // Tokens should be different (new session)
        expect(loginResponse.token, isNot(equals(registerToken)));
      }, timeout: Timeout(TestConfig.testTimeout));
    });

    group('Error Handling Tests', () {
      test('should handle network timeouts during registration', () async {
        // Create auth instance with very short timeout
        final shortTimeoutSanctum = SanctumAuth(
          baseUrl: TestConfig.apiBaseUrl,
          debugMode: true,
          timeouts: const SanctumTimeouts(
            connect: Duration(milliseconds: 1), // Very short timeout
            receive: Duration(milliseconds: 1),
            send: Duration(milliseconds: 1),
          ),
        );

        try {
          expect(
            () async => await shortTimeoutSanctum.register(
              name: 'Timeout Test User',
              email: 'timeout@example.com',
              password: 'TestPassword123!',
              passwordConfirmation: 'TestPassword123!',
              deviceName: 'Timeout Test',
            ),
            throwsA(isA<SanctumNetworkException>()),
          );
        } finally {
          shortTimeoutSanctum.dispose();
        }
      });
    });

    group('Token Management After Registration', () {
      test('should provide valid tokens and user data after registration', () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final testEmail = 'test.token.$timestamp@example.com';

        final registerResponse = await sanctumAuth.register(
          name: 'Token Test User',
          email: testEmail,
          password: 'TestPassword123!',
          passwordConfirmation: 'TestPassword123!',
          deviceName: 'Token Management Test',
        );

        // Verify authorization header format
        final authHeader = registerResponse.authorizationHeaderValue;
        expect(authHeader, matches(RegExp(r'^Bearer .+$')));

        // Should be able to access token manager
        expect(sanctumAuth.tokens, isA<SanctumTokenManager>());

        // Should be able to get current user after registration
        final currentUser = await sanctumAuth.user();
        expect(currentUser, isA<SanctumUser>());
        expect(currentUser.email, equals(testEmail));

        // Should be able to make authenticated requests
        // (This would depend on what endpoints are available)
        expect(sanctumAuth.isAuthenticated, isTrue);
      }, timeout: Timeout(TestConfig.testTimeout));
    });
  });
}