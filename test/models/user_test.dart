import 'package:flutter_test/flutter_test.dart';
import 'package:laravel_sanctum_dart/laravel_sanctum_dart.dart';

void main() {
  group('SanctumUser', () {
    final now = DateTime.now();
    final user = SanctumUser(
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      emailVerifiedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    test('should create a user with required fields', () {
      expect(user.id, equals(1));
      expect(user.name, equals('John Doe'));
      expect(user.email, equals('john@example.com'));
      expect(user.emailVerifiedAt, equals(now));
      expect(user.createdAt, equals(now));
      expect(user.updatedAt, equals(now));
    });

    test('should serialize to and from JSON', () {
      final json = user.toJson();
      final userFromJson = SanctumUser.fromJson(json);

      expect(userFromJson.id, equals(user.id));
      expect(userFromJson.name, equals(user.name));
      expect(userFromJson.email, equals(user.email));
      expect(userFromJson.emailVerifiedAt, equals(user.emailVerifiedAt));
      expect(userFromJson.createdAt, equals(user.createdAt));
      expect(userFromJson.updatedAt, equals(user.updatedAt));
    });

    test('should handle custom fields', () {
      final jsonWithCustomFields = {
        'id': 1,
        'name': 'John Doe',
        'email': 'john@example.com',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'avatar_url': 'https://example.com/avatar.jpg',
        'role': 'admin',
      };

      final userWithCustomFields = SanctumUser.fromJson(jsonWithCustomFields);

      expect(userWithCustomFields.hasCustomField('avatar_url'), isTrue);
      expect(userWithCustomFields.hasCustomField('role'), isTrue);
      expect(userWithCustomFields.getCustomField<String>('avatar_url'),
             equals('https://example.com/avatar.jpg'));
      expect(userWithCustomFields.getCustomField<String>('role'), equals('admin'));
    });

    test('should check email verification status', () {
      final verifiedUser = SanctumUser(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        emailVerifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final unverifiedUser = SanctumUser(
        id: 2,
        name: 'Jane Doe',
        email: 'jane@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(verifiedUser.isEmailVerified, isTrue);
      expect(unverifiedUser.isEmailVerified, isFalse);
    });

    test('should generate correct initials', () {
      final johnDoe = SanctumUser(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final singleName = SanctumUser(
        id: 2,
        name: 'Madonna',
        email: 'madonna@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final threeName = SanctumUser(
        id: 3,
        name: 'Mary Jane Watson',
        email: 'mary@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(johnDoe.initials, equals('JD'));
      expect(singleName.initials, equals('M'));
      expect(threeName.initials, equals('MJ'));
    });

    test('should extract first and last names', () {
      final johnDoe = SanctumUser(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final singleName = SanctumUser(
        id: 2,
        name: 'Madonna',
        email: 'madonna@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(johnDoe.firstName, equals('John'));
      expect(johnDoe.lastName, equals('Doe'));
      expect(singleName.firstName, equals('Madonna'));
      expect(singleName.lastName, equals(''));
    });

    test('should support copyWith', () {
      final copy = user.copyWith(name: 'Jane Doe', email: 'jane@example.com');

      expect(copy.id, equals(user.id));
      expect(copy.name, equals('Jane Doe'));
      expect(copy.email, equals('jane@example.com'));
      expect(copy.createdAt, equals(user.createdAt));
      expect(copy.updatedAt, equals(user.updatedAt));
    });

    test('should support equality comparison', () {
      final user1 = SanctumUser(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: now,
        updatedAt: now,
      );

      final user2 = SanctumUser(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: now,
        updatedAt: now,
      );

      final user3 = SanctumUser(
        id: 2,
        name: 'Jane Doe',
        email: 'jane@example.com',
        createdAt: now,
        updatedAt: now,
      );

      expect(user1, equals(user2));
      expect(user1, isNot(equals(user3)));
    });

    test('should have proper toString representation', () {
      final string = user.toString();
      expect(string, contains('SanctumUser'));
      expect(string, contains('id: 1'));
      expect(string, contains('name: John Doe'));
      expect(string, contains('email: john@example.com'));
    });
  });

  group('SanctumUserBasic', () {
    test('should create a basic user', () {
      const user = SanctumUserBasic(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
      );

      expect(user.id, equals(1));
      expect(user.name, equals('John Doe'));
      expect(user.email, equals('john@example.com'));
    });

    test('should serialize to and from JSON', () {
      const user = SanctumUserBasic(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
      );

      final json = user.toJson();
      final userFromJson = SanctumUserBasic.fromJson(json);

      expect(userFromJson.id, equals(user.id));
      expect(userFromJson.name, equals(user.name));
      expect(userFromJson.email, equals(user.email));
    });

    test('should convert to full user', () {
      const basicUser = SanctumUserBasic(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
      );

      final fullUser = basicUser.toFullUser();

      expect(fullUser.id, equals(basicUser.id));
      expect(fullUser.name, equals(basicUser.name));
      expect(fullUser.email, equals(basicUser.email));
      expect(fullUser.createdAt, isA<DateTime>());
      expect(fullUser.updatedAt, isA<DateTime>());
    });

    test('should support equality comparison', () {
      const user1 = SanctumUserBasic(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
      );

      const user2 = SanctumUserBasic(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
      );

      const user3 = SanctumUserBasic(
        id: 2,
        name: 'Jane Doe',
        email: 'jane@example.com',
      );

      expect(user1, equals(user2));
      expect(user1, isNot(equals(user3)));
    });

    test('should have proper toString representation', () {
      const user = SanctumUserBasic(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
      );

      final string = user.toString();
      expect(string, contains('SanctumUserBasic'));
      expect(string, contains('id: 1'));
      expect(string, contains('name: John Doe'));
      expect(string, contains('email: john@example.com'));
    });
  });
}