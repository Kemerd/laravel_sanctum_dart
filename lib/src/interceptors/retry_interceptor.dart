import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../models/auth_config.dart';
import '../utils/logger.dart';

/// Interceptor that implements intelligent retry logic with exponential backoff
///
/// This interceptor automatically retries failed requests based on configurable
/// criteria, implementing exponential backoff with jitter to avoid thundering
/// herd problems. It supports:
/// - Configurable retry conditions (status codes, error types)
/// - Exponential backoff with customizable parameters
/// - Jitter to distribute retry attempts
/// - Per-request retry tracking
/// - Comprehensive logging of retry attempts
@immutable
class SanctumRetryInterceptor extends Interceptor {
  /// Retry configuration
  final SanctumRetryConfig _config;

  /// Logger for debugging
  final SanctumLogger _logger;

  /// Random number generator for jitter
  final Random _random = Random();

  /// Map to track retry attempts per request
  final Map<String, int> _retryAttempts = <String, int>{};

  /// Creates a new [SanctumRetryInterceptor] instance
  SanctumRetryInterceptor({
    required SanctumRetryConfig config,
    required SanctumLogger logger,
  })  : _config = config,
        _logger = logger;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Skip retry if not enabled
    if (!_config.enabled) {
      handler.next(err);
      return;
    }

    // Check if this error should be retried
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final requestKey = _getRequestKey(err.requestOptions);
    final currentAttempts = _retryAttempts[requestKey] ?? 0;

    // Check if we've exceeded max retry attempts
    if (currentAttempts >= _config.maxRetries) {
      _logger.warning(
        'Max retry attempts ($currentAttempts) exceeded for ${err.requestOptions.method} ${err.requestOptions.path}',
      );
      _retryAttempts.remove(requestKey);
      handler.next(err);
      return;
    }

    // Increment retry count
    _retryAttempts[requestKey] = currentAttempts + 1;

    try {
      // Calculate delay with exponential backoff and jitter
      final delay = _calculateDelay(currentAttempts);

      _logger.info(
        'Retrying request ${currentAttempts + 1}/${_config.maxRetries} '
        'after ${delay.inMilliseconds}ms delay: '
        '${err.requestOptions.method} ${err.requestOptions.path}',
      );

      // Wait before retrying
      await Future.delayed(delay);

      // Create a new Dio instance to avoid interceptor recursion
      final retryDio = Dio();

      // Copy all the original request options
      final options = err.requestOptions.copyWith();

      // Retry the request
      final response = await retryDio.fetch(options);

      // Success! Clean up and resolve
      _retryAttempts.remove(requestKey);
      _logger.info(
        'Retry successful on attempt ${currentAttempts + 1}: '
        '${options.method} ${options.path}',
      );
      handler.resolve(response);
    } catch (retryError) {
      _logger.debug(
        'Retry attempt ${currentAttempts + 1} failed: $retryError',
      );

      if (retryError is DioException) {
        // Continue with retry logic for DioExceptions
        onError(retryError, handler);
      } else {
        // For non-Dio errors, clean up and pass through
        _retryAttempts.remove(requestKey);
        handler.next(err);
      }
    }
  }

  /// Determines if a request should be retried based on the error
  bool _shouldRetry(DioException error) {
    // Check error type
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;

      case DioExceptionType.connectionError:
        // Retry connection errors (network issues)
        return true;

      case DioExceptionType.badResponse:
        // Check if status code is retryable
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          return _config.retryableStatusCodes.contains(statusCode);
        }
        return false;

      case DioExceptionType.cancel:
        // Don't retry cancelled requests
        return false;

      case DioExceptionType.unknown:
        // Retry unknown errors that might be network related
        return _isNetworkError(error);

      default:
        return false;
    }
  }

  /// Checks if an unknown error is likely network-related
  bool _isNetworkError(DioException error) {
    final errorMessage = error.message?.toLowerCase() ?? '';

    // Common network error indicators
    final networkErrorKeywords = [
      'network',
      'connection',
      'socket',
      'timeout',
      'unreachable',
      'dns',
      'resolve',
    ];

    return networkErrorKeywords.any((keyword) => errorMessage.contains(keyword));
  }

  /// Calculates the delay for the next retry attempt
  Duration _calculateDelay(int attemptNumber) {
    // Calculate exponential backoff
    final baseDelayMs = _config.initialDelay.inMilliseconds;
    final backoffDelayMs = (baseDelayMs * pow(_config.backoffMultiplier, attemptNumber)).round();

    // Apply maximum delay limit
    final maxDelayMs = _config.maxDelay.inMilliseconds;
    final constrainedDelayMs = min(backoffDelayMs, maxDelayMs);

    // Add jitter (±25% of the calculated delay)
    final jitterRange = (constrainedDelayMs * 0.25).round();
    final jitter = _random.nextInt(jitterRange * 2) - jitterRange;
    final finalDelayMs = max(constrainedDelayMs + jitter, 0);

    return Duration(milliseconds: finalDelayMs);
  }

  /// Generates a unique key for tracking retry attempts per request
  String _getRequestKey(RequestOptions options) {
    return '${options.method}_${options.path}_${options.hashCode}';
  }

  /// Gets current retry statistics
  SanctumRetryStats getStats() {
    final totalActiveRequests = _retryAttempts.length;
    int totalRetryAttempts = 0;
    int maxAttemptsForRequest = 0;

    for (final attempts in _retryAttempts.values) {
      totalRetryAttempts += attempts;
      maxAttemptsForRequest = max(maxAttemptsForRequest, attempts);
    }

    return SanctumRetryStats(
      activeRetryRequests: totalActiveRequests,
      totalRetryAttempts: totalRetryAttempts,
      maxAttemptsForSingleRequest: maxAttemptsForRequest,
      retryConfig: _config,
    );
  }

  /// Clears all retry tracking (useful for testing or cleanup)
  void clearRetryTracking() {
    _retryAttempts.clear();
    _logger.debug('Retry tracking cleared');
  }

  /// Checks if a specific request is currently being retried
  bool isRequestBeingRetried(RequestOptions options) {
    final requestKey = _getRequestKey(options);
    return _retryAttempts.containsKey(requestKey);
  }

  /// Gets the current retry attempt count for a request
  int getRetryAttemptCount(RequestOptions options) {
    final requestKey = _getRequestKey(options);
    return _retryAttempts[requestKey] ?? 0;
  }
}

