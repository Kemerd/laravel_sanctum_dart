import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../models/auth_config.dart';
import '../models/token.dart';
import '../exceptions/sanctum_exceptions.dart';
import '../constants/sanctum_constants.dart';
import '../utils/storage.dart';
import '../utils/logger.dart';

/// Manager for Laravel Sanctum API token operations
///
/// This class handles the creation, revocation, and management of API tokens
/// for Laravel Sanctum. It provides methods for creating tokens with specific
/// abilities, listing existing tokens, and revoking tokens when needed.
///
/// Example usage:
/// ```dart
/// final tokenManager = SanctumTokenManager(dio: dio, config: config);
///
/// // Create a new token
/// final token = await tokenManager.createToken(
///   name: 'Mobile App',
///   abilities: ['read', 'write'],
/// );
///
/// // List all tokens
/// final tokens = await tokenManager.listTokens();
///
/// // Revoke a specific token
/// await tokenManager.revokeToken(tokenId: 123);
/// ```
@immutable
class SanctumTokenManager {
  /// HTTP client for making requests
  final Dio _dio;

  /// Configuration settings
  final SanctumConfig _config;

  /// Secure storage for token data
  final SanctumStorage _storage;

  /// Logger for debugging
  final SanctumLogger _logger;

  /// Creates a new [SanctumTokenManager] instance
  const SanctumTokenManager({
    required Dio dio,
    required SanctumConfig config,
    required SanctumStorage storage,
    required SanctumLogger logger,
  })  : _dio = dio,
        _config = config,
        _storage = storage,
        _logger = logger;

  /// Creates a new API token with the specified name and abilities
  ///
  /// [name] - Human-readable name for the token (e.g., device name)
  /// [abilities] - List of abilities/scopes to grant to the token
  /// [expiresAt] - Optional expiration date for the token
  ///
  /// Returns a [SanctumTokenResponse] containing the token and metadata.
  Future<SanctumTokenResponse> createToken({
    required String name,
    List<String> abilities = const ['*'],
    DateTime? expiresAt,
  }) async {
    try {
      _logger.logTokenOperation(
        operation: 'CREATE_REQUEST',
        tokenName: name,
        abilities: abilities,
        expiresAt: expiresAt,
      );

      final request = SanctumTokenRequest(
        name: name,
        abilities: abilities,
        expiresAt: expiresAt,
      );

      final response = await _dio.post(
        _config.endpoints.createToken,
        data: request.toJson(),
      );

      final tokenResponse = SanctumTokenResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      _logger.logTokenOperation(
        operation: 'CREATE_SUCCESS',
        tokenName: name,
        abilities: abilities,
        expiresAt: expiresAt,
      );

      return tokenResponse;
    } on DioException catch (e) {
      _logger.logTokenOperation(
        operation: 'CREATE_FAILED',
        tokenName: name,
      );
      throw _handleDioException(e);
    }
  }

  /// Lists all API tokens for the authenticated user
  ///
  /// Returns a list of [SanctumToken] objects representing all tokens
  /// associated with the current user account.
  Future<List<SanctumToken>> listTokens() async {
    try {
      _logger.logTokenOperation(operation: 'LIST_REQUEST');

      final response = await _dio.get(_config.endpoints.listTokens);

      final tokensData = (response.data['tokens'] ?? response.data) as List;
      final tokens = tokensData
          .map((tokenData) => SanctumToken.fromJson(tokenData as Map<String, dynamic>))
          .toList();

      _logger.logTokenOperation(
        operation: 'LIST_SUCCESS',
      );

      return tokens;
    } on DioException catch (e) {
      _logger.logTokenOperation(operation: 'LIST_FAILED');
      throw _handleDioException(e);
    }
  }

  /// Revokes a specific token by its ID
  ///
  /// [tokenId] - The ID of the token to revoke
  ///
  /// This will permanently invalidate the token and prevent it from being
  /// used for future authentication.
  Future<void> revokeToken({required int tokenId}) async {
    try {
      _logger.logTokenOperation(
        operation: 'REVOKE_REQUEST',
        tokenId: tokenId.toString(),
      );

      await _dio.delete('${_config.endpoints.revokeTokens}/$tokenId');

      _logger.logTokenOperation(
        operation: 'REVOKE_SUCCESS',
        tokenId: tokenId.toString(),
      );
    } on DioException catch (e) {
      _logger.logTokenOperation(
        operation: 'REVOKE_FAILED',
        tokenId: tokenId.toString(),
      );
      throw _handleDioException(e);
    }
  }

