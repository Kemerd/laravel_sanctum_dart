import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';

import '../models/user.dart';
import '../models/token.dart';
import '../constants/sanctum_constants.dart';
import 'logger.dart';

/// Secure storage implementation for Laravel Sanctum authentication data
///
/// This class provides secure storage for sensitive authentication data like
/// tokens, user information, and refresh tokens. It uses Flutter's secure
/// storage on each platform to ensure data is encrypted and protected.
///
/// The storage automatically handles serialization/deserialization of complex
/// objects and provides a clean API for common authentication storage needs.
@immutable
class SanctumStorage {
  /// The underlying secure storage instance
  final FlutterSecureStorage _storage;

  /// Logger instance for debugging storage operations
  final SanctumLogger _logger;

  /// Key prefix to avoid conflicts with other storage
  final String _keyPrefix;

  /// Creates a new [SanctumStorage] instance
  SanctumStorage({
    FlutterSecureStorage? storage,
    SanctumLogger? logger,
    String keyPrefix = 'sanctum_',
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _logger = logger ?? SanctumLogger(),
        _keyPrefix = keyPrefix;

  /// Creates a storage instance with custom options
  factory SanctumStorage.withOptions({
    AndroidOptions? androidOptions,
    IOSOptions? iosOptions,
    LinuxOptions? linuxOptions,
    WindowsOptions? windowsOptions,
    WebOptions? webOptions,
    MacOsOptions? macOsOptions,
    SanctumLogger? logger,
    String keyPrefix = 'sanctum_',
  }) {
    final storage = FlutterSecureStorage(
      aOptions: androidOptions ?? _defaultAndroidOptions,
      iOptions: iosOptions ?? _defaultIOSOptions,
      lOptions: linuxOptions ?? _defaultLinuxOptions,
      wOptions: windowsOptions ?? _defaultWindowsOptions,
      webOptions: webOptions ?? _defaultWebOptions,
      mOptions: macOsOptions ?? _defaultMacOSOptions,
    );

    return SanctumStorage(
      storage: storage,
      logger: logger,
      keyPrefix: keyPrefix,
    );
  }

  /// Default Android options for secure storage
  static const AndroidOptions _defaultAndroidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    sharedPreferencesName: 'sanctum_preferences',
    preferencesKeyPrefix: 'sanctum_',
  );

  /// Default iOS options for secure storage
  static const IOSOptions _defaultIOSOptions = IOSOptions(
    groupId: null,
    accountName: 'sanctum_keychain',
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  /// Default Linux options for secure storage
  static const LinuxOptions _defaultLinuxOptions = LinuxOptions();

  /// Default Windows options for secure storage
  static const WindowsOptions _defaultWindowsOptions = WindowsOptions();

  /// Default web options for secure storage
  static const WebOptions _defaultWebOptions = WebOptions(
    dbName: 'sanctum_storage',
    publicKey: 'sanctum_public_key',
  );

  /// Default macOS options for secure storage
  static const MacOsOptions _defaultMacOSOptions = MacOsOptions(
    groupId: null,
    accountName: 'sanctum_keychain',
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  /// Generates a prefixed key for storage
  String _key(String key) => '$_keyPrefix$key';

  /// Stores a raw string value
  Future<void> setString(String key, String value) async {
    try {
      final prefixedKey = _key(key);
      await _storage.write(key: prefixedKey, value: value);
      _logger.logCacheOperation(
        operation: 'SET',
        key: key,
        size: value.length,
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to store string for key: $key', e, stackTrace);
      rethrow;
    }
  }

  /// Retrieves a raw string value
  Future<String?> getString(String key) async {
    try {
      final prefixedKey = _key(key);
      final value = await _storage.read(key: prefixedKey);
      _logger.logCacheOperation(
        operation: 'GET',
        key: key,
        size: value?.length,
      );
      return value;
    } catch (e, stackTrace) {
      _logger.error('Failed to retrieve string for key: $key', e, stackTrace);
      return null;
    }
  }

  /// Stores a JSON-serializable object
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    try {
      final jsonString = jsonEncode(value);
      await setString(key, jsonString);
    } catch (e, stackTrace) {
      _logger.error('Failed to store JSON for key: $key', e, stackTrace);
      rethrow;
    }
  }

  /// Retrieves a JSON object
  Future<Map<String, dynamic>?> getJson(String key) async {
    try {
      final jsonString = await getString(key);
      if (jsonString == null) return null;
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      _logger.error('Failed to retrieve JSON for key: $key', e, stackTrace);
      return null;
    }
  }

  /// Stores an authentication token
  Future<void> setToken(String token, {String? key}) async {
    final storageKey = key ?? SanctumConstants.defaultTokenStorageKey;
    await setString(storageKey, token);
    _logger.logTokenOperation(
      operation: 'STORE',
      tokenName: 'Authentication Token',
    );
  }

  /// Retrieves the authentication token
  Future<String?> getToken({String? key}) async {
    final storageKey = key ?? SanctumConstants.defaultTokenStorageKey;
    final token = await getString(storageKey);
    if (token != null) {
      _logger.logTokenOperation(
        operation: 'RETRIEVE',
        tokenName: 'Authentication Token',
      );
    }
    return token;
  }

  /// Stores a SanctumToken object
  Future<void> setSanctumToken(SanctumToken token, {String? key}) async {
    final storageKey = key ?? 'token_object';
    await setJson(storageKey, token.toJson());
    _logger.logTokenOperation(
      operation: 'STORE',
      tokenId: token.id?.toString(),
      tokenName: token.name,
      abilities: token.abilities,
      expiresAt: token.expiresAt,
    );
  }

  /// Retrieves a SanctumToken object
  Future<SanctumToken?> getSanctumToken({String? key}) async {
    final storageKey = key ?? 'token_object';
    final json = await getJson(storageKey);
    if (json == null) return null;

    try {
      final token = SanctumToken.fromJson(json);
      _logger.logTokenOperation(
        operation: 'RETRIEVE',
        tokenId: token.id?.toString(),
        tokenName: token.name,
        abilities: token.abilities,
        expiresAt: token.expiresAt,
      );
      return token;
    } catch (e, stackTrace) {
      _logger.error('Failed to deserialize SanctumToken', e, stackTrace);
      return null;
    }
  }

  /// Stores user data
  Future<void> setUser(SanctumUser user, {String? key}) async {
    final storageKey = key ?? SanctumConstants.defaultUserStorageKey;
    await setJson(storageKey, user.toJson());
    _logger.logAuthEvent(
      event: 'USER_STORED',
      userId: user.id.toString(),
    );
  }

  /// Retrieves user data
  Future<SanctumUser?> getUser({String? key}) async {
    final storageKey = key ?? SanctumConstants.defaultUserStorageKey;
    final json = await getJson(storageKey);
    if (json == null) return null;

    try {
      final user = SanctumUser.fromJson(json);
      _logger.logAuthEvent(
        event: 'USER_RETRIEVED',
        userId: user.id.toString(),
      );
      return user;
    } catch (e, stackTrace) {
      _logger.error('Failed to deserialize SanctumUser', e, stackTrace);
      return null;
    }
  }

  /// Stores refresh token
  Future<void> setRefreshToken(String refreshToken, {String? key}) async {
    final storageKey = key ?? SanctumConstants.defaultRefreshTokenKey;
    await setString(storageKey, refreshToken);
    _logger.logTokenOperation(
      operation: 'STORE',
      tokenName: 'Refresh Token',
    );
  }

  /// Retrieves refresh token
  Future<String?> getRefreshToken({String? key}) async {
    final storageKey = key ?? SanctumConstants.defaultRefreshTokenKey;
    return await getString(storageKey);
  }

  /// Stores token abilities/scopes
  Future<void> setTokenAbilities(List<String> abilities, {String? key}) async {
    final storageKey = key ?? SanctumConstants.defaultAbilitiesKey;
    await setJson(storageKey, {'abilities': abilities});
    _logger.logTokenOperation(
      operation: 'STORE_ABILITIES',
      abilities: abilities,
    );
  }

  /// Retrieves token abilities/scopes
  Future<List<String>?> getTokenAbilities({String? key}) async {
    final storageKey = key ?? SanctumConstants.defaultAbilitiesKey;
    final json = await getJson(storageKey);
    if (json == null) return null;

    try {
      final abilitiesList = json['abilities'] as List<dynamic>? ?? [];
      final abilities = List<String>.from(abilitiesList);
      return abilities;
    } catch (e, stackTrace) {
      _logger.error('Failed to retrieve token abilities', e, stackTrace);
      return null;
    }
  }

  /// Checks if a key exists in storage
  Future<bool> containsKey(String key) async {
    try {
      final prefixedKey = _key(key);
      return await _storage.containsKey(key: prefixedKey);
    } catch (e, stackTrace) {
      _logger.error('Failed to check if key exists: $key', e, stackTrace);
      return false;
    }
  }

  /// Removes a specific key from storage
  Future<void> remove(String key) async {
    try {
      final prefixedKey = _key(key);
      await _storage.delete(key: prefixedKey);
      _logger.logCacheOperation(
        operation: 'DELETE',
        key: key,
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to remove key: $key', e, stackTrace);
      rethrow;
    }
  }

  /// Removes the authentication token
  Future<void> removeToken({String? key}) async {
    final storageKey = key ?? SanctumConstants.defaultTokenStorageKey;
    await remove(storageKey);
    _logger.logTokenOperation(
      operation: 'REMOVE',
      tokenName: 'Authentication Token',
    );
  }

  /// Removes user data
  Future<void> removeUser({String? key}) async {
    final storageKey = key ?? SanctumConstants.defaultUserStorageKey;
    await remove(storageKey);
    _logger.logAuthEvent(event: 'USER_REMOVED');
  }

  /// Removes refresh token
  Future<void> removeRefreshToken({String? key}) async {
    final storageKey = key ?? SanctumConstants.defaultRefreshTokenKey;
    await remove(storageKey);
    _logger.logTokenOperation(
      operation: 'REMOVE',
      tokenName: 'Refresh Token',
    );
  }

  /// Removes all authentication-related data
  Future<void> clearAll() async {
    try {
      await Future.wait([
        removeToken(),
        removeUser(),
        removeRefreshToken(),
        remove(SanctumConstants.defaultAbilitiesKey),
        remove('token_object'),
      ]);
      _logger.logAuthEvent(event: 'STORAGE_CLEARED');
    } catch (e, stackTrace) {
      _logger.error('Failed to clear all authentication data', e, stackTrace);
      rethrow;
    }
  }

  /// Gets all keys with the storage prefix
  Future<List<String>> getAllKeys() async {
    try {
      final allKeys = await _storage.readAll();
      return allKeys.keys
          .where((key) => key.startsWith(_keyPrefix))
          .map((key) => key.substring(_keyPrefix.length))
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to get all keys', e, stackTrace);
      return [];
    }
  }

  /// Gets storage statistics
  Future<SanctumStorageStats> getStats() async {
    try {
      final keys = await getAllKeys();
      int totalSize = 0;
      final Map<String, int> keySizes = {};

      for (final key in keys) {
        final value = await getString(key);
        if (value != null) {
          final size = value.length;
          keySizes[key] = size;
          totalSize += size;
        }
      }

      return SanctumStorageStats(
        keyCount: keys.length,
        totalSize: totalSize,
        keySizes: keySizes,
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to get storage stats', e, stackTrace);
      return const SanctumStorageStats(
        keyCount: 0,
        totalSize: 0,
        keySizes: {},
      );
    }
  }

  /// Exports all authentication data (for backup purposes)
  ///
  /// **WARNING**: This method returns sensitive data in plain text.
  /// Only use this for backup/migration purposes and ensure the result
  /// is handled securely.
  Future<Map<String, String>> exportData() async {
    try {
      final keys = await getAllKeys();
      final Map<String, String> data = {};

      for (final key in keys) {
        final value = await getString(key);
        if (value != null) {
          data[key] = value;
        }
      }

      _logger.warning('Authentication data exported - handle securely!');
      return data;
    } catch (e, stackTrace) {
      _logger.error('Failed to export authentication data', e, stackTrace);
      return {};
    }
  }

  /// Imports authentication data (for restore purposes)
  ///
  /// **WARNING**: This method clears existing data before importing.
  /// Ensure the imported data is from a trusted source.
  Future<void> importData(Map<String, String> data) async {
    try {
      // Clear existing data first
      await clearAll();

      // Import new data
      for (final entry in data.entries) {
        await setString(entry.key, entry.value);
      }

      _logger.info('Authentication data imported successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to import authentication data', e, stackTrace);
      rethrow;
    }
  }
}

/// Statistics about the secure storage usage
@immutable
class SanctumStorageStats {
  /// Number of keys stored
  final int keyCount;

  /// Total size of all stored data in characters
  final int totalSize;

  /// Size of each individual key
  final Map<String, int> keySizes;

  /// Creates new storage statistics
  const SanctumStorageStats({
    required this.keyCount,
    required this.totalSize,
    required this.keySizes,
  });

  /// Average size per key
  double get averageSize => keyCount > 0 ? totalSize / keyCount : 0;

  /// Largest stored item size
  int get maxSize => keySizes.values.isNotEmpty
      ? keySizes.values.reduce((a, b) => a > b ? a : b)
      : 0;

  /// Smallest stored item size
  int get minSize => keySizes.values.isNotEmpty
      ? keySizes.values.reduce((a, b) => a < b ? a : b)
      : 0;

  @override
  String toString() {
    return 'SanctumStorageStats{'
        'keyCount: $keyCount, '
        'totalSize: $totalSize, '
        'averageSize: ${averageSize.toStringAsFixed(1)}'
        '}';
  }
}