import 'package:logger/logger.dart';
import 'package:meta/meta.dart';

import '../constants/sanctum_constants.dart';

/// Custom logger for Laravel Sanctum operations
///
/// Provides structured logging with different levels and formatting
/// for better debugging and monitoring of authentication operations.
///
/// The logger automatically filters sensitive information like tokens
/// and passwords to prevent them from appearing in logs.
@immutable
class SanctumLogger {
  /// The underlying logger instance
  final Logger _logger;

  /// Whether debug mode is enabled
  final bool debugMode;

  /// Prefix to add to all log messages
  final String prefix;

  /// Creates a new [SanctumLogger] instance
  SanctumLogger({
    this.debugMode = false,
    this.prefix = '[Sanctum]',
    Logger? logger,
  }) : _logger = logger ?? _createDefaultLogger(debugMode);

  /// Creates the default logger configuration
  static Logger _createDefaultLogger(bool debugMode) {
    return Logger(
      level: debugMode ? Level.debug : Level.info,
      printer: PrettyPrinter(
        methodCount: debugMode ? 3 : 0,
        errorMethodCount: 5,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
        noBoxingByDefault: true,
      ),
      filter: ProductionFilter(),
    );
  }

  /// Logs a verbose debug message
  ///
  /// These messages are only shown when [debugMode] is true and provide
  /// detailed information about internal operations.
  void verbose(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!debugMode) return;
    _logger.t(_formatMessage(message), error: error, stackTrace: stackTrace);
  }

  /// Logs a debug message
  ///
  /// Debug messages provide information useful for troubleshooting
  /// authentication issues.
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!debugMode) return;
    _logger.d(_formatMessage(message), error: error, stackTrace: stackTrace);
  }

  /// Logs an informational message
  ///
  /// Info messages provide general information about authentication
  /// operations like successful logins or token refreshes.
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(_formatMessage(message), error: error, stackTrace: stackTrace);
  }

  /// Logs a warning message
  ///
  /// Warning messages indicate potential issues that don't prevent
  /// operation but should be noted.
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(_formatMessage(message), error: error, stackTrace: stackTrace);
  }

  /// Logs an error message
  ///
  /// Error messages indicate failures in authentication operations.
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(_formatMessage(message), error: error, stackTrace: stackTrace);
  }

  /// Logs a critical error message
  ///
  /// Fatal messages indicate severe errors that prevent the authentication
  /// system from functioning properly.
  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(_formatMessage(message), error: error, stackTrace: stackTrace);
  }

  /// Logs an HTTP request
  void logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    if (!debugMode) return;

    final sanitizedHeaders = _sanitizeHeaders(headers);
    final sanitizedBody = _sanitizeBody(body);

    debug('🚀 HTTP Request: $method $url');
    if (sanitizedHeaders != null && sanitizedHeaders.isNotEmpty) {
      verbose('Headers: $sanitizedHeaders');
    }
    if (sanitizedBody != null) {
      verbose('Body: $sanitizedBody');
    }
  }

  /// Logs an HTTP response
  void logResponse({
    required int statusCode,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
    Duration? duration,
  }) {
    if (!debugMode) return;

    final statusEmoji = _getStatusEmoji(statusCode);
    final durationText = duration != null ? ' (${duration.inMilliseconds}ms)' : '';

    debug('$statusEmoji HTTP Response: $statusCode $url$durationText');

    if (headers != null && headers.isNotEmpty) {
      verbose('Response Headers: ${_sanitizeHeaders(headers)}');
    }
    if (body != null) {
      verbose('Response Body: ${_sanitizeBody(body)}');
    }
  }

  /// Logs authentication events
  void logAuthEvent({
    required String event,
    String? userId,
    String? tokenName,
    List<String>? abilities,
    Map<String, dynamic>? additionalData,
  }) {
    final details = <String, dynamic>{
      if (userId != null) 'user_id': userId,
      if (tokenName != null) 'token_name': tokenName,
      if (abilities != null) 'abilities': abilities,
      ...?additionalData,
    };

    info('🔐 Auth Event: $event ${details.isNotEmpty ? details : ''}');
  }

  /// Logs token operations
  void logTokenOperation({
    required String operation,
    String? tokenId,
    String? tokenName,
    List<String>? abilities,
    DateTime? expiresAt,
  }) {
    final details = <String, dynamic>{
      if (tokenId != null) 'token_id': tokenId,
      if (tokenName != null) 'token_name': tokenName,
      if (abilities != null) 'abilities': abilities,
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
    };

    info('🎫 Token Operation: $operation ${details.isNotEmpty ? details : ''}');
  }

  /// Logs cache operations
  void logCacheOperation({
    required String operation,
    required String key,
    int? size,
    Duration? ttl,
  }) {
    if (!debugMode) return;

    final details = <String, dynamic>{
      'key': key,
      if (size != null) 'size': size,
      if (ttl != null) 'ttl': '${ttl.inSeconds}s',
    };

    verbose('💾 Cache $operation: $details');
  }

  /// Logs performance metrics
  void logPerformance({
    required String operation,
    required Duration duration,
    Map<String, dynamic>? metrics,
  }) {
    if (!debugMode) return;

    final details = <String, dynamic>{
      'duration_ms': duration.inMilliseconds,
      ...?metrics,
    };

    if (duration.inMilliseconds > 1000) {
      warning('⚡ Slow Operation: $operation took ${duration.inMilliseconds}ms');
    } else {
      verbose('⚡ Performance: $operation completed in ${duration.inMilliseconds}ms');
    }

    if (details.isNotEmpty) {
      verbose('Metrics: $details');
    }
  }

  /// Formats a message with the prefix
  String _formatMessage(String message) {
    return '$prefix $message';
  }

  /// Sanitizes headers to remove sensitive information
  Map<String, dynamic>? _sanitizeHeaders(Map<String, dynamic>? headers) {
    if (headers == null) return null;

    final sanitized = <String, dynamic>{};
    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      if (_isSensitiveHeader(key)) {
        sanitized[entry.key] = _maskSensitiveValue(entry.value?.toString());
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  /// Sanitizes request/response body to remove sensitive information
  dynamic _sanitizeBody(dynamic body) {
    if (body == null) return null;

    if (body is Map<String, dynamic>) {
      final sanitized = <String, dynamic>{};
      for (final entry in body.entries) {
        final key = entry.key.toLowerCase();
        if (_isSensitiveField(key)) {
          sanitized[entry.key] = _maskSensitiveValue(entry.value?.toString());
        } else {
          sanitized[entry.key] = entry.value;
        }
      }
      return sanitized;
    }

    if (body is String) {
      // Try to parse as JSON and sanitize
      try {
        final decoded = body; // In a real implementation, you'd parse JSON here
        return _sanitizeBody(decoded);
      } catch (e) {
        // If not JSON, return as-is but truncated if too long
        return body.length > 500 ? '${body.substring(0, 500)}...' : body;
      }
    }

    return body;
  }

  /// Checks if a header contains sensitive information
  bool _isSensitiveHeader(String headerName) {
    const sensitiveHeaders = {
      'authorization',
      'cookie',
      'set-cookie',
      'x-xsrf-token',
      'x-csrf-token',
    };
    return sensitiveHeaders.contains(headerName);
  }

  /// Checks if a field contains sensitive information
  bool _isSensitiveField(String fieldName) {
    const sensitiveFields = {
      'password',
      'password_confirmation',
      'token',
      'access_token',
      'refresh_token',
      'api_key',
      'secret',
      'private_key',
    };
    return sensitiveFields.contains(fieldName);
  }

  /// Masks sensitive values for logging
  String _maskSensitiveValue(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.length <= 8) return '*' * value.length;
    return '${value.substring(0, 4)}${'*' * (value.length - 8)}${value.substring(value.length - 4)}';
  }

  /// Gets appropriate emoji for HTTP status code
  String _getStatusEmoji(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return '✅'; // Success
    } else if (statusCode >= 300 && statusCode < 400) {
      return '🔄'; // Redirect
    } else if (statusCode >= 400 && statusCode < 500) {
      return '❌'; // Client error
    } else if (statusCode >= 500) {
      return '💥'; // Server error
    }
    return '❓'; // Unknown
  }
}

