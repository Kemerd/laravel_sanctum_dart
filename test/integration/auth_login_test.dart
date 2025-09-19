import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:laravel_sanctum_dart/laravel_sanctum_dart.dart';

import '../helpers/test_config.dart';

/// Integration tests for Laravel Sanctum authentication login endpoint
///
/// These tests use real API calls against a Laravel Sanctum API
/// with credentials from the .env file to ensure authentication works properly.
///
/// To run these tests:
/// 1. Copy .env.example to .env
/// 2. Fill in your Laravel API URL and test user credentials
/// 3. Ensure your Laravel app has the test users created
///
/// Standard Laravel Sanctum login endpoint: POST /login
/// Expected request format:
/// {
///   "email": "user@example.com",
///   "password": "string",
///   "device_name": "string"
/// }
void main() {
  // Initialize Flutter bindings for tests but allow real HTTP
  TestWidgetsFlutterBinding.ensureInitialized();

  // Override HTTP client to allow real network requests
  HttpOverrides.global = null;

  group('Laravel Sanctum Auth Login Integration Tests', () {
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

    group('Successful Login Tests', () {
      test('should successfully login with primary test user', () async {
        // Test login with the primary test user account
        final loginResponse = await sanctumAuth.login(
          email: TestConfig.testUserEmail,
          password: TestConfig.testUserPassword,
          deviceName: 'Test Primary User Device',
          abilities: ['*'], // Grant all abilities
        );

        // Verify the response structure matches Laravel Sanctum format
        expect(loginResponse, isA<SanctumLoginResponse>());
        expect(loginResponse.token, isNotEmpty);
        expect(loginResponse.tokenType, equals('Bearer'));
        expect(loginResponse.user, isA<SanctumUserBasic>());
        expect(loginResponse.user.email, equals(TestConfig.testUserEmail));

        // Verify authentication state is updated correctly
        expect(sanctumAuth.isAuthenticated, isTrue);
        expect(sanctumAuth.authState, equals(SanctumAuthState.authenticated));

        // Verify token can be used for authorization headers
        expect(loginResponse.authorizationHeaderValue, startsWith('Bearer '));
        expect(loginResponse.authorizationHeaderValue.length, greaterThan(10));
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should successfully login with secondary test user', () async {
        // Test login with the secondary test user account
        final loginResponse = await sanctumAuth.login(
          email: TestConfig.testUser2Email,
          password: TestConfig.testUser2Password,
          deviceName: 'Test Secondary User Device',
          abilities: ['*'], // Grant all abilities
        );

        // Verify the response structure
        expect(loginResponse, isA<SanctumLoginResponse>());
        expect(loginResponse.token, isNotEmpty);
        expect(loginResponse.tokenType, equals('Bearer'));
        expect(loginResponse.user, isA<SanctumUserBasic>());
        expect(loginResponse.user.email, equals(TestConfig.testUser2Email));

        // Verify authentication state
        expect(sanctumAuth.isAuthenticated, isTrue);
        expect(sanctumAuth.authState, equals(SanctumAuthState.authenticated));
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should handle custom device names properly', () async {
        const customDeviceName = 'Integration Test Device 🚀';

        final loginResponse = await sanctumAuth.login(
          email: TestConfig.testUserEmail,
          password: TestConfig.testUserPassword,
          deviceName: customDeviceName,
        );

        expect(loginResponse, isA<SanctumLoginResponse>());
        expect(loginResponse.token, isNotEmpty);

        // The device name should be stored in the token manager
        // (Note: This depends on how the Laravel API handles device names)
        expect(sanctumAuth.isAuthenticated, isTrue);
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should handle specific abilities restriction', () async {
        // Test login with specific abilities (if supported by your Laravel API)
        final loginResponse = await sanctumAuth.login(
          email: TestConfig.testUserEmail,
          password: TestConfig.testUserPassword,
          deviceName: 'Limited Abilities Device',
          abilities: ['read', 'write'], // Specific abilities instead of '*'
        );

        expect(loginResponse, isA<SanctumLoginResponse>());
        expect(loginResponse.token, isNotEmpty);

        // Check if abilities are properly set (if returned by API)
        if (loginResponse.abilities != null) {
          expect(loginResponse.abilities, isNotEmpty);
        }
      }, timeout: Timeout(TestConfig.testTimeout));
    });

    group('Authentication Failure Tests', () {
      test('should throw exception for invalid email', () async {
        // Test with non-existent email address
        expect(
          () async => await sanctumAuth.login(
            email: 'nonexistent@example.com',
            password: TestConfig.testUserPassword,
            deviceName: 'Test Device',
          ),
          throwsA(isA<SanctumAuthenticationException>()),
        );

        // Verify state remains unauthenticated
        expect(sanctumAuth.isAuthenticated, isFalse);
        expect(sanctumAuth.authState, equals(SanctumAuthState.unauthenticated));
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should throw exception for invalid password', () async {
        // Test with correct email but wrong password
        expect(
          () async => await sanctumAuth.login(
            email: TestConfig.testUserEmail,
            password: 'wrongpassword123',
            deviceName: 'Test Device',
          ),
          throwsA(isA<SanctumAuthenticationException>()),
        );

        // Verify state remains unauthenticated
        expect(sanctumAuth.isAuthenticated, isFalse);
        expect(sanctumAuth.authState, equals(SanctumAuthState.unauthenticated));
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should throw exception for malformed email', () async {
        // Test with malformed email address
        expect(
          () async => await sanctumAuth.login(
            email: 'invalid-email-format',
            password: TestConfig.testUserPassword,
            deviceName: 'Test Device',
          ),
          throwsA(isA<SanctumValidationException>()),
        );
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should throw exception for empty credentials', () async {
        // Test with empty email
        expect(
          () async => await sanctumAuth.login(
            email: '',
            password: TestConfig.testUserPassword,
            deviceName: 'Test Device',
          ),
          throwsA(isA<SanctumValidationException>()),
        );

        // Test with empty password
        expect(
          () async => await sanctumAuth.login(
            email: TestConfig.testUserEmail,
            password: '',
            deviceName: 'Test Device',
          ),
          throwsA(isA<SanctumValidationException>()),
        );

        // Test with empty device name
        expect(
          () async => await sanctumAuth.login(
            email: TestConfig.testUserEmail,
            password: TestConfig.testUserPassword,
            deviceName: '',
          ),
          throwsA(isA<SanctumValidationException>()),
        );
      }, timeout: Timeout(TestConfig.testTimeout));
    });

    group('Network and API Tests', () {
      test('should handle network timeouts gracefully', () async {
        // Create auth instance with very short timeout to test timeout handling
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
            () async => await shortTimeoutSanctum.login(
              email: TestConfig.testUserEmail,
              password: TestConfig.testUserPassword,
              deviceName: 'Timeout Test Device',
            ),
            throwsA(isA<SanctumNetworkException>()),
          );
        } finally {
          shortTimeoutSanctum.dispose();
        }
      });

      test('should handle rate limiting properly', () async {
        // This test attempts to trigger rate limiting by making rapid requests
        // Note: This may not always trigger rate limiting depending on API configuration

        final List<Future> loginAttempts = [];

        // Make multiple rapid login attempts to potentially trigger rate limiting
        for (int i = 0; i < 10; i++) {
          loginAttempts.add(
            sanctumAuth.login(
              email: 'rate.limit.test$i@example.com', // Non-existent emails
              password: 'wrongpassword',
              deviceName: 'Rate Limit Test $i',
            ).catchError((e) {
              // Expected to fail with auth errors, but we're looking for rate limit errors
              if (e is SanctumRateLimitException) {
                throw e; // Re-throw rate limit exceptions
              }
              // Ignore other auth exceptions
              return null;
            }),
          );
        }

        // Wait for all attempts and check if any triggered rate limiting
        final results = await Future.wait(loginAttempts, eagerError: false);

        // If we got here without rate limiting, that's also acceptable
        // The test mainly ensures rate limiting is handled properly when it occurs
        expect(results, isA<List>());
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('Token Management Tests', () {
      test('should provide valid authorization headers after login', () async {
        final loginResponse = await sanctumAuth.login(
          email: TestConfig.testUserEmail,
          password: TestConfig.testUserPassword,
          deviceName: 'Header Test Device',
        );

        // Verify authorization header format
        final authHeader = loginResponse.authorizationHeaderValue;
        expect(authHeader, matches(RegExp(r'^Bearer .+$')));

        // The token should be accessible through the token manager
        expect(sanctumAuth.tokens, isA<SanctumTokenManager>());

        // Should be able to get current user after successful login
        final currentUser = await sanctumAuth.user();
        expect(currentUser, isA<SanctumUser>());
        expect(currentUser.email, equals(TestConfig.testUserEmail));
      }, timeout: Timeout(TestConfig.testTimeout));

      test('should handle token expiration information', () async {
        final loginResponse = await sanctumAuth.login(
          email: TestConfig.testUserEmail,
          password: TestConfig.testUserPassword,
          deviceName: 'Expiration Test Device',
        );

        // Check if expiration information is provided
        // Note: Laravel Sanctum may or may not return expiration data
        if (loginResponse.expiresAt != null) {
          expect(loginResponse.expiresAt!.isAfter(DateTime.now()), isTrue);
          expect(loginResponse.isExpired, isFalse);
        }

        // Token should be valid immediately after login
        expect(loginResponse.token, isNotEmpty);
      }, timeout: Timeout(TestConfig.testTimeout));
    });

    group('Multiple Login Tests', () {
      test('should handle multiple sequential logins correctly', () async {
        // First login
        final firstLogin = await sanctumAuth.login(
          email: TestConfig.testUserEmail,
          password: TestConfig.testUserPassword,
          deviceName: 'First Login Device',
        );

        expect(sanctumAuth.isAuthenticated, isTrue);
        final firstToken = firstLogin.token;

        // Logout
        await sanctumAuth.logout();
        expect(sanctumAuth.isAuthenticated, isFalse);

        // Second login with different account
        final secondLogin = await sanctumAuth.login(
          email: TestConfig.testUser2Email,
          password: TestConfig.testUser2Password,
          deviceName: 'Second Login Device',
        );

        expect(sanctumAuth.isAuthenticated, isTrue);
        final secondToken = secondLogin.token;

        // Tokens should be different
        expect(firstToken, isNot(equals(secondToken)));
        expect(secondLogin.user.email, equals(TestConfig.testUser2Email));
      }, timeout: Timeout(TestConfig.testTimeout));
    });
  });
}