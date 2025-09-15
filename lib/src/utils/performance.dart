import 'dart:async';
import 'dart:collection';
import 'package:meta/meta.dart';

import 'logger.dart';

/// Performance monitoring and optimization utilities for Laravel Sanctum
///
/// This class provides caching, connection pooling, and performance monitoring
/// capabilities to optimize the performance of authentication operations.
class SanctumPerformance {
  /// Cache for storing frequently accessed data
  final SanctumCache _cache;

  /// Connection pool for HTTP connections
  final SanctumConnectionPool _connectionPool;

  /// Performance metrics collector
  final SanctumMetrics _metrics;

  /// Logger for performance-related events
  final SanctumLogger _logger;

  /// Creates a new [SanctumPerformance] instance
  SanctumPerformance({
    SanctumCache? cache,
    SanctumConnectionPool? connectionPool,
    SanctumMetrics? metrics,
    SanctumLogger? logger,
  })  : _cache = cache ?? SanctumCache(),
        _connectionPool = connectionPool ?? SanctumConnectionPool(),
        _metrics = metrics ?? SanctumMetrics(),
        _logger = logger ?? SanctumLogger();

  /// Gets the cache instance
  SanctumCache get cache => _cache;

  /// Gets the connection pool instance
  SanctumConnectionPool get connectionPool => _connectionPool;

  /// Gets the metrics instance
  SanctumMetrics get metrics => _metrics;

  /// Measures the execution time of an operation
  Future<T> measureOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();
      stopwatch.stop();

      final duration = stopwatch.elapsed;
      _metrics.recordOperation(operationName, duration);
      _logger.logPerformance(
        operation: operationName,
        duration: duration,
      );

      return result;
    } catch (e) {
      stopwatch.stop();
      _metrics.recordOperation(operationName, stopwatch.elapsed, error: true);
      rethrow;
    }
  }

  /// Executes an operation with caching
  Future<T> cached<T>(
    String key,
    Future<T> Function() operation, {
    Duration? ttl,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.get<T>(key);
      if (cached != null) {
        _logger.logCacheOperation(
          operation: 'HIT',
          key: key,
        );
        return cached;
      }
    }

    _logger.logCacheOperation(
      operation: forceRefresh ? 'REFRESH' : 'MISS',
      key: key,
    );

    final result = await operation();
    _cache.set(key, result, ttl: ttl);

    return result;
  }

  /// Clears all cached data
  void clearCache() {
    _cache.clear();
    _logger.logCacheOperation(
      operation: 'CLEAR_ALL',
      key: 'all',
    );
  }

  /// Gets performance statistics
  SanctumPerformanceStats getStats() {
    return SanctumPerformanceStats(
      cacheStats: _cache.getStats(),
      connectionPoolStats: _connectionPool.getStats(),
      metricsStats: _metrics.getStats(),
    );
  }

  /// Disposes of resources
  void dispose() {
    _cache.dispose();
    _connectionPool.dispose();
    _metrics.dispose();
  }
}

/// High-performance in-memory cache implementation
class SanctumCache {
  /// Internal cache storage
  final Map<String, _CacheEntry> _cache = HashMap<String, _CacheEntry>();

  /// Maximum cache size
  final int maxSize;

  /// Default TTL for cache entries
  final Duration defaultTtl;

  /// Timer for periodic cleanup
  Timer? _cleanupTimer;

  /// Creates a new [SanctumCache] instance
  SanctumCache({
    this.maxSize = 100,
    this.defaultTtl = const Duration(minutes: 5),
  }) {
    _startCleanupTimer();
  }