  /// Revokes multiple tokens by their IDs
  ///
  /// [tokenIds] - List of token IDs to revoke
  ///
  /// This is more efficient than calling [revokeToken] multiple times
  /// when you need to revoke several tokens at once.
  Future<void> revokeTokens({required List<int> tokenIds}) async {
    try {
      _logger.logTokenOperation(
        operation: 'REVOKE_MULTIPLE_REQUEST',
      );

      await _dio.post(
        _config.endpoints.revokeTokens,
        data: {'token_ids': tokenIds},
      );

      _logger.logTokenOperation(
        operation: 'REVOKE_MULTIPLE_SUCCESS',
      );
    } on DioException catch (e) {
      _logger.logTokenOperation(
        operation: 'REVOKE_MULTIPLE_FAILED',
      );
      throw _handleDioException(e);
    }
  }

  /// Revokes all tokens for the authenticated user
  ///
  /// This will invalidate all API tokens associated with the current user,
  /// effectively logging them out from all devices and applications.
  Future<void> revokeAllTokens() async {
    try {
      _logger.logTokenOperation(operation: 'REVOKE_ALL_REQUEST');

      await _dio.post(_config.endpoints.revokeTokens);

      _logger.logTokenOperation(operation: 'REVOKE_ALL_SUCCESS');
    } on DioException catch (e) {
      _logger.logTokenOperation(operation: 'REVOKE_ALL_FAILED');
      throw _handleDioException(e);
    }
  }

  /// Gets detailed information about a specific token
  ///
  /// [tokenId] - The ID of the token to retrieve
  ///
  /// Returns a [SanctumToken] with detailed information including
  /// abilities, expiration, and usage statistics.
  Future<SanctumToken> getToken({required int tokenId}) async {
    try {
      _logger.logTokenOperation(
        operation: 'GET_REQUEST',
        tokenId: tokenId.toString(),
      );

      final response = await _dio.get('${_config.endpoints.listTokens}/$tokenId');

      final token = SanctumToken.fromJson(
        response.data as Map<String, dynamic>,
      );

      _logger.logTokenOperation(
        operation: 'GET_SUCCESS',
        tokenId: tokenId.toString(),
        tokenName: token.name,
      );

      return token;
    } on DioException catch (e) {
      _logger.logTokenOperation(
        operation: 'GET_FAILED',
        tokenId: tokenId.toString(),
      );
      throw _handleDioException(e);
    }
  }

  /// Updates the abilities of an existing token
  ///
  /// [tokenId] - The ID of the token to update
  /// [abilities] - New list of abilities to assign to the token
  ///
  /// Note: Not all Laravel Sanctum implementations support updating token
  /// abilities. This method may throw an exception if not supported.
  Future<SanctumToken> updateTokenAbilities({
    required int tokenId,
    required List<String> abilities,
  }) async {
    try {
      _logger.logTokenOperation(
        operation: 'UPDATE_ABILITIES_REQUEST',
        tokenId: tokenId.toString(),
        abilities: abilities,
      );

      final response = await _dio.put(
        '${_config.endpoints.listTokens}/$tokenId',
        data: {'abilities': abilities},
      );

      final token = SanctumToken.fromJson(
        response.data as Map<String, dynamic>,
      );

      _logger.logTokenOperation(
        operation: 'UPDATE_ABILITIES_SUCCESS',
        tokenId: tokenId.toString(),
        abilities: abilities,
      );

      return token;
    } on DioException catch (e) {
      _logger.logTokenOperation(
        operation: 'UPDATE_ABILITIES_FAILED',
        tokenId: tokenId.toString(),
      );
      throw _handleDioException(e);
    }
  }

  /// Checks if a token has a specific ability
  ///
  /// [tokenId] - The ID of the token to check
  /// [ability] - The ability to check for
  ///
  /// Returns true if the token has the specified ability.
  Future<bool> tokenHasAbility({
    required int tokenId,
    required String ability,
  }) async {
    try {
      final token = await getToken(tokenId: tokenId);
      return token.hasAbility(ability);
    } catch (e) {
      _logger.warning('Failed to check token ability: $e');
      return false;
    }
  }

