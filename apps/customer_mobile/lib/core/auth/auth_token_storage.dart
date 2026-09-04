import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_session.dart';

/// Persistence for the guest [StoredAuthSession] (JWT access + refresh).
abstract interface class AuthTokenStorage {
  Future<StoredAuthSession?> read();
  Future<void> save(StoredAuthSession session);
  Future<void> clear();
}

/// Production storage backed by Keychain (iOS) / EncryptedSharedPreferences
/// (Android) via `flutter_secure_storage`.
final class SecureAuthTokenStorage implements AuthTokenStorage {
  const SecureAuthTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _sessionKey = 'shik.auth.session';

  @override
  Future<StoredAuthSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return StoredAuthSession.decode(raw);
    } on FormatException {
      // Corrupted record: drop it instead of crashing the startup restore.
      await _storage.delete(key: _sessionKey);
      return null;
    }
  }

  @override
  Future<void> save(StoredAuthSession session) =>
      _storage.write(key: _sessionKey, value: session.encode());

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}

/// Volatile storage for widget tests and dev runs without platform plugins.
final class InMemoryAuthTokenStorage implements AuthTokenStorage {
  StoredAuthSession? _session;

  @override
  Future<StoredAuthSession?> read() async => _session;

  @override
  Future<void> save(StoredAuthSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
