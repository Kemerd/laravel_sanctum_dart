import 'package:meta/meta.dart';
import '../constants/sanctum_constants.dart';

/// Base exception class for all Laravel Sanctum authentication errors
///
/// This is the parent class for all exceptions thrown by the Sanctum package.
/// It provides common functionality and properties that all Sanctum exceptions share.
@immutable
abstract class SanctumException implements Exception {
  /// Human-readable error message
  final String message;

  /// Error code for programmatic handling
  final String? code;

  /// HTTP status code if applicable
  final int? statusCode;

  /// Additional error details
  final Map<String, dynamic>? details;

  /// Stack trace when the exception was created
  final StackTrace? stackTrace;

  /// Creates a new [SanctumException] instance
  const SanctumException(
    this.message, {
    this.code,
    this.statusCode,
    this.details,
    this.stackTrace,
  });

  /// Whether this exception is recoverable (can be retried)
  bool get isRecoverable => false;

  /// Suggested recovery action for this exception
  String? get recoveryAction => null;

  /// Gets a user-friendly error message
  String get userFriendlyMessage => message;

  @override
  String toString() {
    return '$runtimeType: $message'
        '${code != null ? ' (Code: $code)' : ''}'
        '${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}

/// Exception thrown when authentication credentials are invalid
///
/// This exception is thrown when login attempts fail due to incorrect
/// email/password combinations or invalid tokens.
@immutable
class SanctumAuthenticationException extends SanctumException {
  /// Creates a new [SanctumAuthenticationException] instance
  const SanctumAuthenticationException(
    super.message, {
    super.code = SanctumConstants.errorInvalidCredentials,
    super.statusCode = SanctumConstants.statusUnauthorized,
    super.details,
    super.stackTrace,
  });

  /// Creates an exception for invalid login credentials
  factory SanctumAuthenticationException.invalidCredentials({
    String? customMessage,
    Map<String, dynamic>? details,
  }) {
    return SanctumAuthenticationException(
      customMessage ?? 'The provided credentials are incorrect.',
      details: details,
    );
  }

  /// Creates an exception for invalid or expired tokens
  factory SanctumAuthenticationException.invalidToken({
    String? customMessage,
    Map<String, dynamic>? details,
  }) {
    return SanctumAuthenticationException(
      customMessage ?? 'The provided token is invalid or expired.',
      code: SanctumConstants.errorTokenInvalid,
      details: details,
    );
  }

  @override
  bool get isRecoverable => true;

  @override
  String? get recoveryAction => 'Please log in again with valid credentials.';

  @override
  String get userFriendlyMessage {
    if (code == SanctumConstants.errorTokenInvalid) {
      return 'Your session has expired. Please log in again.';
    }
    return 'The email or password you entered is incorrect. Please try again.';
  }
}

/// Exception thrown when a user is authenticated but lacks authorization
///
/// This exception is thrown when a user has a valid token but doesn't
/// have the required permissions (abilities/scopes) to perform an action.
@immutable
class SanctumAuthorizationException extends SanctumException {
  /// Required abilities that were missing
  final List<String>? requiredAbilities;

  /// User's current abilities
  final List<String>? currentAbilities;

  /// Creates a new [SanctumAuthorizationException] instance
  const SanctumAuthorizationException(
    super.message, {
    super.code = SanctumConstants.errorForbidden,
    super.statusCode = SanctumConstants.statusForbidden,
    super.details,
    super.stackTrace,
    this.requiredAbilities,
    this.currentAbilities,
  });

  /// Creates an exception for insufficient token abilities
  factory SanctumAuthorizationException.insufficientAbilities({
    required List<String> required,
    List<String>? current,
    String? customMessage,
  }) {
    final message = customMessage ??
        'This action requires the following abilities: ${required.join(', ')}';

    return SanctumAuthorizationException(
      message,
      requiredAbilities: required,
      currentAbilities: current,
      details: {
        'required_abilities': required,
        'current_abilities': current ?? [],
      },
    );
  }

  @override
  String get userFriendlyMessage {
    return 'You don\'t have permission to perform this action.';
  }

  @override
  String? get recoveryAction {
    if (requiredAbilities != null && requiredAbilities!.isNotEmpty) {
      return 'Please request a token with the following abilities: ${requiredAbilities!.join(', ')}';
    }
    return 'Please contact an administrator for the required permissions.';
  }
}

/// Exception thrown when token operations fail
///
/// This exception covers token creation, refresh, revocation, and other
/// token-related operations that can fail.
@immutable
class SanctumTokenException extends SanctumException {
  /// Creates a new [SanctumTokenException] instance
  const SanctumTokenException(
    super.message, {
    super.code = SanctumConstants.errorTokenInvalid,
    super.statusCode,
    super.details,
    super.stackTrace,
  });

  /// Creates an exception for expired tokens
  factory SanctumTokenException.expired({
    String? customMessage,
    DateTime? expiredAt,
  }) {
    return SanctumTokenException(
      customMessage ?? 'The authentication token has expired.',
      code: SanctumConstants.errorTokenExpired,
      statusCode: SanctumConstants.statusUnauthorized,
      details: {
        'expired_at': expiredAt?.toIso8601String(),
      },
    );
  }

  /// Creates an exception for token creation failures
  factory SanctumTokenException.creationFailed({
    String? customMessage,
    Map<String, dynamic>? details,
  }) {
    return SanctumTokenException(
      customMessage ?? 'Failed to create authentication token.',
      statusCode: SanctumConstants.statusInternalServerError,
      details: details,
    );
  }

  /// Creates an exception for token revocation failures
  factory SanctumTokenException.revocationFailed({
    String? customMessage,
    Map<String, dynamic>? details,
  }) {
    return SanctumTokenException(
      customMessage ?? 'Failed to revoke authentication token.',
      statusCode: SanctumConstants.statusInternalServerError,
      details: details,
    );
  }

  @override
  bool get isRecoverable => code != SanctumConstants.errorTokenExpired;

  @override
  String? get recoveryAction {
    if (code == SanctumConstants.errorTokenExpired) {
      return 'Please log in again to get a new token.';
    }
    return 'Please try the operation again or contact support if the issue persists.';
  }

  @override
  String get userFriendlyMessage {
    if (code == SanctumConstants.errorTokenExpired) {
      return 'Your session has expired. Please log in again.';
    }
    return 'There was an issue with your authentication. Please try again.';
  }
}

/// Exception thrown when network operations fail
///
/// This exception covers HTTP request failures, connection timeouts,
/// and other network-related issues.
@immutable
class SanctumNetworkException extends SanctumException {
  /// The original exception that caused the network failure
  final dynamic originalException;

  /// Creates a new [SanctumNetworkException] instance
  const SanctumNetworkException(
    super.message, {
    super.code = SanctumConstants.errorNetworkError,
    super.statusCode,
    super.details,
    super.stackTrace,
    this.originalException,
  });

  /// Creates an exception for connection timeouts
  factory SanctumNetworkException.timeout({
    String? customMessage,
    Duration? timeout,
  }) {
    return SanctumNetworkException(
      customMessage ?? 'The request timed out. Please check your connection.',
      statusCode: 408,
      details: {
        'timeout_duration': timeout?.toString(),
      },
    );
  }

  /// Creates an exception for connection failures
  factory SanctumNetworkException.connectionFailed({
    String? customMessage,
    dynamic originalException,
  }) {
    return SanctumNetworkException(
      customMessage ?? 'Failed to connect to the server. Please check your internet connection.',
      originalException: originalException,
    );
  }

  /// Creates an exception for server errors
  factory SanctumNetworkException.serverError({
    required int statusCode,
    String? customMessage,
    Map<String, dynamic>? details,
  }) {
    return SanctumNetworkException(
      customMessage ?? 'The server encountered an error. Please try again later.',
      code: SanctumConstants.errorServerError,
      statusCode: statusCode,
      details: details,
    );
  }

  @override
  bool get isRecoverable => statusCode != null && statusCode! >= 500;

  @override
  String? get recoveryAction {
    if (statusCode != null && statusCode! >= 500) {
      return 'This appears to be a server issue. Please try again in a few minutes.';
    }
    return 'Please check your internet connection and try again.';
  }

  @override
  String get userFriendlyMessage {
    if (statusCode == 408) {
      return 'The request took too long. Please try again.';
    } else if (statusCode != null && statusCode! >= 500) {
      return 'The server is experiencing issues. Please try again later.';
    }
    return 'Unable to connect to the server. Please check your internet connection.';
  }
}

/// Exception thrown when request validation fails
///
/// This exception is thrown when the server returns validation errors,
/// typically for form submissions with invalid data.
@immutable
class SanctumValidationException extends SanctumException {
  /// Field-specific validation errors
  final Map<String, List<String>> fieldErrors;

  /// Creates a new [SanctumValidationException] instance
  const SanctumValidationException(
    super.message, {
    super.code = SanctumConstants.errorValidationFailed,
    super.statusCode = SanctumConstants.statusUnprocessableEntity,
    super.details,
    super.stackTrace,
    this.fieldErrors = const {},
  });

  /// Creates a validation exception from server response
  factory SanctumValidationException.fromResponse({
    required Map<String, List<String>> errors,
    String? customMessage,
  }) {
    final allErrors = errors.values.expand((e) => e).toList();
    final message = customMessage ??
        (allErrors.isNotEmpty ? allErrors.first : 'Validation failed');

    return SanctumValidationException(
      message,
      fieldErrors: errors,
      details: {'field_errors': errors},
    );
  }

  /// Gets the first error message for a specific field
  String? getFieldError(String field) {
    final errors = fieldErrors[field];
    return errors != null && errors.isNotEmpty ? errors.first : null;
  }

  /// Gets all error messages for a specific field
  List<String> getFieldErrors(String field) {
    return fieldErrors[field] ?? [];
  }

  /// Gets all error messages as a flat list
  List<String> get allErrors {
    return fieldErrors.values.expand((e) => e).toList();
  }

  /// Whether a specific field has errors
  bool hasFieldError(String field) {
    return fieldErrors.containsKey(field) && fieldErrors[field]!.isNotEmpty;
  }

  @override
  String get userFriendlyMessage {
    final errors = allErrors;
    if (errors.isEmpty) return message;
    return errors.length == 1 ? errors.first : 'Please fix the following errors and try again.';
  }

  @override
  String? get recoveryAction {
    return 'Please correct the highlighted fields and try again.';
  }
}

/// Exception thrown when rate limiting is encountered
///
/// This exception is thrown when the server returns a 429 Too Many Requests
/// response, indicating that the client has exceeded the rate limit.
@immutable
class SanctumRateLimitException extends SanctumException {
  /// Time until the rate limit resets
  final Duration? retryAfter;

  /// Maximum number of requests allowed
  final int? maxRequests;

  /// Current number of requests made
  final int? currentRequests;

  /// Creates a new [SanctumRateLimitException] instance
  const SanctumRateLimitException(
    super.message, {
    super.code = SanctumConstants.errorRateLimited,
    super.statusCode = SanctumConstants.statusTooManyRequests,
    super.details,
    super.stackTrace,
    this.retryAfter,
    this.maxRequests,
    this.currentRequests,
  });

  /// Creates a rate limit exception from response headers
  factory SanctumRateLimitException.fromHeaders({
    Map<String, dynamic>? headers,
    String? customMessage,
  }) {
    Duration? retryAfter;
    int? maxRequests;
    int? currentRequests;

    if (headers != null) {
      final retryAfterHeader = headers['retry-after'] ?? headers['Retry-After'];
      if (retryAfterHeader != null) {
        final seconds = int.tryParse(retryAfterHeader.toString());
        if (seconds != null) {
          retryAfter = Duration(seconds: seconds);
        }
      }

      final limitHeader = headers['x-ratelimit-limit'] ?? headers['X-RateLimit-Limit'];
      if (limitHeader != null) {
        maxRequests = int.tryParse(limitHeader.toString());
      }

      final remainingHeader = headers['x-ratelimit-remaining'] ?? headers['X-RateLimit-Remaining'];
      if (remainingHeader != null) {
        final remaining = int.tryParse(remainingHeader.toString());
        if (remaining != null && maxRequests != null) {
          currentRequests = maxRequests - remaining;
        }
      }
    }

    final message = customMessage ??
        'Too many requests. ${retryAfter != null ? 'Try again in ${retryAfter.inSeconds} seconds.' : 'Please try again later.'}';

    return SanctumRateLimitException(
      message,
      retryAfter: retryAfter,
      maxRequests: maxRequests,
      currentRequests: currentRequests,
      details: {
        'retry_after_seconds': retryAfter?.inSeconds,
        'max_requests': maxRequests,
        'current_requests': currentRequests,
      },
    );
  }

  @override
  bool get isRecoverable => true;

  @override
  String? get recoveryAction {
    if (retryAfter != null) {
      return 'Please wait ${retryAfter!.inSeconds} seconds before trying again.';
    }
    return 'Please wait a moment before trying again.';
  }

  @override
  String get userFriendlyMessage {
    if (retryAfter != null) {
      final seconds = retryAfter!.inSeconds;
      if (seconds < 60) {
        return 'Too many requests. Please wait $seconds seconds.';
      } else {
        final minutes = (seconds / 60).ceil();
        return 'Too many requests. Please wait $minutes minute${minutes > 1 ? 's' : ''}.';
      }
    }
    return 'You\'re making requests too quickly. Please slow down.';
  }
}

/// Exception thrown when CSRF protection fails
///
/// This exception is thrown when CSRF token validation fails in SPA mode,
/// typically indicating a mismatch between the token and the request.
@immutable
class SanctumCsrfException extends SanctumException {
  /// Creates a new [SanctumCsrfException] instance
  const SanctumCsrfException(
    super.message, {
    super.code = SanctumConstants.errorCsrfMismatch,
    super.statusCode = SanctumConstants.statusForbidden,
    super.details,
    super.stackTrace,
  });

  /// Creates a CSRF exception for token mismatch
  factory SanctumCsrfException.tokenMismatch({
    String? customMessage,
  }) {
    return SanctumCsrfException(
      customMessage ?? 'CSRF token mismatch. Please refresh the page and try again.',
    );
  }

  @override
  bool get isRecoverable => true;

  @override
  String? get recoveryAction => 'Please refresh the page and try again.';

  @override
  String get userFriendlyMessage {
    return 'Security token expired. Please refresh the page and try again.';
  }
}

/// Exception thrown when configuration is invalid
///
/// This exception is thrown when the Sanctum configuration is invalid
/// or missing required parameters.
@immutable
class SanctumConfigurationException extends SanctumException {
  /// Creates a new [SanctumConfigurationException] instance
  const SanctumConfigurationException(
    super.message, {
    super.code,
    super.statusCode,
    super.details,
    super.stackTrace,
  });

  /// Creates an exception for missing base URL
  factory SanctumConfigurationException.missingBaseUrl() {
    return const SanctumConfigurationException(
      'Base URL is required for Sanctum authentication.',
      details: {'required_field': 'baseUrl'},
    );
  }

  /// Creates an exception for invalid URL format
  factory SanctumConfigurationException.invalidUrl(String url) {
    return SanctumConfigurationException(
      'Invalid URL format: $url',
      details: {'invalid_url': url},
    );
  }

  @override
  String get userFriendlyMessage {
    return 'Configuration error. Please check your setup.';
  }

  @override
  String? get recoveryAction {
    return 'Please verify your Sanctum configuration and try again.';
  }
}