  /// Gets statistics about the user's tokens
  ///
  /// Returns a [SanctumTokenStats] object with information about
  /// the user's token usage, including counts and expiration data.
  Future<SanctumTokenStats> getTokenStats() async {
    try {
      final tokens = await listTokens();

      int activeCount = 0;
      int expiredCount = 0;
      int expiringSoonCount = 0;
      final Map<String, int> abilityCounts = {};

      for (final token in tokens) {
        if (token.isExpired) {
          expiredCount++;
        } else {
          activeCount++;
          if (token.willExpireSoon) {
            expiringSoonCount++;
          }
        }

        for (final ability in token.abilities) {
          abilityCounts[ability] = (abilityCounts[ability] ?? 0) + 1;
        }
      }

      return SanctumTokenStats(
        totalCount: tokens.length,
        activeCount: activeCount,
        expiredCount: expiredCount,
        expiringSoonCount: expiringSoonCount,
        abilityCounts: abilityCounts,
      );
    } catch (e) {
      _logger.error('Failed to get token stats: $e');
      return const SanctumTokenStats(
        totalCount: 0,
        activeCount: 0,
        expiredCount: 0,
        expiringSoonCount: 0,
        abilityCounts: {},
      );
    }
  }

  /// Stores a token securely for future use
  ///
  /// [token] - The token to store
  /// [key] - Optional storage key (defaults to config storage key)
  Future<void> storeToken(SanctumToken token, {String? key}) async {
    try {
      await _storage.setSanctumToken(token, key: key);
      _logger.logTokenOperation(
        operation: 'STORE',
        tokenId: token.id?.toString(),
        tokenName: token.name,
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to store token', e, stackTrace);
      rethrow;
    }
  }

  /// Retrieves a stored token
  ///
  /// [key] - Optional storage key (defaults to config storage key)
  ///
  /// Returns the stored token or null if not found.
  Future<SanctumToken?> getStoredToken({String? key}) async {
    try {
      final token = await _storage.getSanctumToken(key: key);
      if (token != null) {
        _logger.logTokenOperation(
          operation: 'RETRIEVE',
          tokenId: token.id?.toString(),
          tokenName: token.name,
        );
      }
      return token;
    } catch (e, stackTrace) {
      _logger.error('Failed to retrieve stored token', e, stackTrace);
      return null;
    }
  }

  /// Removes a stored token
  ///
  /// [key] - Optional storage key (defaults to config storage key)
  Future<void> removeStoredToken({String? key}) async {
    try {
      await _storage.remove(key ?? 'token_object');
      _logger.logTokenOperation(operation: 'REMOVE_STORED');
    } catch (e, stackTrace) {
      _logger.error('Failed to remove stored token', e, stackTrace);
      rethrow;
    }
  }

  /// Converts Dio exceptions to Sanctum token exceptions
  SanctumException _handleDioException(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;

    if (statusCode == 401) {
      return SanctumAuthenticationException.invalidToken();
    } else if (statusCode == 403) {
      return SanctumAuthorizationException(
        'Insufficient permissions for token operation',
        statusCode: statusCode,
      );
    } else if (statusCode == 422) {
      // Validation error for token creation
      final data = response?.data as Map<String, dynamic>?;
      if (data?['errors'] != null) {
        final errors = <String, List<String>>{};
        final errorData = data!['errors'] as Map<String, dynamic>;
        for (final entry in errorData.entries) {
          errors[entry.key] = List<String>.from(
            entry.value is List ? entry.value as List : [entry.value],
          );
        }
        return SanctumValidationException.fromResponse(errors: errors);
      }
    } else if (statusCode == 404) {
      return SanctumTokenException(
        'Token not found',
        statusCode: statusCode,
      );
    }

    // Default to token exception for other errors
    return SanctumTokenException(
      error.message ?? 'Token operation failed',
      statusCode: statusCode,
    );
  }
}

/// Statistics about a user's API tokens
@immutable
class SanctumTokenStats {
  /// Total number of tokens
  final int totalCount;

  /// Number of active (non-expired) tokens
  final int activeCount;

  /// Number of expired tokens
  final int expiredCount;

  /// Number of tokens expiring soon (within 24 hours)
  final int expiringSoonCount;

  /// Count of tokens by ability
  final Map<String, int> abilityCounts;

  /// Creates new token statistics
  const SanctumTokenStats({
    required this.totalCount,
    required this.activeCount,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.abilityCounts,
  });

  /// Percentage of active tokens
  double get activePercentage =>
      totalCount > 0 ? (activeCount / totalCount) * 100 : 0;

  /// Percentage of expired tokens
  double get expiredPercentage =>
      totalCount > 0 ? (expiredCount / totalCount) * 100 : 0;

  /// Most common ability
  String? get mostCommonAbility {
    if (abilityCounts.isEmpty) return null;
    return abilityCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  @override
  String toString() {
    return 'SanctumTokenStats{'
        'total: $totalCount, '
        'active: $activeCount, '
        'expired: $expiredCount, '
        'expiringSoon: $expiringSoonCount'
        '}';
  }
}