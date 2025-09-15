import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'user.g.dart';

/// Represents an authenticated user in the Laravel Sanctum system
///
/// This model represents the user data returned from Laravel's user endpoint.
/// It includes standard Laravel user fields and can be extended to include
/// custom fields specific to your application.
///
/// Example JSON:
/// ```json
/// {
///   "id": 1,
///   "name": "John Doe",
///   "email": "john@example.com",
///   "email_verified_at": "2023-01-01T00:00:00.000000Z",
///   "created_at": "2023-01-01T00:00:00.000000Z",
///   "updated_at": "2023-01-01T00:00:00.000000Z",
///   "custom_field": "custom_value"
/// }
/// ```
@immutable
@JsonSerializable()
class SanctumUser {
  /// Unique identifier for the user
  final int id;

  /// User's display name
  final String name;

  /// User's email address
  final String email;

  /// Timestamp when the email was verified (nullable)
  @JsonKey(name: 'email_verified_at')
  final DateTime? emailVerifiedAt;

  /// Timestamp when the user was created
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  /// Timestamp when the user was last updated
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  /// Additional custom fields that may be present in the response
  ///
  /// This map contains any extra fields that are not explicitly defined
  /// in this model but are present in the JSON response from your Laravel API.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final Map<String, dynamic> customFields;

  /// Creates a new [SanctumUser] instance
  const SanctumUser({
    required this.id,
    required this.name,
    required this.email,
    this.emailVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
    this.customFields = const {},
  });

  /// Creates a [SanctumUser] from a JSON map
  ///
  /// This factory constructor handles the JSON deserialization and extracts
  /// any custom fields that are not part of the standard user model.
  factory SanctumUser.fromJson(Map<String, dynamic> json) {
    // Extract custom fields by removing known fields
    final customFields = Map<String, dynamic>.from(json);
    customFields.removeWhere((key, value) => [
          'id',
          'name',
          'email',
          'email_verified_at',
          'created_at',
          'updated_at'
        ].contains(key));

    final user = _$SanctumUserFromJson(json);
    return SanctumUser(
      id: user.id,
      name: user.name,
      email: user.email,
      emailVerifiedAt: user.emailVerifiedAt,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      customFields: customFields,
    );
  }

  /// Converts this [SanctumUser] to a JSON map
  ///
  /// Includes both the standard fields and any custom fields that were
  /// present in the original JSON response.
  Map<String, dynamic> toJson() {
    final json = _$SanctumUserToJson(this);
    json.addAll(customFields);
    return json;
  }

  /// Creates a copy of this user with the given fields replaced
  SanctumUser copyWith({
    int? id,
    String? name,
    String? email,
    DateTime? emailVerifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? customFields,
  }) {
    return SanctumUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customFields: customFields ?? this.customFields,
    );
  }

  /// Gets a custom field value by key
  ///
  /// Returns null if the field doesn't exist.
  T? getCustomField<T>(String key) {
    return customFields[key] as T?;
  }

  /// Checks if a custom field exists
  bool hasCustomField(String key) {
    return customFields.containsKey(key);
  }

  /// Whether the user's email has been verified
  bool get isEmailVerified => emailVerifiedAt != null;

  /// Gets the user's initials from their name
  ///
  /// Returns the first letter of each word in the name, up to 2 characters.
  /// Example: "John Doe" returns "JD"
  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0].substring(0, 1).toUpperCase();
    return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'.toUpperCase();
  }

  /// Gets the user's first name
  ///
  /// Returns the first word of the name, or the full name if it's a single word.
  String get firstName {
    final words = name.trim().split(RegExp(r'\s+'));
    return words.isNotEmpty ? words.first : name;
  }

  /// Gets the user's last name
  ///
  /// Returns the last word of the name, or empty string if it's a single word.
  String get lastName {
    final words = name.trim().split(RegExp(r'\s+'));
    return words.length > 1 ? words.last : '';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          emailVerifiedAt == other.emailVerifiedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        email,
        emailVerifiedAt,
        createdAt,
        updatedAt,
      );

  @override
  String toString() {
    return 'SanctumUser{'
        'id: $id, '
        'name: $name, '
        'email: $email, '
        'emailVerifiedAt: $emailVerifiedAt, '
        'isEmailVerified: $isEmailVerified'
        '}';
  }
}

/// Simplified user data for login/register responses
///
/// Some authentication endpoints may return a simplified version of the user
/// data along with the token. This class represents that minimal user info.
@immutable
@JsonSerializable()
class SanctumUserBasic {
  /// Unique identifier for the user
  final int id;

  /// User's display name
  final String name;

  /// User's email address
  final String email;

  /// Creates a new [SanctumUserBasic] instance
  const SanctumUserBasic({
    required this.id,
    required this.name,
    required this.email,
  });

  /// Creates a [SanctumUserBasic] from a JSON map
  factory SanctumUserBasic.fromJson(Map<String, dynamic> json) =>
      _$SanctumUserBasicFromJson(json);

  /// Converts this [SanctumUserBasic] to a JSON map
  Map<String, dynamic> toJson() => _$SanctumUserBasicToJson(this);

  /// Converts this basic user to a full [SanctumUser] instance
  ///
  /// The timestamps will be set to the current time since they're not
  /// available in the basic user data.
  SanctumUser toFullUser() {
    final now = DateTime.now();
    return SanctumUser(
      id: id,
      name: name,
      email: email,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SanctumUserBasic &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email;

  @override
  int get hashCode => Object.hash(id, name, email);

  @override
  String toString() {
    return 'SanctumUserBasic{id: $id, name: $name, email: $email}';
  }
}