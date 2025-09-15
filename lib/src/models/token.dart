import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'token.g.dart';

/// Represents a Laravel Sanctum API token with its metadata
///
/// This model represents the token data returned from Laravel Sanctum
/// when creating or retrieving tokens. It includes the token value,
/// abilities, expiration, and other metadata.
///
/// Example JSON:
/// ```json
/// {
///   "id": 1,
///   "name": "iPhone 12",
///   "token": "1|abc123...",
///   "abilities": ["read", "write"],
///   "expires_at": "2024-01-01T00:00:00.000000Z",
///   "created_at": "2023-01-01T00:00:00.000000Z",
///   "updated_at": "2023-01-01T00:00:00.000000Z",
///   "last_used_at": "2023-12-01T00:00:00.000000Z"
/// }
/// ```
@immutable
@JsonSerializable()
class SanctumToken {
  /// Unique identifier for the token
  final int? id;

  /// Human-readable name for the token (device name)
  final String name;

  /// The actual token value (Bearer token)
  ///
  /// This is the token that should be sent in the Authorization header.
  /// Format: "tokenId|hashedToken"
  final String token;

  /// List of abilities/scopes granted to this token
  ///
  /// These define what actions the token is allowed to perform.
  /// Common abilities include: 'read', 'write', 'delete', '*' (all)
  final List<String> abilities;

  /// Timestamp when the token expires (nullable for non-expiring tokens)
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;

  /// Timestamp when the token was created
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  /// Timestamp when the token was last updated
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  /// Timestamp when the token was last used
  @JsonKey(name: 'last_used_at')
  final DateTime? lastUsedAt;

  /// Creates a new [SanctumToken] instance
  const SanctumToken({
    this.id,
    required this.name,
    required this.token,
    this.abilities = const [],
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
    this.lastUsedAt,
  });

  /// Creates a [SanctumToken] from a JSON map
  factory SanctumToken.fromJson(Map<String, dynamic> json) =>
      _$SanctumTokenFromJson(json);

  /// Converts this [SanctumToken] to a JSON map
  Map<String, dynamic> toJson() => _$SanctumTokenToJson(this);