/// Enhanced retry interceptor with request-specific configuration
class SanctumAdvancedRetryInterceptor extends SanctumRetryInterceptor {
  /// Request-specific retry configurations
  final Map<String, SanctumRetryConfig> _pathSpecificConfigs;

  /// Creates a new [SanctumAdvancedRetryInterceptor] instance
  SanctumAdvancedRetryInterceptor({
    required super.config,
    required super.logger,
    Map<String, SanctumRetryConfig>? pathSpecificConfigs,
  }) : _pathSpecificConfigs = pathSpecificConfigs ?? {};

  /// Gets the appropriate retry configuration for a request
  SanctumRetryConfig _getConfigForRequest(RequestOptions options) {
    // Check for path-specific configuration
    final path = options.path;
    for (final entry in _pathSpecificConfigs.entries) {
      if (path.contains(entry.key)) {
        return entry.value;
      }
    }

    // Fall back to default configuration
    return _config;
  }

  @override
  bool _shouldRetry(DioException error) {
    final requestConfig = _getConfigForRequest(error.requestOptions);

    // Use request-specific configuration
    if (!requestConfig.enabled) {
      return false;
    }

    // Apply same logic but with request-specific config
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;

      case DioExceptionType.connectionError:
        return true;

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          return requestConfig.retryableStatusCodes.contains(statusCode);
        }
        return false;

      case DioExceptionType.cancel:
        return false;

      case DioExceptionType.unknown:
        return _isNetworkError(error);

      default:
        return false;
    }
  }

  @override
  Duration _calculateDelay(int attemptNumber) {
    // This would need access to the current request's config
    // For simplicity, using the default config here
    return super._calculateDelay(attemptNumber);
  }

  /// Adds a path-specific retry configuration
  void addPathConfig(String pathPattern, SanctumRetryConfig config) {
    _pathSpecificConfigs[pathPattern] = config;
    _logger.debug('Added path-specific retry config for: $pathPattern');
  }

  /// Removes a path-specific retry configuration
  void removePathConfig(String pathPattern) {
    _pathSpecificConfigs.remove(pathPattern);
    _logger.debug('Removed path-specific retry config for: $pathPattern');
  }
}

/// Statistics about retry operations
@immutable
class SanctumRetryStats {
  /// Number of requests currently being retried
  final int activeRetryRequests;

  /// Total number of retry attempts across all requests
  final int totalRetryAttempts;

  /// Maximum retry attempts for any single request
  final int maxAttemptsForSingleRequest;

  /// The retry configuration being used
  final SanctumRetryConfig retryConfig;

  /// Creates retry statistics
  const SanctumRetryStats({
    required this.activeRetryRequests,
    required this.totalRetryAttempts,
    required this.maxAttemptsForSingleRequest,
    required this.retryConfig,
  });

  /// Average retry attempts per active request
  double get averageAttemptsPerRequest =>
      activeRetryRequests > 0 ? totalRetryAttempts / activeRetryRequests : 0;

  /// Whether any requests are currently being retried
  bool get hasActiveRetries => activeRetryRequests > 0;

  @override
  String toString() {
    return 'SanctumRetryStats{'
        'activeRequests: $activeRetryRequests, '
        'totalAttempts: $totalRetryAttempts, '
        'maxAttempts: $maxAttemptsForSingleRequest, '
        'avgAttempts: ${averageAttemptsPerRequest.toStringAsFixed(1)}'
        '}';
  }
}

/// Configuration for retry interceptor behavior
@immutable
class SanctumRetryInterceptorConfig {
  /// Base retry configuration
  final SanctumRetryConfig baseConfig;

  /// Path-specific retry configurations
  final Map<String, SanctumRetryConfig> pathConfigs;

  /// Whether to use exponential backoff
  final bool useExponentialBackoff;

  /// Whether to add jitter to delays
  final bool useJitter;

  /// Jitter percentage (0.0 to 1.0)
  final double jitterPercentage;

  /// Creates retry interceptor configuration
  const SanctumRetryInterceptorConfig({
    required this.baseConfig,
    this.pathConfigs = const {},
    this.useExponentialBackoff = true,
    this.useJitter = true,
    this.jitterPercentage = 0.25,
  });
}