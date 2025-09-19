import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'user.dart';
import 'token.dart';

part 'auth_response.g.dart';

/// Response model for login operations
///
/// This model represents the response returned from Laravel Sanctum
/// login endpoints. It typically includes the user data, token information,
/// and any additional metadata about the authentication session.
///
/// Example JSON:
/// ```json
/// {
///   "user": {
///     "id": 1,
///     "name": "John Doe",
///     "email": "john@example.com"
///   },
///   "token": "1|abc123...",
///   "token_type": "Bearer",
///   "expires_at": "2024-01-01T00:00:00.000000Z",
///   "abilities": ["read", "write"]
/// }
/// ```
@immutable
@JsonSerializable()
class SanctumLoginResponse {
  /// The authenticated user's data
  final SanctumUserBasic user;

  /// The authentication token
  final String token;

  /// Type of token (usually "Bearer")
  @JsonKey(name: 'token_type')
  final String tokenType;

  /// When the token expires (nullable for non-expiring tokens)
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;

  /// Abilities granted to this token
  final List<String>? abilities;

  /// Additional response data that might be included
  @JsonKey(includeFromJson: false, includeToJson: false)
  final Map<String, dynamic> additionalData;

  /// Creates a new [SanctumLoginResponse] instance
  const SanctumLoginResponse({
    required this.user,
    required this.token,
    this.tokenType = 'Bearer',
    this.expiresAt,
    this.abilities,
    this.additionalData = const {},
  });

  /// Creates a [SanctumLoginResponse] from a JSON map
  factory SanctumLoginResponse.fromJson(Map<String, dynamic> json) {
    // Extract additional data by removing known fields
    final additionalData = Map<String, dynamic>.from(json);
    additionalData.removeWhere((key, value) => [
          'user',
          'token',
          'token_type',
          'expires_at',
          'abilities'
        ].contains(key));

    final response = _$SanctumLoginResponseFromJson(json);
    return SanctumLoginResponse(
      user: response.user,
      token: response.token,
      tokenType: response.tokenType,
      expiresAt: response.expiresAt,
      abilities: response.abilities,
      additionalData: additionalData,
    );
  }

  /// Converts this [SanctumLoginResponse] to a JSON map
  Map<String, dynamic> toJson() {
    final json = _$SanctumLoginResponseToJson(this);
    json.addAll(additionalData);
    return json;
  }

  /// Gets the authorization header value for this token
  String get authorizationHeaderValue => '$tokenType $token';

  /// Whether this token has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Whether this token has a specific ability
  bool hasAbility(String ability) {
    if (abilities == null) return true; // Assume all abilities if not specified
    return abilities!.contains('*') || abilities!.contains(ability);
  }