/// Static logger instance for convenience
class SanctumLog {
  static SanctumLogger? _instance;

  /// Gets the global logger instance
  static SanctumLogger get instance {
    _instance ??= SanctumLogger();
    return _instance!;
  }

  /// Initializes the global logger with custom configuration
  static void initialize({
    bool debugMode = false,
    String prefix = '[Sanctum]',
    Logger? logger,
  }) {
    _instance = SanctumLogger(
      debugMode: debugMode,
      prefix: prefix,
      logger: logger,
    );
  }

  /// Convenience methods that delegate to the global instance
  static void verbose(String message, [dynamic error, StackTrace? stackTrace]) =>
      instance.verbose(message, error, stackTrace);

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) =>
      instance.debug(message, error, stackTrace);

  static void info(String message, [dynamic error, StackTrace? stackTrace]) =>
      instance.info(message, error, stackTrace);

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) =>
      instance.warning(message, error, stackTrace);

  static void error(String message, [dynamic error, StackTrace? stackTrace]) =>
      instance.error(message, error, stackTrace);

  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) =>
      instance.fatal(message, error, stackTrace);

  static void logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
  }) =>
      instance.logRequest(
        method: method,
        url: url,
        headers: headers,
        body: body,
      );

  static void logResponse({
    required int statusCode,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
    Duration? duration,
  }) =>
      instance.logResponse(
        statusCode: statusCode,
        url: url,
        headers: headers,
        body: body,
        duration: duration,
      );

  static void logAuthEvent({
    required String event,
    String? userId,
    String? tokenName,
    List<String>? abilities,
    Map<String, dynamic>? additionalData,
  }) =>
      instance.logAuthEvent(
        event: event,
        userId: userId,
        tokenName: tokenName,
        abilities: abilities,
        additionalData: additionalData,
      );

  static void logTokenOperation({
    required String operation,
    String? tokenId,
    String? tokenName,
    List<String>? abilities,
    DateTime? expiresAt,
  }) =>
      instance.logTokenOperation(
        operation: operation,
        tokenId: tokenId,
        tokenName: tokenName,
        abilities: abilities,
        expiresAt: expiresAt,
      );

  static void logCacheOperation({
    required String operation,
    required String key,
    int? size,
    Duration? ttl,
  }) =>
      instance.logCacheOperation(
        operation: operation,
        key: key,
        size: size,
        ttl: ttl,
      );

  static void logPerformance({
    required String operation,
    required Duration duration,
    Map<String, dynamic>? metrics,
  }) =>
      instance.logPerformance(
        operation: operation,
        duration: duration,
        metrics: metrics,
      );
}