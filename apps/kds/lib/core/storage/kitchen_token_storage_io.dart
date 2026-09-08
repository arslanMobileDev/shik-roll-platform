import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'kitchen_token_storage.dart';

/// Native terminal-token storage backed by the platform secure enclave
/// (Keychain on iOS/macOS, EncryptedSharedPreferences/Keystore on Android).
KitchenTokenStorage createKitchenTokenStorage() => SecureKitchenTokenStorage();

final class SecureKitchenTokenStorage implements KitchenTokenStorage {
  SecureKitchenTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'kitchen.terminal.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<KitchenSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return KitchenSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(KitchenSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
