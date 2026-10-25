// lib/services/encrypted_config_storage.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_config.dart';

/// Result type for operations that can fail
class EncryptedResult<T> {
  EncryptedResult._(this._value, this._error);
  factory EncryptedResult.success(T value) => EncryptedResult._(value, null);
  factory EncryptedResult.failure(String error) =>
      EncryptedResult._(null, error);

  final T? _value;
  final String? _error;

  bool get isSuccess => _error == null;
  bool get isFailure => _error != null;
  T get value => _value as T;
  String get error => _error!;
}

/// Secure storage wrapper using AES-256-GCM encryption
/// Uses SharedPreferences instead of flutter_secure_storage for cross-platform compatibility
class EncryptedConfigStorage {
  static const String _keyStorageKey = 'encryption_key';
  static const String _serversKey = 'servers_encrypted';
  static const String _hmacKey = 'data_hmac';
  static const String _legacyServersKey = 'servers';
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 12; // 96 bits for GCM

  SharedPreferences? _prefs;
  Uint8List? _encryptionKey;

  EncryptedConfigStorage({SharedPreferences? prefs}) : _prefs = prefs;

  /// Initialize storage and load or generate encryption key
  Future<EncryptedResult<void>> initialize() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _encryptionKey = await _loadOrCreateKey();
      if (_encryptionKey == null) {
        return EncryptedResult.failure('Failed to initialize encryption key');
      }
      return EncryptedResult.success(null);
    } catch (e) {
      return EncryptedResult.failure('Initialization failed: $e');
    }
  }

  /// Load existing key or create new one
  Future<Uint8List?> _loadOrCreateKey() async {
    final existingKey = _prefs!.getString(_keyStorageKey);

    if (existingKey != null) {
      return base64Decode(existingKey);
    }

    // Generate new key
    final key = _generateSecureRandom(_keyLength);
    await _prefs!.setString(_keyStorageKey, base64Encode(key));
    return key;
  }

  /// Generate cryptographically secure random bytes
  Uint8List _generateSecureRandom(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Encrypt data using AES-256-GCM
  String _encrypt(String plaintext, Uint8List key) {
    final iv = _generateSecureRandom(_ivLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          128, // tag length in bits
          iv,
          Uint8List(0), // associated data
        ),
      );

    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
    final ciphertext = cipher.process(plaintextBytes);

    // Prepend IV to ciphertext
    final result = Uint8List(iv.length + ciphertext.length);
    result.setAll(0, iv);
    result.setAll(iv.length, ciphertext);

    return base64Encode(result);
  }

  /// Decrypt data using AES-256-GCM
  String? _decrypt(String encryptedData, Uint8List key) {
    try {
      final data = base64Decode(encryptedData);
      if (data.length < _ivLength) return null;

      final iv = data.sublist(0, _ivLength);
      final ciphertext = data.sublist(_ivLength);

      final cipher = GCMBlockCipher(AESEngine())
        ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));

      final plaintext = cipher.process(ciphertext);
      return utf8.decode(plaintext);
    } catch (e) {
      return null;
    }
  }

  /// Compute HMAC for data integrity
  String _computeHmac(String data, Uint8List key) {
    final hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(key));
    final hash = hmac.process(utf8.encode(data));
    return base64Encode(hash);
  }

  /// Verify HMAC
  bool _verifyHmac(String data, String storedHmac, Uint8List key) {
    final computedHmac = _computeHmac(data, key);
    return computedHmac == storedHmac;
  }

  /// Save servers with encryption
  Future<EncryptedResult<void>> saveServers(List<ServerConfig> servers) async {
    if (_prefs == null) {
      final initResult = await initialize();
      if (initResult.isFailure) return initResult;
    }

    try {
      final jsonString = jsonEncode(servers.map((s) => s.toJson()).toList());

      // Encrypt the data
      final encrypted = _encrypt(jsonString, _encryptionKey!);

      // Compute HMAC for integrity
      final hmac = _computeHmac(jsonString, _encryptionKey!);

      // Store encrypted data and HMAC
      await _prefs!.setString(_serversKey, encrypted);
      await _prefs!.setString(_hmacKey, hmac);

      return EncryptedResult.success(null);
    } catch (e) {
      return EncryptedResult.failure('Failed to save servers: $e');
    }
  }

  /// Load and decrypt servers
  Future<EncryptedResult<List<ServerConfig>>> loadServers() async {
    if (_prefs == null) {
      final initResult = await initialize();
      if (initResult.isFailure)
        return EncryptedResult.failure(initResult.error);
    }

    try {
      final encrypted = _prefs!.getString(_serversKey);
      final storedHmac = _prefs!.getString(_hmacKey);

      if (encrypted == null) {
        // No data yet
        return EncryptedResult.success(<ServerConfig>[]);
      }

      // Decrypt
      final decrypted = _decrypt(encrypted, _encryptionKey!);
      if (decrypted == null) {
        return EncryptedResult.failure(
          'Decryption failed - data may be corrupted',
        );
      }

      // Verify HMAC
      if (storedHmac != null &&
          !_verifyHmac(decrypted, storedHmac, _encryptionKey!)) {
        return EncryptedResult.failure(
          'Data integrity check failed - HMAC mismatch',
        );
      }

      // Parse JSON
      final List<dynamic> jsonList = jsonDecode(decrypted);
      final servers = jsonList
          .map((json) => ServerConfig.fromJson(json as Map<String, dynamic>))
          .toList();

      return EncryptedResult.success(servers);
    } catch (e) {
      return EncryptedResult.failure('Failed to load servers: $e');
    }
  }

  /// Migrate from legacy unencrypted storage
  Future<EncryptedResult<void>> migrate() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final legacyData = _prefs!.getString(_legacyServersKey);

      if (legacyData == null || legacyData.isEmpty) {
        return EncryptedResult.success(null); // Nothing to migrate
      }

      // Parse legacy data
      final List<dynamic> jsonList = jsonDecode(legacyData);
      final servers = jsonList
          .map((json) => ServerConfig.fromJson(json as Map<String, dynamic>))
          .toList();

      // Save with encryption
      final saveResult = await saveServers(servers);
      if (saveResult.isFailure) {
        return saveResult;
      }

      // Remove legacy data
      await _prefs!.remove(_legacyServersKey);

      return EncryptedResult.success(null);
    } catch (e) {
      return EncryptedResult.failure('Migration failed: $e');
    }
  }

  /// Check if migration is needed
  Future<bool> needsMigration() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.containsKey(_legacyServersKey);
  }

  /// Check if encrypted data exists
  Future<bool> hasEncryptedData() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.containsKey(_serversKey);
  }

  /// Clear all stored data
  Future<EncryptedResult<void>> clear() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_serversKey);
      await _prefs!.remove(_hmacKey);
      await _prefs!.remove(_keyStorageKey);
      _encryptionKey = null;
      return EncryptedResult.success(null);
    } catch (e) {
      return EncryptedResult.failure('Failed to clear data: $e');
    }
  }
}