  /// Converts this login response to a [SanctumToken] instance
  SanctumToken toToken({String? name}) {
    return SanctumToken(
      name: name ?? 'Login Token',
      token: token,
      abilities: abilities ?? ['*'],
      expiresAt: expiresAt,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumLoginResponse &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          token == other.token &&
          tokenType == other.tokenType &&
          expiresAt == other.expiresAt &&
          abilities == other.abilities;

  @override
  int get hashCode => Object.hash(user, token, tokenType, expiresAt, abilities);

  @override
  String toString() {
    return 'SanctumLoginResponse{'
        'user: $user, '
        'tokenType: $tokenType, '
        'expiresAt: $expiresAt, '
        'abilities: $abilities'
        '}';
  }
}

/// Response model for user registration
///
/// Similar to login response but may include additional fields
/// specific to the registration process like email verification status.
@immutable
@JsonSerializable()
class SanctumRegisterResponse {
  /// The newly created user's data
  final SanctumUserBasic user;

  /// The authentication token for the new user
  final String token;

  /// Type of token (usually "Bearer")
  @JsonKey(name: 'token_type')
  final String tokenType;

  /// When the token expires (nullable for non-expiring tokens)
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;

  /// Abilities granted to this token
  final List<String>? abilities;

  /// Whether email verification is required
  @JsonKey(name: 'email_verification_required')
  final bool? emailVerificationRequired;

  /// Additional response data that might be included
  @JsonKey(includeFromJson: false, includeToJson: false)
  final Map<String, dynamic> additionalData;

  /// Creates a new [SanctumRegisterResponse] instance
  const SanctumRegisterResponse({
    required this.user,
    required this.token,
    this.tokenType = 'Bearer',
    this.expiresAt,
    this.abilities,
    this.emailVerificationRequired,
    this.additionalData = const {},
  });

  /// Creates a [SanctumRegisterResponse] from a JSON map
  factory SanctumRegisterResponse.fromJson(Map<String, dynamic> json) {
    // Extract additional data by removing known fields
    final additionalData = Map<String, dynamic>.from(json);
    additionalData.removeWhere((key, value) => [
          'user',
          'token',
          'token_type',
          'expires_at',
          'abilities',
          'email_verification_required'
        ].contains(key));

    final response = _$SanctumRegisterResponseFromJson(json);
    return SanctumRegisterResponse(
      user: response.user,
      token: response.token,
      tokenType: response.tokenType,
      expiresAt: response.expiresAt,
      abilities: response.abilities,
      emailVerificationRequired: response.emailVerificationRequired,
      additionalData: additionalData,
    );
  }

  /// Converts this [SanctumRegisterResponse] to a JSON map
  Map<String, dynamic> toJson() {
    final json = _$SanctumRegisterResponseToJson(this);
    json.addAll(additionalData);
    return json;
  }

  /// Gets the authorization header value for this token
  String get authorizationHeaderValue => '$tokenType $token';

  /// Whether this token has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Converts this register response to a [SanctumLoginResponse]
  SanctumLoginResponse toLoginResponse() {
    return SanctumLoginResponse(
      user: user,
      token: token,
      tokenType: tokenType,
      expiresAt: expiresAt,
      abilities: abilities,
      additionalData: additionalData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumRegisterResponse &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          token == other.token &&
          tokenType == other.tokenType &&
          expiresAt == other.expiresAt &&
          abilities == other.abilities &&
          emailVerificationRequired == other.emailVerificationRequired;

  @override
  int get hashCode => Object.hash(
        user,
        token,
        tokenType,
        expiresAt,
        abilities,
        emailVerificationRequired,
      );

  @override
  String toString() {
    return 'SanctumRegisterResponse{'
        'user: $user, '
        'tokenType: $tokenType, '
        'emailVerificationRequired: $emailVerificationRequired'
        '}';
  }
}

/// Response model for logout operations
@immutable
@JsonSerializable()
class SanctumLogoutResponse {
  /// Success message
  final String message;

  /// Additional response data
  @JsonKey(includeFromJson: false, includeToJson: false)
  final Map<String, dynamic> additionalData;

  /// Creates a new [SanctumLogoutResponse] instance
  const SanctumLogoutResponse({
    this.message = 'Successfully logged out',
    this.additionalData = const {},
  });

  /// Creates a [SanctumLogoutResponse] from a JSON map
  factory SanctumLogoutResponse.fromJson(Map<String, dynamic> json) {
    // Extract additional data by removing known fields
    final additionalData = Map<String, dynamic>.from(json);
    additionalData.removeWhere((key, value) => ['message'].contains(key));

    final response = _$SanctumLogoutResponseFromJson(json);
    return SanctumLogoutResponse(
      message: response.message,
      additionalData: additionalData,
    );
  }

  /// Converts this [SanctumLogoutResponse] to a JSON map
  Map<String, dynamic> toJson() {
    final json = _$SanctumLogoutResponseToJson(this);
    json.addAll(additionalData);
    return json;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumLogoutResponse &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() {
    return 'SanctumLogoutResponse{message: $message}';
  }
}

/// Generic API response wrapper for error handling
@immutable
@JsonSerializable(genericArgumentFactories: true)
class SanctumApiResponse<T> {
  /// Whether the request was successful
  final bool success;

  /// Response data (null if error)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final T? data;

  /// Error message (null if success)
  final String? message;

  /// HTTP status code
  final int? statusCode;

  /// Validation errors (for 422 responses)
  final Map<String, List<String>>? errors;

  /// Additional metadata about the response
  final Map<String, dynamic>? meta;

  /// Creates a new [SanctumApiResponse] instance
  const SanctumApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
    this.errors,
    this.meta,
  });

  /// Creates a successful response
  factory SanctumApiResponse.success({
    required T data,
    int? statusCode,
    Map<String, dynamic>? meta,
  }) {
    return SanctumApiResponse<T>(
      success: true,
      data: data,
      statusCode: statusCode,
      meta: meta,
    );
  }

  /// Creates an error response
  factory SanctumApiResponse.error({
    required String message,
    int? statusCode,
    Map<String, List<String>>? errors,
    Map<String, dynamic>? meta,
  }) {
    return SanctumApiResponse<T>(
      success: false,
      message: message,
      statusCode: statusCode,
      errors: errors,
      meta: meta,
    );
  }

  /// Creates a [SanctumApiResponse] from a JSON map
  factory SanctumApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    return SanctumApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      message: json['message'] as String?,
      statusCode: json['status_code'] as int?,
      errors: json['errors'] != null
          ? Map<String, List<String>>.from(
              (json['errors'] as Map).map(
                (key, value) => MapEntry(
                  key as String,
                  List<String>.from(value is List ? value : [value]),
                ),
              ),
            )
          : null,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }

  /// Converts this [SanctumApiResponse] to a JSON map
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    final json = _$SanctumApiResponseToJson(this, toJsonT);
    if (data != null) {
      json['data'] = toJsonT(data as T);
    }
    return json;
  }

  /// Whether this is a validation error (422 status)
  bool get isValidationError => statusCode == 422 && errors != null;

  /// Gets the first validation error message
  String? get firstError {
    if (errors == null || errors!.isEmpty) return message;
    final firstField = errors!.values.first;
    return firstField.isNotEmpty ? firstField.first : message;
  }

  /// Gets all error messages as a flat list
  List<String> get allErrorMessages {
    final messages = <String>[];
    if (message != null) messages.add(message!);
    if (errors != null) {
      for (final fieldErrors in errors!.values) {
        messages.addAll(fieldErrors);
      }
    }
    return messages;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumApiResponse<T> &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          data == other.data &&
          message == other.message &&
          statusCode == other.statusCode &&
          errors == other.errors &&
          meta == other.meta;

  @override
  int get hashCode => Object.hash(success, data, message, statusCode, errors, meta);

  @override
  String toString() {
    return 'SanctumApiResponse{'
        'success: $success, '
        'statusCode: $statusCode, '
        'message: $message'
        '}';
  }
}