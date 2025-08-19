import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' hide Key;
import 'package:encrypt/encrypt.dart' as encrypt show Key;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SecureStorageService {
  static const String _encryptionKeyKey = 'app_encryption_key';
  static const String _sensitiveDataPrefix = 'secure_';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;
  late final Encrypter _encrypter;
  late final IV _iv;

  // Define what data should be encrypted vs stored in plain SharedPreferences
  static const Set<String> _sensitiveKeys = {
    'user_preferences',
    'user_data_',
    'current_user_id',
    'users_list',
  };

  SecureStorageService(this._prefs)
    : _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
          keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
          storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  /// Initialize the secure storage service
  Future<void> initialize() async {
    try {
      // Get or create encryption key
      String? keyString = await _secureStorage.read(key: _encryptionKeyKey);

      if (keyString == null) {
        // Generate new encryption key
        final key = encrypt.Key.fromSecureRandom(32);
        keyString = key.base64;
        await _secureStorage.write(key: _encryptionKeyKey, value: keyString);
        debugPrint('🔐 Generated new encryption key');
      }

      final key = encrypt.Key.fromBase64(keyString);
      _encrypter = Encrypter(AES(key));
      _iv = IV.fromSecureRandom(16);

      // Migrate existing plain text data to encrypted storage
      await _migrateExistingData();

      debugPrint('✅ Secure storage initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing secure storage: $e');
      rethrow;
    }
  }

  /// Migrate existing plain text data to encrypted storage
  Future<void> _migrateExistingData() async {
    try {
      final migrationKey = 'data_encryption_migrated';
      final migrated = _prefs.getBool(migrationKey) ?? false;

      if (migrated) return;

      debugPrint('🔄 Migrating existing data to encrypted storage...');

      // Get all keys from SharedPreferences
      final allKeys = _prefs.getKeys();

      for (final key in allKeys) {
        if (_shouldEncrypt(key)) {
          final value = _prefs.getString(key);
          if (value != null) {
            // Move to encrypted storage
            await setSecureString(key, value);
            // Remove from plain storage
            await _prefs.remove(key);
            debugPrint('🔐 Migrated key: $key');
          }
        }
      }

      // Mark migration as complete
      await _prefs.setBool(migrationKey, true);
      debugPrint('✅ Data migration completed');
    } catch (e) {
      debugPrint('⚠️ Error during data migration: $e');
      // Don't fail initialization if migration fails
    }
  }

  /// Check if a key should be encrypted
  bool _shouldEncrypt(String key) {
    return _sensitiveKeys.any((sensitiveKey) => key.startsWith(sensitiveKey));
  }

  /// Store encrypted string data
  Future<void> setSecureString(String key, String value) async {
    try {
      final encrypted = _encrypter.encrypt(value, iv: _iv);
      final secureKey = '$_sensitiveDataPrefix$key';
      await _secureStorage.write(key: secureKey, value: encrypted.base64);
    } catch (e) {
      debugPrint('❌ Error storing secure string for key $key: $e');
      rethrow;
    }
  }

  /// Retrieve and decrypt string data
  Future<String?> getSecureString(String key) async {
    try {
      final secureKey = '$_sensitiveDataPrefix$key';
      final encryptedValue = await _secureStorage.read(key: secureKey);

      if (encryptedValue == null) return null;

      final encrypted = Encrypted.fromBase64(encryptedValue);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      debugPrint('❌ Error retrieving secure string for key $key: $e');
      return null;
    }
  }

  /// Store encrypted JSON data
  Future<void> setSecureJson(String key, Map<String, dynamic> data) async {
    final jsonString = jsonEncode(data);
    await setSecureString(key, jsonString);
  }

  /// Retrieve and decrypt JSON data
  Future<Map<String, dynamic>?> getSecureJson(String key) async {
    final jsonString = await getSecureString(key);
    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error parsing JSON for key $key: $e');
      return null;
    }
  }

  /// Remove encrypted data
  Future<void> removeSecure(String key) async {
    try {
      final secureKey = '$_sensitiveDataPrefix$key';
      await _secureStorage.delete(key: secureKey);
    } catch (e) {
      debugPrint('❌ Error removing secure data for key $key: $e');
    }
  }

  /// Clear all encrypted data (for privacy compliance)
  Future<void> clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
      debugPrint('🗑️ All secure data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing secure data: $e');
    }
  }

  /// Get all secure storage keys (for debugging/export)
  Future<Map<String, String>> getAllSecureData() async {
    try {
      return await _secureStorage.readAll();
    } catch (e) {
      debugPrint('❌ Error reading all secure data: $e');
      return {};
    }
  }

  /// Generate hash for data integrity verification
  String generateDataHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify data integrity
  bool verifyDataIntegrity(String data, String expectedHash) {
    final actualHash = generateDataHash(data);
    return actualHash == expectedHash;
  }

  /// Export user data for GDPR compliance (encrypted)
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    final userData = <String, dynamic>{};

    try {
      // Get user-specific data
      final userDataKey = 'user_data_$userId';
      final userPrefsKey = 'user_preferences_$userId';

      final userDataJson = await getSecureString(userDataKey);
      final userPrefsJson = await getSecureString(userPrefsKey);

      if (userDataJson != null) {
        userData['userData'] = jsonDecode(userDataJson);
      }

      if (userPrefsJson != null) {
        userData['userPreferences'] = jsonDecode(userPrefsJson);
      }

      // Add metadata
      userData['exportedAt'] = DateTime.now().toIso8601String();
      userData['userId'] = userId;
      userData['dataHash'] = generateDataHash(jsonEncode(userData));

      return userData;
    } catch (e) {
      debugPrint('❌ Error exporting user data: $e');
      rethrow;
    }
  }

  /// Delete all user data for GDPR compliance
  Future<void> deleteUserData(String userId) async {
    try {
      final keysToDelete = ['user_data_$userId', 'user_preferences_$userId'];

      for (final key in keysToDelete) {
        await removeSecure(key);
      }

      debugPrint('🗑️ Deleted all data for user $userId');
    } catch (e) {
      debugPrint('❌ Error deleting user data: $e');
      rethrow;
    }
  }
}