  /// Creates a copy of this token with the given fields replaced
  SanctumToken copyWith({
    int? id,
    String? name,
    String? token,
    List<String>? abilities,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
  }) {
    return SanctumToken(
      id: id ?? this.id,
      name: name ?? this.name,
      token: token ?? this.token,
      abilities: abilities ?? this.abilities,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  /// Whether this token has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Whether this token will expire soon (within 24 hours)
  bool get willExpireSoon {
    if (expiresAt == null) return false;
    final now = DateTime.now();
    final expiryThreshold = now.add(const Duration(hours: 24));
    return expiresAt!.isBefore(expiryThreshold);
  }

  /// Time remaining until the token expires
  ///
  /// Returns null if the token doesn't expire.
  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }

  /// Whether this token has a specific ability
  ///
  /// Returns true if the token has the specific ability or has the '*' ability
  /// which grants all permissions.
  bool hasAbility(String ability) {
    return abilities.contains('*') || abilities.contains(ability);
  }

  /// Whether this token has any of the specified abilities
  bool hasAnyAbility(List<String> requiredAbilities) {
    if (abilities.contains('*')) return true;
    return requiredAbilities.any((ability) => abilities.contains(ability));
  }

  /// Whether this token has all of the specified abilities
  bool hasAllAbilities(List<String> requiredAbilities) {
    if (abilities.contains('*')) return true;
    return requiredAbilities.every((ability) => abilities.contains(ability));
  }

  /// Gets the token ID from the token string
  ///
  /// Laravel Sanctum tokens have the format "tokenId|hashedToken".
  /// This method extracts and returns the token ID.
  int? get tokenId {
    final parts = token.split('|');
    if (parts.length != 2) return null;
    return int.tryParse(parts[0]);
  }

  /// Gets the hashed portion of the token
  ///
  /// Returns the part after the '|' in the token string.
  String? get hashedToken {
    final parts = token.split('|');
    if (parts.length != 2) return null;
    return parts[1];
  }

  /// Whether this token was used recently (within the last hour)
  bool get wasUsedRecently {
    if (lastUsedAt == null) return false;
    final now = DateTime.now();
    final recentThreshold = now.subtract(const Duration(hours: 1));
    return lastUsedAt!.isAfter(recentThreshold);
  }

  /// Human-readable string describing when the token was last used
  String get lastUsedDescription {
    if (lastUsedAt == null) return 'Never used';

    final now = DateTime.now();
    final difference = now.difference(lastUsedAt!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else {
      return 'Over a month ago';
    }
  }

  /// Human-readable string describing when the token expires
  String get expirationDescription {
    if (expiresAt == null) return 'Never expires';

    if (isExpired) return 'Expired';

    final timeLeft = timeUntilExpiry!;

    if (timeLeft.inDays > 0) {
      return 'Expires in ${timeLeft.inDays} days';
    } else if (timeLeft.inHours > 0) {
      return 'Expires in ${timeLeft.inHours} hours';
    } else {
      return 'Expires in ${timeLeft.inMinutes} minutes';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumToken &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          token == other.token &&
          abilities == other.abilities &&
          expiresAt == other.expiresAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          lastUsedAt == other.lastUsedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        token,
        abilities,
        expiresAt,
        createdAt,
        updatedAt,
        lastUsedAt,
      );

  @override
  String toString() {
    return 'SanctumToken{'
        'id: $id, '
        'name: $name, '
        'abilities: $abilities, '
        'expiresAt: $expiresAt, '
        'isExpired: $isExpired'
        '}';
  }
}

/// Represents the response from token creation endpoint
///
/// When creating a new token, Laravel Sanctum returns both the token
/// and additional metadata about the token that was created.
@immutable
@JsonSerializable()
class SanctumTokenResponse {
  /// The token string that should be used for authentication
  final String token;

  /// The token metadata (optional, may not be included in all responses)
  @JsonKey(name: 'access_token')
  final SanctumToken? accessToken;

  /// Token type (usually "Bearer")
  @JsonKey(name: 'token_type')
  final String tokenType;

  /// Timestamp when the token expires (optional)
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;

  /// Creates a new [SanctumTokenResponse] instance
  const SanctumTokenResponse({
    required this.token,
    this.accessToken,
    this.tokenType = 'Bearer',
    this.expiresAt,
  });

  /// Creates a [SanctumTokenResponse] from a JSON map
  factory SanctumTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$SanctumTokenResponseFromJson(json);

  /// Converts this [SanctumTokenResponse] to a JSON map
  Map<String, dynamic> toJson() => _$SanctumTokenResponseToJson(this);

  /// Gets the authorization header value for this token
  ///
  /// Returns the token in the format expected by the Authorization header:
  /// "Bearer {token}"
  String get authorizationHeaderValue => '$tokenType $token';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumTokenResponse &&
          runtimeType == other.runtimeType &&
          token == other.token &&
          accessToken == other.accessToken &&
          tokenType == other.tokenType &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(token, accessToken, tokenType, expiresAt);

  @override
  String toString() {
    return 'SanctumTokenResponse{'
        'tokenType: $tokenType, '
        'expiresAt: $expiresAt'
        '}';
  }
}

/// Request model for creating new tokens
@immutable
class SanctumTokenRequest {
  /// Human-readable name for the token (usually device name)
  final String name;

  /// List of abilities to grant to the token
  final List<String> abilities;

  /// Optional expiration date for the token
  final DateTime? expiresAt;

  /// Creates a new [SanctumTokenRequest] instance
  const SanctumTokenRequest({
    required this.name,
    this.abilities = const ['*'],
    this.expiresAt,
  });

  /// Converts this request to a JSON map for API submission
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
      'abilities': abilities,
    };

    if (expiresAt != null) {
      json['expires_at'] = expiresAt!.toIso8601String();
    }

    return json;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumTokenRequest &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          abilities == other.abilities &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(name, abilities, expiresAt);

  @override
  String toString() {
    return 'SanctumTokenRequest{'
        'name: $name, '
        'abilities: $abilities, '
        'expiresAt: $expiresAt'
        '}';
  }
}