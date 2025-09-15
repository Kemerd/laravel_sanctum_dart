import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:laravel_sanctum_dart/laravel_sanctum_dart.dart';

import 'sanctum_auth_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  group('SanctumAuth', () {
    late MockDio mockDio;
    late SanctumAuth sanctumAuth;

    setUp(() {
      mockDio = MockDio();
      sanctumAuth = SanctumAuth(
        baseUrl: 'https://api.example.com',
        debugMode: false,
      );
    });

    tearDown(() {
      sanctumAuth.dispose();
    });

    group('Configuration', () {
      test('should initialize with correct base URL', () {
        expect(sanctumAuth.config.baseUrl, equals('https://api.example.com'));
      });

      test('should use API mode by default', () {
        expect(sanctumAuth.config.authMode, equals(SanctumAuthMode.api));
      });

      test('should throw exception for invalid URL', () {
        expect(
          () => SanctumAuth(baseUrl: 'invalid-url'),
          throwsA(isA<SanctumConfigurationException>()),
        );
      });

      test('should throw exception for empty base URL', () {
        expect(
          () => SanctumAuth(baseUrl: ''),
          throwsA(isA<SanctumConfigurationException>()),
        );
      });
    });

    group('Authentication State', () {
      test('should start in verifying state', () {
        expect(sanctumAuth.authState, equals(SanctumAuthState.verifying));
      });

      test('should emit state changes through stream', () async {
        expectLater(
          sanctumAuth.authStateStream,
          emitsInOrder([
            SanctumAuthState.verifying,
            SanctumAuthState.unauthenticated,
          ]),
        );

        // Wait for initialization to complete
        await Future.delayed(const Duration(milliseconds: 100));
      });

      test('isAuthenticated should return false initially', () {
        expect(sanctumAuth.isAuthenticated, isFalse);
      });

      test('isUnauthenticated should return false initially (verifying state)', () {
        expect(sanctumAuth.isUnauthenticated, isFalse);
      });

      test('isVerifying should return true initially', () {
        expect(sanctumAuth.isVerifying, isTrue);
      });
    });

    group('Error Handling', () {
      test('should convert DioException to SanctumException', () {
        final dioError = DioException(
          requestOptions: RequestOptions(),
          response: Response(
            requestOptions: RequestOptions(),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        );

        expect(
          () => sanctumAuth.login(
            email: 'test@example.com',
            password: 'password',
            deviceName: 'test',
          ),
          throwsA(isA<SanctumAuthenticationException>()),
        );
      });

      test('should handle network timeout errors', () {
        final timeoutError = DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
        );

        expect(
          () => throw sanctumAuth._handleDioException(timeoutError),
          throwsA(isA<SanctumNetworkException>()),
        );
      });

      test('should handle validation errors (422)', () {
        final validationError = DioException(
          requestOptions: RequestOptions(),
          response: Response(
            requestOptions: RequestOptions(),
            statusCode: 422,
            data: {
              'errors': {
                'email': ['The email field is required.'],
                'password': ['The password field is required.'],
              },
            },
          ),
          type: DioExceptionType.badResponse,
        );

        expect(
          () => throw sanctumAuth._handleDioException(validationError),
          throwsA(isA<SanctumValidationException>()),
        );
      });

      test('should handle rate limiting (429)', () {
        final rateLimitError = DioException(
          requestOptions: RequestOptions(),
          response: Response(
            requestOptions: RequestOptions(),
            statusCode: 429,
            headers: Headers.fromMap({
              'retry-after': ['60'],
              'x-ratelimit-limit': ['100'],
              'x-ratelimit-remaining': ['0'],
            }),
          ),
          type: DioExceptionType.badResponse,
        );

        expect(
          () => throw sanctumAuth._handleDioException(rateLimitError),
          throwsA(isA<SanctumRateLimitException>()),
        );
      });
    });

    group('Configuration Validation', () {
      test('should accept valid HTTPS URLs', () {
        expect(
          () => SanctumAuth(baseUrl: 'https://api.example.com'),
          returnsNormally,
        );
      });

      test('should accept valid HTTP URLs', () {
        expect(
          () => SanctumAuth(baseUrl: 'http://localhost:8000'),
          returnsNormally,
        );
      });

      test('should reject malformed URLs', () {
        expect(
          () => SanctumAuth(baseUrl: 'not-a-url'),
          throwsA(isA<SanctumConfigurationException>()),
        );
      });
    });

    group('Custom Configuration', () {
      test('should accept custom endpoints', () {
        final customConfig = SanctumConfig(
          baseUrl: 'https://api.example.com',
          endpoints: const SanctumEndpoints(
            login: '/api/v1/login',
            register: '/api/v1/register',
            logout: '/api/v1/logout',
          ),
        );

        final customSanctum = SanctumAuth.withConfig(customConfig);
        expect(customSanctum.config.endpoints.login, equals('/api/v1/login'));
        expect(customSanctum.config.endpoints.register, equals('/api/v1/register'));
        expect(customSanctum.config.endpoints.logout, equals('/api/v1/logout'));

        customSanctum.dispose();
      });

      test('should accept custom timeouts', () {
        final customConfig = SanctumConfig(
          baseUrl: 'https://api.example.com',
          timeouts: const SanctumTimeouts(
            connect: Duration(seconds: 10),
            receive: Duration(seconds: 20),
            send: Duration(seconds: 15),
          ),
        );

        final customSanctum = SanctumAuth.withConfig(customConfig);
        expect(
          customSanctum.config.timeouts.connect,
          equals(const Duration(seconds: 10)),
        );
        expect(
          customSanctum.config.timeouts.receive,
          equals(const Duration(seconds: 20)),
        );

        customSanctum.dispose();
      });

      test('should accept custom cache configuration', () {
        final customConfig = SanctumConfig(
          baseUrl: 'https://api.example.com',
          cacheConfig: const SanctumCacheConfig(
            enabled: true,
            maxSize: 200,
            timeout: Duration(minutes: 10),
          ),
        );

        final customSanctum = SanctumAuth.withConfig(customConfig);
        expect(customSanctum.config.cacheConfig.enabled, isTrue);
        expect(customSanctum.config.cacheConfig.maxSize, equals(200));
        expect(
          customSanctum.config.cacheConfig.timeout,
          equals(const Duration(minutes: 10)),
        );

        customSanctum.dispose();
      });
    });

    group('Performance Stats', () {
      test('should provide performance statistics', () {
        final stats = sanctumAuth.performanceStats;
        expect(stats, isA<SanctumPerformanceStats>());
        expect(stats.cacheStats, isA<SanctumCacheStats>());
        expect(stats.connectionPoolStats, isA<SanctumConnectionPoolStats>());
        expect(stats.metricsStats, isA<SanctumMetricsStats>());
      });
    });

    group('Token Manager', () {
      test('should provide token manager instance', () {
        expect(sanctumAuth.tokens, isA<SanctumTokenManager>());
      });
    });

    group('Cookie Manager', () {
      test('should provide cookie manager instance', () {
        expect(sanctumAuth.cookies, isA<SanctumCookieManager>());
      });
    });
  });

  group('SanctumConfig', () {
    test('should create with required parameters', () {
      const config = SanctumConfig(baseUrl: 'https://api.example.com');
      expect(config.baseUrl, equals('https://api.example.com'));
      expect(config.authMode, equals(SanctumAuthMode.api));
      expect(config.debugMode, isFalse);
    });

    test('should support copyWith', () {
      const original = SanctumConfig(
        baseUrl: 'https://api.example.com',
        debugMode: false,
      );

      final copy = original.copyWith(debugMode: true);
      expect(copy.baseUrl, equals('https://api.example.com'));
      expect(copy.debugMode, isTrue);
    });

    test('should support equality comparison', () {
      const config1 = SanctumConfig(baseUrl: 'https://api.example.com');
      const config2 = SanctumConfig(baseUrl: 'https://api.example.com');
      const config3 = SanctumConfig(baseUrl: 'https://different.com');

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });

    test('should have proper toString representation', () {
      const config = SanctumConfig(
        baseUrl: 'https://api.example.com',
        authMode: SanctumAuthMode.spa,
        debugMode: true,
      );

      final string = config.toString();
      expect(string, contains('https://api.example.com'));
      expect(string, contains('SanctumAuthMode.spa'));
      expect(string, contains('true'));
    });
  });

  group('SanctumAuthMode', () {
    test('should have correct enum values', () {
      expect(SanctumAuthMode.values.length, equals(3));
      expect(SanctumAuthMode.values, contains(SanctumAuthMode.api));
      expect(SanctumAuthMode.values, contains(SanctumAuthMode.spa));
      expect(SanctumAuthMode.values, contains(SanctumAuthMode.hybrid));
    });
  });

  group('SanctumAuthState', () {
    test('should have correct enum values', () {
      expect(SanctumAuthState.values.length, equals(3));
      expect(SanctumAuthState.values, contains(SanctumAuthState.unauthenticated));
      expect(SanctumAuthState.values, contains(SanctumAuthState.verifying));
      expect(SanctumAuthState.values, contains(SanctumAuthState.authenticated));
    });
  });
}