  /// Starts the periodic cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _cleanup(),
    );
  }

  /// Gets a value from the cache
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    entry._updateLastAccessed();
    return entry.value as T?;
  }

  /// Sets a value in the cache
  void set<T>(String key, T value, {Duration? ttl}) {
    if (_cache.length >= maxSize) {
      _evictLeastRecentlyUsed();
    }

    final entry = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );

    _cache[key] = entry;
  }

  /// Removes a value from the cache
  void remove(String key) {
    _cache.remove(key);
  }

  /// Clears all cache entries
  void clear() {
    _cache.clear();
  }

  /// Checks if a key exists in the cache
  bool containsKey(String key) {
    final entry = _cache[key];
    if (entry == null) return false;

    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }

    return true;
  }

  /// Gets cache statistics
  SanctumCacheStats getStats() {
    final now = DateTime.now();
    int expiredCount = 0;
    int totalSize = 0;

    for (final entry in _cache.values) {
      if (entry.expiresAt.isBefore(now)) {
        expiredCount++;
      }
      totalSize += entry.estimatedSize;
    }

    return SanctumCacheStats(
      entryCount: _cache.length,
      expiredCount: expiredCount,
      totalSize: totalSize,
      maxSize: maxSize,
      hitRate: 0.0, // This would be calculated over time in a real implementation
    );
  }

  /// Removes expired entries from the cache
  void _cleanup() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.expiresAt.isBefore(now)) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }

  /// Evicts the least recently used entry
  void _evictLeastRecentlyUsed() {
    if (_cache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      if (oldestTime == null || entry.value.lastAccessed.isBefore(oldestTime)) {
        oldestTime = entry.value.lastAccessed;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }

  /// Disposes of the cache and cleanup timer
  void dispose() {
    _cleanupTimer?.cancel();
    clear();
  }
}

/// Represents a cached entry with metadata
class _CacheEntry {
  /// The cached value
  final dynamic value;

  /// When this entry expires
  final DateTime expiresAt;

  /// When this entry was last accessed
  DateTime _lastAccessed;

  /// Creates a new cache entry
  _CacheEntry({
    required this.value,
    required this.expiresAt,
  }) : _lastAccessed = DateTime.now();

  /// Gets the last accessed time
  DateTime get lastAccessed => _lastAccessed;

  /// Updates the last accessed time
  void _updateLastAccessed() {
    _lastAccessed = DateTime.now();
  }

  /// Whether this entry has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Estimated size of this entry in memory
  int get estimatedSize {
    // Simple estimation based on type
    if (value is String) {
      return (value as String).length * 2; // UTF-16 encoding
    } else if (value is List) {
      return (value as List).length * 8; // Rough estimate
    } else if (value is Map) {
      return (value as Map).length * 16; // Rough estimate
    } else {
      return 8; // Default size for other types
    }
  }
}

/// Connection pool for managing HTTP connections
class SanctumConnectionPool {
  /// Maximum number of connections
  final int maxConnections;

  /// Connection timeout
  final Duration connectionTimeout;

  /// Keep-alive duration
  final Duration keepAliveDuration;

  /// Active connections count
  int _activeConnections = 0;

  /// Total connections created
  int _totalConnections = 0;

  /// Creates a new [SanctumConnectionPool] instance
  SanctumConnectionPool({
    this.maxConnections = 5,
    this.connectionTimeout = const Duration(seconds: 15),
    this.keepAliveDuration = const Duration(seconds: 30),
  });

  /// Acquires a connection from the pool
  Future<SanctumConnection> acquire() async {
    if (_activeConnections >= maxConnections) {
      throw Exception('Connection pool exhausted');
    }

    _activeConnections++;
    _totalConnections++;

    return SanctumConnection(
      id: _totalConnections,
      createdAt: DateTime.now(),
      pool: this,
    );
  }

  /// Releases a connection back to the pool
  void release(SanctumConnection connection) {
    if (_activeConnections > 0) {
      _activeConnections--;
    }
  }

  /// Gets connection pool statistics
  SanctumConnectionPoolStats getStats() {
    return SanctumConnectionPoolStats(
      activeConnections: _activeConnections,
      totalConnections: _totalConnections,
      maxConnections: maxConnections,
      utilizationRate: _activeConnections / maxConnections,
    );
  }

  /// Disposes of the connection pool
  void dispose() {
    _activeConnections = 0;
  }
}

/// Represents a connection from the pool
class SanctumConnection {
  /// Unique identifier for this connection
  final int id;

  /// When this connection was created
  final DateTime createdAt;

  /// Reference to the connection pool
  final SanctumConnectionPool pool;

  /// Creates a new connection
  SanctumConnection({
    required this.id,
    required this.createdAt,
    required this.pool,
  });

  /// Releases this connection back to the pool
  void release() {
    pool.release(this);
  }

  /// Whether this connection has expired
  bool get isExpired {
    return DateTime.now().difference(createdAt) > pool.keepAliveDuration;
  }
}

/// Metrics collection for performance monitoring
class SanctumMetrics {
  /// Operation timing data
  final Map<String, List<Duration>> _operationTimes = HashMap();

  /// Error counts by operation
  final Map<String, int> _errorCounts = HashMap();

  /// Total operation counts
  final Map<String, int> _operationCounts = HashMap();

  /// Records an operation completion
  void recordOperation(String operation, Duration duration, {bool error = false}) {
    _operationTimes.putIfAbsent(operation, () => <Duration>[]);
    _operationTimes[operation]!.add(duration);

    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;

    if (error) {
      _errorCounts[operation] = (_errorCounts[operation] ?? 0) + 1;
    }

    // Keep only the last 1000 entries per operation to prevent memory leaks
    if (_operationTimes[operation]!.length > 1000) {
      _operationTimes[operation]!.removeAt(0);
    }
  }

  /// Gets average duration for an operation
  Duration? getAverageDuration(String operation) {
    final times = _operationTimes[operation];
    if (times == null || times.isEmpty) return null;

    final totalMicroseconds = times
        .map((d) => d.inMicroseconds)
        .reduce((a, b) => a + b);

    return Duration(microseconds: totalMicroseconds ~/ times.length);
  }

  /// Gets error rate for an operation
  double getErrorRate(String operation) {
    final totalCount = _operationCounts[operation] ?? 0;
    final errorCount = _errorCounts[operation] ?? 0;

    if (totalCount == 0) return 0.0;
    return errorCount / totalCount;
  }

  /// Gets metrics statistics
  SanctumMetricsStats getStats() {
    final operations = <String, SanctumOperationStats>{};

    for (final operation in _operationCounts.keys) {
      final times = _operationTimes[operation] ?? [];
      final count = _operationCounts[operation] ?? 0;
      final errors = _errorCounts[operation] ?? 0;

      if (times.isNotEmpty) {
        times.sort((a, b) => a.compareTo(b));
        final p50Index = (times.length * 0.5).floor();
        final p95Index = (times.length * 0.95).floor();
        final p99Index = (times.length * 0.99).floor();

        operations[operation] = SanctumOperationStats(
          name: operation,
          count: count,
          errorCount: errors,
          averageDuration: getAverageDuration(operation)!,
          p50Duration: times[p50Index],
          p95Duration: times[p95Index],
          p99Duration: times[p99Index],
          minDuration: times.first,
          maxDuration: times.last,
        );
      }
    }

    return SanctumMetricsStats(operations: operations);
  }

  /// Clears all metrics data
  void clear() {
    _operationTimes.clear();
    _errorCounts.clear();
    _operationCounts.clear();
  }

  /// Disposes of metrics resources
  void dispose() {
    clear();
  }
}

/// Performance statistics container
@immutable
class SanctumPerformanceStats {
  /// Cache statistics
  final SanctumCacheStats cacheStats;

  /// Connection pool statistics
  final SanctumConnectionPoolStats connectionPoolStats;

  /// Metrics statistics
  final SanctumMetricsStats metricsStats;

  /// Creates performance statistics
  const SanctumPerformanceStats({
    required this.cacheStats,
    required this.connectionPoolStats,
    required this.metricsStats,
  });

  @override
  String toString() {
    return 'SanctumPerformanceStats{'
        'cache: $cacheStats, '
        'connectionPool: $connectionPoolStats, '
        'operations: ${metricsStats.operations.length}'
        '}';
  }
}

/// Cache statistics
@immutable
class SanctumCacheStats {
  final int entryCount;
  final int expiredCount;
  final int totalSize;
  final int maxSize;
  final double hitRate;

  const SanctumCacheStats({
    required this.entryCount,
    required this.expiredCount,
    required this.totalSize,
    required this.maxSize,
    required this.hitRate,
  });

  @override
  String toString() {
    return 'SanctumCacheStats{'
        'entries: $entryCount/$maxSize, '
        'expired: $expiredCount, '
        'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%'
        '}';
  }
}

/// Connection pool statistics
@immutable
class SanctumConnectionPoolStats {
  final int activeConnections;
  final int totalConnections;
  final int maxConnections;
  final double utilizationRate;

  const SanctumConnectionPoolStats({
    required this.activeConnections,
    required this.totalConnections,
    required this.maxConnections,
    required this.utilizationRate,
  });

  @override
  String toString() {
    return 'SanctumConnectionPoolStats{'
        'active: $activeConnections/$maxConnections, '
        'total: $totalConnections, '
        'utilization: ${(utilizationRate * 100).toStringAsFixed(1)}%'
        '}';
  }
}

/// Metrics statistics
@immutable
class SanctumMetricsStats {
  final Map<String, SanctumOperationStats> operations;

  const SanctumMetricsStats({
    required this.operations,
  });
}

/// Statistics for a specific operation
@immutable
class SanctumOperationStats {
  final String name;
  final int count;
  final int errorCount;
  final Duration averageDuration;
  final Duration p50Duration;
  final Duration p95Duration;
  final Duration p99Duration;
  final Duration minDuration;
  final Duration maxDuration;

  const SanctumOperationStats({
    required this.name,
    required this.count,
    required this.errorCount,
    required this.averageDuration,
    required this.p50Duration,
    required this.p95Duration,
    required this.p99Duration,
    required this.minDuration,
    required this.maxDuration,
  });

  double get errorRate => count > 0 ? errorCount / count : 0.0;

  @override
  String toString() {
    return 'SanctumOperationStats{'
        'name: $name, '
        'count: $count, '
        'avgDuration: ${averageDuration.inMilliseconds}ms, '
        'errorRate: ${(errorRate * 100).toStringAsFixed(1)}%'
        '}';
  }
}